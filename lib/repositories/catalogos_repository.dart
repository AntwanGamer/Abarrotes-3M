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
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_departamentos')
          .select()
          .eq('estatus', 'Activo')
          .order('nombre_departamento', ascending: true);
      return (res as List).map((r) => Departamento.fromMap(r as Map<String, dynamic>)).toList();
    }

    final res = await _db.query(
      "SELECT * FROM tbl_departamentos WHERE estatus::text = 'Activo' ORDER BY nombre_departamento ASC",
    );
    return res.map((r) => Departamento.fromMap(r.toColumnMap())).toList();
  }

  /// Crea un departamento nuevo.
  Future<Departamento> crearDepartamento(String nombre) async {
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      final insertData = {
        'nombre_departamento': nombre.trim(),
        'estatus': 'Activo',
        'fecha_registro': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': _db.terminalId,
      };
      final res = await _db.supabase.from('tbl_departamentos').insert(insertData).select().single();
      dev.log('[CatalogosRepository] ✅ Departamento creado en Supabase: $nombre');
      return Departamento.fromMap(res);
    }

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

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_departamentos').update({
        'nombre_departamento': nombre.trim(),
        'fecha_actualizacion': now,
      }).eq('id_departamento', idDepartamento);
      return;
    }

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

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_departamentos').update({
        'estatus': 'Inactivo',
        'fecha_actualizacion': now,
      }).eq('id_departamento', idDepartamento);
      return;
    }

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
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_formas_pago')
          .select()
          .eq('estatus', 'Activo')
          .order('id_forma_pago', ascending: true);
      return (res as List).map((r) => FormaPago.fromMap(r as Map<String, dynamic>)).toList();
    }

    final res = await _db.query(
      "SELECT * FROM tbl_formas_pago WHERE estatus::text = 'Activo' ORDER BY id_forma_pago",
    );
    return res.map((r) => FormaPago.fromMap(r.toColumnMap())).toList();
  }

  /// Busca una forma de pago por nombre (case-insensitive) y retorna su id_forma_pago.
  Future<int?> obtenerIdFormaPagoPorNombre(String nombre) async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_formas_pago')
          .select('id_forma_pago')
          .ilike('nombre_forma_pago', nombre.trim())
          .eq('estatus', 'Activo')
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return res['id_forma_pago'] as int?;
    }

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
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_promociones')
          .select('*, tbl_productos(codigo_barras, descripcion)')
          .eq('estatus', 'Activo')
          .order('fecha_inicio', ascending: false);

      return (res as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final prod = m['tbl_productos'];
        final cod = (prod is Map ? prod['codigo_barras'] : null)?.toString() ?? '';
        final desc = (prod is Map ? prod['descripcion'] : null)?.toString() ?? '';
        return PromocionConProducto(
          promocion: Promocion.fromMap(m),
          codigoBarras: cod,
          descripcionProducto: desc,
        );
      }).toList();
    }

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

  /// Crea una nueva promoción.
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

    if (_db.isCloudOnlyMode) {
      final insertData = {
        'nombre_promocion': nombrePromocion.trim(),
        'id_producto': idProducto,
        'tipo_promocion': tipoPromocion,
        'cantidad_minima': cantidadMinima,
        'cantidad_paga': cantidadPaga,
        'valor_descuento': valorDescuento,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'estatus': 'Activo',
        'fecha_registro': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': _db.terminalId,
      };
      final res = await _db.supabase.from('tbl_promociones').insert(insertData).select().single();
      dev.log('[CatalogosRepository] ✅ Promoción creada en Supabase: $nombrePromocion');
      return Promocion.fromMap(res);
    }

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

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_promociones').update({
        'nombre_promocion': nombrePromocion.trim(),
        'id_producto': idProducto,
        'tipo_promocion': tipoPromocion,
        'cantidad_minima': cantidadMinima,
        'cantidad_paga': cantidadPaga,
        'valor_descuento': valorDescuento,
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin.toIso8601String(),
        'fecha_actualizacion': now,
      }).eq('id_promocion', idPromocion);
      return;
    }

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

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_promociones').update({
        'estatus': 'Inactivo',
        'fecha_actualizacion': now,
      }).eq('id_promocion', idPromocion);
      return;
    }

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
    if (_db.isCloudOnlyMode) {
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      final res = await _db.supabase
          .from('tbl_promociones')
          .select()
          .eq('id_producto', idProducto)
          .eq('estatus', 'Activo')
          .lte('fecha_inicio', nowStr)
          .gte('fecha_fin', nowStr);
      return (res as List).map((r) => Promocion.fromMap(r as Map<String, dynamic>)).toList();
    }

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
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase.from('tbl_configuracion').select().limit(1).maybeSingle();
      if (res == null) return null;
      return ConfiguracionNegocio.fromMap(res);
    }

    final res = await _db.query('SELECT * FROM tbl_configuracion LIMIT 1');
    if (res.isEmpty) return null;
    return ConfiguracionNegocio.fromMap(res.first.toColumnMap());
  }

  /// Guarda o actualiza la configuración del negocio.
  Future<void> guardarConfiguracion({
    required String nombreNegocio,
    String? direccionNegocio,
    String? telefonoNegocio,
    String? mensajeTicket,
    required bool imprimirTicket,
  }) async {
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      final existe = await _db.supabase.from('tbl_configuracion').select('id_configuracion').limit(1).maybeSingle();
      if (existe == null) {
        await _db.supabase.from('tbl_configuracion').insert({
          'nombre_negocio': nombreNegocio.trim(),
          'direccion_negocio': direccionNegocio?.trim().isEmpty == true ? null : direccionNegocio?.trim(),
          'telefono_negocio': telefonoNegocio?.trim().isEmpty == true ? null : telefonoNegocio?.trim(),
          'mensaje_ticket': mensajeTicket?.trim().isEmpty == true ? null : mensajeTicket?.trim(),
          'imprimir_ticket': imprimirTicket,
          'fecha_registro': now,
          'fecha_actualizacion': now,
          'sincronizado': true,
          'terminal_origen': _db.terminalId,
        });
      } else {
        final id = existe['id_configuracion'];
        await _db.supabase.from('tbl_configuracion').update({
          'nombre_negocio': nombreNegocio.trim(),
          'direccion_negocio': direccionNegocio?.trim().isEmpty == true ? null : direccionNegocio?.trim(),
          'telefono_negocio': telefonoNegocio?.trim().isEmpty == true ? null : telefonoNegocio?.trim(),
          'mensaje_ticket': mensajeTicket?.trim().isEmpty == true ? null : mensajeTicket?.trim(),
          'imprimir_ticket': imprimirTicket,
          'fecha_actualizacion': now,
        }).eq('id_configuracion', id);
      }
      return;
    }

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
