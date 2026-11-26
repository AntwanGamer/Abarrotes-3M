import 'helpers.dart';

/// Modelo de datos para [tbl_turnos].
class Turno {
  final int idTurno;
  final int idUsuario;
  final double fondoInicial;
  final double? fondoFinal;
  final String estadoTurno; // 'Abierto' | 'Cerrado'
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final String estatus; // 'Activo' | 'Inactivo'
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;

  // --- Campos de sincronización ---
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  // --- Campo auxiliar opcional (JOIN con tbl_usuarios) ---
  final String? nombreUsuario;

  const Turno({
    required this.idTurno,
    required this.idUsuario,
    required this.fondoInicial,
    this.fondoFinal,
    this.estadoTurno = 'Abierto',
    required this.fechaApertura,
    this.fechaCierre,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
    this.nombreUsuario,
  });

  bool get estaAbierto => estadoTurno.toLowerCase() == 'abierto';

  factory Turno.fromMap(Map<String, dynamic> map) {
    return Turno(
      idTurno: parseIntSafe(map['id_turno']),
      idUsuario: parseIntSafe(map['id_usuario']),
      fondoInicial: parseDecimal(map['fondo_inicial']),
      fondoFinal: map['fondo_final'] != null ? parseDecimal(map['fondo_final']) : null,
      estadoTurno: parsePgString(map['estado_turno'], defaultValue: 'Abierto'),
      fechaApertura: parseDateTime(map['fecha_apertura']),
      fechaCierre: map['fecha_cierre'] != null ? parseDateTime(map['fecha_cierre']) : null,
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
      nombreUsuario: parsePgNullableString(map['nombre_usuario']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_turno': idTurno,
      'id_usuario': idUsuario,
      'fondo_inicial': fondoInicial,
      'fondo_final': fondoFinal,
      'estado_turno': estadoTurno,
      'fecha_apertura': fechaApertura.toIso8601String(),
      'fecha_cierre': fechaCierre?.toIso8601String(),
      'estatus': estatus,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'uuid_sync': uuidSync,
      'sincronizado': sincronizado,
      'terminal_origen': terminalOrigen,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    final m = toMap();
    m.remove('id_turno');
    return m;
  }
}

