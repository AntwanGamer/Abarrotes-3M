import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/cliente_db.dart';
import '../repositories/auth_repository.dart';
import '../repositories/clientes_repository.dart';
import '../repositories/cortes_caja_repository.dart';
import '../repositories/ventas_repository.dart';
import '../services/database_service.dart';

/// Modelo representativo para los artículos de una venta
class ItemVenta {
  final int? idProducto;
  final String codigo;
  final String descripcion;
  final double precioVenta;
  final double? precioMayoreo;
  final double? cantidadMayoreo;
  final double costoUnitario;
  int cantidad;
  final int existencia;

  ItemVenta({
    this.idProducto,
    required this.codigo,
    required this.descripcion,
    required this.precioVenta,
    this.precioMayoreo,
    this.cantidadMayoreo,
    this.costoUnitario = 0.0,
    this.cantidad = 1,
    this.existencia = 100,
  });

  /// Precio unitario efectivo: aplica precio de mayoreo automáticamente si corresponde.
  double get precioEfectivo {
    if (precioMayoreo != null &&
        cantidadMayoreo != null &&
        cantidadMayoreo! > 0 &&
        cantidad >= cantidadMayoreo!) {
      return precioMayoreo!;
    }
    return precioVenta;
  }

  double get importe => precioEfectivo * cantidad;
}

/// Vista del módulo de Ventas (Punto de Venta estilo Eleventa).
/// Incluye lector de código, atajos de función, tabla de venta y panel de cobro.
class VentasView extends StatefulWidget {
  const VentasView({super.key});

  @override
  State<VentasView> createState() => _VentasViewState();
}

class _VentasViewState extends State<VentasView> {
  final _codigoController = TextEditingController();
  final List<ItemVenta> _items = [];
  final int _ticketActivo = 1;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  double get _totalVenta => _items.fold(0.0, (acc, item) => acc + item.importe);
  int get _totalProductos => _items.fold(0, (acc, item) => acc + item.cantidad);

  void _agregarProducto() {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      _mostrarMensaje('Ingresa o escanea un código de producto', esError: true);
      return;
    }

    setState(() {
      // Si el producto ya está en la lista, incrementa cantidad
      final index = _items.indexWhere((it) => it.codigo == codigo);
      if (index >= 0) {
        _items[index].cantidad++;
      } else {
        // Agrega un producto de ejemplo según el código
        _items.add(
          ItemVenta(
            codigo: codigo,
            descripcion: 'Producto $codigo (Abarrotes)',
            precioVenta: 25.00,
            cantidad: 1,
            existencia: 50,
          ),
        );
      }
      _codigoController.clear();
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _limpiarVenta() {
    if (_items.isEmpty) return;
    setState(() {
      _items.clear();
    });
    _mostrarMensaje('Venta cancelada / vaciada');
  }

  Future<void> _cobrar() async {
    if (_items.isEmpty) {
      _mostrarMensaje('No hay productos en la venta actual', esError: true);
      return;
    }

    final exito = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoCobroAvanzado(
        totalVenta: _totalVenta,
        totalProductos: _totalProductos,
        items: List<ItemVenta>.from(_items),
      ),
    );

    if (exito == true && mounted) {
      setState(() => _items.clear());
      _mostrarMensaje('¡Venta registrada con éxito!');
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? AppColors.error : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra de entrada de producto (Código + Botón Agregar)
        _buildBarraEntradaProducto(),

        // 2. Barra de atajos rápidos estilo Eleventa (INS Varios, F10 Buscar...)
        _buildBarraAtajos(),

        // 3. Pestaña de Ticket
        _buildPestanaTicket(),

        // 4. Tabla de artículos de la venta
        Expanded(child: _buildTablaProductos()),

        // 5. Barra inferior con resumen, opciones y botón de Cobro (F12)
        _buildBarraInferiorVenta(),
      ],
    );
  }

