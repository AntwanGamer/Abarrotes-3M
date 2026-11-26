import 'dart:developer' as dev;
import '../models/departamento.dart';
import '../models/forma_pago.dart';
import '../models/configuracion.dart';
import '../models/helpers.dart';
import '../models/promocion.dart';
import '../services/database_service.dart';

/// Promoción extendida con información legible del producto asociado.
class PromocionConProducto {
  final Promocion promocion;
  final String codigoBarras;
  final String descripcionProducto;

  const PromocionConProducto({
    required this.promocion,
    required this.codigoBarras,
    required this.descripcionProducto,
  });
}

/// Repositorio local-first para catálogos: [tbl_departamentos], [tbl_formas_pago],
/// [tbl_promociones] y [tbl_configuracion].
class CatalogosRepository {
  final DatabaseService _db;

  CatalogosRepository(this._db);

  static CatalogosRepository? _instance;
  static CatalogosRepository get instance {
    _instance ??= CatalogosRepository(DatabaseService.instance);
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Departamentos
  // ---------------------------------------------------------------------------

  /// Obtiene departamentos activos.
  Future<List<Departamento>> obtenerDepartamentos() async {
    final res = await _db.query(
      "SELECT * FROM tbl_departamentos WHERE estatus::text = 'Activo' ORDER BY nombre_departamento ASC",
    );
    return res.map((r) => Departamento.fromMap(r.toColumnMap())).toList();
  }

  /// Crea un departamento nuevo.
  Future<Departamento> crearDepartamento(String nombre) async {
    final now = DateTime.now().toIso8601String();
    final res = await _db.query(
      '''INSERT INTO tbl_departamentos
         (nombre_departamento, estatus, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
         VALUES
         (@nombre, 'Activo', @now, @now, FALSE, @terminal)
         RETURNING *''',
      params: {
        'nombre': nombre.trim(),
        'now': now,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[CatalogosRepository] ✅ Departamento creado: $nombre');
    return Departamento.fromMap(res.first.toColumnMap());
  }

  /// Actualiza el nombre de un departamento.
  Future<void> actualizarDepartamento(int idDepartamento, String nombre) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_departamentos SET
         nombre_departamento = @nombre,
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_departamento = @id''',
      params: {
        'nombre': nombre.trim(),
        'now': now,
        'terminal': _db.terminalId,
        'id': idDepartamento,
      },
    );
  }

  /// Eliminación lógica de un departamento.
  Future<void> eliminarDepartamento(int idDepartamento) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_departamentos SET
         estatus = 'Inactivo',
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_departamento = @id''',
      params: {
        'now': now,
        'terminal': _db.terminalId,
        'id': idDepartamento,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Formas de Pago
  // ---------------------------------------------------------------------------

  /// Obtiene formas de pago activas (Efectivo, Tarjeta, Transferencia, Crédito, Vales).
  Future<List<FormaPago>> obtenerFormasPago() async {
    final res = await _db.query(
      "SELECT * FROM tbl_formas_pago WHERE estatus::text = 'Activo' ORDER BY id_forma_pago",
    );
    return res.map((r) => FormaPago.fromMap(r.toColumnMap())).toList();
  }

  /// Busca una forma de pago por nombre (case-insensitive) y retorna su id_forma_pago.
  Future<int?> obtenerIdFormaPagoPorNombre(String nombre) async {
    final res = await _db.query(
      "SELECT id_forma_pago FROM tbl_formas_pago WHERE LOWER(nombre_forma_pago) = @nombre AND estatus::text = 'Activo' LIMIT 1",
      params: {'nombre': nombre.trim().toLowerCase()},
    );
    if (res.isEmpty) return null;
    return res.first.toColumnMap()['id_forma_pago'] as int?;
  }

  // ---------------------------------------------------------------------------
  // Promociones
  // ---------------------------------------------------------------------------

  /// Obtiene todas las promociones activas junto con la información de su producto.
  Future<List<PromocionConProducto>> obtenerTodasPromociones() async {
    const sql = '''
      SELECT pr.*, p.codigo_barras, p.descripcion
      FROM tbl_promociones pr
      JOIN tbl_productos p ON pr.id_producto = p.id_producto
      WHERE pr.estatus::text = 'Activo'
      ORDER BY pr.fecha_inicio DESC
    ''';
    final res = await _db.query(sql);
    return res.map((r) {
      final m = r.toColumnMap();
      return PromocionConProducto(
        promocion: Promocion.fromMap(m),
        codigoBarras: parsePgString(m['codigo_barras']),
        descripcionProducto: parsePgString(m['descripcion']),
      );
    }).toList();
  }

  /// Crea una nueva promoción en PostgreSQL local.
  Future<Promocion> crearPromocion({
    required String nombrePromocion,
    required int idProducto,
    required String tipoPromocion, // 'Porcentaje' | 'Monto' | 'Multiple'
    required double cantidadMinima,
    double? cantidadPaga,
    required double valorDescuento,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _db.query(
      '''INSERT INTO tbl_promociones
         (nombre_promocion, id_producto, tipo_promocion, cantidad_minima,
          cantidad_paga, valor_descuento, fecha_inicio, fecha_fin,
          estatus, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
         VALUES
         (@nombre, @idProd, @tipo, @cantMin,
          @cantPaga, @valorDesc, @fIni, @fFin,
          'Activo', @now, @now, FALSE, @terminal)
         RETURNING *''',
      params: {
        'nombre': nombrePromocion.trim(),
        'idProd': idProducto,
        'tipo': tipoPromocion,
        'cantMin': cantidadMinima,
        'cantPaga': cantidadPaga,
        'valorDesc': valorDescuento,
        'fIni': fechaInicio.toIso8601String(),
        'fFin': fechaFin.toIso8601String(),
        'now': now,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[CatalogosRepository] ✅ Promoción creada: $nombrePromocion');
    return Promocion.fromMap(res.first.toColumnMap());
  }

  /// Actualiza una promoción existente.
  Future<void> actualizarPromocion({
    required int idPromocion,
    required String nombrePromocion,
    required int idProducto,
    required String tipoPromocion,
    required double cantidadMinima,
    double? cantidadPaga,
    required double valorDescuento,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_promociones SET
         nombre_promocion = @nombre,
         id_producto = @idProd,
         tipo_promocion = @tipo,
         cantidad_minima = @cantMin,
         cantidad_paga = @cantPaga,
         valor_descuento = @valorDesc,
         fecha_inicio = @fIni,
         fecha_fin = @fFin,
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_promocion = @id''',
      params: {
        'nombre': nombrePromocion.trim(),
        'idProd': idProducto,
        'tipo': tipoPromocion,
        'cantMin': cantidadMinima,
        'cantPaga': cantidadPaga,
        'valorDesc': valorDescuento,
        'fIni': fechaInicio.toIso8601String(),
        'fFin': fechaFin.toIso8601String(),
        'now': now,
        'terminal': _db.terminalId,
        'id': idPromocion,
      },
    );
  }

  /// Desactiva una promoción (baja lógica).
  Future<void> desactivarPromocion(int idPromocion) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_promociones SET
         estatus = 'Inactivo',
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_promocion = @id''',
      params: {
        'now': now,
        'terminal': _db.terminalId,
        'id': idPromocion,
      },
    );
  }

  /// Obtiene promociones activas y vigentes para un producto.
  Future<List<Promocion>> obtenerPromocionesVigentes(int idProducto) async {
    final res = await _db.query(
      '''SELECT * FROM tbl_promociones
         WHERE id_producto = @idProd
           AND estatus::text = 'Activo'
           AND CURRENT_DATE BETWEEN fecha_inicio AND fecha_fin''',
      params: {'idProd': idProducto},
    );
    return res.map((r) => Promocion.fromMap(r.toColumnMap())).toList();
  }

  /// Obtiene la configuración del negocio.
  Future<ConfiguracionNegocio?> obtenerConfiguracion() async {
    final res = await _db.query('SELECT * FROM tbl_configuracion LIMIT 1');
    if (res.isEmpty) return null;
    return ConfiguracionNegocio.fromMap(res.first.toColumnMap());
  }

  /// Guarda o actualiza la configuración del negocio en PostgreSQL local.
  Future<void> guardarConfiguracion({
    required String nombreNegocio,
    String? direccionNegocio,
    String? telefonoNegocio,
    String? mensajeTicket,
    required bool imprimirTicket,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existe = await _db.query('SELECT id_configuracion FROM tbl_configuracion LIMIT 1');
    if (existe.isEmpty) {
      await _db.query('''
        INSERT INTO tbl_configuracion
        (nombre_negocio, direccion_negocio, telefono_negocio, mensaje_ticket, imprimir_ticket,
         fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
        VALUES
        (@nombre, @dir, @tel, @msj, @imp, @now, @now, FALSE, @term)
      ''', params: {
        'nombre': nombreNegocio.trim(),
        'dir': direccionNegocio?.trim().isEmpty == true ? null : direccionNegocio?.trim(),
        'tel': telefonoNegocio?.trim().isEmpty == true ? null : telefonoNegocio?.trim(),
        'msj': mensajeTicket?.trim().isEmpty == true ? null : mensajeTicket?.trim(),
        'imp': imprimirTicket,
        'now': now,
        'term': _db.terminalId,
      });
    } else {
      final id = existe.first.toColumnMap()['id_configuracion'];
      await _db.query('''
        UPDATE tbl_configuracion SET
          nombre_negocio = @nombre,
          direccion_negocio = @dir,
          telefono_negocio = @tel,
          mensaje_ticket = @msj,
          imprimir_ticket = @imp,
          fecha_actualizacion = @now,
          sincronizado = FALSE,
          terminal_origen = @term
        WHERE id_configuracion = @id
      ''', params: {
        'nombre': nombreNegocio.trim(),
        'dir': direccionNegocio?.trim().isEmpty == true ? null : direccionNegocio?.trim(),
        'tel': telefonoNegocio?.trim().isEmpty == true ? null : telefonoNegocio?.trim(),
        'msj': mensajeTicket?.trim().isEmpty == true ? null : mensajeTicket?.trim(),
        'imp': imprimirTicket,
        'now': now,
        'term': _db.terminalId,
        'id': id,
      });
    }
  }
}
