import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';

/// Vista del módulo de Productos (Pantalla estilo Eleventa).
/// Permite registrar un nuevo producto con código, descripción, precios e inventario.
class ProductosView extends StatefulWidget {
  const ProductosView({super.key});

  @override
  State<ProductosView> createState() => _ProductosViewState();
}

class _ProductosViewState extends State<ProductosView> {
  String _subOpcionSeleccionada = 'Nuevo';

  // Controladores del formulario
  final _codigoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _costoController = TextEditingController(text: '0.00');
  final _gananciaController = TextEditingController(text: '20.00');
  final _ventaController = TextEditingController(text: '0.00');
  final _mayoreoController = TextEditingController(text: '0.00');
  final _hayController = TextEditingController(text: '0');
  final _minimoController = TextEditingController(text: '0');
  final _maximoController = TextEditingController(text: '0');

  String _tipoVenta = 'unidad'; // 'unidad', 'granel', 'kit'
  String _departamentoSeleccionado = '- Sin Departamento -';

  final List<String> _departamentos = [
    '- Sin Departamento -',
    'Abarrotes',
    'Bebidas',
    'Lácteos y Quesos',
    'Botanas y Dulces',
    'Frutas y Verduras',
    'Carnicería y Embutidos',
    'Panadería y Tortillería',
    'Limpieza del Hogar',
    'Cuidado Personal',
  ];

  @override
  void dispose() {
    _codigoController.dispose();
    _descripcionController.dispose();
    _costoController.dispose();
    _gananciaController.dispose();
    _ventaController.dispose();
    _mayoreoController.dispose();
    _hayController.dispose();
    _minimoController.dispose();
    _maximoController.dispose();
    super.dispose();
  }

  void _calcularPrecioVenta() {
    final costo = double.tryParse(_costoController.text.replaceAll(',', '')) ?? 0.0;
    final ganancia = double.tryParse(_gananciaController.text.replaceAll(',', '')) ?? 0.0;
    if (costo >= 0) {
      final venta = costo * (1 + (ganancia / 100));
      _ventaController.text = venta.toStringAsFixed(2);
    }
  }

  void _calcularGanancia() {
    final costo = double.tryParse(_costoController.text.replaceAll(',', '')) ?? 0.0;
    final venta = double.tryParse(_ventaController.text.replaceAll(',', '')) ?? 0.0;
    if (costo > 0 && venta >= costo) {
      final ganancia = ((venta - costo) / costo) * 100;
      _gananciaController.text = ganancia.toStringAsFixed(2);
    }
  }

  void _guardarProducto() {
    if (_codigoController.text.trim().isEmpty) {
      _mostrarMensaje('Por favor ingresa o escanea el código de barras', esError: true);
      return;
    }
    if (_descripcionController.text.trim().isEmpty) {
      _mostrarMensaje('Por favor ingresa la descripción del producto', esError: true);
      return;
    }

    _mostrarMensaje('Producto "${_descripcionController.text.trim()}" guardado correctamente');
    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    setState(() {
      _codigoController.clear();
      _descripcionController.clear();
      _costoController.text = '0.00';
      _gananciaController.text = '20.00';
      _ventaController.text = '0.00';
      _mayoreoController.text = '0.00';
      _hayController.text = '0';
      _minimoController.text = '0';
      _maximoController.text = '0';
      _tipoVenta = 'unidad';
      _departamentoSeleccionado = '- Sin Departamento -';
    });
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? AppColors.error : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra de herramientas de acciones de Productos (Nuevo, Modificar, Eliminar...)
        _buildBarraAccionesProductos(),

        // 2. Contenido del formulario con scroll
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título "NUEVO PRODUCTO"
                  const Text(
                    'NUEVO PRODUCTO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pestaña "Producto"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(
                        top: BorderSide(color: Color(0xFFD1D5DB)),
                        left: BorderSide(color: Color(0xFFD1D5DB)),
                        right: BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Producto',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta contenedor principal del formulario
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildFormulario(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // 3. Barra inferior de botones (Guardar Producto / Cancelar)
        _buildBarraInferiorAcciones(),
      ],
    );
  }

