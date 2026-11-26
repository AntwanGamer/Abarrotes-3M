import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';
import '../models/corte_caja.dart';
import '../models/movimiento_caja.dart';
import '../services/database_service.dart';

/// Repositorio local-first para [tbl_cortes_caja] y [tbl_movimientos_caja].
class CortesCajaRepository {
  final DatabaseService _db;

  CortesCajaRepository(this._db);

  static CortesCajaRepository? _instance;
  static CortesCajaRepository get instance {
    _instance ??= CortesCajaRepository(DatabaseService.instance);
    return _instance!;
  }

  CorteCaja? _corteActivo;
  CorteCaja? get corteActivo => _corteActivo;
  int? get idCorteActivo => _corteActivo?.idCorte;

  void limpiarCorte() {
    _corteActivo = null;
  }

  /// Consulta el último corte en estado `'Abierto'`.
  Future<CorteCaja?> obtenerUltimoCorteAbierto() async {
    final res = await _db.query(
      '''SELECT c.*, COALESCE(u.nombre_completo, u.nombre_usuario) AS nombre_usuario
         FROM tbl_cortes_caja c
         LEFT JOIN tbl_usuarios u ON c.id_usuario = u.id_usuario
         WHERE c.estatus_corte::text = 'Abierto'
         ORDER BY c.fecha_apertura DESC
         LIMIT 1''',
    );
    if (res.isEmpty) return null;
    return CorteCaja.fromMap(res.first.toColumnMap());
  }

  /// Carga el último corte abierto como activo.
  Future<CorteCaja?> continuarCorteAbierto() async {
    final corte = await obtenerUltimoCorteAbierto();
    _corteActivo = corte;
    if (corte != null) {
      dev.log('[CortesCajaRepository] ✅ Continuando corte #${corte.idCorte}');
    }
    return corte;
  }

  /// Cierra cualquier corte previo abierto e inicia un nuevo corte de caja.
  Future<CorteCaja> iniciarCorteNuevo({
    required int idUsuario,
    required double fondoInicial,
  }) async {
    final terminalId = _db.terminalId;
    final nuevoCorte = await _db.transaction<CorteCaja>((tx) async {
      await tx.execute(
        Sql.named('''UPDATE tbl_cortes_caja
           SET estatus_corte = 'Cerrado',
               fecha_cierre = CURRENT_TIMESTAMP,
               fecha_actualizacion = CURRENT_TIMESTAMP,
               sincronizado = FALSE
           WHERE estatus_corte::text = 'Abierto' '''),
      );

      final res = await tx.execute(
        Sql.named('''INSERT INTO tbl_cortes_caja
           (id_usuario, fecha_apertura, fondo_inicial, total_ventas, total_entradas,
            total_salidas, efectivo_esperado, efectivo_contado, diferencia,
            estatus_corte, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
           VALUES
           (@idUsuario, CURRENT_TIMESTAMP, @fondoInicial, 0, 0,
            0, @fondoInicial, 0, 0,
            'Abierto', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE, @terminal)
           RETURNING *'''),
        parameters: {
          'idUsuario': idUsuario,
          'fondoInicial': fondoInicial,
          'terminal': terminalId,
        },
      );

      final row = res.first.toColumnMap();
      final userRes = await tx.execute(
        Sql.named('SELECT COALESCE(nombre_completo, nombre_usuario) AS nombre FROM tbl_usuarios WHERE id_usuario = @id LIMIT 1'),
        parameters: {'id': idUsuario},
      );
      if (userRes.isNotEmpty) {
        row['nombre_usuario'] = userRes.first.toColumnMap()['nombre'];
      }
      return CorteCaja.fromMap(row);
    });

    _corteActivo = nuevoCorte;
    dev.log('[CortesCajaRepository] ✅ Corte nuevo #${nuevoCorte.idCorte} iniciado.');
    return nuevoCorte;
  }

  /// Registra una Entrada o Salida de efectivo en [tbl_movimientos_caja]
  /// y actualiza [total_entradas] / [total_salidas] y [efectivo_esperado] en [tbl_cortes_caja].
  Future<MovimientoCaja> registrarMovimientoCaja({
    required int idUsuario,
    required String tipoMovimiento, // 'Entrada' | 'Salida'
    required double monto,
    required String concepto,
  }) async {
    final idCorte = _corteActivo?.idCorte;
    if (idCorte == null) {
      throw StateError('No hay un corte de caja abierto.');
    }
    final terminalId = _db.terminalId;

    final mov = await _db.transaction<MovimientoCaja>((tx) async {
      final res = await tx.execute(
        Sql.named('''INSERT INTO tbl_movimientos_caja
           (id_corte, id_usuario, tipo_movimiento, monto, concepto,
            fecha_registro, sincronizado, terminal_origen)
           VALUES
           (@idCorte, @idUsuario, @tipo, @monto, @concepto,
            CURRENT_TIMESTAMP, FALSE, @terminal)
           RETURNING *'''),
        parameters: {
          'idCorte': idCorte,
          'idUsuario': idUsuario,
          'tipo': tipoMovimiento,
          'monto': monto,
          'concepto': concepto.trim(),
          'terminal': terminalId,
        },
      );

      final esEntrada = tipoMovimiento.toLowerCase() == 'entrada';
      final corteRes = await tx.execute(
        Sql.named(esEntrada
            ? '''UPDATE tbl_cortes_caja
                 SET total_entradas = total_entradas + @monto,
                     efectivo_esperado = efectivo_esperado + @monto,
                     fecha_actualizacion = CURRENT_TIMESTAMP,
                     sincronizado = FALSE
                 WHERE id_corte = @idCorte
                 RETURNING *'''
            : '''UPDATE tbl_cortes_caja
                 SET total_salidas = total_salidas + @monto,
                     efectivo_esperado = efectivo_esperado - @monto,
                     fecha_actualizacion = CURRENT_TIMESTAMP,
                     sincronizado = FALSE
                 WHERE id_corte = @idCorte
                 RETURNING *'''),
        parameters: {
          'monto': monto,
          'idCorte': idCorte,
        },
      );

      if (corteRes.isNotEmpty) {
        final updatedRow = corteRes.first.toColumnMap();
        updatedRow['nombre_usuario'] = _corteActivo?.nombreUsuario;
        _corteActivo = CorteCaja.fromMap(updatedRow);
      }

      return MovimientoCaja.fromMap(res.first.toColumnMap());
    });

    dev.log('[CortesCajaRepository] ✅ Movimiento de caja ($tipoMovimiento \$${monto.toStringAsFixed(2)}) registrado.');
    return mov;
  }

  /// Refresca el corte activo desde PostgreSQL local.
  Future<void> refrescarCorteActivo() async {
    if (_corteActivo == null) return;
    final res = await _db.query(
      '''SELECT c.*, COALESCE(u.nombre_completo, u.nombre_usuario) AS nombre_usuario
         FROM tbl_cortes_caja c
         LEFT JOIN tbl_usuarios u ON c.id_usuario = u.id_usuario
         WHERE c.id_corte = @id LIMIT 1''',
      params: {'id': _corteActivo!.idCorte},
    );
    if (res.isNotEmpty) {
      _corteActivo = CorteCaja.fromMap(res.first.toColumnMap());
    }
  }
}

