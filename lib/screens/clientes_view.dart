import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/cliente_db.dart';
import '../models/forma_pago.dart';
import '../models/permisos_ventanas.dart';
import '../repositories/abonos_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalogos_repository.dart';
import '../repositories/clientes_repository.dart';
import '../repositories/cortes_caja_repository.dart';

/// Vista del módulo de Clientes (Restaurada al diseño original de Eleventa).
/// Disposición de dos columnas: lista y búsqueda a la izquierda, formulario y barra a la derecha.
/// Conectada 100% a PostgreSQL local (Offline-First).
class ClientesView extends StatefulWidget {
  /// Si es true, filtra solo clientes con saldo pendiente (modo Créditos).
  final bool soloConSaldo;
  const ClientesView({super.key, this.soloConSaldo = false});

  @override
  State<ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends State<ClientesView> {
  final _clientesRepo = ClientesRepository.instance;
  final _buscarController = TextEditingController();

  // Controladores del formulario
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _limiteController = TextEditingController(text: '0.00');

  List<ClienteDB> _clientes = [];
  ClienteDB? _clienteSeleccionado;
  bool _tieneLimite = false;
  bool _cargando = true;
  bool _guardando = false;
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _limiteController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes([String? filtro]) async {
    setState(() => _cargando = true);
    try {
      var lista = (filtro == null || filtro.trim().isEmpty)
          ? await _clientesRepo.obtenerTodos()
          : await _clientesRepo.buscar(filtro);

      if (widget.soloConSaldo) {
        lista = lista.where((c) => c.saldoActual > 0).toList();
      }

      if (mounted) {
        setState(() {
          _clientes = lista;
          _cargando = false;
          if (_clienteSeleccionado != null) {
            final match = lista.where((c) => c.idCliente == _clienteSeleccionado!.idCliente);
            if (match.isNotEmpty) {
              _cargarEnFormulario(match.first);
            } else if (lista.isNotEmpty) {
              _cargarEnFormulario(lista.first);
            } else {
              _iniciarNuevoCliente();
            }
          } else if (lista.isNotEmpty) {
            _cargarEnFormulario(lista.first);
          } else {
            _iniciarNuevoCliente();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cargarEnFormulario(ClienteDB c) {
    setState(() {
      _clienteSeleccionado = c;
      _nombreController.text = c.nombre;
      _telefonoController.text = c.telefono ?? '';
      _tieneLimite = c.tieneLimiteCredito;
      _limiteController.text = c.tieneLimiteCredito ? c.limiteCredito.toStringAsFixed(2) : '0.00';
    });
  }

  void _iniciarNuevoCliente() {
    setState(() {
      _clienteSeleccionado = null;
      _nombreController.clear();
      _telefonoController.clear();
      _tieneLimite = false;
      _limiteController.text = '0.00';
    });
  }

  Future<void> _guardarCliente() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      _mostrarMensaje('Ingresa el nombre del cliente', esError: true);
      return;
    }

    final limite = _tieneLimite ? (double.tryParse(_limiteController.text.trim()) ?? 0.0) : 0.0;
    final tel = _telefonoController.text.trim();

    setState(() => _guardando = true);
    try {
      if (_clienteSeleccionado == null) {
        // CREAR
        final nuevo = await _clientesRepo.crear(
          nombre: nombre,
          telefono: tel.isEmpty ? null : tel,
          tieneLimiteCredito: _tieneLimite,
          limiteCredito: limite,
        );
        _mostrarMensaje('Cliente "${nuevo.nombre}" guardado con éxito');
        await _cargarClientes(_filtroBusqueda);
        _cargarEnFormulario(nuevo);
      } else {
        // ACTUALIZAR
        final actualizado = await _clientesRepo.actualizar(
          idCliente: _clienteSeleccionado!.idCliente,
          nombre: nombre,
          telefono: tel.isEmpty ? null : tel,
          tieneLimiteCredito: _tieneLimite,
          limiteCredito: limite,
        );
        _mostrarMensaje('Cliente "${actualizado.nombre}" actualizado con éxito');
        await _cargarClientes(_filtroBusqueda);
        _cargarEnFormulario(actualizado);
      }
    } catch (e) {
      _mostrarMensaje('Error al guardar cliente: $e', esError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminarCliente() async {
    final c = _clienteSeleccionado;
    if (c == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Eliminar Cliente'),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar al cliente "${c.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _clientesRepo.eliminar(c.idCliente);
      _mostrarMensaje('Cliente eliminado correctamente');
      _iniciarNuevoCliente();
      _cargarClientes(_filtroBusqueda);
    }
  }

  void _abrirEstadoCuenta(ClienteDB c) {
    showDialog(
      context: context,
      builder: (_) => _DialogoEstadoCuenta(
        cliente: c,
        onAbonoRegistrado: () => _cargarClientes(_filtroBusqueda),
      ),
    );
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
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

  bool get _puedeEditar =>
      AuthRepository.instance.tieneAcceso(PermisosVentanas.clientesEditarKey);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Pestaña superior de sub-opción estilo Eleventa
        _buildPestanaSubOpcion(),

        // 2. Contenido principal con el layout original de dos columnas
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEncabezadoModulo(),
                  const SizedBox(height: 14),

                  // Área dividida en dos paneles: Lista a la izquierda | Formulario a la derecha
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda: Buscador y lista
                        SizedBox(
                          width: 440,
                          child: _buildPanelIzquierdo(),
                        ),
                        const SizedBox(width: 20),

                        // Columna derecha: Barra de herramientas y formulario
                        Expanded(
                          child: _buildPanelDerecho(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPestanaSubOpcion() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_pin_outlined, size: 17, color: AppColors.clientesIcon),
                SizedBox(width: 8),
                Text(
                  'Administración de clientes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoModulo() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRACION DE CLIENTES',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF1E293B)),
        ),
        SizedBox(height: 4),
        Text(
          'Administra a todos los clientes de tu negocio (crédito, límites y abonos) de forma centralizada.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  /// Panel Izquierdo: Buscador y Tabla de Clientes con Folio, Nombre, Saldo, Límite y Botón Estado de Cuenta
  Widget _buildPanelIzquierdo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _buscarController,
                onChanged: (val) {
                  _filtroBusqueda = val;
                  _cargarClientes(val);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o teléfono...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Encabezados de la tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 45, child: Text('Folio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Text('Nombre', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 80, child: Text('Saldo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                SizedBox(width: 80, child: Text('Límite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                SizedBox(width: 40),
              ],
            ),
          ),

          // Lista de clientes
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _clientes.isEmpty
                    ? const Center(child: Text('No hay clientes registrados', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: _clientes.length,
                        itemBuilder: (ctx, index) {
                          final c = _clientes[index];
                          final seleccionado = _clienteSeleccionado?.idCliente == c.idCliente;
                          final tieneDeuda = c.saldoActual > 0;

                          return InkWell(
                            onTap: () => _cargarEnFormulario(c),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: seleccionado ? const Color(0xFFEFF6FF) : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                border: Border(
                                  bottom: BorderSide(color: seleccionado ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 45,
                                    child: Text('#${c.idCliente}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ),
                                  Expanded(
                                    child: Text(
                                      c.nombre,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                                        color: seleccionado ? AppColors.primary : AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '\$${c.saldoActual.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: tieneDeuda ? Colors.red.shade800 : Colors.green.shade800,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      c.tieneLimiteCredito ? '\$${c.limiteCredito.toStringAsFixed(0)}' : 'Sin límite',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: const Icon(Icons.receipt_long, size: 17, color: AppColors.primary),
                                      tooltip: 'Estado de cuenta / Abonar',
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _abrirEstadoCuenta(c),
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

  /// Panel Derecho: Barra superior de acciones (Nuevo, Modificar, Eliminar, Abonar) y Formulario
  Widget _buildPanelDerecho() {
    final c = _clienteSeleccionado;
    final esModoNuevo = c == null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // Barra de acciones superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                if (_puedeEditar) ...[
                  _buildBotonToolbar(
                    label: 'Nuevo Cliente',
                    icon: Icons.person_add_alt_1_rounded,
                    iconColor: AppColors.clientesIcon,
                    onTap: _iniciarNuevoCliente,
                  ),
                  const SizedBox(width: 8),
                  _buildBotonToolbar(
                    label: 'Eliminar',
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.error,
                    onTap: esModoNuevo ? null : _eliminarCliente,
                  ),
                  const SizedBox(width: 8),
                ],
                if (!esModoNuevo) ...[
                  _buildBotonToolbar(
                    label: 'Estado de Cuenta / Abonar',
                    icon: Icons.payments_outlined,
                    iconColor: Colors.green.shade700,
                    onTap: () => _abrirEstadoCuenta(c),
                  ),
                ],
              ],
            ),
          ),

          // Formulario
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: esModoNuevo ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: esModoNuevo ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          esModoNuevo ? 'Creando Nuevo Cliente' : 'Editando Cliente #${c.idCliente}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: esModoNuevo ? AppColors.primary : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!esModoNuevo)
                        Text(
                          'Deuda actual: \$${c.saldoActual.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: c.saldoActual > 0 ? AppColors.error : Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCampoFila(
                    label: 'Nombre completo *',
                    controller: _nombreController,
                    hint: 'Ej. Juan Pérez González',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildCampoFila(
                    label: 'Teléfono',
                    controller: _telefonoController,
                    hint: 'Ej. 55 1234 5678',
                    icon: Icons.phone_outlined,
                    tipoTeclado: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Checkbox de límite de crédito
                  Row(
                    children: [
                      const SizedBox(width: 140),
                      Checkbox(
                        value: _tieneLimite,
                        onChanged: _puedeEditar
                            ? (v) => setState(() {
                                  _tieneLimite = v ?? false;
                                  if (!_tieneLimite) _limiteController.text = '0.00';
                                })
                            : null,
                      ),
                      const Text(
                        '¿Tiene límite de crédito?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Campo de límite de crédito habilitado condicionalmente
                  if (_tieneLimite) ...[
                    _buildCampoFila(
                      label: 'Límite de crédito (\$)',
                      controller: _limiteController,
                      hint: '0.00',
                      icon: Icons.attach_money_rounded,
                      tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                      enabled: _puedeEditar,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),
                  if (_puedeEditar)
                    Row(
                      children: [
                        const SizedBox(width: 140),
                        ElevatedButton.icon(
                          onPressed: _guardando ? null : _guardarCliente,
                          icon: _guardando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(esModoNuevo ? 'Guardar Cliente' : 'Guardar Cambios'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.clientesIcon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    );
  }

  Widget _buildBotonToolbar({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    final bool deshabilitado = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: deshabilitado ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: deshabilitado ? const Color(0xFF94A3B8) : iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: deshabilitado ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampoFila({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType tipoTeclado = TextInputType.text,
    bool enabled = true,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          height: 38,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: tipoTeclado,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// MODAL: ESTADO DE CUENTA Y ABONOS GENERALES
// =============================================================================
class _DialogoEstadoCuenta extends StatefulWidget {
  final ClienteDB cliente;
  final VoidCallback onAbonoRegistrado;

  const _DialogoEstadoCuenta({
    required this.cliente,
    required this.onAbonoRegistrado,
  });

  @override
  State<_DialogoEstadoCuenta> createState() => _DialogoEstadoCuentaState();
}

class _DialogoEstadoCuentaState extends State<_DialogoEstadoCuenta> {
  late double _saldoActual;
  List<MovimientoEstadoCuenta> _movimientos = [];
  List<FormaPago> _formasPago = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.cliente.saldoActual;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final movs = await AbonosRepository.instance.obtenerEstadoCuenta(widget.cliente.idCliente);
      final fps = await CatalogosRepository.instance.obtenerFormasPago();
      if (mounted) {
        setState(() {
          _movimientos = movs;
          _formasPago = fps;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirDialogoAbonar({double? montoPrefill}) async {
    final montoCtrl = TextEditingController(text: montoPrefill != null ? montoPrefill.toStringAsFixed(2) : '');
    String metodo = _formasPago.isNotEmpty ? _formasPago.first.nombreFormaPago : 'Efectivo';
    final formKey = GlobalKey<FormState>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(montoPrefill != null ? 'Liquidar Todo el Saldo' : 'Registrar Abono General'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: montoCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto a abonar *', prefixText: '\$ ', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Ingresa un monto válido';
                      if (n > _saldoActual + 0.001) return 'No puede exceder el saldo (\$${_saldoActual.toStringAsFixed(2)})';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: metodo,
                    decoration: const InputDecoration(labelText: 'Forma de pago', border: OutlineInputBorder()),
                    items: (_formasPago.isNotEmpty
                            ? _formasPago.map((fp) => fp.nombreFormaPago).toList()
                            : ['Efectivo', 'Tarjeta', 'Transferencia'])
                        .map((nombre) => DropdownMenuItem(value: nombre, child: Text(nombre)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => metodo = v ?? 'Efectivo'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final m = double.parse(montoCtrl.text.trim());
                await AbonosRepository.instance.registrarAbono(
                  idCliente: widget.cliente.idCliente,
                  idUsuario: AuthRepository.instance.usuarioActual?.idUsuario ?? 1,
                  idCorte: CortesCajaRepository.instance.idCorteActivo,
                  monto: m,
                  nombreFormaPago: metodo,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              child: const Text('Confirmar Abono'),
            ),
          ],
        ),
      ),
    );

    if (confirmado == true) {
      final abono = double.tryParse(montoCtrl.text.trim()) ?? 0.0;
      setState(() => _saldoActual = (_saldoActual - abono).clamp(0.0, double.infinity));
      widget.onAbonoRegistrado();
      _cargar();
    }
  }

  Future<void> _verTicket(int idVenta) async {
    final detalles = await AbonosRepository.instance.obtenerDetalleTicket(idVenta);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Productos del Ticket #$idVenta'),
        content: SizedBox(
          width: 480,
          child: detalles.isEmpty
              ? const Text('Sin productos registrados en este ticket.')
              : SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Producto')),
                      DataColumn(label: Text('Cant.')),
                      DataColumn(label: Text('Precio')),
                      DataColumn(label: Text('Importe')),
                    ],
                    rows: detalles.map((d) {
                      return DataRow(
                        cells: [
                          DataCell(Text(d.descripcion)),
                          DataCell(Text(d.cantidad.toStringAsFixed(2))),
                          DataCell(Text('\$${d.precioUnitario.toStringAsFixed(2)}')),
                          DataCell(Text('\$${d.importe.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tieneDeuda = _saldoActual > 0.001;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.cliente.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text(
                  'Límite de crédito: ${widget.cliente.tieneLimiteCredito ? '\$${widget.cliente.limiteCredito.toStringAsFixed(2)}' : 'Sin límite'}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Saldo pendiente', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(
                '\$${_saldoActual.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: tieneDeuda ? Colors.red.shade800 : Colors.green.shade800,
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: tieneDeuda ? () => _abrirDialogoAbonar() : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Registrar Abono'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: tieneDeuda ? () => _abrirDialogoAbonar(montoPrefill: _saldoActual) : null,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Liquidar Todo'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Historial Cronológico (clic en una VENTA para ver los artículos del ticket):',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),

            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _movimientos.isEmpty
                      ? const Center(child: Text('Sin compras a crédito ni abonos registrados.'))
                      : SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                              columns: const [
                                DataColumn(label: Text('Fecha / Hora')),
                                DataColumn(label: Text('Movimiento')),
                                DataColumn(label: Text('Monto')),
                                DataColumn(label: Text('Saldo Resultante')),
                                DataColumn(label: Text('Forma / Cajero')),
                              ],
                              rows: _movimientos.map((m) {
                                final esVenta = m.tipo == 'VENTA';
                                final fStr = '${m.fecha.day.toString().padLeft(2, '0')}/${m.fecha.month.toString().padLeft(2, '0')}/${m.fecha.year} '
                                    '${m.fecha.hour.toString().padLeft(2, '0')}:${m.fecha.minute.toString().padLeft(2, '0')}';

                                return DataRow(
                                  onSelectChanged: esVenta ? (_) => _verTicket(m.idReferencia) : null,
                                  cells: [
                                    DataCell(Text(fStr)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: esVenta ? Colors.orange.shade50 : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          m.tipo,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: esVenta ? Colors.deepOrange : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${esVenta ? '+' : '-'}\$${m.monto.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: esVenta ? Colors.red.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('\$${m.saldoResultante.toStringAsFixed(2)}')),
                                    DataCell(Text('${m.formaPago ?? 'Efectivo'} (${m.cajero})')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
