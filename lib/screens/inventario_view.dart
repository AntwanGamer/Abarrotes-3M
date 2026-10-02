import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Modelo de artículo para la tabla del Reporte de Inventario
class ItemInventario {
  final String codigo;
  final String descripcion;
  final String departamento;
  final double costo;
  final double precioVenta;
  int existencia;
  final int invMinimo;
  final int invMaximo;

  ItemInventario({
    required this.codigo,
    required this.descripcion,
    required this.departamento,
    required this.costo,
    required this.precioVenta,
    required this.existencia,
    required this.invMinimo,
    required this.invMaximo,
  });

  double get valorInventario => costo * existencia;
}

/// Vista del módulo de Inventario (Reporte de Inventario estilo Eleventa).
/// Incluye KPIs de costo/cantidad, filtro de departamento, alerta informativa y tabla de existencias.
class InventarioView extends StatefulWidget {
  const InventarioView({super.key});

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  String _subOpcionSeleccionada = 'Reporte de Inventario';
  String _departamentoSeleccionado = '- Todos -';
  int? _filaSeleccionadaIndex = 0;

  final List<String> _departamentos = [
    '- Todos -',
    'Abarrotes',
    'Bebidas',
    'Lácteos y Quesos',
    'Botanas y Dulces',
    'Limpieza del Hogar',
  ];

  // Datos representativos iniciales (como en la captura de eleventa)
  final List<ItemInventario> _productosInventario = [
    ItemInventario(
      codigo: 'NEW PRODUCTO',
      descripcion: 'Prueba 1',
      departamento: 'Abarrotes',
      costo: 10.00,
      precioVenta: 12.00,
      existencia: 15,
      invMinimo: 3,
      invMaximo: 24,
    ),
  ];

  List<ItemInventario> get _productosFiltrados {
    if (_departamentoSeleccionado == '- Todos -') {
      return _productosInventario;
    }
    return _productosInventario
        .where((p) => p.departamento == _departamentoSeleccionado)
        .toList();
  }

  double get _costoTotalInventario =>
      _productosFiltrados.fold(0.0, (acc, item) => acc + item.valorInventario);

  int get _cantidadTotalProductos =>
      _productosFiltrados.fold(0, (acc, item) => acc + item.existencia);

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.primaryDark,
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
        // 1. Barra de sub-opciones estilo Eleventa (Agregar, Ajustes, Reporte de Inventario...)
        _buildBarraSubOpciones(),

        // 2. Contenido principal del Reporte de Inventario
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel superior con Título, Métricas (Costo / Cantidad), Filtro y Botones
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título: "REPORTE DE INVENTARIO"
                      const Text(
                        'REPORTE DE INVENTARIO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Color(0xFF3B3B8F),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Métricas: Costo del inventario y Cantidad de productos en Inventario
                      Row(
                        children: [
                          _buildMetrica(
                            label: 'Costo del inventario',
                            valor: '\$${_costoTotalInventario.toStringAsFixed(2)}',
                          ),
                          const SizedBox(width: 60),
                          _buildMetrica(
                            label: 'Cantidad de productos en Inventario',
                            valor: '$_cantidadTotalProductos',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila con Filtro de Departamento a la izquierda y Botones a la derecha
                      Row(
                        children: [
                          const Text(
                            'Departamento:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _departamentoSeleccionado,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                isDense: true,
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
                          const Spacer(),

                          // Botones auxiliares a la derecha: Modificar Producto, Exportar..., Imprimir...
                          _buildBotonAccionHeader('Modificar Producto', Icons.edit_outlined),
                          const SizedBox(width: 8),
                          _buildBotonAccionHeader('Exportar...', Icons.file_download_outlined),
                          const SizedBox(width: 8),
                          _buildBotonAccionHeader('Imprimir...', Icons.print_outlined),
                        ],
                      ),
                    ],
                  ),
                ),

                // Franja informativa amarilla estilo Eleventa
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF9C3), // Amarillo pastel
                    border: Border(
                      top: BorderSide(color: Color(0xFFFDE047), width: 1),
                      bottom: BorderSide(color: Color(0xFFFDE047), width: 1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF854D0E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ahora en este reporte solo se muestran los productos que manejan inventario. Si deseas ver todos tus productos independientemente si usan inventario o no, consulta el nuevo reporte en Productos > Catálogo.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF713F12), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabla de datos del inventario
                Expanded(
                  child: _buildTablaInventario(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Barra de sub-opciones horizontal (Agregar, Ajustes, Reporte de Inventario...)
  Widget _buildBarraSubOpciones() {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          _buildBotonSubOpcion('Agregar', Icons.add_circle_outline_rounded),
          const SizedBox(width: 6),
          _buildBotonSubOpcion('Ajustes', Icons.edit_note_rounded),
          const SizedBox(width: 6),
          _buildBotonSubOpcion('Productos bajos en Inventario', Icons.error_outline_rounded, colorIcono: AppColors.error),
          const SizedBox(width: 6),
          _buildBotonSubOpcion('Reporte de Inventario', Icons.assignment_outlined),
          const SizedBox(width: 6),
          _buildBotonSubOpcion('Reporte de Movimientos', Icons.history_rounded),
          const SizedBox(width: 6),
          _buildBotonSubOpcion('Kardex de inventario', Icons.view_list_rounded),
        ],
      ),
    );
  }

  Widget _buildBotonSubOpcion(String titulo, IconData icono, {Color? colorIcono}) {
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
              color: activo ? const Color(0xFFB45309) : (colorIcono ?? AppColors.textSecondary),
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

  Widget _buildMetrica({required String label, required String valor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildBotonAccionHeader(String texto, IconData icono) {
    return InkWell(
      onTap: () => _mostrarMensaje('$texto ejecutado'),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD1D5DB)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tabla con encabezados: Código, Descripción, Costo, Precio Venta, Existencia, Inv. Mínimo, Inv. Máximo
  Widget _buildTablaInventario() {
    final items = _productosFiltrados;

    return Column(
      children: [
        // Encabezados de la tabla con líneas divisorias
        Container(
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(
              bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 140,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Código', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Descripción del Producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Costo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Precio Venta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Existencia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Inv. Mínimo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
              VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
              SizedBox(
                width: 110,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Inv. Máximo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),

        // Filas de la tabla
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos registrados en este departamento',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool seleccionado = _filaSeleccionadaIndex == index;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _filaSeleccionadaIndex = index;
                        });
                      },
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: seleccionado
                              ? const Color(0xFFEFF6FF)
                              : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                          border: Border(
                            bottom: BorderSide(
                              color: seleccionado ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 140,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(item.codigo, style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(item.descripcion, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('\$${item.costo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('\$${item.precioVenta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            // Existencia con sombreado tenue como en Eleventa
                            Container(
                              width: 110,
                              color: const Color(0xFFF1F5F9),
                              child: Center(
                                child: Text(
                                  '${item.existencia}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            SizedBox(
                              width: 110,
                              child: Center(
                                child: Text('${item.invMinimo}', style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const VerticalDivider(width: 1, color: Color(0xFFF1F5F9)),
                            SizedBox(
                              width: 110,
                              child: Center(
                                child: Text('${item.invMaximo}', style: const TextStyle(fontSize: 12)),
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
    );
  }
}
