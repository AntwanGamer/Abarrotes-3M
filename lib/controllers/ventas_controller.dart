import 'package:flutter/foundation.dart';
import '../models/cliente_db.dart';
import '../models/producto.dart';

/// Modelo de partida dentro de un ticket de venta en el POS.
class ItemVenta {
  final int? idProducto;
  final String codigo;
  final String descripcion;
  final double precioVenta;
  final double? precioMayoreo;
  final double? cantidadMayoreo;
  final double costoUnitario;
  double cantidad;
  final double existencia;
  final String tipoVenta; // 'Unidad' | 'Granel'
  bool forzarMayoreo;

  ItemVenta({
    this.idProducto,
    required this.codigo,
    required this.descripcion,
    required this.precioVenta,
    this.precioMayoreo,
    this.cantidadMayoreo,
    this.costoUnitario = 0.0,
    this.cantidad = 1.0,
    this.existencia = 100.0,
    this.tipoVenta = 'Unidad',
    this.forzarMayoreo = false,
  });

  /// Precio unitario efectivo: considera el switch manual o automático de mayoreo.
  double get precioEfectivo {
    if (forzarMayoreo && precioMayoreo != null && precioMayoreo! > 0) {
      return precioMayoreo!;
    }
    if (precioMayoreo != null &&
        cantidadMayoreo != null &&
        cantidadMayoreo! > 0 &&
        cantidad >= cantidadMayoreo!) {
      return precioMayoreo!;
    }
    return precioVenta;
  }

  double get importe => precioEfectivo * cantidad;

  ItemVenta copyWith({
    int? idProducto,
    String? codigo,
    String? descripcion,
    double? precioVenta,
    double? precioMayoreo,
    double? cantidadMayoreo,
    double? costoUnitario,
    double? cantidad,
    double? existencia,
    String? tipoVenta,
    bool? forzarMayoreo,
  }) {
    return ItemVenta(
      idProducto: idProducto ?? this.idProducto,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      precioVenta: precioVenta ?? this.precioVenta,
      precioMayoreo: precioMayoreo ?? this.precioMayoreo,
      cantidadMayoreo: cantidadMayoreo ?? this.cantidadMayoreo,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      cantidad: cantidad ?? this.cantidad,
      existencia: existencia ?? this.existencia,
      tipoVenta: tipoVenta ?? this.tipoVenta,
      forzarMayoreo: forzarMayoreo ?? this.forzarMayoreo,
    );
  }
}

/// Representación en memoria de un ticket abierto en paralelo (Eleventa Multi-ticket).
class TicketVenta {
  final String id;
  String nombre;
  final List<ItemVenta> items;
  ClienteDB? cliente;
  int filaSeleccionada;

  TicketVenta({
    required this.id,
    required this.nombre,
    List<ItemVenta>? items,
    this.cliente,
    this.filaSeleccionada = 0,
  }) : items = items ?? [];

  double get total => items.fold(0.0, (acc, item) => acc + item.importe);
  double get totalProductos => items.fold(0.0, (acc, item) => acc + item.cantidad);
}

/// Controlador global persistente para el módulo de Ventas (fuera del árbol de la vista).
/// Permite conservar todos los tickets abiertos intactos al navegar por otras pestañas.
class VentasController extends ChangeNotifier {
  static VentasController? _instance;
  static VentasController get instance => _instance ??= VentasController();

  final List<TicketVenta> _tickets = [
    TicketVenta(id: '1', nombre: 'Ticket 1'),
  ];
  int _ticketActivoIndex = 0;
  int _contadorSiguienteTicket = 2;

  List<TicketVenta> get tickets => List.unmodifiable(_tickets);
  int get ticketActivoIndex => _ticketActivoIndex;

  TicketVenta get ticketActivo {
    if (_ticketActivoIndex < 0 || _ticketActivoIndex >= _tickets.length) {
      _ticketActivoIndex = 0;
    }
    return _tickets[_ticketActivoIndex];
  }

  String sugerirNombreNuevoTicket() {
    return 'Ticket $_contadorSiguienteTicket';
  }

  /// Crea un nuevo ticket en paralelo y lo activa inmediatamente (F6 - Pendiente).
  void crearTicket([String? nombre]) {
    final nuevoNombre = (nombre != null && nombre.trim().isNotEmpty)
        ? nombre.trim()
        : sugerirNombreNuevoTicket();
    final nuevoId = DateTime.now().millisecondsSinceEpoch.toString();
    final nuevoTicket = TicketVenta(id: nuevoId, nombre: nuevoNombre);

    _tickets.add(nuevoTicket);
    _ticketActivoIndex = _tickets.length - 1;
    _contadorSiguienteTicket++;
    notifyListeners();
  }

