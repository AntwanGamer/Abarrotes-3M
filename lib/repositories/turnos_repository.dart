import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';
import '../models/turno.dart';
import '../services/database_service.dart';

/// Repositorio local-first para el control de turnos de caja ([tbl_turnos]).
class TurnosRepository {
  final DatabaseService _db;

  TurnosRepository(this._db);

  static TurnosRepository? _instance;
  static TurnosRepository get instance {
    _instance ??= TurnosRepository(DatabaseService.instance);
    return _instance!;
  }

  /// Turno activo actualmente en memoria.
  Turno? _turnoActivo;
  Turno? get turnoActivo => _turnoActivo;
  int? get idTurnoActivo => _turnoActivo?.idTurno;

  void limpiarTurno() {
    _turnoActivo = null;
  }

  /// Consulta el último registro de `tbl_turnos` con `estado_turno = 'Abierto'`.
  Future<Turno?> obtenerUltimoTurnoAbierto() async {
    final result = await _db.query(
      '''SELECT t.*, u.nombre_usuario
         FROM tbl_turnos t
         LEFT JOIN tbl_usuarios u ON t.id_usuario = u.id_usuario
         WHERE t.estado_turno::text = 'Abierto' AND t.estatus::text = 'Activo'
         ORDER BY t.fecha_apertura DESC
         LIMIT 1''',
    );
    if (result.isEmpty) return null;
    return Turno.fromMap(result.first.toColumnMap());
  }

  /// Carga el último turno abierto como turno activo.
  Future<Turno?> continuarTurnoAnterior() async {
    final turno = await obtenerUltimoTurnoAbierto();
    _turnoActivo = turno;
    if (turno != null) {
      dev.log('[TurnosRepository] ✅ Continuando turno #${turno.idTurno} (${turno.nombreUsuario})');
    }
    return turno;
  }

  /// Cierra cualquier turno abierto previo e inicia un nuevo turno en `tbl_turnos`.
  Future<Turno> iniciarTurnoNuevo({
    required int idUsuario,
    required double fondoInicial,
  }) async {
    final terminalId = _db.terminalId;
    final nuevoTurno = await _db.transaction<Turno>((tx) async {
      // Cerrar turnos previos abiertos
      await tx.execute(
        Sql.named('''UPDATE tbl_turnos
           SET estado_turno = 'Cerrado',
               fecha_cierre = CURRENT_TIMESTAMP,
               fecha_actualizacion = CURRENT_TIMESTAMP,
               sincronizado = FALSE
           WHERE estado_turno::text = 'Abierto' '''),
      );

      // Insertar nuevo turno
      final res = await tx.execute(
        Sql.named('''INSERT INTO tbl_turnos
           (id_usuario, fondo_inicial, estado_turno, fecha_apertura,
            estatus, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
           VALUES
           (@idUsuario, @fondoInicial, 'Abierto', CURRENT_TIMESTAMP,
            'Activo', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE, @terminal)
           RETURNING *'''),
        parameters: {
          'idUsuario': idUsuario,
          'fondoInicial': fondoInicial,
          'terminal': terminalId,
        },
      );

      final row = res.first.toColumnMap();
      // Obtener nombre_usuario para mostrar en barra superior
      final userRes = await tx.execute(
        Sql.named('SELECT nombre_usuario FROM tbl_usuarios WHERE id_usuario = @id LIMIT 1'),
        parameters: {'id': idUsuario},
      );
      if (userRes.isNotEmpty) {
        row['nombre_usuario'] = userRes.first.toColumnMap()['nombre_usuario'];
      }
      return Turno.fromMap(row);
    });

    _turnoActivo = nuevoTurno;
    dev.log('[TurnosRepository] ✅ Turno nuevo #${nuevoTurno.idTurno} iniciado con fondo \$${fondoInicial.toStringAsFixed(2)}');
    return nuevoTurno;
  }
}