  /// Barra de sub-opciones estilo Eleventa: Nuevo, Modificar, Eliminar, Departamentos...
  Widget _buildBarraAccionesProductos() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _buildBotonAccion('Nuevo', Icons.add_circle_outline_rounded),
          const SizedBox(width: 6),
          _buildBotonAccion('Modificar', Icons.edit_outlined),
          const SizedBox(width: 6),
          _buildBotonAccion('Eliminar', Icons.delete_outline_rounded),
          const SizedBox(width: 6),
          _buildBotonAccion('Departamentos', Icons.folder_outlined),
          const SizedBox(width: 6),
          _buildBotonAccion('Ventas por Periodo', Icons.insert_chart_outlined_rounded),
          const SizedBox(width: 6),
          _buildBotonAccion('Promociones', Icons.star_border_rounded),
          const SizedBox(width: 6),
          _buildBotonAccion('Importar', Icons.file_download_outlined),
          const SizedBox(width: 6),
          _buildBotonAccion('Catálogo', Icons.menu_book_outlined),
        ],
      ),
    );
  }

  Widget _buildBotonAccion(String titulo, IconData icono) {
    final bool activo = _subOpcionSeleccionada == titulo;

    return InkWell(
      onTap: () {
        setState(() {
          _subOpcionSeleccionada = titulo;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFFEF3C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: activo ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: activo ? const Color(0xFFB45309) : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                color: activo ? const Color(0xFFB45309) : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el formulario con todos los campos solicitados
  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Código de Barras
        _buildFilaCampo(
          etiqueta: 'Código de Barras',
          widgetCampo: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 280,
                height: 38,
                child: TextField(
                  controller: _codigoController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                    hintText: 'Ej. 7501055312345',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Descripción
        _buildFilaCampo(
          etiqueta: 'Descripción',
          widgetCampo: SizedBox(
            width: 440,
            height: 38,
            child: TextField(
              controller: _descripcionController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
                hintText: 'Ej. Refresco Coca Cola 600ml',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Se vende
        _buildFilaCampo(
          etiqueta: 'Se vende',
          widgetCampo: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildRadioOpcion('Por Unidad/Pza', 'unidad'),
              _buildRadioOpcion('A Granel (Usa Decimales)', 'granel'),
              _buildRadioOpcion('Como paquete (kit)', 'kit'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Precio Costo y Ganancia
        _buildFilaCampo(
          etiqueta: 'Precio Costo',
          widgetCampo: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 38,
                child: TextField(
                  controller: _costoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                  ),
                  onChanged: (_) => _calcularPrecioVenta(),
                ),
              ),
              const SizedBox(width: 24),
              const Text(
                'Ganancia',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                height: 38,
                child: TextField(
                  controller: _gananciaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    suffixText: '%',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                  ),
                  onChanged: (_) => _calcularPrecioVenta(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Precio Venta
        _buildFilaCampo(
          etiqueta: 'Precio Venta',
          widgetCampo: SizedBox(
            width: 140,
            height: 38,
            child: TextField(
              controller: _ventaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
              ),
              onChanged: (_) => _calcularGanancia(),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 6. Precio Mayoreo
        _buildFilaCampo(
          etiqueta: 'Precio Mayoreo',
          widgetCampo: SizedBox(
            width: 140,
            height: 38,
            child: TextField(
              controller: _mayoreoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 7. Departamento
        _buildFilaCampo(
          etiqueta: 'Departamento',
          widgetCampo: Container(
            width: 260,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _departamentoSeleccionado,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                items: _departamentos.map((dept) {
                  return DropdownMenuItem<String>(
                    value: dept,
                    child: Text(dept),
                  );
                }).toList(),
                onChanged: (nuevo) {
                  if (nuevo != null) {
                    setState(() => _departamentoSeleccionado = nuevo);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 8. Sección de Inventario (Con banda vertical como en eleventa, pero SIN el checkbox)
        _buildSeccionInventario(),
      ],
    );
  }

  /// Sección de Inventario con banda indicadora vertical amarilla (SIN checkbox por indicación del usuario)
  Widget _buildSeccionInventario() {
    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banda vertical con la palabra "Inventario" (estilo eleventa)
            Container(
              width: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
              ),
              child: const Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'Inventario',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Campos de inventario: Hay, Mínimo, Máximo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo "Hay: [ 0 ] en este momento."
                    Row(
                      children: [
                        const SizedBox(
                          width: 65,
                          child: Text(
                            'Hay',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _hayController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'en este momento.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Campo "Mínimo: [ 0 ]"
                    Row(
                      children: [
                        const SizedBox(
                          width: 65,
                          child: Text(
                            'Mínimo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _minimoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Campo "Máximo: [ 0 ]"
                    Row(
                      children: [
                        const SizedBox(
                          width: 65,
                          child: Text(
                            'Máximo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: TextField(
                            controller: _maximoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila de campo con etiqueta a la izquierda alineada uniformemente
  Widget _buildFilaCampo({
    required String etiqueta,
    required Widget widgetCampo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        widgetCampo,
      ],
    );
  }

  /// Radio button personalizado con etiqueta
  Widget _buildRadioOpcion(String titulo, String valor) {
    final bool seleccionado = _tipoVenta == valor;

    return InkWell(
      onTap: () {
        setState(() => _tipoVenta = valor);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado ? AppColors.primary : const Color(0xFF9CA3AF),
                  width: seleccionado ? 5.5 : 1.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra inferior con "Guardar Producto" y "Cancelar"
  Widget _buildBarraInferiorAcciones() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Guardar Producto
          ElevatedButton.icon(
            onPressed: _guardarProducto,
            icon: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
            label: const Text(
              'Guardar Producto',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
          ),

          // Botón Cancelar
          OutlinedButton.icon(
            onPressed: _limpiarFormulario,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
            label: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
