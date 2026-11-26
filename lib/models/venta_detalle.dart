import 'helpers.dart';

/// Modelo de datos para [tbl_detalle_ventas] según Diccionario de Datos - Abarrotes 3M.
class VentaDetalle {
  final int idDetalleVenta;
  final int idVenta;
  final int idProducto;
  final int? idPromocion;
  final String descripcionProducto;
  final double cantidad;
  final double precioUnitario;
  final double costoUnitario;
  final double descuento;
  final double importe;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const VentaDetalle({
    required this.idDetalleVenta,
    required this.idVenta,
    required this.idProducto,
    this.idPromocion,
    required this.descripcionProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.costoUnitario,
    this.descuento = 0.0,
    required this.importe,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      idDetalleVenta: parseIntSafe(map['id_detalle_venta']),
      idVenta: parseIntSafe(map['id_venta']),
      idProducto: parseIntSafe(map['id_producto']),
      idPromocion: map['id_promocion'] != null ? parseIntSafe(map['id_promocion']) : null,
      descripcionProducto: parsePgString(map['descripcion_producto']),
      cantidad: parseDecimal(map['cantidad']),
      precioUnitario: parseDecimal(map['precio_unitario']),
      costoUnitario: parseDecimal(map['costo_unitario']),
      descuento: parseDecimal(map['descuento']),
      importe: parseDecimal(map['importe']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}
