import 'helpers.dart';

/// Modelo de datos para [tbl_departamentos] (reemplaza a tbl_categorias).
class Departamento {
  final int idDepartamento;
  final String nombreDepartamento;
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Departamento({
    required this.idDepartamento,
    required this.nombreDepartamento,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory Departamento.fromMap(Map<String, dynamic> map) {
    return Departamento(
      idDepartamento: parseIntSafe(map['id_departamento']),
      nombreDepartamento: parsePgString(map['nombre_departamento']),
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id_departamento': idDepartamento,
        'nombre_departamento': nombreDepartamento,
        'estatus': estatus,
        'fecha_registro': fechaRegistro.toIso8601String(),
        'fecha_actualizacion': fechaActualizacion.toIso8601String(),
        'uuid_sync': uuidSync,
        'sincronizado': sincronizado,
        'terminal_origen': terminalOrigen,
      };
}

