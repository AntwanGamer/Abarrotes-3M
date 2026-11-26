import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/departamento.dart';
import '../models/permisos_ventanas.dart';
import '../models/producto.dart';
import '../models/promocion.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalogos_repository.dart';
import '../repositories/productos_repository.dart';

/// Vista del módulo de Productos (estilo Eleventa).
/// Incluye las 8 sub-pestañas conectadas a PostgreSQL local (Offline-First).
class ProductosView extends StatefulWidget {
  const ProductosView({super.key});

  @override
  State<ProductosView> createState() => _ProductosViewState();
}

class _ProductosViewState extends State<ProductosView> {
  final _prodRepo = ProductosRepository.instance;
  final _catRepo = CatalogosRepository.instance;

  String _subOpcion = 'Nuevo';
  Producto? _productoAModificar;
  List<Departamento> _departamentos = [];

  @override
  void initState() {
    super.initState();
    _cargarDepartamentos();
  }

  Future<void> _cargarDepartamentos() async {
    try {
      final deptos = await _catRepo.obtenerDepartamentos();
      if (mounted) setState(() => _departamentos = deptos);
    } catch (_) {}
  }

  bool get _puedeEditar =>
      AuthRepository.instance.tieneAcceso(PermisosVentanas.inventarioEditarKey);

