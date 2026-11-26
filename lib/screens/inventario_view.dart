import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/departamento.dart';
import '../models/permisos_ventanas.dart';
import '../models/producto.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalogos_repository.dart';
import '../repositories/inventario_repository.dart';
import '../repositories/productos_repository.dart';

/// Vista principal del módulo de Inventario (estilo Eleventa).
/// Conecta las 6 sub-pestañas directamente a PostgreSQL local.
class InventarioView extends StatefulWidget {
  const InventarioView({super.key});

  @override
  State<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends State<InventarioView> {
  final _invRepo = InventarioRepository.instance;
  final _catRepo = CatalogosRepository.instance;
  final _prodRepo = ProductosRepository.instance;

  String _subOpcion = 'Reporte de Inventario';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra horizontal de sub-pestañas
        _buildBarraSubOpciones(),

        // 2. Contenido de la sub-pestaña activa
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildContenidoSubOpcion(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          if (_puedeEditar) ...[
            _buildBotonTab('Agregar', Icons.add_circle_outline_rounded),
            const SizedBox(width: 6),
            _buildBotonTab('Ajustes', Icons.tune_rounded),
            const SizedBox(width: 6),
          ],
          _buildBotonTab('Productos bajos en Inventario', Icons.warning_amber_rounded,
              colorIcono: AppColors.error),
          const SizedBox(width: 6),
          _buildBotonTab('Reporte de Inventario', Icons.assignment_outlined),
          const SizedBox(width: 6),
          _buildBotonTab('Reporte de Movimientos', Icons.history_rounded),
          const SizedBox(width: 6),
          _buildBotonTab('Kardex de inventario', Icons.receipt_long_rounded),
        ],
      ),
    );
  }

  Widget _buildBotonTab(String titulo, IconData icono, {Color? colorIcono}) {
    final activo = _subOpcion == titulo;
    return InkWell(
      onTap: () => setState(() => _subOpcion = titulo),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFEDE9FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: activo ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: activo ? const Color(0xFF6D28D9) : (colorIcono ?? AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.bold : FontWeight.w600,
                color: activo ? const Color(0xFF6D28D9) : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenidoSubOpcion() {
    switch (_subOpcion) {
      case 'Agregar':
        return _PestanaAgregarEntrada(
          onGuardado: () => setState(() => _subOpcion = 'Reporte de Inventario'),
        );
      case 'Ajustes':
        return _PestanaAjustesMerma(
          onGuardado: () => setState(() => _subOpcion = 'Reporte de Inventario'),
        );
      case 'Productos bajos en Inventario':
        return const _PestanaBajosInventario();
      case 'Reporte de Movimientos':
        return const _PestanaReporteMovimientos();
      case 'Kardex de inventario':
        return const _PestanaKardex();
      case 'Reporte de Inventario':
      default:
        return _PestanaReporteInventario(departamentos: _departamentos);
    }
  }
}

// =============================================================================
// 1. SUB-PESTAÑA: AGREGAR (ENTRADA DE MERCANCÍA)
// =============================================================================
class _PestanaAgregarEntrada extends StatefulWidget {
  final VoidCallback onGuardado;
  const _PestanaAgregarEntrada({required this.onGuardado});

  @override
  State<_PestanaAgregarEntrada> createState() => _PestanaAgregarEntradaState();
}

class _PestanaAgregarEntradaState extends State<_PestanaAgregarEntrada> {
  final _busquedaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController(text: '1');
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController(text: 'Entrada de mercancía');

  Producto? _productoSeleccionado;
  bool _buscando = false;
  bool _guardando = false;
  String? _mensaje;
  bool _esError = false;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarProducto(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _buscando = true;
      _mensaje = null;
    });

    try {
      Producto? p = await ProductosRepository.instance.buscarPorCodigo(q);
      if (p == null) {
        final lista = await ProductosRepository.instance.buscarPorDescripcion(q);
        if (lista.isNotEmpty) p = lista.first;
      }

      if (mounted) {
        setState(() {
          _buscando = false;
          _productoSeleccionado = p;
          if (p != null) {
            _costoCtrl.text = p.precioCosto.toStringAsFixed(2);
            _precioCtrl.text = p.precioVenta.toStringAsFixed(2);
            _cantidadCtrl.text = p.tipoVenta == 'Granel' ? '1.000' : '1';
            _mensaje = null;
          } else {
            _mensaje = 'No se encontró ningún producto con el código o texto ingresado.';
            _esError = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _buscando = false;
          _mensaje = 'Error al buscar producto: $e';
          _esError = true;
        });
      }
    }
  }

  Future<void> _guardarEntrada() async {
    if (_productoSeleccionado == null) return;
    final cant = double.tryParse(_cantidadCtrl.text.trim()) ?? 0.0;
    if (cant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad mayor a 0')),
      );
      return;
    }

    final costo = double.tryParse(_costoCtrl.text.trim());
    final venta = double.tryParse(_precioCtrl.text.trim());

    setState(() => _guardando = true);
    try {
      final user = AuthRepository.instance.usuarioActual;
      await InventarioRepository.instance.registrarEntrada(
        idProducto: _productoSeleccionado!.idProducto,
        cantidad: cant,
        nuevoCosto: costo,
        nuevoPrecioVenta: venta,
        idUsuario: user?.idUsuario ?? 1,
        motivo: _motivoCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entrada de $cant ${_productoSeleccionado!.tipoVenta == 'Granel' ? 'Kg' : 'unidades'} registrada correctamente.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onGuardado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar entrada: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
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
                      Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF6D28D9), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'ENTRADA DE MERCANCÍA AL INVENTARIO',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ingresa el código de barras o descripción del producto para sumarle existencias.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 28),

                  // Buscador
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busquedaCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Código de barras o descripción',
                            hintText: 'Escanea el código o escribe...',
                            prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _buscando
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : null,
                          ),
                          onSubmitted: _buscarProducto,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _buscarProducto(_busquedaCtrl.text),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ],
                  ),

                  if (_mensaje != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _mensaje!,
                      style: TextStyle(
                        color: _esError ? AppColors.error : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  if (_productoSeleccionado != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productoSeleccionado!.descripcion,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95)),
                          ),
                          const SizedBox(height: 6),
                          Text('Código: ${_productoSeleccionado!.codigoBarras} • Tipo de venta: ${_productoSeleccionado!.tipoVenta}'),
                          const SizedBox(height: 4),
                          Text(
                            'Existencia actual: ${_productoSeleccionado!.existencia.toStringAsFixed(3)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campos de entrada
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cantidadCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Cantidad a ingresar *',
                              suffixText: _productoSeleccionado!.tipoVenta == 'Granel' ? 'Kg' : 'Pzas',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _costoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio de costo',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _precioCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Precio de venta',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _motivoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motivo o Nota de compra',
                        hintText: 'Ej. Factura #1234, Proveedor...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardarEntrada,
                        icon: _guardando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(_guardando ? 'Guardando entrada...' : 'Confirmar y Sumar al Inventario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
// 2. SUB-PESTAÑA: AJUSTES (AJUSTE FÍSICO Y MERMA)
// =============================================================================
class _PestanaAjustesMerma extends StatefulWidget {
  final VoidCallback onGuardado;
  const _PestanaAjustesMerma({required this.onGuardado});

  @override
  State<_PestanaAjustesMerma> createState() => _PestanaAjustesMermaState();
}

class _PestanaAjustesMermaState extends State<_PestanaAjustesMerma> {
  final _busquedaCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();

  Producto? _producto;
  String _tipoMovimiento = 'Ajuste'; // 'Ajuste' | 'Merma'
  bool _buscando = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _valorCtrl.dispose();
    _motivoCtrl.dispose();
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
        if (p != null) {
          _valorCtrl.text = _tipoMovimiento == 'Ajuste' ? p.existencia.toStringAsFixed(3) : '1';
          _motivoCtrl.text = _tipoMovimiento == 'Ajuste' ? 'Conteo físico de inventario' : 'Producto dañado / caducado';
        } else {
          _error = 'Producto no encontrado';
        }
      });
    } catch (e) {
      setState(() {
        _buscando = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _guardarAjuste() async {
    if (_producto == null) return;
    final val = double.tryParse(_valorCtrl.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un valor numérico válido')));
      return;
    }
    if (_motivoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El motivo es obligatorio')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final user = AuthRepository.instance.usuarioActual;
      await InventarioRepository.instance.registrarAjusteOMerma(
        idProducto: _producto!.idProducto,
        tipoMovimiento: _tipoMovimiento,
        valor: val,
        motivo: _motivoCtrl.text.trim(),
        idUsuario: user?.idUsuario ?? 1,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_tipoMovimiento registrado exitosamente.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onGuardado();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
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
                      Icon(Icons.tune_rounded, color: Color(0xFF6D28D9), size: 24),
                      SizedBox(width: 10),
                      Text(
                        'AJUSTE FÍSICO Y MERMAS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Establece la existencia física real de un producto o descuenta mercancía dañada o caducada.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 28),

                  // Buscador
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busquedaCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Buscar producto por código o nombre',
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
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9), foregroundColor: Colors.white),
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ],

                  if (_producto != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_producto!.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('Código: ${_producto!.codigoBarras}'),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Existencia actual', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(
                                _producto!.existencia.toStringAsFixed(3),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Selector de tipo
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Ajuste', label: Text('Ajuste Físico (Fijar existencia)'), icon: Icon(Icons.assignment_turned_in)),
                        ButtonSegment(value: 'Merma', label: Text('Merma (Descontar dañados)'), icon: Icon(Icons.remove_shopping_cart)),
                      ],
                      selected: {_tipoMovimiento},
                      onSelectionChanged: (set) {
                        setState(() {
                          _tipoMovimiento = set.first;
                          _motivoCtrl.text = _tipoMovimiento == 'Ajuste' ? 'Conteo físico de inventario' : 'Producto dañado / caducado';
                          if (_tipoMovimiento == 'Ajuste') {
                            _valorCtrl.text = _producto!.existencia.toStringAsFixed(3);
                          } else {
                            _valorCtrl.text = '1';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _tipoMovimiento == 'Ajuste' ? 'Nueva existencia física real *' : 'Cantidad a descontar por merma *',
                        border: const OutlineInputBorder(),
                        helperText: _tipoMovimiento == 'Ajuste'
                            ? 'El sistema calculará automáticamente la diferencia con la existencia anterior.'
                            : 'Esta cantidad se restará de las existencias actuales.',
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _motivoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motivo del movimiento *',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardarAjuste,
                        icon: const Icon(Icons.save),
                        label: Text(_guardando ? 'Guardando...' : 'Aplicar $_tipoMovimiento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tipoMovimiento == 'Merma' ? Colors.red.shade700 : const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                        ),
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
// 3. SUB-PESTAÑA: PRODUCTOS BAJOS EN INVENTARIO
// =============================================================================
class _PestanaBajosInventario extends StatefulWidget {
  const _PestanaBajosInventario();

  @override
  State<_PestanaBajosInventario> createState() => _PestanaBajosInventarioState();
}

class _PestanaBajosInventarioState extends State<_PestanaBajosInventario> {
  List<ItemBajoStock> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await InventarioRepository.instance.obtenerProductosBajosStock();
      if (mounted) setState(() => _items = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRODUCTOS BAJOS EN INVENTARIO',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    Text(
                      'Lista de artículos cuya existencia actual es menor o igual al inventario mínimo establecido.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar lista'),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabla
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                          SizedBox(height: 10),
                          Text('¡Excelente! No hay productos bajos en inventario.',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFFEF2F2)),
                            columns: const [
                              DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Departamento', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Existencia', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Inv. Mínimo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Sugerencia Resurtido', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _items.map((it) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(it.codigo)),
                                  DataCell(Text(it.descripcion, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(it.departamento)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.red.shade300),
                                      ),
                                      child: Text(
                                        it.existencia.toStringAsFixed(3),
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(it.invMinimo.toStringAsFixed(3))),
                                  DataCell(
                                    Text(
                                      '+${it.sugerenciaResurtido.toStringAsFixed(3)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
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
// 4. SUB-PESTAÑA: REPORTE DE INVENTARIO
// =============================================================================
class _PestanaReporteInventario extends StatefulWidget {
  final List<Departamento> departamentos;
  const _PestanaReporteInventario({required this.departamentos});

  @override
  State<_PestanaReporteInventario> createState() => _PestanaReporteInventarioState();
}

class _PestanaReporteInventarioState extends State<_PestanaReporteInventario> {
  List<ItemReporteInventario> _items = [];
  bool _cargando = true;
  int? _idDepartamentoSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await InventarioRepository.instance.obtenerReporteInventario(
        idDepartamento: _idDepartamentoSeleccionado,
      );
      if (mounted) setState(() => _items = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  double get _totalCosto => _items.fold(0.0, (acc, it) => acc + it.valorCosto);
  double get _totalVenta => _items.fold(0.0, (acc, it) => acc + it.valorVenta);
  int get _totalArticulos => _items.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tarjetas resumen superiores
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REPORTE DE INVENTARIO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3B3B8F)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildCardResumen('Total Productos Activos', '$_totalArticulos', Icons.inventory_2_outlined),
                  const SizedBox(width: 20),
                  _buildCardResumen('Valor Inventario a Costo', '\$${_totalCosto.toStringAsFixed(2)}', Icons.attach_money_rounded),
                  const SizedBox(width: 20),
                  _buildCardResumen('Valor a Precio Venta', '\$${_totalVenta.toStringAsFixed(2)}', Icons.point_of_sale_rounded),
                  const Spacer(),
                  // Filtro por departamento
                  Row(
                    children: [
                      const Text('Departamento: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _idDepartamentoSeleccionado,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('- Todos los Departamentos -')),
                              ...widget.departamentos.map((d) => DropdownMenuItem<int?>(
                                    value: d.idDepartamento,
                                    child: Text(d.nombreDepartamento),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() => _idDepartamentoSeleccionado = val);
                              _cargar();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh), tooltip: 'Recargar'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Listado
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No hay productos que coincidan con el filtro.'))
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
                              DataColumn(label: Text('Inv. Mínimo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Inv. Máximo', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _items.map((it) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(it.codigo)),
                                  DataCell(Text(it.descripcion, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(it.departamento)),
                                  DataCell(Text('\$${it.costo.toStringAsFixed(2)}')),
                                  DataCell(Text('\$${it.precioVenta.toStringAsFixed(2)}')),
                                  DataCell(
                                    Text(
                                      it.existencia.toStringAsFixed(3),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: it.existencia <= it.invMinimo ? Colors.red.shade800 : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(it.invMinimo.toStringAsFixed(3))),
                                  DataCell(Text(it.invMaximo.toStringAsFixed(3))),
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

  Widget _buildCardResumen(String titulo, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF6D28D9), size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 5. SUB-PESTAÑA: REPORTE DE MOVIMIENTOS
// =============================================================================
class _PestanaReporteMovimientos extends StatefulWidget {
  const _PestanaReporteMovimientos();

  @override
  State<_PestanaReporteMovimientos> createState() => _PestanaReporteMovimientosState();
}

class _PestanaReporteMovimientosState extends State<_PestanaReporteMovimientos> {
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();
  String _tipoMovimiento = 'Todos';
  List<MovimientoInventarioDetalle> _movimientos = [];
  bool _cargando = true;

  final _tipos = ['Todos', 'Venta', 'Entrada', 'Ajuste', 'Merma', 'Cancelacion'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final res = await InventarioRepository.instance.obtenerMovimientos(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        tipoMovimiento: _tipoMovimiento,
      );
      if (mounted) setState(() => _movimientos = res);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _seleccionarRangoFechas() async {
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

  @override
  Widget build(BuildContext context) {
    final fIniStr = '${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year}';
    final fFinStr = '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year}';

    return Column(
      children: [
        // Barra superior de filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _seleccionarRangoFechas,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text('Periodo: $fIniStr - $fFinStr'),
              ),
              const SizedBox(width: 16),
              const Text('Tipo: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoMovimiento,
                    items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _tipoMovimiento = val);
                        _cargar();
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Filtrar'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabla
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _movimientos.isEmpty
                  ? const Center(child: Text('No hay movimientos registrados en el periodo seleccionado.'))
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
                              DataColumn(label: Text('Fecha / Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Exist. Anterior', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Exist. Nueva', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _movimientos.map((m) {
                              final fStr = '${m.fecha.day.toString().padLeft(2, '0')}/${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year} '
                                  '${m.fecha.hour.toString().padLeft(2, '0')}:${m.fecha.minute.toString().padLeft(2, '0')}';
                              final esPositivo = m.cantidad > 0;
                              return DataRow(
                                cells: [
                                  DataCell(Text(fStr)),
                                  DataCell(Text('${m.codigoProducto} - ${m.descripcionProducto}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _colorTipo(m.tipoMovimiento).withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(m.tipoMovimiento, style: TextStyle(fontWeight: FontWeight.bold, color: _colorTipo(m.tipoMovimiento))),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${esPositivo ? '+' : ''}${m.cantidad.toStringAsFixed(3)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: esPositivo ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(m.existenciaAnterior.toStringAsFixed(3))),
                                  DataCell(Text(m.existenciaNueva.toStringAsFixed(3))),
                                  DataCell(Text(m.motivo)),
                                  DataCell(Text(m.usuario)),
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

  Color _colorTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'entrada':
        return Colors.green.shade800;
      case 'venta':
        return Colors.blue.shade800;
      case 'merma':
        return Colors.red.shade800;
      case 'ajuste':
        return Colors.orange.shade800;
      default:
        return Colors.purple.shade800;
    }
  }
}

// =============================================================================
// 6. SUB-PESTAÑA: KARDEX DE INVENTARIO
// =============================================================================
class _PestanaKardex extends StatefulWidget {
  const _PestanaKardex();

  @override
  State<_PestanaKardex> createState() => _PestanaKardexState();
}

class _PestanaKardexState extends State<_PestanaKardex> {
  final _busquedaCtrl = TextEditingController();
  Producto? _producto;
  List<MovimientoInventarioDetalle> _historial = [];
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarYConsultar(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      Producto? p = await ProductosRepository.instance.buscarPorCodigo(q);
      if (p == null) {
        final list = await ProductosRepository.instance.buscarPorDescripcion(q);
        if (list.isNotEmpty) p = list.first;
      }

      if (p != null) {
        final kardex = await InventarioRepository.instance.obtenerKardex(p.idProducto);
        if (mounted) {
          setState(() {
            _producto = p;
            _historial = kardex;
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _producto = null;
            _historial = [];
            _error = 'Producto no encontrado';
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Buscador superior
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 380,
                child: TextField(
                  controller: _busquedaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto por código de barras o nombre',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _buscarYConsultar,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _buscarYConsultar(_busquedaCtrl.text),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Consultar Kardex'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D28D9), foregroundColor: Colors.white),
              ),
              if (_producto != null) ...[
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_producto!.codigoBarras} - ${_producto!.descripcion}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4C1D95))),
                        Text('Existencia actual: ${_producto!.existencia.toStringAsFixed(3)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),

        // Tabla Kardex
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _producto == null
                  ? const Center(child: Text('Ingresa un producto para ver su Kardex de movimientos.'))
                  : _historial.isEmpty
                      ? const Center(child: Text('Sin movimientos de inventario registrados para este producto.'))
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
                                  DataColumn(label: Text('Fecha / Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Existencia Anterior', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Existencia Resultante', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Motivo', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _historial.map((m) {
                                  final fStr = '${m.fecha.day.toString().padLeft(2, '0')}/${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year} '
                                      '${m.fecha.hour.toString().padLeft(2, '0')}:${m.fecha.minute.toString().padLeft(2, '0')}';
                                  final esPositivo = m.cantidad > 0;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(fStr)),
                                      DataCell(Text(m.tipoMovimiento, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Text(
                                          '${esPositivo ? '+' : ''}${m.cantidad.toStringAsFixed(3)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: esPositivo ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(m.existenciaAnterior.toStringAsFixed(3))),
                                      DataCell(Text(m.existenciaNueva.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(m.motivo)),
                                      DataCell(Text(m.usuario)),
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
