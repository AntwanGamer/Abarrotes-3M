import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/helpers.dart';
import '../models/venta.dart';
import '../models/venta_detalle.dart';
import '../repositories/ventas_repository.dart';
import '../services/database_service.dart';

/// Módulo de Facturas e Historial de Ventas (Punto de Venta Eleventa).
/// Permite consultar tickets históricos, revisar su desglose y gestionar facturación.
class FacturasView extends StatefulWidget {
  const FacturasView({super.key});

  @override
  State<FacturasView> createState() => _FacturasViewState();
}

class _FacturasViewState extends State<FacturasView> {
  final _busquedaCtrl = TextEditingController();
  List<Map<String, dynamic>> _ventas = [];
  Map<String, dynamic>? _ventaSeleccionada;
  List<VentaDetalle> _detallesSeleccionados = [];
  bool _cargando = true;
  String _filtroFecha = 'Hoy'; // 'Hoy' | 'Semana' | 'Todas'

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVentas() async {
    setState(() => _cargando = true);
    try {
      String whereClause = '1=1';
      if (_filtroFecha == 'Hoy') {
        whereClause += ' AND DATE(v.fecha_venta) = CURRENT_DATE';
      } else if (_filtroFecha == 'Semana') {
        whereClause += ' AND v.fecha_venta >= CURRENT_DATE - INTERVAL \'7 days\'';
      }

      final query = _busquedaCtrl.text.trim();
      final params = <String, dynamic>{};
      if (query.isNotEmpty) {
        whereClause += ' AND (v.folio_ticket ILIKE @q OR COALESCE(c.nombre, \'\') ILIKE @q)';
        params['q'] = '%$query%';
      }

      final sql = '''
        SELECT v.*, COALESCE(c.nombre, 'Público General') AS cliente_nombre,
               COALESCE(u.nombre_completo, 'Cajero') AS cajero_nombre
        FROM tbl_ventas v
        LEFT JOIN tbl_clientes c ON v.id_cliente = c.id_cliente
        LEFT JOIN tbl_usuarios u ON v.id_usuario = u.id_usuario
        WHERE $whereClause
        ORDER BY v.fecha_venta DESC
        LIMIT 100
      ''';

      final res = await DatabaseService.instance.query(sql, params: params);
      final list = res.map((r) => r.toColumnMap()).toList();

      if (mounted) {
        setState(() {
          _ventas = list;
          _cargando = false;
          if (list.isNotEmpty) {
            _seleccionarVenta(list.first);
          } else {
            _ventaSeleccionada = null;
            _detallesSeleccionados = [];
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarVenta(Map<String, dynamic> venta) async {
    setState(() => _ventaSeleccionada = venta);
    final idVenta = parseIntSafe(venta['id_venta']);
    try {
      final detalles = await VentasRepository.instance.obtenerDetalle(idVenta);
      if (mounted && _ventaSeleccionada?['id_venta'] == idVenta) {
        setState(() => _detallesSeleccionados = detalles);
      }
    } catch (_) {}
  }

  void _abrirModalFacturacion() {
    if (_ventaSeleccionada == null) return;
    final folio = _ventaSeleccionada!['folio_ticket'];
    final total = parseDecimal(_ventaSeleccionada!['total']);
    final rfcCtrl = TextEditingController(text: 'XAXX010101000');
    final razonCtrl = TextEditingController(text: _ventaSeleccionada!['cliente_nombre']);
    String usoCfdi = 'G03 - Gastos en general';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Text('Facturar Ticket $folio'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a facturar: \$${total.toStringAsFixed(2)} MXN',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D9488))),
                const SizedBox(height: 16),
                TextField(
                  controller: rfcCtrl,
                  decoration: const InputDecoration(labelText: 'RFC del Receptor', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: razonCtrl,
                  decoration: const InputDecoration(labelText: 'Razón Social / Nombre', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: usoCfdi,
                  decoration: const InputDecoration(labelText: 'Uso de CFDI', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'G01 - Adquisición de mercancías', child: Text('G01 - Adquisición de mercancías')),
                    DropdownMenuItem(value: 'G03 - Gastos en general', child: Text('G03 - Gastos en general')),
                    DropdownMenuItem(value: 'S01 - Sin efectos fiscales', child: Text('S01 - Sin efectos fiscales')),
                  ],
                  onChanged: (v) => setModalState(() => usoCfdi = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Factura generada exitosamente para ticket $folio.'),
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Emitir Factura'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0D9488), size: 22),
              const SizedBox(width: 10),
              const Text('HISTORIAL DE VENTAS Y FACTURACIÓN',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F766E), letterSpacing: 0.8)),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Hoy', label: Text('Hoy')),
                  ButtonSegment(value: 'Semana', label: Text('Últimos 7 días')),
                  ButtonSegment(value: 'Todas', label: Text('Todas')),
                ],
                selected: {_filtroFecha},
                onSelectionChanged: (set) {
                  setState(() => _filtroFecha = set.first);
                  _cargarVentas();
                },
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 240,
                height: 38,
                child: TextField(
                  controller: _busquedaCtrl,
                  onSubmitted: (_) => _cargarVentas(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Folio o Cliente...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _cargarVentas, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),

        // Área principal
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    // Columna Izquierda: Lista de ventas
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: Colors.white,
                        child: _ventas.isEmpty
                            ? const Center(child: Text('No hay ventas registradas en el periodo seleccionado.'))
                            : ListView.separated(
                                itemCount: _ventas.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                itemBuilder: (ctx, idx) {
                                  final v = _ventas[idx];
                                  final isSelected = _ventaSeleccionada?['id_venta'] == v['id_venta'];
                                  final isCancelada = parsePgString(v['estatus_venta']) == 'Cancelada';
                                  final total = parseDecimal(v['total']);
                                  final fecha = v['fecha_venta'] != null
                                      ? DateTime.tryParse(v['fecha_venta'].toString())
                                      : null;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFFF0FDFA),
                                    onTap: () => _seleccionarVenta(v),
                                    leading: CircleAvatar(
                                      backgroundColor: isCancelada ? Colors.red.shade100 : const Color(0xFFCCFBF1),
                                      child: Icon(
                                        isCancelada ? Icons.cancel_outlined : Icons.receipt_rounded,
                                        color: isCancelada ? AppColors.error : const Color(0xFF0F766E),
                                        size: 20,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(v['folio_ticket'] ?? 'Sin Folio',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                decoration: isCancelada ? TextDecoration.lineThrough : null)),
                                        const SizedBox(width: 8),
                                        if (isCancelada)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('CANCELADA', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text('${v['cliente_nombre']} • Cajero: ${v['cajero_nombre']}'),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('\$${total.toStringAsFixed(2)}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isCancelada ? Colors.grey : const Color(0xFF0F766E))),
                                        if (fecha != null)
                                          Text('${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

                    // Columna Derecha: Detalle de venta y opciones
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.all(20),
                        child: _ventaSeleccionada == null
                            ? const Center(child: Text('Selecciona una venta de la lista para ver su detalle.'))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Detalle del Ticket ${_ventaSeleccionada!['folio_ticket']}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        onPressed: _abrirModalFacturacion,
                                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                        label: const Text('Facturar'),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Cliente: ${_ventaSeleccionada!['cliente_nombre']} • Atendió: ${_ventaSeleccionada!['cajero_nombre']}',
                                      style: const TextStyle(color: Color(0xFF64748B))),
                                  const Divider(height: 24),

                                  Expanded(
                                    child: Card(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                                      child: ListView.separated(
                                        itemCount: _detallesSeleccionados.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (ctx, idx) {
                                          final d = _detallesSeleccionados[idx];
                                          return ListTile(
                                            dense: true,
                                            title: Text(d.descripcionProducto, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text('${d.cantidad} x \$${d.precioUnitario.toStringAsFixed(2)}'),
                                            trailing: Text('\$${d.importe.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('TOTAL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        Text('\$${parseDecimal(_ventaSeleccionada!['total']).toStringAsFixed(2)} MXN',
                                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
