/// Modelo representativo para un producto en el Inventario y Catálogo.
class ItemInventario {
  final String codigo;
  final String descripcion;
  final String departamento;
  final double costo;
  final double precioVenta;
  final double ganancia;
  final double precioMayoreo;
  final String tipoVenta;
  int existencia;
  final int invMinimo;
  final int invMaximo;

  ItemInventario({
    required this.codigo,
    required this.descripcion,
    required this.departamento,
    required this.costo,
    required this.precioVenta,
    this.ganancia = 20.0,
    this.precioMayoreo = 0.0,
    this.tipoVenta = 'unidad',
    required this.existencia,
    required this.invMinimo,
    required this.invMaximo,
  });

  double get valorInventario => costo * existencia;
}
