import 'package:flutter/material.dart';
import '../models/item_inventario.dart';

/// Servicio centralizado y reactivo de Inventario.
/// Permite compartir en tiempo real los productos entre
/// Productos, Inventario y Ventas.
class InventarioService extends ChangeNotifier {
  static final InventarioService _instance = InventarioService._internal();
  factory InventarioService() => _instance;

  InventarioService._internal() {
    _cargarProductosIniciales();
  }

  final List<ItemInventario> _productos = [];

  List<ItemInventario> get productos => List.unmodifiable(_productos);

  double get costoTotal =>
      _productos.fold(0.0, (acc, item) => acc + item.valorInventario);

  int get cantidadTotal =>
      _productos.fold(0, (acc, item) => acc + item.existencia);

  void _cargarProductosIniciales() {
    _productos.addAll([
      ItemInventario(
        codigo: 'NEW PRODUCTO',
        descripcion: 'Prueba 1',
        departamento: 'Abarrotes',
        costo: 10.00,
        precioVenta: 12.00,
        ganancia: 20.0,
        precioMayoreo: 11.50,
        existencia: 15,
        invMinimo: 3,
        invMaximo: 24,
      ),
    ]);
  }

  /// Agrega un nuevo producto o actualiza si el código ya existe
  void agregarOActualizarProducto(ItemInventario nuevo) {
    final codigoNormalizado = nuevo.codigo.trim().toLowerCase();
    final index = _productos.indexWhere(
      (p) => p.codigo.trim().toLowerCase() == codigoNormalizado,
    );

    if (index != -1) {
      _productos[index] = nuevo;
    } else {
      _productos.insert(0, nuevo);
    }
    notifyListeners();
  }

  /// Busca un producto por su código
  ItemInventario? buscarPorCodigo(String codigo) {
    final codigoNormalizado = codigo.trim().toLowerCase();
    try {
      return _productos.firstWhere(
        (p) => p.codigo.trim().toLowerCase() == codigoNormalizado,
      );
    } catch (_) {
      return null;
    }
  }
}