  /// Barra de entrada de código con botón "ENTER - Agregar Producto"
  Widget _buildBarraEntradaProducto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Text(
            'Código del Producto:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 320,
            height: 36,
            child: TextField(
              controller: _codigoController,
              onSubmitted: (_) => _agregarProducto(),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: AppColors.ventasIcon,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                hintText: 'Ingresa código o escanea...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _agregarProducto,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 16,
                    color: AppColors.ventasIcon,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ENTER - Agregar Producto',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de botones con los atajos rápidos de venta (INS, CTRL+P, F10, F11, etc.)
  Widget _buildBarraAtajos() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        children: [
          _buildBotonAtajo('INS Varios', Icons.post_add_rounded),
          const SizedBox(width: 6),
          _buildBotonAtajo('CTRL+P Art. Común', Icons.shopping_bag_outlined),
          const SizedBox(width: 6),
          _buildBotonAtajo('F10 Buscar', Icons.search_rounded),
          const SizedBox(width: 6),
          _buildBotonAtajo('F11 Mayoreo', Icons.sell_outlined),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'F7 Entradas',
            Icons.arrow_downward_rounded,
            colorIcono: AppColors.ventasIcon,
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'F8 Salidas',
            Icons.arrow_upward_rounded,
            colorIcono: AppColors.error,
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'DEL Borrar Art.',
            Icons.backspace_outlined,
            onTap: () {
              if (_items.isNotEmpty) _eliminarItem(_items.length - 1);
            },
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo('F9 - Verificador', Icons.price_check_rounded),
        ],
      ),
    );
  }

  Widget _buildBotonAtajo(
    String texto,
    IconData icono, {
    Color? colorIcono,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => _mostrarMensaje('$texto seleccionado'),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15, color: colorIcono ?? AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pestaña del Ticket activo (Ticket 1)
  Widget _buildPestanaTicket() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 14,
                  color: AppColors.ventasIcon,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ticket $_ticketActivo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tabla de productos en la venta actual
  Widget _buildTablaProductos() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Encabezado de la tabla estilo Eleventa
          Container(
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E7EB),
              border: Border(
                top: BorderSide(color: Color(0xFFD1D5DB)),
                bottom: BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Código de Barras',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Descripción del Producto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Precio Venta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 80,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Cant.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Importe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 90,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Existencia',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de renglones de la tabla
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 50,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay artículos en la venta',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Escanea o ingresa un código de producto para comenzar.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        height: 38,
                        color: index.isEven
                            ? Colors.white
                            : const Color(0xFFF9FAFB),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  item.codigo,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Color(0xFFF1F3F5),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  item.descripcion,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Color(0xFFF1F3F5),
                            ),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  '\$${item.precioVenta.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Color(0xFFF1F3F5),
                            ),
                            SizedBox(
                              width: 80,
                              child: Center(
                                child: Text(
                                  '${item.cantidad}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Color(0xFFF1F3F5),
                            ),
                            // Columna Importe con sutil sombreado verde como en Eleventa
                            Container(
                              width: 110,
                              color: const Color(0xFFECFDF5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              alignment: Alignment.centerRight,
                              child: Text(
                                '\$${item.importe.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ventasIcon,
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              color: Color(0xFFF1F3F5),
                            ),
                            SizedBox(
                              width: 90,
                              child: Center(
                                child: Text(
                                  '${item.existencia}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Barra inferior con acciones de ticket, total y botón F12 Cobrar
  Widget _buildBarraInferiorVenta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(top: BorderSide(color: Color(0xFFD1D5DB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Lado Izquierdo: Contador, botones auxiliares y resumen
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contador de productos
                Text(
                  '$_totalProductos  Productos en la venta actual.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 8),

                // Botones auxiliares: F5 Cambiar, F6 Pendiente, Eliminar, Asignar cliente
                Row(
                  children: [
                    _buildBotonInferiorAux(
                      'F5 - Cambiar',
                      Icons.swap_horiz_rounded,
                    ),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux(
                      'F6 - Pendiente',
                      Icons.pause_circle_outline_rounded,
                    ),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux(
                      'Eliminar',
                      Icons.delete_outline_rounded,
                      onTap: _limpiarVenta,
                    ),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux(
                      'Asignar cliente',
                      Icons.person_add_alt_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Resumen de pago
                Row(
                  children: [
                    Text(
                      'Total: \$${_totalVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Pagó Con: \$0.00',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Cambio: \$0.00',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lado Derecho: Botón Reimprimir / Ventas del día, F12 Cobrar y Cuadro Gigante de Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botones superiores de la derecha
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBotonInferiorAux(
                    'Reimprimir Último Ticket',
                    Icons.print_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildBotonInferiorAux(
                    'Ventas del día y Devoluciones',
                    Icons.assessment_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Botón Cobrar + Cuadro del Total
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón F12 - Cobrar
                  ElevatedButton.icon(
                    onPressed: _cobrar,
                    icon: const Icon(
                      Icons.point_of_sale_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'F12 - Cobrar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ventasIcon,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Caja gigante del total
                  Container(
                    width: 170,
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      '\$${_totalVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          0xFF1E3A8A,
                        ), // Azul fuerte característico de Eleventa
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonInferiorAux(
    String texto,
    IconData icono, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => _mostrarMensaje(texto),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoCobroAvanzado extends StatefulWidget {
  final double totalVenta;
  final int totalProductos;
  final List<ItemVenta> items;

  const _DialogoCobroAvanzado({
    required this.totalVenta,
    required this.totalProductos,
    required this.items,
  });

  @override
  State<_DialogoCobroAvanzado> createState() => _DialogoCobroAvanzadoState();
}

class _DialogoCobroAvanzadoState extends State<_DialogoCobroAvanzado> {
  String _metodo = 'Efectivo'; // 'Efectivo' | 'Tarjeta' | 'Mixto' | 'Crédito'
  bool _procesando = false;
  String? _errorMsg;

  // Efectivo
  final _pagoConCtrl = TextEditingController();

  // Mixto
  final _mixtoTarjetaCtrl = TextEditingController();
  final _mixtoEfectivoCtrl = TextEditingController();

  // Crédito
  List<ClienteDB> _clientes = [];
  List<ClienteDB> _clientesFiltrados = [];
  ClienteDB? _clienteSeleccionado;
  final _buscarClienteCtrl = TextEditingController();
  bool _cargandoClientes = false;

  @override
  void initState() {
    super.initState();
    _pagoConCtrl.text = widget.totalVenta.toStringAsFixed(2);
    _cargarClientes();
  }

  @override
  void dispose() {
    _pagoConCtrl.dispose();
    _mixtoTarjetaCtrl.dispose();
    _mixtoEfectivoCtrl.dispose();
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _cargandoClientes = true);
    try {
      final lista = await ClientesRepository.instance.obtenerTodos();
      if (mounted) {
        setState(() {
          _clientes = lista;
          _clientesFiltrados = lista;
          _cargandoClientes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoClientes = false);
    }
  }

  void _filtrarClientes(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _clientesFiltrados = _clientes
          .where((c) =>
              c.nombreCompleto.toLowerCase().contains(query) ||
              (c.telefono?.toLowerCase().contains(query) ?? false))
          .toList();
    });
  }

  double get _pagoEfectivo => double.tryParse(_pagoConCtrl.text.trim()) ?? 0.0;
  double get _cambioEfectivo => _pagoEfectivo - widget.totalVenta;

  double get _mixtoTarjeta => double.tryParse(_mixtoTarjetaCtrl.text.trim()) ?? 0.0;
  double get _mixtoEfectivo => double.tryParse(_mixtoEfectivoCtrl.text.trim()) ?? 0.0;
  double get _mixtoRestanteEfectivo => (widget.totalVenta - _mixtoTarjeta).clamp(0.0, double.infinity);
  double get _mixtoCambio => _mixtoEfectivo - _mixtoRestanteEfectivo;

  bool get _puedeConfirmar {
    if (_procesando) return false;
    switch (_metodo) {
      case 'Efectivo':
        return _pagoEfectivo >= widget.totalVenta - 0.001;
      case 'Tarjeta':
        return true;
      case 'Mixto':
        return _mixtoTarjeta > 0 &&
            _mixtoTarjeta < widget.totalVenta &&
            (_mixtoTarjeta + _mixtoEfectivo) >= widget.totalVenta - 0.001;
      case 'Crédito':
        if (_clienteSeleccionado == null) return false;
        final c = _clienteSeleccionado!;
        if (c.tieneLimiteCredito && (c.deudaActual + widget.totalVenta) > c.limiteCredito) {
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _confirmarCobro() async {
    if (!_puedeConfirmar) return;
    setState(() {
      _procesando = true;
      _errorMsg = null;
    });

    try {
      final idUsuario = AuthRepository.instance.usuarioActual?.idUsuario ?? 1;
      final idCorte = CortesCajaRepository.instance.idCorteActivo;
      final lineas = widget.items
          .map((i) => LineaVenta(
                idProducto: i.idProducto ?? 1,
                descripcionProducto: i.descripcion,
                cantidad: i.cantidad.toDouble(),
                precioUnitario: i.precioEfectivo,
                costoUnitario: i.costoUnitario,
              ))
          .toList();

      final pagos = <PagoVentaInput>[];
      bool esCredito = false;
      int? idCliente;

      if (_metodo == 'Efectivo') {
        final cambio = _cambioEfectivo < 0 ? 0.0 : _cambioEfectivo;
        pagos.add(PagoVentaInput(
          nombreFormaPago: 'Efectivo',
          monto: _pagoEfectivo,
          cambio: cambio,
        ));
      } else if (_metodo == 'Tarjeta') {
        pagos.add(PagoVentaInput(
          nombreFormaPago: 'Tarjeta',
          monto: widget.totalVenta,
          cambio: 0.0,
        ));
      } else if (_metodo == 'Mixto') {
        final cambio = _mixtoCambio < 0 ? 0.0 : _mixtoCambio;
        pagos.add(PagoVentaInput(
          nombreFormaPago: 'Tarjeta',
          monto: _mixtoTarjeta,
          cambio: 0.0,
        ));
        pagos.add(PagoVentaInput(
          nombreFormaPago: 'Efectivo',
          monto: _mixtoEfectivo,
          cambio: cambio,
        ));
      } else if (_metodo == 'Crédito') {
        idCliente = _clienteSeleccionado!.idCliente;
        esCredito = true;
        pagos.add(PagoVentaInput(
          nombreFormaPago: 'Crédito',
          monto: widget.totalVenta,
          cambio: 0.0,
        ));
      }

      await VentasRepository(DatabaseService.instance).registrarVenta(
        idUsuario: idUsuario,
        idCliente: idCliente,
        idCorte: idCorte,
        lineas: lineas,
        pagos: pagos,
        esCredito: esCredito,
      );

      await CortesCajaRepository.instance.refrescarCorteActivo();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _procesando = false;
          _errorMsg = 'Error al registrar venta: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: AppColors.ventasIcon),
              SizedBox(width: 10),
              Text('Cobrar Venta', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Total: \$${widget.totalVenta.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de 4 métodos de pago
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Efectivo', label: Text('Efectivo'), icon: Icon(Icons.payments_outlined)),
                  ButtonSegment(value: 'Tarjeta', label: Text('Tarjeta'), icon: Icon(Icons.credit_card)),
                  ButtonSegment(value: 'Mixto', label: Text('Mixto'), icon: Icon(Icons.call_split)),
                  ButtonSegment(value: 'Crédito', label: Text('Crédito'), icon: Icon(Icons.person_outline)),
                ],
                selected: {_metodo},
                onSelectionChanged: (sel) => setState(() {
                  _metodo = sel.first;
                  _errorMsg = null;
                }),
              ),
              const SizedBox(height: 16),

              if (_metodo == 'Efectivo') _buildPanelEfectivo(),
              if (_metodo == 'Tarjeta') _buildPanelTarjeta(),
              if (_metodo == 'Mixto') _buildPanelMixto(),
              if (_metodo == 'Crédito') _buildPanelCredito(),

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _puedeConfirmar ? _confirmarCobro : null,
          icon: _procesando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: const Text('Confirmar Cobro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ventasIcon,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPanelEfectivo() {
    final cambio = _cambioEfectivo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pagoConCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Pago con:',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Exacto'),
              onPressed: () => setState(() => _pagoConCtrl.text = widget.totalVenta.toStringAsFixed(2)),
            ),
            for (final billete in [50, 100, 200, 500])
              ActionChip(
                label: Text('\$$billete'),
                onPressed: () => setState(() => _pagoConCtrl.text = billete.toStringAsFixed(2)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cambio >= 0 ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cambio >= 0 ? Colors.green.shade300 : Colors.red.shade300),
          ),
          child: Text(
            cambio >= 0
                ? 'Cambio: \$${cambio.toStringAsFixed(2)}'
                : 'Falta: \$${(-cambio).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cambio >= 0 ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelTarjeta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pago con Tarjeta (Sin cambio)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Monto a cargar: \$${widget.totalVenta.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildPanelMixto() {
    final restante = _mixtoRestanteEfectivo;
    final cambio = _mixtoCambio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _mixtoTarjetaCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto con Tarjeta',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Text(
          'Restante por cubrir en efectivo: \$${restante.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mixtoEfectivoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Efectivo recibido',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_mixtoTarjeta > 0 && _mixtoTarjeta < widget.totalVenta)
          Text(
            cambio >= 0
                ? 'Cambio en efectivo: \$${cambio.toStringAsFixed(2)}'
                : 'Falta en efectivo: \$${(-cambio).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cambio >= 0 ? Colors.green.shade800 : Colors.red.shade800,
            ),
          )
        else
          const Text(
            'El monto con tarjeta debe ser mayor a \$0 y menor al total.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
      ],
    );
  }

  Widget _buildPanelCredito() {
    final c = _clienteSeleccionado;
    final excede = c != null && c.tieneLimiteCredito && (c.deudaActual + widget.totalVenta) > c.limiteCredito;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _buscarClienteCtrl,
          decoration: const InputDecoration(
            labelText: 'Buscar cliente activo...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _filtrarClientes,
        ),
        const SizedBox(height: 8),
        if (_cargandoClientes)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else
          Container(
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _clientesFiltrados.length,
              itemBuilder: (_, idx) {
                final cli = _clientesFiltrados[idx];
                final sel = _clienteSeleccionado?.idCliente == cli.idCliente;
                return ListTile(
                  dense: true,
                  selected: sel,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  title: Text(cli.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Deuda: \$${cli.deudaActual.toStringAsFixed(2)}'),
                  trailing: Text(
                    cli.tieneLimiteCredito ? 'Lím: \$${cli.limiteCredito.toStringAsFixed(2)}' : 'Sin límite',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => setState(() => _clienteSeleccionado = cli),
                );
              },
            ),
          ),
        if (c != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: excede ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: excede ? Colors.red.shade300 : Colors.green.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: ${c.nombreCompleto}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Deuda actual: \$${c.deudaActual.toStringAsFixed(2)}  •  '
                  'Límite: ${c.tieneLimiteCredito ? '\$${c.limiteCredito.toStringAsFixed(2)}' : 'Sin límite de crédito'}',
                ),
                if (excede)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ Esta venta excede el límite de crédito disponible del cliente.',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
