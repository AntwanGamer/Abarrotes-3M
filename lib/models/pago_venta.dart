import 'helpers.dart';

/// Modelo de datos para [tbl_pagos_venta].
class PagoVenta {
  final int idPagoVenta;
  final int idVenta;
  final int idFormaPago;
  final double monto;
  final double cambio;
  final DateTime fechaRegistro;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const PagoVenta({
    required this.idPagoVenta,
    required this.idVenta,
    required this.idFormaPago,
    required this.monto,
    this.cambio = 0.0,
    required this.fechaRegistro,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory PagoVenta.fromMap(Map<String, dynamic> map) {
    return PagoVenta(
      idPagoVenta: parseIntSafe(map['id_pago_venta']),
      idVenta: parseIntSafe(map['id_venta']),
      idFormaPago: parseIntSafe(map['id_forma_pago']),
      monto: parseDecimal(map['monto']),
      cambio: parseDecimal(map['cambio']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}

