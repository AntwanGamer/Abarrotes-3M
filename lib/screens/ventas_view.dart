import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Modelo representativo para los artículos de una venta
class ItemVenta {
  final String codigo;
  final String descripcion;
  final double precioVenta;
  int cantidad;
  final int existencia;

  ItemVenta({
    required this.codigo,
    required this.descripcion,
    required this.precioVenta,
    this.cantidad = 1,
    this.existencia = 100,
  });

  double get importe => precioVenta * cantidad;
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

  void _cobrar() {
    if (_items.isEmpty) {
      _mostrarMensaje('No hay productos en la venta actual', esError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale_rounded, color: AppColors.ventasIcon),
            SizedBox(width: 10),
            Text('Cobrar Venta', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total a pagar: \$${_totalVenta.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            const SizedBox(height: 12),
            Text('Productos: $_totalProductos artículo(s)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _items.clear());
              _mostrarMensaje('¡Venta completada con éxito!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ventasIcon,
              foregroundColor: Colors.white,
            ),
            child: const Text('Completar Venta'),
          ),
        ],
      ),
    );
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
        Expanded(
          child: _buildTablaProductos(),
        ),

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
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.ventasIcon),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
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
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.ventasIcon),
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
          _buildBotonAtajo('F7 Entradas', Icons.arrow_downward_rounded, colorIcono: AppColors.ventasIcon),
          const SizedBox(width: 6),
          _buildBotonAtajo('F8 Salidas', Icons.arrow_upward_rounded, colorIcono: AppColors.error),
          const SizedBox(width: 6),
          _buildBotonAtajo('DEL Borrar Art.', Icons.backspace_outlined, onTap: () {
            if (_items.isNotEmpty) _eliminarItem(_items.length - 1);
          }),
          const SizedBox(width: 6),
          _buildBotonAtajo('F9 - Verificador', Icons.price_check_rounded),
        ],
      ),
    );
  }

  Widget _buildBotonAtajo(String texto, IconData icono, {Color? colorIcono, VoidCallback? onTap}) {
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              border: Border(
                top: BorderSide(color: Color(0xFFD1D5DB)),
                left: BorderSide(color: Color(0xFFD1D5DB)),
                right: BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.ventasIcon),
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
                    child: Text('Código de Barras', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Descripción del Producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Precio Venta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 80,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Cant.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 110,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Importe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                  ),
                ),
                VerticalDivider(width: 1, color: Color(0xFFD1D5DB)),
                SizedBox(
                  width: 90,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Existencia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                        Icon(Icons.shopping_cart_outlined, size: 50, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text(
                          'No hay artículos en la venta',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Escanea o ingresa un código de producto para comenzar.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        height: 38,
                        color: index.isEven ? Colors.white : const Color(0xFFF9FAFB),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(item.codigo, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(item.descripcion, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('\$${item.precioVenta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                            SizedBox(
                              width: 80,
                              child: Center(
                                child: Text('${item.cantidad}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                            // Columna Importe con sutil sombreado verde como en Eleventa
                            Container(
                              width: 110,
                              color: const Color(0xFFECFDF5),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              alignment: Alignment.centerRight,
                              child: Text(
                                '\$${item.importe.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ventasIcon),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                            SizedBox(
                              width: 90,
                              child: Center(
                                child: Text('${item.existencia}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                    _buildBotonInferiorAux('F5 - Cambiar', Icons.swap_horiz_rounded),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('F6 - Pendiente', Icons.pause_circle_outline_rounded),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('Eliminar', Icons.delete_outline_rounded, onTap: _limpiarVenta),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('Asignar cliente', Icons.person_add_alt_rounded),
                  ],
                ),
                const SizedBox(height: 8),

                // Resumen de pago
                Row(
                  children: [
                    Text('Total: \$${_totalVenta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    const Text('Pagó Con: \$0.00', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 16),
                    const Text('Cambio: \$0.00', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  _buildBotonInferiorAux('Reimprimir Último Ticket', Icons.print_outlined),
                  const SizedBox(width: 8),
                  _buildBotonInferiorAux('Ventas del día y Devoluciones', Icons.assessment_outlined),
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
                    icon: const Icon(Icons.point_of_sale_rounded, size: 22, color: Colors.white),
                    label: const Text(
                      'F12 - Cobrar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ventasIcon,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
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
                        color: Color(0xFF1E3A8A), // Azul fuerte característico de Eleventa
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

  Widget _buildBotonInferiorAux(String texto, IconData icono, {VoidCallback? onTap}) {
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
