import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../controllers/ventas_controller.dart';
import '../models/cliente_db.dart';
import '../models/helpers.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../models/venta_detalle.dart';
import '../repositories/auth_repository.dart';
import '../repositories/clientes_repository.dart';
import '../repositories/cortes_caja_repository.dart';
import '../repositories/productos_repository.dart';
import '../repositories/ventas_repository.dart';
import '../services/database_service.dart';

export '../controllers/ventas_controller.dart' show ItemVenta, TicketVenta;

/// Vista del módulo de Ventas (Punto de Venta Eleventa 100% Teclado Primero).
/// Integra persistencia global multi-ticket (VentasController), auto-enfoque al escribir,
/// navegación por filas y todos los atajos de función F5..F12, INS, CTRL+P, DEL.
class VentasView extends StatefulWidget {
  const VentasView({super.key});

  @override
  State<VentasView> createState() => _VentasViewState();
}

class _VentasViewState extends State<VentasView> {
  final _controller = VentasController.instance;
  final _codigoController = TextEditingController();
  final _codigoFocusNode = FocusNode();
  final _tecladoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onVentasChanged);
    _codigoFocusNode.addListener(_onFocusChanged);
    HardwareKeyboard.instance.addHandler(_capturarTecladoVentas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asegurarFoco();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_capturarTecladoVentas);
    _codigoFocusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onVentasChanged);
    _codigoController.dispose();
    _codigoFocusNode.dispose();
    _tecladoFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_codigoFocusNode.hasFocus && mounted) {
      // Re-enfocar automáticamente si no hay un diálogo o modal activo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _asegurarFoco();
      });
    }
  }

  void _asegurarFoco() {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent && !_codigoFocusNode.hasFocus) {
      _codigoFocusNode.requestFocus();
    }
  }

  bool _capturarTecladoVentas(KeyEvent event) {
    if (!mounted) return false;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) return false;

    // Si el usuario escribe caracteres y el foco se perdió o está fuera, asegurar que entre a _codigoFocusNode
    if (event is KeyDownEvent &&
        event.character != null &&
        event.character!.isNotEmpty &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !_codigoFocusNode.hasFocus) {
      _codigoFocusNode.requestFocus();
      _codigoController.text += event.character!;
      _codigoController.selection = TextSelection.fromPosition(
        TextPosition(offset: _codigoController.text.length),
      );
      return true;
    }
    return false;
  }

  void _onVentasChanged() {
    if (mounted) setState(() {});
  }

  TicketVenta get _ticketActivo => _controller.ticketActivo;
  List<ItemVenta> get _items => _ticketActivo.items;
  double get _totalVenta => _ticketActivo.total;
  double get _totalProductos => _ticketActivo.totalProductos;

  // ---------------------------------------------------------------------------
  // Manejo del Lector y Entrada de Código
  // ---------------------------------------------------------------------------

  Future<void> _procesarCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      if (_items.isNotEmpty) {
        // Si el campo está vacío y hay productos, navegar sobre las filas
        _controller.moverFila(1);
      } else {
        _mostrarMensaje('Ingresa o escanea un código de producto', esError: true);
      }
      return;
    }

    try {
      // Buscar producto en la base de datos local
      final prod = await ProductosRepository.instance.buscarPorCodigo(codigo);
      if (prod != null) {
        _controller.agregarProducto(prod);
        _codigoController.clear();
        _codigoFocusNode.requestFocus();
      } else {
        // Intentar buscar por descripción si coincide
        final porDesc = await ProductosRepository.instance.buscarPorDescripcion(codigo);
        if (porDesc.isNotEmpty) {
          _controller.agregarProducto(porDesc.first);
          _codigoController.clear();
          _codigoFocusNode.requestFocus();
        } else {
          _mostrarMensaje('Producto no encontrado ($codigo)', esError: true);
          _codigoController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _codigoController.text.length,
          );
          _codigoFocusNode.requestFocus();
        }
      }
    } catch (e) {
      _mostrarMensaje('Error al buscar producto: $e', esError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Atajos de Teclado y Modales
  // ---------------------------------------------------------------------------

  void _manejarTeclaGlobal(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // CTRL + P: Artículo Común
    if (isCtrl && key == LogicalKeyboardKey.keyP) {
      _abrirArticuloComun();
      return;
    }

    // Tecla Insert: INS Varios
    if (key == LogicalKeyboardKey.insert) {
      _abrirInsVarios();
      return;
    }

    // Tecla Delete / Supr: Borrar partida seleccionada
    if (key == LogicalKeyboardKey.delete) {
      _eliminarItemSeleccionado();
      return;
    }

    // F5: Cambiar ticket
    if (key == LogicalKeyboardKey.f5) {
      _abrirCambiarTicket();
      return;
    }

    // F6: Ticket pendiente (nuevo ticket con nombre)
    if (key == LogicalKeyboardKey.f6) {
      _abrirNuevoTicket();
      return;
    }

    // F7: Entradas de dinero a caja
    if (key == LogicalKeyboardKey.f7) {
      _abrirEntradaSalidaCaja('Entrada');
      return;
    }

    // F8: Salidas de dinero de caja
    if (key == LogicalKeyboardKey.f8) {
      _abrirEntradaSalidaCaja('Salida');
      return;
    }

    // F9: Verificador de precios
    if (key == LogicalKeyboardKey.f9) {
      _abrirVerificador();
      return;
    }

    // F10: Buscar producto
    if (key == LogicalKeyboardKey.f10) {
      _abrirBuscarProducto();
      return;
    }

    // F11: Alternar mayoreo
    if (key == LogicalKeyboardKey.f11) {
      _alternarMayoreo();
      return;
    }

    // F12: Cobrar
    if (key == LogicalKeyboardKey.f12) {
      _cobrar();
      return;
    }

    // Flechas arriba/abajo si el campo de código está vacío
    if (_codigoController.text.isEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _controller.moverFila(1);
        return;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        _controller.moverFila(-1);
        return;
      }
    }

    // Captura automática de caracteres alfanuméricos cuando el foco no está en el campo
    if (!_codigoFocusNode.hasFocus &&
        event.character != null &&
        event.character!.isNotEmpty &&
        !isCtrl &&
        !HardwareKeyboard.instance.isAltPressed) {
      _codigoFocusNode.requestFocus();
      _codigoController.text += event.character!;
      _codigoController.selection = TextSelection.fromPosition(
        TextPosition(offset: _codigoController.text.length),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones de los Atajos
  // ---------------------------------------------------------------------------

  Future<void> _abrirInsVarios() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoInsVarios(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirArticuloComun() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoArticuloComun(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirBuscarProducto() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoBuscarProducto(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  void _alternarMayoreo() {
    if (_items.isEmpty) return;
    final fila = _ticketActivo.filaSeleccionada;
    if (fila >= 0 && fila < _items.length) {
      final it = _items[fila];
      if (it.precioMayoreo != null && it.precioMayoreo! > 0) {
        _controller.alternarMayoreo(fila);
        _mostrarMensaje('Mayoreo ${it.forzarMayoreo ? 'aplicado' : 'desactivado'} en "${it.descripcion}"');
      } else {
        _mostrarMensaje('"${it.descripcion}" no tiene precio de mayoreo configurado', esError: true);
      }
    }
  }

  Future<void> _abrirEntradaSalidaCaja(String tipo) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoEntradaSalidaCaja(tipo: tipo),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  void _eliminarItemSeleccionado() {
    if (_items.isEmpty) return;
    final fila = _ticketActivo.filaSeleccionada;
    if (fila >= 0 && fila < _items.length) {
      final desc = _items[fila].descripcion;
      _controller.eliminarItem(fila);
      _mostrarMensaje('Artículo eliminado: $desc');
    }
  }

  Future<void> _abrirVerificador() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoVerificadorPrecios(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirCambiarTicket() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoCambiarTicket(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirNuevoTicket() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoNuevoTicket(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _confirmarEliminarTicket() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Confirmar Cancelación de Ticket'),
          ],
        ),
        content: Text(
          '¿Estás seguro de cancelar y limpiar ${_ticketActivo.nombre}?\n\n'
          'Se vaciarán los ${_items.length} artículos del ticket actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar [ESC]'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Cancelar [ENTER]'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (_controller.tickets.length > 1) {
        _controller.cerrarTicket(_controller.ticketActivoIndex);
        _mostrarMensaje('Ticket cerrado.');
      } else {
        _controller.limpiarTicketActual();
        _mostrarMensaje('Ticket vaciado.');
      }
      _codigoFocusNode.requestFocus();
    }
  }

  Future<void> _abrirAsignarCliente() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoAsignarCliente(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirReimprimirUltimoTicket() async {
    await showDialog(
      context: context,
      builder: (ctx) => const _DialogoReimprimirTicket(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
  }

  Future<void> _abrirVentasDelDia() async {
    await showDialog(
      context: context,
      builder: (ctx) => const _DialogoVentasDelDia(),
    );
    if (mounted) _codigoFocusNode.requestFocus();
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
        totalProductos: _totalProductos.toInt(),
        items: List<ItemVenta>.from(_items),
        clientePreseleccionado: _ticketActivo.cliente,
      ),
    );

    if (exito == true && mounted) {
      _controller.limpiarTicketActual();
      if (_controller.tickets.length > 1) {
        _controller.cerrarTicket(_controller.ticketActivoIndex);
      }
      _mostrarMensaje('¡Venta registrada con éxito!');
      _codigoFocusNode.requestFocus();
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

  // ---------------------------------------------------------------------------
  // Interfaz de Usuario
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _asegurarFoco(),
      child: KeyboardListener(
        focusNode: _tecladoFocusNode,
        autofocus: false,
        onKeyEvent: _manejarTeclaGlobal,
        child: Column(
          children: [
            // 1. Barra de entrada de producto
            _buildBarraEntradaProducto(),

            // 2. Barra de atajos rápidos estilo Eleventa
            _buildBarraAtajos(),

            // 3. Fila de pestañas multi-ticket persistentes
            _buildPestanasMultiTicket(),

            // 4. Tabla de artículos de la venta
            Expanded(child: _buildTablaProductos()),

            // 5. Barra inferior con resumen, opciones y botón de Cobro (F12)
            _buildBarraInferiorVenta(),
          ],
        ),
      ),
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
            width: 340,
            height: 38,
            child: TextField(
              controller: _codigoController,
              focusNode: _codigoFocusNode,
              autofocus: true,
              onSubmitted: (_) => _procesarCodigo(),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: AppColors.ventasIcon,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                hintText: 'Ingresa código o escanea [ENTER]...',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _procesarCodigo,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('ENTER - Agregar Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const Spacer(),
          if (_ticketActivo.cliente != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    'Cliente: ${_ticketActivo.cliente!.nombreCompleto}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _controller.asignarCliente(null),
                    child: const Icon(Icons.close, size: 14, color: Color(0xFF0369A1)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Barra de atajos rápidos de venta (INS, CTRL+P, F10, F11, F7, F8, DEL, F9)
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
          _buildBotonAtajo('INS Varios', Icons.post_add_rounded, onTap: _abrirInsVarios),
          const SizedBox(width: 6),
          _buildBotonAtajo('CTRL+P Art. Común', Icons.shopping_bag_outlined, onTap: _abrirArticuloComun),
          const SizedBox(width: 6),
          _buildBotonAtajo('F10 Buscar', Icons.search_rounded, onTap: _abrirBuscarProducto),
          const SizedBox(width: 6),
          _buildBotonAtajo('F11 Mayoreo', Icons.sell_outlined, onTap: _alternarMayoreo),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'F7 Entradas',
            Icons.arrow_downward_rounded,
            colorIcono: AppColors.ventasIcon,
            onTap: () => _abrirEntradaSalidaCaja('Entrada'),
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'F8 Salidas',
            Icons.arrow_upward_rounded,
            colorIcono: AppColors.error,
            onTap: () => _abrirEntradaSalidaCaja('Salida'),
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo(
            'DEL Borrar Art.',
            Icons.backspace_outlined,
            onTap: _eliminarItemSeleccionado,
          ),
          const SizedBox(width: 6),
          _buildBotonAtajo('F9 - Verificador', Icons.price_check_rounded, onTap: _abrirVerificador),
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
      onTap: onTap,
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

  /// Fila de pestañas de tickets abiertos estilo Eleventa
  Widget _buildPestanasMultiTicket() {
    final tickets = _controller.tickets;
    final activoIdx = _controller.ticketActivoIndex;

    return Container(
      width: double.infinity,
      color: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < tickets.length; i++) ...[
              _buildPestanaItem(
                ticket: tickets[i],
                esActivo: i == activoIdx,
                onTap: () => _controller.cambiarTicket(i),
                onClose: tickets.length > 1 ? () => _controller.cerrarTicket(i) : null,
              ),
              const SizedBox(width: 4),
            ],
            // Botón rápido para nuevo ticket
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              tooltip: 'Nuevo Ticket (F6)',
              onPressed: _abrirNuevoTicket,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPestanaItem({
    required TicketVenta ticket,
    required bool esActivo,
    required VoidCallback onTap,
    VoidCallback? onClose,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: esActivo ? Colors.white : const Color(0xFFCBD5E1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          border: Border.all(
            color: esActivo ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
            width: esActivo ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 14,
              color: esActivo ? AppColors.ventasIcon : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              ticket.nombre,
              style: TextStyle(
                fontSize: 12,
                fontWeight: esActivo ? FontWeight.bold : FontWeight.w500,
                color: esActivo ? AppColors.textPrimary : const Color(0xFF475569),
              ),
            ),
            if (ticket.items.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: esActivo ? const Color(0xFFDCFCE7) : Colors.white60,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${ticket.items.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: esActivo ? const Color(0xFF166534) : Colors.black87,
                  ),
                ),
              ),
            ],
            if (onClose != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClose,
                child: const Icon(Icons.close, size: 14, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tabla de productos en la venta actual
  Widget _buildTablaProductos() {
    final filaSeleccionada = _ticketActivo.filaSeleccionada;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Encabezado de la tabla
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
                  width: 120,
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
                  width: 120,
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

          // Filas de productos
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 50, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text('No hay artículos en la venta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                        SizedBox(height: 4),
                        Text('Escanea o ingresa un código de producto para comenzar.', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isSelected = index == filaSeleccionada;
                      final esMayoreo = item.precioEfectivo != item.precioVenta;

                      return InkWell(
                        onTap: () => _controller.seleccionarFila(index),
                        child: Container(
                          height: 38,
                          color: isSelected
                              ? const Color(0xFFE0F2FE)
                              : (index.isEven ? Colors.white : const Color(0xFFF9FAFB)),
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
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.descripcion,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (esMayoreo)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFCD34D)),
                                          ),
                                          child: const Text('MAYOREO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                              SizedBox(
                                width: 120,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    '\$${item.precioEfectivo.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: esMayoreo ? FontWeight.bold : FontWeight.normal,
                                      color: esMayoreo ? const Color(0xFFB45309) : null,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                              SizedBox(
                                width: 80,
                                child: Center(
                                  child: Text(
                                    item.tipoVenta == 'Granel'
                                        ? item.cantidad.toStringAsFixed(3)
                                        : item.cantidad.toInt().toString(),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                              Container(
                                width: 120,
                                color: const Color(0xFFECFDF5),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
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
                              const VerticalDivider(width: 1, color: Color(0xFFF1F3F5)),
                              SizedBox(
                                width: 90,
                                child: Center(
                                  child: Text(
                                    item.tipoVenta == 'Granel'
                                        ? item.existencia.toStringAsFixed(2)
                                        : item.existencia.toInt().toString(),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                Text(
                  '${_totalProductos.toStringAsFixed(_items.any((i) => i.tipoVenta == 'Granel') ? 2 : 0)}  Productos en la venta actual.',
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
                    _buildBotonInferiorAux('F5 - Cambiar', Icons.swap_horiz_rounded, onTap: _abrirCambiarTicket),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('F6 - Pendiente', Icons.pause_circle_outline_rounded, onTap: _abrirNuevoTicket),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('Eliminar', Icons.delete_outline_rounded, onTap: _confirmarEliminarTicket),
                    const SizedBox(width: 6),
                    _buildBotonInferiorAux('Asignar cliente', Icons.person_add_alt_rounded, onTap: _abrirAsignarCliente),
                  ],
                ),
                const SizedBox(height: 8),

                // Resumen de pago
                Row(
                  children: [
                    Text('Total: \$${_totalVenta.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text(
                      _ticketActivo.cliente != null
                          ? 'Saldo Cliente: \$${_ticketActivo.cliente!.saldoActual.toStringAsFixed(2)}'
                          : 'Cliente: Público General',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lado Derecho: Reimprimir, Ventas del día, Cobrar y Caja del total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildBotonInferiorAux('Reimprimir Último Ticket', Icons.print_outlined, onTap: _abrirReimprimirUltimoTicket),
                  const SizedBox(width: 8),
                  _buildBotonInferiorAux('Ventas del día y Devoluciones', Icons.assessment_outlined, onTap: _abrirVentasDelDia),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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

                  Container(
                    width: 170,
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      '\$${_totalVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
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
      onTap: onTap,
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

// =============================================================================
// MODAL F5: CAMBIAR TICKET (100% TECLADO)
// =============================================================================
class _DialogoCambiarTicket extends StatefulWidget {
  const _DialogoCambiarTicket();

  @override
  State<_DialogoCambiarTicket> createState() => _DialogoCambiarTicketState();
}

class _DialogoCambiarTicketState extends State<_DialogoCambiarTicket> {
  final _controller = VentasController.instance;
  late int _seleccionado;

  @override
  void initState() {
    super.initState();
    _seleccionado = _controller.ticketActivoIndex;
  }

  void _manejarTecla(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final total = _controller.tickets.length;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _seleccionado = (_seleccionado + 1) % total);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _seleccionado = (_seleccionado - 1 + total) % total);
    } else if (key == LogicalKeyboardKey.enter) {
      _confirmar();
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _confirmar() {
    _controller.cambiarTicket(_seleccionado);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _controller.tickets;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _manejarTecla,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: AppColors.ventasIcon),
            SizedBox(width: 8),
            Text('F5 - Cambiar de Ticket'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Usa las flechas [↑] [↓] para moverte y [ENTER] para seleccionar:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              for (int i = 0; i < tickets.length; i++) ...[
                ListTile(
                  selected: i == _seleccionado,
                  selectedTileColor: const Color(0xFFE0F2FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  leading: Icon(
                    Icons.receipt_long_rounded,
                    color: i == _seleccionado ? AppColors.ventasIcon : Colors.grey,
                  ),
                  title: Text(tickets[i].nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${tickets[i].items.length} productos'),
                  trailing: Text(
                    '\$${tickets[i].total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: i == _seleccionado ? const Color(0xFF1E3A8A) : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    setState(() => _seleccionado = i);
                    _confirmar();
                  },
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
          ElevatedButton(
            onPressed: _confirmar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
            child: const Text('Seleccionar [ENTER]'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL F6: TICKET PENDIENTE / NUEVO TICKET
// =============================================================================
class _DialogoNuevoTicket extends StatefulWidget {
  const _DialogoNuevoTicket();

  @override
  State<_DialogoNuevoTicket> createState() => _DialogoNuevoTicketState();
}

class _DialogoNuevoTicketState extends State<_DialogoNuevoTicket> {
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = VentasController.instance.sugerirNombreNuevoTicket();
    _nombreCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _nombreCtrl.text.length);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _crear() {
    VentasController.instance.crearTicket(_nombreCtrl.text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_shopping_cart_rounded, color: AppColors.ventasIcon),
          SizedBox(width: 8),
          Text('F6 - Crear Ticket Pendiente'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Asigna un nombre al nuevo ticket:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del ticket',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _crear(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
        ElevatedButton(
          onPressed: _crear,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
          child: const Text('Crear [ENTER]'),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL INS: VARIOS (CANTIDAD + CÓDIGO ENCADENADOS POR ENTER)
// =============================================================================
class _DialogoInsVarios extends StatefulWidget {
  const _DialogoInsVarios();

  @override
  State<_DialogoInsVarios> createState() => _DialogoInsVariosState();
}

class _DialogoInsVariosState extends State<_DialogoInsVarios> {
  final _cantCtrl = TextEditingController(text: '2');
  final _codigoCtrl = TextEditingController();
  final _focusCant = FocusNode();
  final _focusCodigo = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _cantCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _cantCtrl.text.length);
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _codigoCtrl.dispose();
    _focusCant.dispose();
    _focusCodigo.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final cant = double.tryParse(_cantCtrl.text.trim()) ?? 1.0;
    final cod = _codigoCtrl.text.trim();
    if (cod.isEmpty) {
      setState(() => _error = 'Ingresa el código o búsqueda');
      _focusCodigo.requestFocus();
      return;
    }

    try {
      final p = await ProductosRepository.instance.buscarPorCodigo(cod);
      if (p != null) {
        VentasController.instance.agregarProducto(p, cantidad: cant);
        if (mounted) Navigator.pop(context);
      } else {
        final list = await ProductosRepository.instance.buscarPorDescripcion(cod);
        if (list.isNotEmpty) {
          VentasController.instance.agregarProducto(list.first, cantidad: cant);
          if (mounted) Navigator.pop(context);
        } else {
          setState(() => _error = 'Producto no encontrado');
          _focusCodigo.requestFocus();
        }
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.post_add_rounded, color: AppColors.ventasIcon),
          SizedBox(width: 8),
          Text('INS - Agregar Varios Artículos'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _cantCtrl,
              focusNode: _focusCant,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cantidad a vender',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _focusCodigo.requestFocus(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _codigoCtrl,
              focusNode: _focusCodigo,
              decoration: const InputDecoration(
                labelText: 'Código de barras o descripción',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _agregar(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
        ElevatedButton(
          onPressed: _agregar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
          child: const Text('Agregar [ENTER]'),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL CTRL+P: ARTÍCULO COMÚN
// =============================================================================
class _DialogoArticuloComun extends StatefulWidget {
  const _DialogoArticuloComun();

  @override
  State<_DialogoArticuloComun> createState() => _DialogoArticuloComunState();
}

class _DialogoArticuloComunState extends State<_DialogoArticuloComun> {
  final _descCtrl = TextEditingController();
  final _cantCtrl = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController(text: '0.00');

  final _focusDesc = FocusNode();
  final _focusCant = FocusNode();
  final _focusPrecio = FocusNode();
  bool _guardando = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    _focusDesc.dispose();
    _focusCant.dispose();
    _focusPrecio.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final desc = _descCtrl.text.trim();
    final cant = double.tryParse(_cantCtrl.text.trim()) ?? 1.0;
    final precio = double.tryParse(_precioCtrl.text.trim()) ?? 0.0;

    if (desc.isEmpty) {
      _focusDesc.requestFocus();
      return;
    }
    if (precio <= 0) {
      _focusPrecio.requestFocus();
      return;
    }

    setState(() => _guardando = true);
    try {
      final baseProd = await ProductosRepository.instance.obtenerOCrearArticuloComun();
      VentasController.instance.agregarItem(
        ItemVenta(
          idProducto: baseProd.idProducto,
          codigo: 'ART-COMUN',
          descripcion: desc,
          precioVenta: precio,
          costoUnitario: 0.0,
          cantidad: cant,
          existencia: 999.0,
          tipoVenta: 'Unidad',
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shopping_bag_outlined, color: AppColors.ventasIcon),
          SizedBox(width: 8),
          Text('CTRL+P - Venta de Artículo Común'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _descCtrl,
              focusNode: _focusDesc,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Descripción del artículo *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _focusCant.requestFocus(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cantCtrl,
                    focusNode: _focusCant,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder(), isDense: true),
                    onSubmitted: (_) => _focusPrecio.requestFocus(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _precioCtrl,
                    focusNode: _focusPrecio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio Unitario *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _agregar(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
        ElevatedButton(
          onPressed: _guardando ? null : _agregar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
          child: const Text('Agregar al Ticket [ENTER]'),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL F10: BUSCADOR EN VIVO DE PRODUCTOS (FLECHAS + ENTER)
// =============================================================================
class _DialogoBuscarProducto extends StatefulWidget {
  const _DialogoBuscarProducto();

  @override
  State<_DialogoBuscarProducto> createState() => _DialogoBuscarProductoState();
}

class _DialogoBuscarProductoState extends State<_DialogoBuscarProducto> {
  final _busquedaCtrl = TextEditingController();
  List<Producto> _resultados = [];
  int _seleccionado = 0;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    try {
      final list = await ProductosRepository.instance.obtenerCatalogoCompleto(busqueda: q);
      if (mounted) {
        setState(() {
          _resultados = list.map((e) => e.producto).toList();
          _seleccionado = 0;
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _manejarTecla(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (_resultados.isEmpty) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _seleccionado = (_seleccionado + 1).clamp(0, _resultados.length - 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _seleccionado = (_seleccionado - 1).clamp(0, _resultados.length - 1));
    } else if (key == LogicalKeyboardKey.enter) {
      _confirmar();
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _confirmar() {
    if (_resultados.isNotEmpty && _seleccionado < _resultados.length) {
      VentasController.instance.agregarProducto(_resultados[_seleccionado]);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _manejarTecla,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.ventasIcon),
            SizedBox(width: 8),
            Text('F10 - Buscar Producto'),
          ],
        ),
        content: SizedBox(
          width: 580,
          height: 420,
          child: Column(
            children: [
              TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Descripción o código...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _buscar,
                onSubmitted: (_) => _confirmar(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buscando
                    ? const Center(child: CircularProgressIndicator())
                    : _resultados.isEmpty
                        ? const Center(child: Text('No hay productos coincidentes.'))
                        : ListView.separated(
                            itemCount: _resultados.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (ctx, idx) {
                              final p = _resultados[idx];
                              final isSel = idx == _seleccionado;
                              return ListTile(
                                dense: true,
                                selected: isSel,
                                selectedTileColor: const Color(0xFFE0F2FE),
                                title: Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Código: ${p.codigoBarras} • Existencia: ${p.existencia}'),
                                trailing: Text(
                                  '\$${p.precioVenta.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isSel ? const Color(0xFF1E3A8A) : AppColors.ventasIcon,
                                  ),
                                ),
                                onTap: () {
                                  setState(() => _seleccionado = idx);
                                  _confirmar();
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
          ElevatedButton(
            onPressed: _confirmar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
            child: const Text('Agregar a Venta [ENTER]'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL F7/F8: ENTRADAS Y SALIDAS DE DINERO A CAJA
// =============================================================================
class _DialogoEntradaSalidaCaja extends StatefulWidget {
  final String tipo; // 'Entrada' | 'Salida'
  const _DialogoEntradaSalidaCaja({required this.tipo});

  @override
  State<_DialogoEntradaSalidaCaja> createState() => _DialogoEntradaSalidaCajaState();
}

class _DialogoEntradaSalidaCajaState extends State<_DialogoEntradaSalidaCaja> {
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  final _focusMonto = FocusNode();
  final _focusConcepto = FocusNode();
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    _focusMonto.dispose();
    _focusConcepto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0.0;
    final concepto = _conceptoCtrl.text.trim();
    if (monto <= 0) {
      _focusMonto.requestFocus();
      return;
    }
    if (concepto.isEmpty) {
      _focusConcepto.requestFocus();
      return;
    }

    setState(() => _guardando = true);
    try {
      final idCorte = CortesCajaRepository.instance.idCorteActivo;
      final terminalId = DatabaseService.instance.terminalId;

      await DatabaseService.instance.query(
        '''INSERT INTO tbl_movimientos_caja
           (id_corte, tipo_movimiento, monto, concepto, fecha_movimiento, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
           VALUES (@corte, @tipo, @monto, @concepto, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE, @terminal)''',
        params: {
          'corte': idCorte,
          'tipo': widget.tipo,
          'monto': monto,
          'concepto': concepto,
          'terminal': terminalId,
        },
      );

      // Actualizar corte activo si existe
      if (idCorte != null && CortesCajaRepository.instance.corteActivo != null) {
        final corte = CortesCajaRepository.instance.corteActivo!;
        final nuevoEsp = widget.tipo == 'Entrada'
            ? corte.efectivoEsperado + monto
            : corte.efectivoEsperado - monto;
        await DatabaseService.instance.query(
          '''UPDATE tbl_cortes_caja SET efectivo_esperado = @esp, sincronizado = FALSE WHERE id_corte = @corte''',
          params: {'esp': nuevoEsp, 'corte': idCorte},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.tipo} de \$${monto.toStringAsFixed(2)} registrada correctamente.'),
            backgroundColor: widget.tipo == 'Entrada' ? Colors.green.shade700 : AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEntrada = widget.tipo == 'Entrada';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            esEntrada ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: esEntrada ? AppColors.ventasIcon : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(esEntrada ? 'F7 - Entrada de Dinero' : 'F8 - Salida de Dinero'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _montoCtrl,
              focusNode: _focusMonto,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto *', prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
              onSubmitted: (_) => _focusConcepto.requestFocus(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _conceptoCtrl,
              focusNode: _focusConcepto,
              decoration: InputDecoration(
                labelText: 'Concepto / Motivo *',
                hintText: esEntrada ? 'Ej. Cambio inicial, fondo extra' : 'Ej. Pago proveedor, compra insumos',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _guardar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: esEntrada ? AppColors.ventasIcon : AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Registrar [ENTER]'),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL F9: VERIFICADOR DE PRECIOS
// =============================================================================
class _DialogoVerificadorPrecios extends StatefulWidget {
  const _DialogoVerificadorPrecios();

  @override
  State<_DialogoVerificadorPrecios> createState() => _DialogoVerificadorPreciosState();
}

class _DialogoVerificadorPreciosState extends State<_DialogoVerificadorPrecios> {
  final _codigoCtrl = TextEditingController();
  Producto? _producto;
  String? _mensaje;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificar(String cod) async {
    final query = cod.trim();
    if (query.isEmpty) return;

    try {
      Producto? p = await ProductosRepository.instance.buscarPorCodigo(query);
      if (p == null) {
        final list = await ProductosRepository.instance.buscarPorDescripcion(query);
        if (list.isNotEmpty) p = list.first;
      }

      setState(() {
        _producto = p;
        if (p == null) _mensaje = 'Producto no encontrado';
      });
    } catch (e) {
      setState(() => _mensaje = 'Error: $e');
    }
  }

  void _agregarYSalir() {
    if (_producto != null) {
      VentasController.instance.agregarProducto(_producto!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.price_check_rounded, color: AppColors.ventasIcon, size: 26),
          SizedBox(width: 8),
          Text('F9 - Verificador de Precios'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codigoCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Escanea o ingresa el código del producto',
                prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) {
                if (_producto != null) {
                  _agregarYSalir();
                } else {
                  _verificar(v);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_producto != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    Text(_producto!.descripcion,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      '\$${_producto!.precioVenta.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                    if (_producto!.precioMayoreo != null && _producto!.precioMayoreo! > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Precio Mayoreo: \$${_producto!.precioMayoreo!.toStringAsFixed(2)} (a partir de ${_producto!.cantidadMayoreo ?? 0} pzas)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                    const Divider(height: 20),
                    Text(
                      'Existencia actual: ${_producto!.existencia} ${_producto!.tipoVenta == 'Granel' ? 'Kg' : 'pzas'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ] else if (_mensaje != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_mensaje!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Salir [ESC]')),
        if (_producto != null)
          ElevatedButton(
            onPressed: _agregarYSalir,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
            child: const Text('Agregar a Venta [ENTER]'),
          ),
      ],
    );
  }
}

// =============================================================================
// MODAL ASIGNAR CLIENTE
// =============================================================================
class _DialogoAsignarCliente extends StatefulWidget {
  const _DialogoAsignarCliente();

  @override
  State<_DialogoAsignarCliente> createState() => _DialogoAsignarClienteState();
}

class _DialogoAsignarClienteState extends State<_DialogoAsignarCliente> {
  final _busquedaCtrl = TextEditingController();
  List<ClienteDB> _clientes = [];
  int _seleccionado = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    setState(() => _cargando = true);
    try {
      final list = (q.trim().isEmpty)
          ? await ClientesRepository.instance.obtenerTodos()
          : await ClientesRepository.instance.buscar(q);
      if (mounted) {
        setState(() {
          _clientes = list;
          _seleccionado = 0;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _manejarTecla(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (_clientes.isEmpty) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _seleccionado = (_seleccionado + 1).clamp(0, _clientes.length - 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _seleccionado = (_seleccionado - 1).clamp(0, _clientes.length - 1));
    } else if (key == LogicalKeyboardKey.enter) {
      _confirmar();
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _confirmar() {
    if (_clientes.isNotEmpty && _seleccionado < _clientes.length) {
      VentasController.instance.asignarCliente(_clientes[_seleccionado]);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _manejarTecla,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_rounded, color: AppColors.clientesIcon),
            SizedBox(width: 8),
            Text('Vincular Cliente al Ticket'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 380,
          child: Column(
            children: [
              TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre o teléfono...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _buscar,
                onSubmitted: (_) => _confirmar(),
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_off_rounded, color: Colors.grey),
                title: const Text('Público General (Desvincular)'),
                onTap: () {
                  VentasController.instance.asignarCliente(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _clientes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (ctx, idx) {
                          final c = _clientes[idx];
                          final isSel = idx == _seleccionado;
                          return ListTile(
                            dense: true,
                            selected: isSel,
                            selectedTileColor: const Color(0xFFE0F2FE),
                            title: Text(c.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Tel: ${c.telefono ?? '-'} • Saldo: \$${c.saldoActual.toStringAsFixed(2)}'),
                            trailing: c.tieneLimiteCredito
                                ? Text('Límite: \$${c.limiteCredito.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                                : null,
                            onTap: () {
                              VentasController.instance.asignarCliente(c);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar [ESC]')),
          ElevatedButton(
            onPressed: _confirmar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.clientesIcon, foregroundColor: Colors.white),
            child: const Text('Asignar [ENTER]'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL REIMPRIMIR ÚLTIMO TICKET
// =============================================================================
class _DialogoReimprimirTicket extends StatefulWidget {
  const _DialogoReimprimirTicket();

  @override
  State<_DialogoReimprimirTicket> createState() => _DialogoReimprimirTicketState();
}

class _DialogoReimprimirTicketState extends State<_DialogoReimprimirTicket> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final res = await VentasRepository.instance.obtenerUltimaVentaCompletada();
      if (mounted) setState(() { _datos = res; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
    }

    if (_datos == null) {
      return AlertDialog(
        title: const Text('Reimprimir Último Ticket'),
        content: const Text('No se encontraron ventas completadas recientemente en esta terminal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar [ESC]')),
        ],
      );
    }

    final venta = _datos!['venta'] as Venta;
    final detalles = _datos!['detalles'] as List<VentaDetalle>;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.print_outlined, color: AppColors.ventasIcon),
          const SizedBox(width: 8),
          Text('Ticket ${venta.folioTicket} (Reimpresión)'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF8FAFC),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('ABARROTES 3M', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              const Center(child: Text('Reimpresión de Comprobante', style: TextStyle(fontSize: 12, color: Colors.grey))),
              const Divider(height: 20),
              Text('Folio: ${venta.folioTicket}'),
              Text('Fecha: ${venta.fechaVenta}'),
              Text('Cajero: ${_datos!['usuario_nombre']}'),
              Text('Cliente: ${_datos!['cliente_nombre']}'),
              const Divider(height: 20),
              for (final d in detalles) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${d.cantidad} x ${d.descripcionProducto}', style: const TextStyle(fontSize: 12))),
                    Text('\$${d.importe.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('\$${venta.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A))),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar [ESC]')),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ticket ${venta.folioTicket} enviado a la impresora.'), backgroundColor: Colors.green.shade700),
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('Imprimir'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ventasIcon, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL VENTAS DEL DÍA Y DEVOLUCIONES
// =============================================================================
class _DialogoVentasDelDia extends StatefulWidget {
  const _DialogoVentasDelDia();

  @override
  State<_DialogoVentasDelDia> createState() => _DialogoVentasDelDiaState();
}

class _DialogoVentasDelDiaState extends State<_DialogoVentasDelDia> {
  List<Venta> _ventas = [];
  Venta? _seleccionada;
  List<VentaDetalle> _detalles = [];
  bool _cargando = true;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas() async {
    setState(() => _cargando = true);
    try {
      final list = await VentasRepository.instance.obtenerVentasDelDia();
      if (mounted) {
        setState(() {
          _ventas = list;
          _cargando = false;
          if (list.isNotEmpty) _seleccionarVenta(list.first);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarVenta(Venta v) async {
    setState(() => _seleccionada = v);
    try {
      final d = await VentasRepository.instance.obtenerDetalle(v.idVenta);
      if (mounted && _seleccionada?.idVenta == v.idVenta) {
        setState(() => _detalles = d);
      }
    } catch (_) {}
  }

  Future<void> _ejecutarDevolucion() async {
    if (_seleccionada == null) return;
    if (_seleccionada!.estatusVenta == 'Cancelada') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta venta ya se encuentra cancelada.')));
      return;
    }

    final motivoCtrl = TextEditingController(text: 'Devolución de cliente');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Confirmar Devolución / Cancelación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se cancelará el ticket ${_seleccionada!.folioTicket} por \$${_seleccionada!.total.toStringAsFixed(2)}.\n\n'
                'Las existencias de los productos se devolverán automáticamente al inventario (Kardex: Cancelacion).'),
            const SizedBox(height: 14),
            TextField(
              controller: motivoCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo de la devolución', border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Confirmar Devolución'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _cancelando = true);
      try {
        final idUsuario = AuthRepository.instance.usuarioActual?.idUsuario ?? 1;
        await VentasRepository.instance.cancelarVentaConDevolucion(
          idVenta: _seleccionada!.idVenta,
          idUsuario: idUsuario,
          motivo: motivoCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Venta ${_seleccionada!.folioTicket} cancelada e inventario devuelto.'), backgroundColor: Colors.orange.shade800),
          );
          _cargarVentas();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
        }
      } finally {
        if (mounted) setState(() => _cancelando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assessment_outlined, color: AppColors.ventasIcon),
          SizedBox(width: 8),
          Text('Ventas del Día y Devoluciones'),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 440,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView.separated(
                      itemCount: _ventas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final v = _ventas[idx];
                        final isSel = v.idVenta == _seleccionada?.idVenta;
                        final isCancelada = v.estatusVenta == 'Cancelada';
                        return ListTile(
                          selected: isSel,
                          selectedTileColor: const Color(0xFFE0F2FE),
                          title: Row(
                            children: [
                              Text(v.folioTicket, style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelada ? TextDecoration.lineThrough : null)),
                              const SizedBox(width: 6),
                              if (isCancelada)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('CANCELADA', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text(v.fechaVenta.toString().substring(11, 16)),
                          trailing: Text('\$${v.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => _seleccionarVenta(v),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: _seleccionada == null
                        ? const Center(child: Text('Selecciona una venta'))
                        : Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Detalle de ${_seleccionada!.folioTicket}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Divider(),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _detalles.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (ctx, idx) {
                                      final d = _detalles[idx];
                                      return ListTile(
                                        dense: true,
                                        title: Text(d.descripcionProducto),
                                        subtitle: Text('${d.cantidad} x \$${d.precioUnitario.toStringAsFixed(2)}'),
                                        trailing: Text('\$${d.importe.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      );
                                    },
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('\$${_seleccionada!.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_seleccionada!.estatusVenta != 'Cancelada')
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _cancelando ? null : _ejecutarDevolucion,
                                      icon: const Icon(Icons.settings_backup_restore_rounded),
                                      label: Text(_cancelando ? 'Cancelando...' : 'Hacer Devolución / Cancelar'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar [ESC]')),
      ],
    );
  }
}

// =============================================================================
// MODAL F12: COBRO AVANZADO ESTILO ELEVENTA (TECLADO PRIMERO)
// =============================================================================
class _DialogoCobroAvanzado extends StatefulWidget {
  final double totalVenta;
  final int totalProductos;
  final List<ItemVenta> items;
  final ClienteDB? clientePreseleccionado;

  const _DialogoCobroAvanzado({
    required this.totalVenta,
    required this.totalProductos,
    required this.items,
    this.clientePreseleccionado,
  });

  @override
  State<_DialogoCobroAvanzado> createState() => _DialogoCobroAvanzadoState();
}

class _DialogoCobroAvanzadoState extends State<_DialogoCobroAvanzado> {
  // Formas de pago disponibles en orden
  static const _formas = ['Efectivo', 'Crédito', 'Tarjeta', 'Mixto', 'Transferencia'];
  int _formaidx = 0; // índice en _formas
  String get _metodo => _formas[_formaidx];

  bool _procesando = false;
  bool _imprimirDatosCliente = false;
  String? _errorMsg;
  String _notas = '';

  // FocusNodes
  final _focusNode = FocusNode(); // captura global del diálogo
  final _focusEfectivo = FocusNode();
  final _focusBusqueda = FocusNode();
  final _focusMixtoEfectivo = FocusNode();
  final _focusMixtoTarjeta = FocusNode();
  final _focusReferencia = FocusNode();

  // Efectivo
  final _pagoConCtrl = TextEditingController();
  bool _primeraDigitacion = true; // reemplaza el valor inicial al primer dígito

  // Mixto
  final _mixtoTarjetaCtrl = TextEditingController();
  final _mixtoEfectivoCtrl = TextEditingController();

  // Crédito
  List<ClienteDB> _clientes = [];
  List<ClienteDB> _clientesFiltrados = [];
  ClienteDB? _clienteSeleccionado;
  final _buscarClienteCtrl = TextEditingController();
  int _clienteCursorIdx = -1;
  bool _cargandoClientes = false;

  // Tarjeta / Transferencia
  final _referenciaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pagoConCtrl.text = widget.totalVenta.toStringAsFixed(2);
    _clienteSeleccionado = widget.clientePreseleccionado;
    _imprimirDatosCliente = widget.clientePreseleccionado != null;
    _cargarClientes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (_metodo == 'Efectivo') {
        _focusEfectivo.requestFocus();
        _seleccionarTodoEfectivo();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _focusEfectivo.dispose();
    _focusBusqueda.dispose();
    _focusMixtoEfectivo.dispose();
    _focusMixtoTarjeta.dispose();
    _focusReferencia.dispose();
    _pagoConCtrl.dispose();
    _mixtoTarjetaCtrl.dispose();
    _mixtoEfectivoCtrl.dispose();
    _buscarClienteCtrl.dispose();
    _referenciaCtrl.dispose();
    super.dispose();
  }

  void _seleccionarTodoEfectivo() {
    _pagoConCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pagoConCtrl.text.length,
    );
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
          if (_clienteSeleccionado != null) {
            _clienteCursorIdx = lista.indexWhere((c) => c.idCliente == _clienteSeleccionado!.idCliente);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoClientes = false);
    }
  }

  void _filtrarClientes(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _clientesFiltrados = query.isEmpty
          ? _clientes
          : _clientes.where((c) =>
              c.nombre.toLowerCase().contains(query) ||
              (c.telefono?.toLowerCase().contains(query) ?? false)).toList();
      _clienteCursorIdx = _clientesFiltrados.isEmpty ? -1 : 0;
      if (_clientesFiltrados.isNotEmpty) {
        _clienteSeleccionado = _clientesFiltrados[0];
      }
    });
  }

  void _cambiarForma(int delta) {
    setState(() {
      _formaidx = (_formaidx + delta + _formas.length) % _formas.length;
      _primeraDigitacion = true;
      _errorMsg = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (_metodo) {
        case 'Efectivo':
          _focusEfectivo.requestFocus();
          _seleccionarTodoEfectivo();
          break;
        case 'Crédito':
          _focusBusqueda.requestFocus();
          break;
        case 'Mixto':
          _mixtoTarjetaCtrl.text = '';
          _mixtoEfectivoCtrl.text = '';
          _focusMixtoTarjeta.requestFocus();
          break;
        default:
          _focusReferencia.requestFocus();
      }
    });
  }

  // ─── Computed ───────────────────────────────────────────────────────────────
  double get _pagoEfectivo => double.tryParse(_pagoConCtrl.text.trim()) ?? 0.0;
  double get _cambioEfectivo => _pagoEfectivo - widget.totalVenta;

  double get _mixtoTarjeta => double.tryParse(_mixtoTarjetaCtrl.text.trim()) ?? 0.0;
  double get _mixtoEfectivo => double.tryParse(_mixtoEfectivoCtrl.text.trim()) ?? 0.0;
  double get _mixtoRestante => (widget.totalVenta - _mixtoTarjeta).clamp(0.0, double.infinity);
  double get _mixtoCambio => (_mixtoEfectivo - _mixtoRestante).clamp(0.0, double.infinity);

  bool get _puedeConfirmar {
    if (_procesando) return false;
    switch (_metodo) {
      case 'Efectivo':
        return _pagoEfectivo >= widget.totalVenta - 0.001;
      case 'Tarjeta':
      case 'Transferencia':
        return true;
      case 'Mixto':
        return _mixtoTarjeta > 0 &&
            _mixtoTarjeta < widget.totalVenta &&
            (_mixtoTarjeta + _mixtoEfectivo) >= widget.totalVenta - 0.001;
      case 'Crédito':
        if (_clienteSeleccionado == null) return false;
        final c = _clienteSeleccionado!;
        if (c.tieneLimiteCredito && (c.saldoActual + widget.totalVenta) > c.limiteCredito) return false;
        return true;
      default:
        return false;
    }
  }

  // ─── Acción Cobrar ──────────────────────────────────────────────────────────
  Future<bool?> _confirmarCobro({required bool imprimir}) async {
    if (!_puedeConfirmar) {
      setState(() => _errorMsg = _mensajeError());
      return null;
    }
    setState(() { _procesando = true; _errorMsg = null; });

    try {
      final idUsuario = AuthRepository.instance.usuarioActual?.idUsuario ?? 1;
      final idCorte = CortesCajaRepository.instance.idCorteActivo;
      final lineas = widget.items.map((i) => LineaVenta(
        idProducto: i.idProducto ?? 1,
        descripcionProducto: i.descripcion,
        cantidad: i.cantidad,
        precioUnitario: i.precioEfectivo,
        costoUnitario: i.costoUnitario,
      )).toList();

      final pagos = <PagoVentaInput>[];
      bool esCredito = false;
      int? idCliente;

      switch (_metodo) {
        case 'Efectivo':
          final cambio = _cambioEfectivo < 0 ? 0.0 : _cambioEfectivo;
          pagos.add(PagoVentaInput(nombreFormaPago: 'Efectivo', monto: _pagoEfectivo, cambio: cambio));
          break;
        case 'Tarjeta':
          pagos.add(PagoVentaInput(nombreFormaPago: 'Tarjeta', monto: widget.totalVenta));
          break;
        case 'Transferencia':
          pagos.add(PagoVentaInput(nombreFormaPago: 'Transferencia', monto: widget.totalVenta));
          break;
        case 'Mixto':
          final cambio = _mixtoCambio;
          pagos.add(PagoVentaInput(nombreFormaPago: 'Tarjeta', monto: _mixtoTarjeta));
          pagos.add(PagoVentaInput(nombreFormaPago: 'Efectivo', monto: _mixtoEfectivo, cambio: cambio));
          break;
        case 'Crédito':
          esCredito = true;
          idCliente = _clienteSeleccionado!.idCliente;
          pagos.add(PagoVentaInput(nombreFormaPago: 'Crédito', monto: widget.totalVenta));
          break;
      }

      await VentasRepository.instance.registrarVenta(
        idUsuario: idUsuario,
        idCliente: idCliente ?? _clienteSeleccionado?.idCliente,
        idCorte: idCorte,
        lineas: lineas,
        pagos: pagos,
        esCredito: esCredito,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _procesando = false; _errorMsg = 'Error: $e'; });
    }
    return null;
  }

  String? _mensajeError() {
    switch (_metodo) {
      case 'Efectivo':
        return 'El monto recibido debe ser mayor o igual al total';
      case 'Crédito':
        if (_clienteSeleccionado == null) return 'Selecciona un cliente para venta a crédito';
        final c = _clienteSeleccionado!;
        if (c.tieneLimiteCredito && (c.saldoActual + widget.totalVenta) > c.limiteCredito) {
          return 'Límite de crédito insuficiente (disponible: \$${(c.limiteCredito - c.saldoActual).toStringAsFixed(2)})';
        }
        return null;
      case 'Mixto':
        return 'La suma de tarjeta + efectivo debe cubrir el total';
      default:
        return null;
    }
  }

  // ─── Keyboard handler ───────────────────────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isBusquedaActiva = _metodo == 'Crédito' && _focusBusqueda.hasFocus;

    // ESC → cancelar
    if (key == LogicalKeyboardKey.escape) {
      Navigator.pop(context, false);
      return KeyEventResult.handled;
    }

    // F1 → cobrar e imprimir
    if (key == LogicalKeyboardKey.f1 && !isCtrl) {
      _confirmarCobro(imprimir: true);
      return KeyEventResult.handled;
    }

    // F2 → cobrar sin imprimir
    if (key == LogicalKeyboardKey.f2 && !isCtrl) {
      _confirmarCobro(imprimir: false);
      return KeyEventResult.handled;
    }

    // F4 → notas
    if (key == LogicalKeyboardKey.f4) {
      _abrirNotas();
      return KeyEventResult.handled;
    }

    // Enter → confirmar cobro (si no está en buscador de crédito)
    if (key == LogicalKeyboardKey.enter && !isBusquedaActiva) {
      _confirmarCobro(imprimir: true);
      return KeyEventResult.handled;
    }

    // Flechas Izq / Der → cambiar forma de pago (si no estamos editando texto)
    if (!isBusquedaActiva &&
        !_focusMixtoEfectivo.hasFocus &&
        !_focusMixtoTarjeta.hasFocus &&
        !_focusReferencia.hasFocus) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _cambiarForma(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _cambiarForma(1);
        return KeyEventResult.handled;
      }
    }

    // Flechas Arriba / Abajo → navegar clientes en modo Crédito
    if (_metodo == 'Crédito' && _clientesFiltrados.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _clienteCursorIdx = (_clienteCursorIdx + 1).clamp(0, _clientesFiltrados.length - 1);
          _clienteSeleccionado = _clientesFiltrados[_clienteCursorIdx];
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _clienteCursorIdx = (_clienteCursorIdx - 1).clamp(0, _clientesFiltrados.length - 1);
          _clienteSeleccionado = _clientesFiltrados[_clienteCursorIdx];
        });
        return KeyEventResult.handled;
      }
    }

    // Escritura numérica automática en Efectivo
    if (_metodo == 'Efectivo' && event.character != null) {
      final ch = event.character!;
      final isNumeric = RegExp(r'[0-9.]').hasMatch(ch);
      if (isNumeric) {
        if (!_focusEfectivo.hasFocus) _focusEfectivo.requestFocus();
        if (_primeraDigitacion) {
          _pagoConCtrl.text = ch;
          _primeraDigitacion = false;
          _pagoConCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _pagoConCtrl.text.length));
          setState(() {});
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _abrirNotas() async {
    final ctrl = TextEditingController(text: _notas);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Notas al Ticket'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Notas opcionales para el ticket...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _notas = ctrl.text);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 820,
          height: 580,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Panel Central (izquierda) ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Encabezado azul degradado
                    _buildEncabezado(),
                    // Selector de formas de pago
                    _buildSelectorFormas(),
                    // Panel dinámico
                    Expanded(child: _buildPanelDinamico()),
                    // Mensaje de error
                    if (_errorMsg != null)
                      Container(
                        color: const Color(0xFFFEF2F2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              // ── Panel Lateral Derecho ──────────────────────────────────────
              _buildPanelDerecho(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COBRAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(
            '\$${widget.totalVenta.toStringAsFixed(2)} MXN',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorFormas() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Row(
        children: List.generate(_formas.length, (i) {
          final selected = i == _formaidx;
          final icons = [Icons.money_rounded, Icons.credit_card_rounded, Icons.payment_rounded, Icons.call_split_rounded, Icons.swap_horiz_rounded];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _formaidx = i;
                _primeraDigitacion = true;
                _errorMsg = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icons[i], size: 22, color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                    const SizedBox(height: 4),
                    Text(_formas[i], style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPanelDinamico() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: switch (_metodo) {
        'Efectivo' => _buildPanelEfectivo(),
        'Crédito'  => _buildPanelCredito(),
        'Mixto'    => _buildPanelMixto(),
        _          => _buildPanelTarjeta(),
      },
    );
  }

  Widget _buildPanelEfectivo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pagó con:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        TextField(
          controller: _pagoConCtrl,
          focusNode: _focusEfectivo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            prefixStyle: TextStyle(fontSize: 22, color: Color(0xFF64748B)),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) {
            _primeraDigitacion = false;
            setState(() {});
          },
          onSubmitted: (_) => _confirmarCobro(imprimir: true),
        ),
        const SizedBox(height: 20),
        // Cambio
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cambioEfectivo >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cambioEfectivo >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _cambioEfectivo >= 0 ? 'Su Cambio:' : 'Faltan:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: _cambioEfectivo >= 0 ? const Color(0xFF065F46) : AppColors.error),
              ),
              Text(
                '\$${(_cambioEfectivo.abs()).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: _cambioEfectivo >= 0 ? const Color(0xFF047857) : AppColors.error),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Accesos rápidos
        Wrap(
          spacing: 8,
          children: [5, 10, 20, 50, 100, 200, 500].map((v) => ActionChip(
            label: Text('\$$v'),
            onPressed: () {
              _pagoConCtrl.text = v.toStringAsFixed(2);
              _primeraDigitacion = false;
              setState(() {});
            },
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildPanelCredito() {
    return Column(
      children: [
        TextField(
          controller: _buscarClienteCtrl,
          focusNode: _focusBusqueda,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar cliente (nombre o teléfono)...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _filtrarClientes,
        ),
        const SizedBox(height: 8),
        // Cabecera de columnas
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: Text('Cliente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 90, child: Text('Saldo actual', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 80, child: Text('Límite', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _cargandoClientes
              ? const Center(child: CircularProgressIndicator())
              : _clientesFiltrados.isEmpty
                  ? const Center(child: Text('Sin clientes que coincidan'))
                  : ListView.builder(
                      itemCount: _clientesFiltrados.length,
                      itemBuilder: (ctx, i) {
                        final c = _clientesFiltrados[i];
                        final sel = c.idCliente == _clienteSeleccionado?.idCliente;
                        final excede = c.tieneLimiteCredito && (c.saldoActual + widget.totalVenta) > c.limiteCredito;
                        return InkWell(
                          onTap: () => setState(() {
                            _clienteSeleccionado = c;
                            _clienteCursorIdx = i;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            color: sel ? const Color(0xFFEFF6FF) : (i.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: sel
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18)
                                      : Text('#${c.idCliente}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ),
                                Expanded(
                                  child: Text(c.nombre, style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                      color: excede ? AppColors.error : AppColors.textPrimary)),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text('\$${c.saldoActual.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 12, color: c.saldoActual > 0 ? Colors.orange.shade800 : Colors.grey)),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                      c.tieneLimiteCredito ? '\$${c.limiteCredito.toStringAsFixed(0)}' : 'Sin límite',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_clienteSeleccionado != null) ...[
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_clienteSeleccionado!.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                Text('Deuda: \$${_clienteSeleccionado!.saldoActual.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPanelMixto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dividir el pago:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Con Tarjeta:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mixtoTarjetaCtrl,
                    focusNode: _focusMixtoTarjeta,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _focusMixtoEfectivo.requestFocus(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Text('+', style: TextStyle(fontSize: 24, color: Colors.grey.shade500)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pagó en Efectivo:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mixtoEfectivoCtrl,
                    focusNode: _focusMixtoEfectivo,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _confirmarCobro(imprimir: true),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildFilaMixto('Total a pagar:', '\$${widget.totalVenta.toStringAsFixed(2)}', bold: true),
              _buildFilaMixto('Resta en efectivo:', '\$${_mixtoRestante.toStringAsFixed(2)}'),
              _buildFilaMixto('Cambio a devolver:', '\$${_mixtoCambio.toStringAsFixed(2)}',
                  color: _mixtoCambio > 0 ? const Color(0xFF047857) : null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilaMixto(String label, String valor, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Widget _buildPanelTarjeta() {
    final icon = _metodo == 'Tarjeta' ? Icons.payment_rounded : Icons.swap_horiz_rounded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF2563EB)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cobro por $_metodo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Se registrará el monto exacto de la venta.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monto total:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('\$${widget.totalVenta.toStringAsFixed(2)} MXN',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _referenciaCtrl,
          focusNode: _focusReferencia,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Referencia / Autorización (opcional)',
            prefixIcon: Icon(Icons.tag_rounded),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _confirmarCobro(imprimir: true),
        ),
      ],
    );
  }

  Widget _buildPanelDerecho() {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total artículos
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text('Total Artículos', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Text('${widget.totalProductos}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Checkbox imprimir datos cliente
          Row(
            children: [
              Checkbox(
                value: _imprimirDatosCliente,
                onChanged: (v) => setState(() => _imprimirDatosCliente = v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Expanded(child: Text('Imprimir\ndatos cliente', style: TextStyle(fontSize: 11))),
            ],
          ),
          const SizedBox(height: 8),

          // Notas
          if (_notas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6)),
              child: Text(_notas, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

          const Divider(),

          // Botón F1 Cobrar e Imprimir
          _buildBotonAccion(
            label: 'F1 Cobrar e Imprimir',
            icon: Icons.print_rounded,
            color: _puedeConfirmar ? const Color(0xFF059669) : Colors.grey,
            onTap: _procesando ? null : () => _confirmarCobro(imprimir: true),
          ),
          const SizedBox(height: 8),

          // Botón F2 Cobrar sin imprimir
          _buildBotonAccion(
            label: 'F2 Sin imprimir',
            icon: Icons.check_circle_outline_rounded,
            color: _puedeConfirmar ? const Color(0xFF2563EB) : Colors.grey,
            onTap: _procesando ? null : () => _confirmarCobro(imprimir: false),
          ),
          const SizedBox(height: 8),

          // Botón F4 Notas
          _buildBotonAccion(
            label: 'F4 Notas',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: _abrirNotas,
          ),

          const Spacer(),

          // Botón ESC Cancelar
          _buildBotonAccion(
            label: 'ESC Cancelar',
            icon: Icons.close_rounded,
            color: AppColors.error,
            onTap: () => Navigator.pop(context, false),
          ),

          if (_procesando) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        ),
      ),
    );
  }
}
