import 'helpers.dart';

/// Modelo de datos para [tbl_productos] según Diccionario de Datos - Abarrotes 3M.
class Producto {
  final int idProducto;
  final String codigoBarras;
  final String descripcion;
  final int idDepartamento;
  final String tipoVenta; // 'Unidad' | 'Granel'
  final double precioCosto;
  final double precioVenta;
  final double? precioMayoreo;
  final double? cantidadMayoreo;
  final bool usaInventario;
  final double existencia;
  final double inventarioMinimo;
  final double inventarioMaximo;
  final bool aplicaIva;
  final double tasaIva;
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Producto({
    required this.idProducto,
    required this.codigoBarras,
    required this.descripcion,
    required this.idDepartamento,
    this.tipoVenta = 'Unidad',
    required this.precioCosto,
    required this.precioVenta,
    this.precioMayoreo,
    this.cantidadMayoreo,
    this.usaInventario = true,
    required this.existencia,
    this.inventarioMinimo = 0.0,
    this.inventarioMaximo = 0.0,
    this.aplicaIva = false,
    this.tasaIva = 0.0,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  // Compatibilidad con código anterior
  bool get seVendeAGranel => tipoVenta.toLowerCase() == 'granel';
  double get stockActual => existencia;
  double get stockMinimo => inventarioMinimo;
  int get idCategoria => idDepartamento;

  /// Calcula el precio unitario efectivo según la cantidad (aplica mayoreo si corresponde).
  double precioParaCantidad(double cantidad) {
    if (precioMayoreo != null &&
        cantidadMayoreo != null &&
        cantidadMayoreo! > 0 &&
        cantidad >= cantidadMayoreo!) {
      return precioMayoreo!;
    }
    return precioVenta;
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      idProducto: parseIntSafe(map['id_producto']),
      codigoBarras: parsePgString(map['codigo_barras']),
      descripcion: parsePgString(map['descripcion']),
      idDepartamento: parseIntSafe(map['id_departamento']),
      tipoVenta: parsePgString(map['tipo_venta'], defaultValue: 'Unidad'),
      precioCosto: parseDecimal(map['precio_costo']),
      precioVenta: parseDecimal(map['precio_venta']),
      precioMayoreo: map['precio_mayoreo'] != null ? parseDecimal(map['precio_mayoreo']) : null,
      cantidadMayoreo: map['cantidad_mayoreo'] != null ? parseDecimal(map['cantidad_mayoreo']) : null,
      usaInventario: map['usa_inventario'] != null ? parseBool(map['usa_inventario']) : true,
      existencia: parseDecimal(map['existencia']),
      inventarioMinimo: parseDecimal(map['inventario_minimo']),
      inventarioMaximo: parseDecimal(map['inventario_maximo']),
      aplicaIva: parseBool(map['aplica_iva']),
      tasaIva: parseDecimal(map['tasa_iva']),
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
      'id_producto': idProducto,
      'codigo_barras': codigoBarras,
      'descripcion': descripcion,
      'id_departamento': idDepartamento,
      'tipo_venta': tipoVenta,
      'precio_costo': precioCosto,
      'precio_venta': precioVenta,
      'precio_mayoreo': precioMayoreo,
      'cantidad_mayoreo': cantidadMayoreo,
      'usa_inventario': usaInventario,
      'existencia': existencia,
      'inventario_minimo': inventarioMinimo,
      'inventario_maximo': inventarioMaximo,
      'aplica_iva': aplicaIva,
      'tasa_iva': tasaIva,
      'estatus': estatus,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'uuid_sync': uuidSync,
      'sincronizado': sincronizado,
      'terminal_origen': terminalOrigen,
    };
  }
}