  void _irAModificar(Producto p) {
    setState(() {
      _productoAModificar = p;
      _subOpcion = 'Modificar';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra horizontal de sub-pestañas
        _buildBarraSubOpciones(),

        // 2. Contenido de la sub-pestaña seleccionada
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildContenido(),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraSubOpciones() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          if (_puedeEditar) ...[
            _buildBotonTab('Nuevo', Icons.add_circle_outline_rounded),
            const SizedBox(width: 6),
            _buildBotonTab('Modificar', Icons.edit_outlined),
            const SizedBox(width: 6),
            _buildBotonTab('Eliminar', Icons.delete_outline_rounded),
            const SizedBox(width: 6),
          ],
          _buildBotonTab('Departamentos', Icons.folder_outlined),
          const SizedBox(width: 6),
          _buildBotonTab('Ventas por Periodo', Icons.insert_chart_outlined_rounded),
          const SizedBox(width: 6),
          _buildBotonTab('Promociones', Icons.star_border_rounded),
          const SizedBox(width: 6),
          if (_puedeEditar) ...[
            _buildBotonTab('Importar', Icons.file_download_outlined),
            const SizedBox(width: 6),
          ],
          _buildBotonTab('Catálogo', Icons.menu_book_outlined),
        ],
      ),
    );
  }

  Widget _buildBotonTab(String titulo, IconData icono) {
    final activo = _subOpcion == titulo;
    return InkWell(
      onTap: () => setState(() => _subOpcion = titulo),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildContenido() {
    switch (_subOpcion) {
      case 'Nuevo':
        return _FormularioProducto(
          departamentos: _departamentos,
          onGuardado: () => setState(() => _subOpcion = 'Catálogo'),
        );
      case 'Modificar':
        return _PestanaModificar(
          productoInicial: _productoAModificar,
          departamentos: _departamentos,
          onGuardado: () => setState(() {
            _productoAModificar = null;
            _subOpcion = 'Catálogo';
          }),
        );
      case 'Eliminar':
        return _PestanaEliminar(
          onEliminado: () => setState(() => _subOpcion = 'Catálogo'),
        );
      case 'Departamentos':
        return _PestanaDepartamentos(
          departamentos: _departamentos,
          onDepartamentosCambiados: _cargarDepartamentos,
        );
      case 'Ventas por Periodo':
        return _PestanaVentasPeriodo(departamentos: _departamentos);
      case 'Promociones':
        return const _PestanaPromociones();
      case 'Importar':
        return _PestanaImportarCSV(
          onImportado: () {
            _cargarDepartamentos();
            setState(() => _subOpcion = 'Catálogo');
          },
        );
      case 'Catálogo':
      default:
        return _PestanaCatalogo(
          departamentos: _departamentos,
          onEditar: _irAModificar,
        );
    }
  }
}

// =============================================================================
// FORMULARIO REUTILIZABLE DE PRODUCTO (NUEVO / MODIFICAR)
// =============================================================================
class _FormularioProducto extends StatefulWidget {
  final Producto? producto;
  final List<Departamento> departamentos;
  final VoidCallback onGuardado;

  const _FormularioProducto({
    super.key,
    this.producto,
    required this.departamentos,
    required this.onGuardado,
  });

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _codigoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costoCtrl = TextEditingController(text: '0.00');
  final _gananciaCtrl = TextEditingController(text: '20.00');
  final _ventaCtrl = TextEditingController(text: '0.00');
  final _mayoreoCtrl = TextEditingController(text: '0.00');
  final _cantMayoreoCtrl = TextEditingController(text: '0');
  final _existenciaCtrl = TextEditingController(text: '0');
  final _minCtrl = TextEditingController(text: '0');
  final _maxCtrl = TextEditingController(text: '0');
  final _tasaIvaCtrl = TextEditingController(text: '16.00');

  String _tipoVenta = 'Unidad'; // 'Unidad' | 'Granel'
  int? _idDepartamento;
  bool _usaInventario = true;
  bool _aplicaIva = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p != null) {
      _codigoCtrl.text = p.codigoBarras;
      _descCtrl.text = p.descripcion;
      _costoCtrl.text = p.precioCosto.toStringAsFixed(2);
      _ventaCtrl.text = p.precioVenta.toStringAsFixed(2);
      if (p.precioCosto > 0) {
        final g = ((p.precioVenta - p.precioCosto) / p.precioCosto) * 100;
        _gananciaCtrl.text = g.toStringAsFixed(2);
      }
      _mayoreoCtrl.text = (p.precioMayoreo ?? 0.0).toStringAsFixed(2);
      _cantMayoreoCtrl.text = (p.cantidadMayoreo ?? 0.0).toStringAsFixed(0);
      _existenciaCtrl.text = p.existencia.toStringAsFixed(3);
      _minCtrl.text = p.inventarioMinimo.toStringAsFixed(3);
      _maxCtrl.text = p.inventarioMaximo.toStringAsFixed(3);
      _tipoVenta = p.tipoVenta;
      _idDepartamento = p.idDepartamento;
      _usaInventario = p.usaInventario;
      _aplicaIva = p.aplicaIva;
      _tasaIvaCtrl.text = p.tasaIva.toStringAsFixed(2);
    } else {
      if (widget.departamentos.isNotEmpty) {
        _idDepartamento = widget.departamentos.first.idDepartamento;
      }
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _descCtrl.dispose();
    _costoCtrl.dispose();
    _gananciaCtrl.dispose();
    _ventaCtrl.dispose();
    _mayoreoCtrl.dispose();
    _cantMayoreoCtrl.dispose();
    _existenciaCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _tasaIvaCtrl.dispose();
    super.dispose();
  }

  void _calcularVenta() {
    final c = double.tryParse(_costoCtrl.text) ?? 0.0;
    final g = double.tryParse(_gananciaCtrl.text) ?? 0.0;
    if (c >= 0) {
      _ventaCtrl.text = (c * (1 + (g / 100))).toStringAsFixed(2);
    }
  }

  void _calcularGanancia() {
    final c = double.tryParse(_costoCtrl.text) ?? 0.0;
    final v = double.tryParse(_ventaCtrl.text) ?? 0.0;
    if (c > 0 && v >= c) {
      _gananciaCtrl.text = (((v - c) / c) * 100).toStringAsFixed(2);
    }
  }

  Future<void> _guardar() async {
    final codigo = _codigoCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (codigo.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de barras y descripción son obligatorios'), backgroundColor: AppColors.error),
      );
      return;
    }

    final deptoId = _idDepartamento ?? (widget.departamentos.isNotEmpty ? widget.departamentos.first.idDepartamento : 1);
    final costo = double.tryParse(_costoCtrl.text.trim()) ?? 0.0;
    final venta = double.tryParse(_ventaCtrl.text.trim()) ?? 0.0;
    final mayoreo = double.tryParse(_mayoreoCtrl.text.trim());
    final cantMayoreo = double.tryParse(_cantMayoreoCtrl.text.trim());
    final existencia = double.tryParse(_existenciaCtrl.text.trim()) ?? 0.0;
    final min = double.tryParse(_minCtrl.text.trim()) ?? 0.0;
    final max = double.tryParse(_maxCtrl.text.trim()) ?? 0.0;
    final tasaIva = double.tryParse(_tasaIvaCtrl.text.trim()) ?? 16.0;

    setState(() => _guardando = true);
    try {
      if (widget.producto == null) {
        // CREAR
        await ProductosRepository.instance.crear(
          codigoBarras: codigo,
          descripcion: desc,
          precioCosto: costo,
          precioVenta: venta,
          precioMayoreo: (mayoreo != null && mayoreo > 0) ? mayoreo : null,
          cantidadMayoreo: (cantMayoreo != null && cantMayoreo > 0) ? cantMayoreo : null,
          existencia: existencia,
          inventarioMinimo: min,
          inventarioMaximo: max,
          usaInventario: _usaInventario,
          tipoVenta: _tipoVenta,
          aplicaIva: _aplicaIva,
          tasaIva: _aplicaIva ? tasaIva : 0.0,
          idDepartamento: deptoId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto "$desc" creado exitosamente.'), backgroundColor: Colors.green.shade700),
          );
        }
      } else {
        // ACTUALIZAR
        final actualizado = Producto(
          idProducto: widget.producto!.idProducto,
          codigoBarras: codigo,
          descripcion: desc,
          idDepartamento: deptoId,
          tipoVenta: _tipoVenta,
          precioCosto: costo,
          precioVenta: venta,
          precioMayoreo: (mayoreo != null && mayoreo > 0) ? mayoreo : null,
          cantidadMayoreo: (cantMayoreo != null && cantMayoreo > 0) ? cantMayoreo : null,
          usaInventario: _usaInventario,
          existencia: existencia,
          inventarioMinimo: min,
          inventarioMaximo: max,
          aplicaIva: _aplicaIva,
          tasaIva: _aplicaIva ? tasaIva : 0.0,
          estatus: widget.producto!.estatus,
          fechaRegistro: widget.producto!.fechaRegistro,
          fechaActualizacion: DateTime.now(),
          uuidSync: widget.producto!.uuidSync,
          sincronizado: false,
        );
        await ProductosRepository.instance.actualizar(actualizado);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto "$desc" actualizado exitosamente.'), backgroundColor: Colors.green.shade700),
          );
        }
      }
      widget.onGuardado();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.producto == null ? 'NUEVO PRODUCTO' : 'MODIFICAR PRODUCTO #${widget.producto!.idProducto}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD97706), letterSpacing: 1.1),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Código de barras
                  _buildFila(
                    'Código de Barras *',
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _codigoCtrl,
                        autofocus: widget.producto == null,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                          hintText: 'Ej. 7501055312345',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Descripción
                  _buildFila(
                    'Descripción *',
                    SizedBox(
                      width: 480,
                      child: TextField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Coca Cola 600ml Desechable',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Se vende
                  _buildFila(
                    'Tipo de venta',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: 'Unidad', groupValue: _tipoVenta, onChanged: (v) => setState(() => _tipoVenta = v!)),
                        const Text('Por Unidad/Pza'),
                        const SizedBox(width: 20),
                        Radio<String>(value: 'Granel', groupValue: _tipoVenta, onChanged: (v) => setState(() => _tipoVenta = v!)),
                        const Text('A Granel (Usa Decimales)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Costo y Ganancia
                  _buildFila(
                    'Precio Costo',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _costoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => _calcularVenta(),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Text('Ganancia:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _gananciaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder(), isDense: true),
                            onChanged: (_) => _calcularVenta(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Precio Venta
                  _buildFila(
                    'Precio Venta *',
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _ventaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
                        onChanged: (_) => _calcularGanancia(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mayoreo
                  _buildFila(
                    'Precio Mayoreo',
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _mayoreoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Text('A partir de:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _cantMayoreoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'Cant.', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Departamento
                  _buildFila(
                    'Departamento',
                    Container(
                      width: 280,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _idDepartamento,
                          isExpanded: true,
                          items: widget.departamentos
                              .map((d) => DropdownMenuItem(value: d.idDepartamento, child: Text(d.nombreDepartamento)))
                              .toList(),
                          onChanged: (v) => setState(() => _idDepartamento = v),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // IVA
                  _buildFila(
                    'Impuestos',
                    Row(
                      children: [
                        Checkbox(value: _aplicaIva, onChanged: (v) => setState(() => _aplicaIva = v ?? false)),
                        const Text('Aplica IVA'),
                        if (_aplicaIva) ...[
                          const SizedBox(width: 16),
                          const Text('Tasa:'),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _tasaIvaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sección Inventario
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _usaInventario,
                              onChanged: (v) => setState(() => _usaInventario = v ?? true),
                            ),
                            const Text(
                              'Este producto utiliza control de Inventario',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                        if (_usaInventario) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(width: 32),
                              const Text('Existencia actual: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: _existenciaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Text('Mínimo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _minCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Text('Máximo: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _maxCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón Guardar
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(widget.producto == null ? 'Guardar Producto' : 'Guardar Cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
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

  Widget _buildFila(String label, Widget campo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
        ),
        const SizedBox(width: 16),
        campo,
      ],
    );
  }
}

// =============================================================================
// 2. SUB-PESTAÑA: MODIFICAR
// =============================================================================
class _PestanaModificar extends StatefulWidget {
  final Producto? productoInicial;
  final List<Departamento> departamentos;
  final VoidCallback onGuardado;

  const _PestanaModificar({
    this.productoInicial,
    required this.departamentos,
    required this.onGuardado,
  });

  @override
  State<_PestanaModificar> createState() => _PestanaModificarState();
}

class _PestanaModificarState extends State<_PestanaModificar> {
  final _busquedaCtrl = TextEditingController();
  Producto? _producto;
  bool _buscando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _producto = widget.productoInicial;
    if (_producto != null) {
      _busquedaCtrl.text = _producto!.codigoBarras;
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _buscando = true;
      _error = null;
    });

    try {
      Producto? p = await ProductosRepository.instance.buscarPorCodigo(q);
      if (p == null) {
        final list = await ProductosRepository.instance.buscarPorDescripcion(q);
        if (list.isNotEmpty) p = list.first;
      }

      setState(() {
        _buscando = false;
        _producto = p;
        if (p == null) _error = 'No se encontró ningún producto con ese criterio.';
      });
    } catch (e) {
      setState(() {
        _buscando = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Buscador superior
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto a modificar',
                    hintText: 'Ingresa código o descripción...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _buscar,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _buscar(_busquedaCtrl.text),
                icon: const Icon(Icons.search),
                label: const Text('Cargar'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),

        Expanded(
          child: _producto == null
              ? const Center(child: Text('Busca un producto por código o descripción para cargar su formulario de edición.'))
              : _FormularioProducto(
                  key: ValueKey(_producto!.idProducto),
                  producto: _producto,
                  departamentos: widget.departamentos,
                  onGuardado: widget.onGuardado,
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// 3. SUB-PESTAÑA: ELIMINAR (BAJA LÓGICA)
// =============================================================================
class _PestanaEliminar extends StatefulWidget {
  final VoidCallback onEliminado;
  const _PestanaEliminar({required this.onEliminado});

  @override
  State<_PestanaEliminar> createState() => _PestanaEliminarState();
}

class _PestanaEliminarState extends State<_PestanaEliminar> {
  final _busquedaCtrl = TextEditingController();
  Producto? _producto;
  bool _eliminando = false;
  String? _error;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _error = null);

    try {
      Producto? p = await ProductosRepository.instance.buscarPorCodigo(q);
      if (p == null) {
        final list = await ProductosRepository.instance.buscarPorDescripcion(q);
        if (list.isNotEmpty) p = list.first;
      }
      setState(() {
        _producto = p;
        if (p == null) _error = 'Producto no encontrado';
      });
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  Future<void> _confirmarEliminar() async {
    if (_producto == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Confirmar Baja de Producto'),
          ],
        ),
        content: Text(
          '¿Estás seguro de dar de baja lógica al producto "${_producto!.descripcion}" (Código: ${_producto!.codigoBarras})?\n\n'
          'No se borrarán sus ventas históricas, pero ya no aparecerá en el Punto de Venta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Sí, Dar de Baja'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() => _eliminando = true);
      try {
        await ProductosRepository.instance.eliminar(_producto!.idProducto);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Producto "${_producto!.descripcion}" dado de baja.'), backgroundColor: Colors.orange.shade800),
          );
          widget.onEliminado();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _eliminando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 24),
                      SizedBox(width: 8),
                      Text('DAR DE BAJA UN PRODUCTO',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Busca el producto para verificar sus datos antes de retirarlo del catálogo activo.'),
                  const Divider(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busquedaCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Código de barras o descripción',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: _buscar,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _buscar(_busquedaCtrl.text),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],

                  if (_producto != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_producto!.descripcion, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Código: ${_producto!.codigoBarras}'),
                          Text('Precio de venta: \$${_producto!.precioVenta.toStringAsFixed(2)}'),
                          Text('Existencia actual: ${_producto!.existencia.toStringAsFixed(3)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _eliminando ? null : _confirmarEliminar,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(_eliminando ? 'Eliminando...' : 'Dar de Baja Producto'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. SUB-PESTAÑA: DEPARTAMENTOS
// =============================================================================
class _PestanaDepartamentos extends StatefulWidget {
  final List<Departamento> departamentos;
  final VoidCallback onDepartamentosCambiados;

  const _PestanaDepartamentos({
    required this.departamentos,
    required this.onDepartamentosCambiados,
  });

  @override
  State<_PestanaDepartamentos> createState() => _PestanaDepartamentosState();
}

class _PestanaDepartamentosState extends State<_PestanaDepartamentos> {
  final _nombreCtrl = TextEditingController();
  Departamento? _departamentoEnEdicion;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarDepartamento() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;

    setState(() => _guardando = true);
    try {
      if (_departamentoEnEdicion == null) {
        await CatalogosRepository.instance.crearDepartamento(nombre);
      } else {
        await CatalogosRepository.instance.actualizarDepartamento(_departamentoEnEdicion!.idDepartamento, nombre);
      }
      _nombreCtrl.clear();
      _departamentoEnEdicion = null;
      widget.onDepartamentosCambiados();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarDepartamento(Departamento d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Departamento'),
        content: Text('¿Deseas dar de baja el departamento "${d.nombreDepartamento}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await CatalogosRepository.instance.eliminarDepartamento(d.idDepartamento);
      widget.onDepartamentosCambiados();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulario a la izquierda
          SizedBox(
            width: 340,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _departamentoEnEdicion == null ? 'NUEVO DEPARTAMENTO' : 'EDITAR DEPARTAMENTO',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del departamento *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _guardarDepartamento(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (_departamentoEnEdicion != null)
                          TextButton(
                            onPressed: () => setState(() {
                              _departamentoEnEdicion = null;
                              _nombreCtrl.clear();
                            }),
                            child: const Text('Cancelar'),
                          ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _guardando ? null : _guardarDepartamento,
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(_departamentoEnEdicion == null ? 'Agregar' : 'Actualizar'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Tabla a la derecha
          Expanded(
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Nombre de Departamento', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: widget.departamentos.map((d) {
                    return DataRow(
                      cells: [
                        DataCell(Text('#${d.idDepartamento}')),
                        DataCell(Text(d.nombreDepartamento, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                tooltip: 'Editar',
                                onPressed: () {
                                  setState(() {
                                    _departamentoEnEdicion = d;
                                    _nombreCtrl.text = d.nombreDepartamento;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                tooltip: 'Eliminar',
                                onPressed: () => _eliminarDepartamento(d),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 5. SUB-PESTAÑA: VENTAS POR PERIODO
// =============================================================================
class _PestanaVentasPeriodo extends StatefulWidget {
  final List<Departamento> departamentos;
  const _PestanaVentasPeriodo({required this.departamentos});

  @override
  State<_PestanaVentasPeriodo> createState() => _PestanaVentasPeriodoState();
}

class _PestanaVentasPeriodoState extends State<_PestanaVentasPeriodo> {
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();
  int? _idDepartamento;
  List<VentaPorPeriodoItem> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await ProductosRepository.instance.obtenerVentasPorPeriodo(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        idDepartamento: _idDepartamento,
      );
      if (mounted) setState(() => _items = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
    );
    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
      _cargar();
    }
  }

  double get _totalVendido => _items.fold(0.0, (acc, i) => acc + i.totalVendido);
  double get _totalUtilidad => _items.fold(0.0, (acc, i) => acc + i.utilidadEstimada);

  @override
  Widget build(BuildContext context) {
    final fIni = '${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year}';
    final fFin = '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year}';

    return Column(
      children: [
        // Filtros superiores
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _seleccionarRango,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text('Periodo: $fIni - $fFin'),
              ),
              const SizedBox(width: 16),
              const Text('Departamento: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _idDepartamento,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('- Todos los Departamentos -')),
                      ...widget.departamentos.map((d) => DropdownMenuItem(value: d.idDepartamento, child: Text(d.nombreDepartamento))),
                    ],
                    onChanged: (v) {
                      setState(() => _idDepartamento = v);
                      _cargar();
                    },
                  ),
                ),
              ),
              const Spacer(),
              Text('Total: \$${_totalVendido.toStringAsFixed(2)} • Utilidad: \$${_totalUtilidad.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD97706))),
              const SizedBox(width: 12),
              IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No hay ventas completadas en el periodo seleccionado.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            columns: const [
                              DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Departamento', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Cantidad Vendida', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Total Vendido', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Utilidad Estimada', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _items.map((i) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(i.codigo)),
                                  DataCell(Text(i.descripcion, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(i.departamento)),
                                  DataCell(Text(i.cantidadVendida.toStringAsFixed(2))),
                                  DataCell(Text('\$${i.totalVendido.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(
                                    Text(
                                      '\$${i.utilidadEstimada.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

// =============================================================================
// 6. SUB-PESTAÑA: PROMOCIONES
// =============================================================================
class _PestanaPromociones extends StatefulWidget {
  const _PestanaPromociones();

  @override
  State<_PestanaPromociones> createState() => _PestanaPromocionesState();
}

class _PestanaPromocionesState extends State<_PestanaPromociones> {
  List<PromocionConProducto> _promociones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await CatalogosRepository.instance.obtenerTodasPromociones();
      if (mounted) setState(() => _promociones = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _abrirDialogoPromocion([PromocionConProducto? item]) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoFormularioPromocion(item: item),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _desactivar(int idPromocion) async {
    await CatalogosRepository.instance.desactivarPromocion(idPromocion);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Encabezado
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 8),
              const Text('PROMOCIONES ACTIVAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _abrirDialogoPromocion(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva Promoción'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              ),
              const SizedBox(width: 10),
              IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _promociones.isEmpty
                  ? const Center(child: Text('No hay promociones configuradas.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            columns: const [
                              DataColumn(label: Text('Nombre Promoción', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Regla / Descuento', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Vigencia', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _promociones.map((p) {
                              final pr = p.promocion;
                              String regla = '';
                              if (pr.tipoPromocion == 'Multiple') {
                                regla = 'Lleva ${pr.cantidadMinima.toStringAsFixed(0)} paga ${(pr.cantidadPaga ?? 0).toStringAsFixed(0)}';
                              } else if (pr.tipoPromocion == 'Porcentaje') {
                                regla = '${pr.valorDescuento.toStringAsFixed(1)}% de desc. (mín ${pr.cantidadMinima.toStringAsFixed(0)})';
                              } else {
                                regla = '\$${pr.valorDescuento.toStringAsFixed(2)} de desc. (mín ${pr.cantidadMinima.toStringAsFixed(0)})';
                              }

                              final fIni = '${pr.fechaInicio.day}/${pr.fechaInicio.month}/${pr.fechaInicio.year}';
                              final fFin = '${pr.fechaFin.day}/${pr.fechaFin.month}/${pr.fechaFin.year}';

                              return DataRow(
                                cells: [
                                  DataCell(Text(pr.nombrePromocion, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text('${p.codigoBarras} - ${p.descripcionProducto}')),
                                  DataCell(Text(pr.tipoPromocion)),
                                  DataCell(Text(regla, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900))),
                                  DataCell(Text('$fIni a $fFin')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                          onPressed: () => _abrirDialogoPromocion(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          onPressed: () => _desactivar(pr.idPromocion),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _DialogoFormularioPromocion extends StatefulWidget {
  final PromocionConProducto? item;
  const _DialogoFormularioPromocion({this.item});

  @override
  State<_DialogoFormularioPromocion> createState() => _DialogoFormularioPromocionState();
}

class _DialogoFormularioPromocionState extends State<_DialogoFormularioPromocion> {
  final _nombreCtrl = TextEditingController();
  final _busquedaProdCtrl = TextEditingController();
  final _cantMinCtrl = TextEditingController(text: '2');
  final _cantPagaCtrl = TextEditingController(text: '1');
  final _valorDescCtrl = TextEditingController(text: '10.00');

  Producto? _producto;
  String _tipo = 'Multiple'; // 'Porcentaje' | 'Monto' | 'Multiple'
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 30));
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      final pr = it.promocion;
      _nombreCtrl.text = pr.nombrePromocion;
      _tipo = pr.tipoPromocion;
      _cantMinCtrl.text = pr.cantidadMinima.toStringAsFixed(0);
      _cantPagaCtrl.text = (pr.cantidadPaga ?? 0).toStringAsFixed(0);
      _valorDescCtrl.text = pr.valorDescuento.toStringAsFixed(2);
      _fechaInicio = pr.fechaInicio;
      _fechaFin = pr.fechaFin;
      _busquedaProdCtrl.text = it.codigoBarras;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _busquedaProdCtrl.dispose();
    _cantMinCtrl.dispose();
    _cantPagaCtrl.dispose();
    _valorDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarProd(String q) async {
    if (q.trim().isEmpty) return;
    Producto? p = await ProductosRepository.instance.buscarPorCodigo(q.trim());
    if (p == null) {
      final l = await ProductosRepository.instance.buscarPorDescripcion(q.trim());
      if (l.isNotEmpty) p = l.first;
    }
    setState(() => _producto = p);
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    final idProd = _producto?.idProducto ?? widget.item?.promocion.idProducto;
    if (nombre.isEmpty || idProd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre y selecciona un producto.')),
      );
      return;
    }

    final cantMin = double.tryParse(_cantMinCtrl.text) ?? 2.0;
    final cantPaga = double.tryParse(_cantPagaCtrl.text);
    final valorDesc = double.tryParse(_valorDescCtrl.text) ?? 0.0;

    setState(() => _guardando = true);
    try {
      if (widget.item == null) {
        await CatalogosRepository.instance.crearPromocion(
          nombrePromocion: nombre,
          idProducto: idProd,
          tipoPromocion: _tipo,
          cantidadMinima: cantMin,
          cantidadPaga: _tipo == 'Multiple' ? cantPaga : null,
          valorDescuento: _tipo != 'Multiple' ? valorDesc : 0.0,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );
      } else {
        await CatalogosRepository.instance.actualizarPromocion(
          idPromocion: widget.item!.promocion.idPromocion,
          nombrePromocion: nombre,
          idProducto: idProd,
          tipoPromocion: _tipo,
          cantidadMinima: cantMin,
          cantidadPaga: _tipo == 'Multiple' ? cantPaga : null,
          valorDescuento: _tipo != 'Multiple' ? valorDesc : 0.0,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Nueva Promoción' : 'Editar Promoción'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la promoción *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busquedaProdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código de barras del producto *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _buscarProd,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _buscarProd(_busquedaProdCtrl.text), child: const Text('Buscar')),
                ],
              ),
              if (_producto != null) ...[
                const SizedBox(height: 6),
                Text('Seleccionado: ${_producto!.descripcion}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de Promoción', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Multiple', child: Text('Múltiple (Ej. 3x2, Pague 2 lleve 3)')),
                  DropdownMenuItem(value: 'Porcentaje', child: Text('Porcentaje de Descuento (%)')),
                  DropdownMenuItem(value: 'Monto', child: Text('Monto de Descuento en Dinero (\$)')),
                ],
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 12),

              if (_tipo == 'Multiple') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cantMinCtrl,
                        decoration: const InputDecoration(labelText: 'Lleva (Cant. Mínima) *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cantPagaCtrl,
                        decoration: const InputDecoration(labelText: 'Paga (Cant. Cobrada) *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cantMinCtrl,
                        decoration: const InputDecoration(labelText: 'A partir de cuántas pzas *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _valorDescCtrl,
                        decoration: InputDecoration(
                          labelText: _tipo == 'Porcentaje' ? 'Porcentaje de descuento *' : 'Monto de descuento (\$)',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
          child: _guardando ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar'),
        ),
      ],
    );
  }
}

// =============================================================================
// 7. SUB-PESTAÑA: IMPORTAR CSV
// =============================================================================
class _PestanaImportarCSV extends StatefulWidget {
  final VoidCallback onImportado;
  const _PestanaImportarCSV({required this.onImportado});

  @override
  State<_PestanaImportarCSV> createState() => _PestanaImportarCSVState();
}

class _PestanaImportarCSVState extends State<_PestanaImportarCSV> {
  List<Map<String, dynamic>> _registros = [];
  bool _procesandoArchivo = false;
  bool _importando = false;
  String? _nombreArchivo;

  Future<void> _seleccionarArchivo() async {
    setState(() => _procesandoArchivo = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        _nombreArchivo = file.name;

        final bytes = await file.readAsBytes();
        final rawContent = utf8.decode(bytes);
        final rows = csv.decode(rawContent);

        if (rows.length > 1) {
          // Encabezados en primera fila
          final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
          final data = <Map<String, dynamic>>[];

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.isEmpty) continue;
            final map = <String, dynamic>{};
            for (int h = 0; h < headers.length && h < row.length; h++) {
              map[headers[h]] = row[h];
            }

            // Normalización de columnas comunes
            final codigo = map['codigo_barras'] ?? map['codigo'] ?? map['barcode'] ?? '';
            final desc = map['descripcion'] ?? map['nombre'] ?? map['producto'] ?? '';
            final costo = map['precio_costo'] ?? map['costo'] ?? '0.00';
            final venta = map['precio_venta'] ?? map['precio'] ?? '0.00';
            final existencia = map['existencia'] ?? map['stock'] ?? '0';
            final min = map['inventario_minimo'] ?? map['minimo'] ?? '0';
            final depto = map['departamento'] ?? map['categoria'] ?? 'General';

            if (codigo.toString().trim().isNotEmpty && desc.toString().trim().isNotEmpty) {
              data.add({
                'codigo_barras': codigo.toString().trim(),
                'descripcion': desc.toString().trim(),
                'precio_costo': costo,
                'precio_venta': venta,
                'existencia': existencia,
                'inventario_minimo': min,
                'departamento': depto.toString().trim(),
              });
            }
          }

          setState(() {
            _registros = data;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer CSV: $e')));
      }
    } finally {
      if (mounted) setState(() => _procesandoArchivo = false);
    }
  }

  Future<void> _confirmarImportacion() async {
    if (_registros.isEmpty) return;
    setState(() => _importando = true);
    try {
      final total = await ProductosRepository.instance.importarProductosCSV(_registros);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Importación completada! Se procesaron $total productos.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
        widget.onImportado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar a la base de datos: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _procesandoArchivo ? null : _seleccionarArchivo,
                icon: const Icon(Icons.file_upload),
                label: const Text('Seleccionar Archivo .CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
              ),
              const SizedBox(width: 14),
              if (_nombreArchivo != null)
                Text('Archivo: $_nombreArchivo (${_registros.length} filas leídas)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_registros.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _importando ? null : _confirmarImportacion,
                  icon: _importando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(_importando ? 'Importando...' : 'Confirmar Importación a Base de Datos'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _registros.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_view_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Selecciona un archivo .csv delimitado por comas.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Columnas esperadas: codigo_barras, descripcion, precio_costo, precio_venta, existencia, inventario_minimo, departamento',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                        columns: const [
                          DataColumn(label: Text('Código')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Costo')),
                          DataColumn(label: Text('Venta')),
                          DataColumn(label: Text('Existencia')),
                          DataColumn(label: Text('Mínimo')),
                          DataColumn(label: Text('Departamento')),
                        ],
                        rows: _registros.take(100).map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(r['codigo_barras'] ?? '')),
                              DataCell(Text(r['descripcion'] ?? '')),
                              DataCell(Text('\$${r['precio_costo']}')),
                              DataCell(Text('\$${r['precio_venta']}')),
                              DataCell(Text('${r['existencia']}')),
                              DataCell(Text('${r['inventario_minimo']}')),
                              DataCell(Text(r['departamento'] ?? '')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// =============================================================================
// 8. SUB-PESTAÑA: CATÁLOGO GENERAL
// =============================================================================
class _PestanaCatalogo extends StatefulWidget {
  final List<Departamento> departamentos;
  final void Function(Producto) onEditar;

  const _PestanaCatalogo({
    required this.departamentos,
    required this.onEditar,
  });

  @override
  State<_PestanaCatalogo> createState() => _PestanaCatalogoState();
}

class _PestanaCatalogoState extends State<_PestanaCatalogo> {
  final _busquedaCtrl = TextEditingController();
  int? _idDepartamento;
  List<ProductoConDepartamento> _productos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await ProductosRepository.instance.obtenerCatalogoCompleto(
        idDepartamento: _idDepartamento,
        busqueda: _busquedaCtrl.text,
      );
      if (mounted) setState(() => _productos = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _eliminar(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Deseas dar de baja lógica el producto "${p.descripcion}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ProductosRepository.instance.eliminar(p.idProducto);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtros superiores
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por código o descripción...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _cargar(),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Departamento: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _idDepartamento,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('- Todos los Departamentos -')),
                      ...widget.departamentos.map((d) => DropdownMenuItem(value: d.idDepartamento, child: Text(d.nombreDepartamento))),
                    ],
                    onChanged: (v) {
                      setState(() => _idDepartamento = v);
                      _cargar();
                    },
                  ),
                ),
              ),
              const Spacer(),
              Text('${_productos.length} productos', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _productos.isEmpty
                  ? const Center(child: Text('No hay productos que coincidan con la búsqueda.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                            columns: const [
                              DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Departamento', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Costo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Precio Venta', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Existencia', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _productos.map((pd) {
                              final p = pd.producto;
                              return DataRow(
                                cells: [
                                  DataCell(Text(p.codigoBarras)),
                                  DataCell(Text(p.descripcion, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(pd.nombreDepartamento)),
                                  DataCell(Text('\$${p.precioCosto.toStringAsFixed(2)}')),
                                  DataCell(Text('\$${p.precioVenta.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(p.usaInventario ? p.existencia.toStringAsFixed(3) : 'N/A')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                          tooltip: 'Editar',
                                          onPressed: () => widget.onEditar(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                          tooltip: 'Dar de baja',
                                          onPressed: () => _eliminar(p),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