  /// Cambia al ticket especificado por índice (F5 - Cambiar).
  void cambiarTicket(int index) {
    if (index >= 0 && index < _tickets.length) {
      _ticketActivoIndex = index;
      notifyListeners();
    }
  }

  /// Cierra un ticket. Si es el único, lo vacía en lugar de dejar la app sin tickets.
  void cerrarTicket(int index) {
    if (index < 0 || index >= _tickets.length) return;

    if (_tickets.length > 1) {
      _tickets.removeAt(index);
      if (_ticketActivoIndex >= _tickets.length) {
        _ticketActivoIndex = _tickets.length - 1;
      }
    } else {
      _tickets[0].items.clear();
      _tickets[0].cliente = null;
      _tickets[0].nombre = 'Ticket 1';
      _tickets[0].filaSeleccionada = 0;
    }
    notifyListeners();
  }

  /// Agrega un [Producto] de la base de datos al ticket activo.
  void agregarProducto(Producto p, {double cantidad = 1.0}) {
    final existenteIndex = ticketActivo.items.indexWhere((it) => it.codigo == p.codigoBarras);
    if (existenteIndex >= 0) {
      ticketActivo.items[existenteIndex].cantidad += cantidad;
      ticketActivo.filaSeleccionada = existenteIndex;
    } else {
      ticketActivo.items.add(
        ItemVenta(
          idProducto: p.idProducto,
          codigo: p.codigoBarras,
          descripcion: p.descripcion,
          precioVenta: p.precioVenta,
          precioMayoreo: p.precioMayoreo,
          cantidadMayoreo: p.cantidadMayoreo,
          costoUnitario: p.precioCosto,
          cantidad: cantidad,
          existencia: p.existencia,
          tipoVenta: p.tipoVenta,
        ),
      );
      ticketActivo.filaSeleccionada = ticketActivo.items.length - 1;
    }
    notifyListeners();
  }

  /// Agrega directamente un [ItemVenta] (ej. Artículo Común o escaneo manual).
  void agregarItem(ItemVenta item) {
    final existenteIndex = ticketActivo.items.indexWhere((it) => it.codigo == item.codigo);
    if (existenteIndex >= 0 && item.idProducto != null) {
      ticketActivo.items[existenteIndex].cantidad += item.cantidad;
      ticketActivo.filaSeleccionada = existenteIndex;
    } else {
      ticketActivo.items.add(item);
      ticketActivo.filaSeleccionada = ticketActivo.items.length - 1;
    }
    notifyListeners();
  }

  /// Elimina una fila del ticket activo (DEL Borrar Art.).
  void eliminarItem(int index) {
    if (index >= 0 && index < ticketActivo.items.length) {
      ticketActivo.items.removeAt(index);
      if (ticketActivo.filaSeleccionada >= ticketActivo.items.length) {
        ticketActivo.filaSeleccionada = ticketActivo.items.length - 1;
      }
      if (ticketActivo.filaSeleccionada < 0) {
        ticketActivo.filaSeleccionada = 0;
      }
      notifyListeners();
    }
  }

  /// Alterna el precio de mayoreo forzado en una partida (F11 Mayoreo).
  void alternarMayoreo(int index) {
    if (index >= 0 && index < ticketActivo.items.length) {
      final it = ticketActivo.items[index];
      if (it.precioMayoreo != null && it.precioMayoreo! > 0) {
        it.forzarMayoreo = !it.forzarMayoreo;
        notifyListeners();
      }
    }
  }

  /// Limpia los artículos del ticket activo (botón Eliminar).
  void limpiarTicketActual() {
    ticketActivo.items.clear();
    ticketActivo.cliente = null;
    ticketActivo.filaSeleccionada = 0;
    notifyListeners();
  }

  /// Vincula o desvincula un cliente del ticket activo.
  void asignarCliente(ClienteDB? cliente) {
    ticketActivo.cliente = cliente;
    notifyListeners();
  }

  /// Navega la selección de filas con el teclado.
  void moverFila(int delta) {
    if (ticketActivo.items.isEmpty) return;
    final nueva = (ticketActivo.filaSeleccionada + delta).clamp(0, ticketActivo.items.length - 1);
    if (nueva != ticketActivo.filaSeleccionada) {
      ticketActivo.filaSeleccionada = nueva;
      notifyListeners();
    }
  }

  /// Selecciona directamente una fila.
  void seleccionarFila(int index) {
    if (index >= 0 && index < ticketActivo.items.length) {
      ticketActivo.filaSeleccionada = index;
      notifyListeners();
    }
  }
}
