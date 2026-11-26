import 'helpers.dart';

/// Modelo de datos para [tbl_abonos_clientes] según Diccionario de Datos - Abarrotes 3M.
class AbonoCliente {
  final int idAbono;
  final int idCliente;
  final int idUsuario;
  final int? idCorte;
  final int idFormaPago;
  final double monto;
  final double saldoPosterior;
  final DateTime fechaRegistro;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  // Auxiliar opcional
  final String? nombreUsuario;
  final String? nombreFormaPago;

  const AbonoCliente({
    required this.idAbono,
    required this.idCliente,
    required this.idUsuario,
    this.idCorte,
    required this.idFormaPago,
    required this.monto,
    required this.saldoPosterior,
    required this.fechaRegistro,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
    this.nombreUsuario,
    this.nombreFormaPago,
  });

  factory AbonoCliente.fromMap(Map<String, dynamic> map) {
    return AbonoCliente(
      idAbono: parseIntSafe(map['id_abono']),
      idCliente: parseIntSafe(map['id_cliente']),
      idUsuario: parseIntSafe(map['id_usuario']),
      idCorte: map['id_corte'] != null ? parseIntSafe(map['id_corte']) : null,
      idFormaPago: parseIntSafe(map['id_forma_pago']),
      monto: parseDecimal(map['monto']),
      saldoPosterior: parseDecimal(map['saldo_posterior']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
      nombreUsuario: parsePgNullableString(map['nombre_usuario']),
      nombreFormaPago: parsePgNullableString(map['nombre_forma_pago']),
    );
  }
}
