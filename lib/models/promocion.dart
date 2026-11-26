import 'helpers.dart';

/// Modelo de datos para [tbl_promociones].
class Promocion {
  final int idPromocion;
  final String nombrePromocion;
  final int idProducto;
  final String tipoPromocion; // 'Porcentaje' | 'Monto' | 'Multiple'
  final double cantidadMinima;
  final double? cantidadPaga;
  final double valorDescuento;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Promocion({
    required this.idPromocion,
    required this.nombrePromocion,
    required this.idProducto,
    required this.tipoPromocion,
    required this.cantidadMinima,
    this.cantidadPaga,
    required this.valorDescuento,
    required this.fechaInicio,
    required this.fechaFin,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory Promocion.fromMap(Map<String, dynamic> map) {
    return Promocion(
      idPromocion: parseIntSafe(map['id_promocion']),
      nombrePromocion: parsePgString(map['nombre_promocion']),
      idProducto: parseIntSafe(map['id_producto']),
      tipoPromocion: parsePgString(map['tipo_promocion'], defaultValue: 'Porcentaje'),
      cantidadMinima: parseDecimal(map['cantidad_minima']),
      cantidadPaga: map['cantidad_paga'] != null ? parseDecimal(map['cantidad_paga']) : null,
      valorDescuento: parseDecimal(map['valor_descuento']),
      fechaInicio: parseDateTime(map['fecha_inicio']),
      fechaFin: parseDateTime(map['fecha_fin']),
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}

