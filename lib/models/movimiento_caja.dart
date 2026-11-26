import 'helpers.dart';

/// Modelo de datos para [tbl_movimientos_caja].
class MovimientoCaja {
  final int idMovimientoCaja;
  final int idCorte;
  final int idUsuario;
  final String tipoMovimiento; // 'Entrada' | 'Salida'
  final double monto;
  final String concepto;
  final DateTime fechaRegistro;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const MovimientoCaja({
    required this.idMovimientoCaja,
    required this.idCorte,
    required this.idUsuario,
    required this.tipoMovimiento,
    required this.monto,
    required this.concepto,
    required this.fechaRegistro,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory MovimientoCaja.fromMap(Map<String, dynamic> map) {
    return MovimientoCaja(
      idMovimientoCaja: parseIntSafe(map['id_movimiento_caja']),
      idCorte: parseIntSafe(map['id_corte']),
      idUsuario: parseIntSafe(map['id_usuario']),
      tipoMovimiento: parsePgString(map['tipo_movimiento'], defaultValue: 'Entrada'),
      monto: parseDecimal(map['monto']),
      concepto: parsePgString(map['concepto']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}

