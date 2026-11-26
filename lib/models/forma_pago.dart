import 'helpers.dart';

/// Modelo de datos para [tbl_formas_pago].
class FormaPago {
  final int idFormaPago;
  final String nombreFormaPago; // 'Efectivo', 'Tarjeta', 'Transferencia', 'Crédito', 'Vales'
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const FormaPago({
    required this.idFormaPago,
    required this.nombreFormaPago,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory FormaPago.fromMap(Map<String, dynamic> map) {
    return FormaPago(
      idFormaPago: parseIntSafe(map['id_forma_pago']),
      nombreFormaPago: parsePgString(map['nombre_forma_pago']),
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}

