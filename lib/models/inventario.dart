import 'helpers.dart';

/// Modelo de datos para [tbl_movimientos_inventario] (Kardex).
class Inventario {
  final int idMovimiento;
  final int idProducto;
  final int idUsuario;
  final String tipoMovimiento; // 'Venta' | 'Entrada' | 'Salida' | 'Ajuste' | etc.
  final double cantidad;
  final double existenciaAnterior;
  final double existenciaNueva;
  final int? idReferencia;
  final String? motivo;
  final DateTime fechaRegistro;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Inventario({
    required this.idMovimiento,
    required this.idProducto,
    required this.idUsuario,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.existenciaAnterior,
    required this.existenciaNueva,
    this.idReferencia,
    this.motivo,
    required this.fechaRegistro,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory Inventario.fromMap(Map<String, dynamic> map) {
    return Inventario(
      idMovimiento: parseIntSafe(map['id_movimiento'] ?? map['id_movimiento_inventario']),
      idProducto: parseIntSafe(map['id_producto']),
      idUsuario: parseIntSafe(map['id_usuario']),
      tipoMovimiento: parsePgString(map['tipo_movimiento'], defaultValue: 'Salida'),
      cantidad: parseDecimal(map['cantidad']),
      existenciaAnterior: parseDecimal(map['existencia_anterior']),
      existenciaNueva: parseDecimal(map['existencia_nueva']),
      idReferencia: map['id_referencia'] != null ? parseIntSafe(map['id_referencia']) : null,
      motivo: parsePgNullableString(map['motivo']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}
