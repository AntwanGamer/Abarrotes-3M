import 'helpers.dart';

/// Modelo de datos para [tbl_categorias].
class Categoria {
  final int idCategoria;
  final String nombre;
  final String? descripcion;
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;

  // --- Campos de sincronización ---
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Categoria({
    required this.idCategoria,
    required this.nombre,
    this.descripcion,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      idCategoria: parseIntSafe(map['id_categoria']),
      nombre: parsePgString(map['nombre']),
      descripcion: parsePgNullableString(map['descripcion']),
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_categoria': idCategoria,
      'nombre': nombre,
      'descripcion': descripcion,
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
    m.remove('id_categoria');
    return m;
  }
}

