import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/permisos_ventanas.dart';
import '../models/corte_caja.dart';
import '../models/usuario_db.dart';
import '../repositories/auth_repository.dart';
import '../repositories/cortes_caja_repository.dart';
import 'login_screen.dart';
import 'productos_view.dart';
import 'ventas_view.dart';
import 'inventario_view.dart';
import 'clientes_view.dart';
import 'corte_view.dart';
import 'reportes_view.dart';
import 'configuracion_view.dart';

/// Pantalla principal después del login (Punto de Venta).
/// Barra de botones superior estilo Eleventa: Ventas, Productos, Inventario.
class HomeScreen extends StatefulWidget {
  final UsuarioDB? usuario;
  final String? userType;

  const HomeScreen({super.key, this.usuario, this.userType});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _moduloSeleccionado = 'Ventas';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_manejarTecladoGlobal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _verificarTurnoInicial();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_manejarTecladoGlobal);
    _focusNode.dispose();
    super.dispose();
  }

  bool _manejarTecladoGlobal(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Atajos globales F1-F4 funcionan desde cualquier módulo
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      if (_moduloSeleccionado != 'Ventas') {
        setState(() => _moduloSeleccionado = 'Ventas');
      }
      return false; // Permite que VentasView reciba F1 si lo necesita
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      if (_moduloSeleccionado != 'Clientes') {
        setState(() => _moduloSeleccionado = 'Clientes');
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      if (_moduloSeleccionado != 'Productos') {
        setState(() => _moduloSeleccionado = 'Productos');
      }
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      if (_moduloSeleccionado != 'Inventario') {
        setState(() => _moduloSeleccionado = 'Inventario');
      }
      return true;
    }
    return false;
  }

  UsuarioDB get _usuarioActivo {
    if (widget.usuario != null) return widget.usuario!;
    final u = AuthRepository.instance.usuarioActual;
    if (u != null) return u;
    return UsuarioDB(
      idUsuario: 1,
      nombreCompleto: widget.userType ?? 'Usuario',
      nombreUsuario: widget.userType ?? 'Usuario',
      hashPassword: '',
      permisosVentanas: const PermisosVentanas({}),
      fechaRegistro: DateTime.now(),
      fechaActualizacion: DateTime.now(),
      uuidSync: '',
    );
  }

  Future<void> _verificarTurnoInicial() async {
    if (CortesCajaRepository.instance.corteActivo != null) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoControlTurno(
        idUsuario: _usuarioActivo.idUsuario,
        nombreUsuario: _usuarioActivo.nombreCompleto,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _abrirMovimientoCaja() async {
    if (CortesCajaRepository.instance.corteActivo == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoMovimientoCaja(idUsuario: _usuarioActivo.idUsuario),
    );
    if (ok == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento de caja registrado correctamente.')),
      );
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    CortesCajaRepository.instance.limpiarCorte();
    await AuthRepository.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  /// Obtiene el saludo correspondiente según la hora actual del día.
  String _obtenerSaludo() {
    final hora = DateTime.now().hour;
    if (hora >= 6 && hora < 12) {
      return '¡Buen día!';
    } else if (hora >= 12 && hora < 19) {
      return '¡Buenas tardes!';
    } else {
      return '¡Buenas noches!';
    }
  }

  /// Obtiene el ícono representativo según el momento del día.
  IconData _obtenerIconoSaludo() {
    final hora = DateTime.now().hour;
    if (hora >= 6 && hora < 12) {
      return Icons.wb_sunny_rounded;
    } else if (hora >= 12 && hora < 19) {
      return Icons.wb_twilight_rounded;
    } else {
      return Icons.nights_stay_rounded;
    }
  }

  Color _obtenerColorModulo(String modulo) {
    switch (modulo) {
      case 'Ventas':
        return AppColors.ventasIcon;
      case 'Clientes':
        return AppColors.clientesIcon;
      case 'Productos':
        return AppColors.productosIcon;
      case 'Inventario':
        return AppColors.inventarioIcon;
      case 'Configuración':
        return AppColors.configuracionIcon;
      case 'Corte':
        return AppColors.corteIcon;
      case 'Reportes':
        return AppColors.reportesIcon;
      default:
        return AppColors.primary;
    }
  }

  IconData _obtenerIconoModulo(String modulo) {
    switch (modulo) {
      case 'Ventas':
        return Icons.point_of_sale_rounded;
      case 'Clientes':
        return Icons.people_alt_rounded;
      case 'Productos':
        return Icons.inventory_2_outlined;
      case 'Inventario':
        return Icons.warehouse_outlined;
      case 'Configuración':
        return Icons.settings_rounded;
      case 'Corte':
        return Icons.content_cut_rounded;
      case 'Reportes':
        return Icons.bar_chart_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            // Atajos globales idénticos a Eleventa (F1 a F4 únicamente a nivel aplicación)
            if (event.logicalKey == LogicalKeyboardKey.f1) {
              setState(() => _moduloSeleccionado = 'Ventas');
            } else if (event.logicalKey == LogicalKeyboardKey.f2) {
              setState(() => _moduloSeleccionado = 'Créditos');
            } else if (event.logicalKey == LogicalKeyboardKey.f3) {
              setState(() => _moduloSeleccionado = 'Productos');
            } else if (event.logicalKey == LogicalKeyboardKey.f4) {
              setState(() => _moduloSeleccionado = 'Inventario');
            }
          }
        },
        child: Column(
          children: [
            // 1. Barra superior de marca e información de usuario
            _buildEncabezadoSuperior(context),

            // 2. Barra de herramientas de navegación superior (estilo eleventa)
            _buildBarraBotonesSuperior(context),

            // 3. Franja / Banner del módulo activo
            _buildBannerModuloActivo(),

            // 4. Área de trabajo inferior
            Expanded(
              child: _moduloSeleccionado == 'Ventas'
                  ? const VentasView()
                  : (_moduloSeleccionado == 'Clientes'
                      ? const ClientesView()
                      : (_moduloSeleccionado == 'Productos'
                          ? const ProductosView()
                          : (_moduloSeleccionado == 'Inventario'
                              ? const InventarioView()
                              : (_moduloSeleccionado == 'Corte'
                                  ? const CorteView()
                                  : (_moduloSeleccionado == 'Reportes'
                                      ? const ReportesView()
                                      : (_moduloSeleccionado == 'Configuración' &&
                                              _usuarioActivo.tieneAccesoAjustes
                                          ? ConfiguracionView(usuario: _usuarioActivo)
                                          : const VentasView())))))),
            ),
          ],
        ),
      ),
    );
  }

  /// Barra superior con el logotipo de la tienda y el usuario activo
  Widget _buildEncabezadoSuperior(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo e Identidad
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 24,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'ABARROTES 3M',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'PUNTO DE VENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),

          // Indicador de usuario: "[userType]" (Usuario / Administrador)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withAlpha(60),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _usuarioActivo.puedeGestionarUsuarios
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  size: 18,
                  color: AppColors.textOnPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  _usuarioActivo.nombreUsuario,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de herramientas horizontal con los botones principales del sistema
  Widget _buildBarraBotonesSuperior(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F3F5),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 1. F1 Ventas
                  _buildBotonModulo(
                    titulo: 'Ventas',
                    atajo: 'F1',
                    icono: Icons.point_of_sale_rounded,
                    colorIcono: AppColors.ventasIcon,
                  ),
                  const SizedBox(width: 8),

                  // 2. F2 Clientes (unifica gestión, saldo y abonos)
                  _buildBotonModulo(
                    titulo: 'Clientes',
                    atajo: 'F2',
                    icono: Icons.people_alt_rounded,
                    colorIcono: AppColors.clientesIcon,
                  ),
                  const SizedBox(width: 8),

                  // 3. F3 Productos
                  _buildBotonModulo(
                    titulo: 'Productos',
                    atajo: 'F3',
                    icono: Icons.inventory_2_outlined,
                    colorIcono: AppColors.productosIcon,
                  ),
                  const SizedBox(width: 8),

                  // 4. F4 Inventario
                  _buildBotonModulo(
                    titulo: 'Inventario',
                    atajo: 'F4',
                    icono: Icons.warehouse_outlined,
                    colorIcono: AppColors.inventarioIcon,
                  ),
                  const SizedBox(width: 8),

                  // 5. Configuración (solo si tiene acceso)
                  if (_usuarioActivo.tieneAccesoAjustes) ...[
                    _buildBotonModulo(
                      titulo: 'Configuración',
                      atajo: null,
                      icono: Icons.settings_rounded,
                      colorIcono: AppColors.configuracionIcon,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 6. Corte
                  _buildBotonModulo(
                    titulo: 'Corte',
                    atajo: null,
                    icono: Icons.content_cut_rounded,
                    colorIcono: AppColors.corteIcon,
                  ),
                  const SizedBox(width: 8),

                  // 7. Reportes
                  _buildBotonModulo(
                    titulo: 'Reportes',
                    atajo: null,
                    icono: Icons.bar_chart_rounded,
                    colorIcono: AppColors.reportesIcon,
                  ),

                  const SizedBox(width: 16),

                  // Saludo dinámico (Buenos días / tardes / noches)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _obtenerIconoSaludo(),
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _obtenerSaludo(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (CortesCajaRepository.instance.corteActivo != null) ...[
                    const SizedBox(width: 10),
                    _buildBadgeTurno(CortesCajaRepository.instance.corteActivo!),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _abrirMovimientoCaja,
                      icon: const Icon(Icons.swap_vert_rounded, size: 16),
                      label: const Text('Mov. Caja', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Botón Salir (estilo eleventa a la derecha de la barra)
          InkWell(
            onTap: () => _cerrarSesion(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  Icon(Icons.exit_to_app_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 6),
                  Text(
                    'Salir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

  /// Botón individual de módulo para la barra superior
  Widget _buildBotonModulo({
    required String titulo,
    String? atajo,
    required IconData icono,
    required Color colorIcono,
  }) {
    final bool seleccionado = _moduloSeleccionado == titulo;

    return InkWell(
      onTap: () {
        setState(() {
          _moduloSeleccionado = titulo;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.white : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? AppColors.accent : const Color(0xFFD0D5DD),
            width: seleccionado ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: seleccionado
                  ? AppColors.accent.withAlpha(45)
                  : Colors.black.withAlpha(8),
              blurRadius: seleccionado ? 6 : 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 20,
              color: colorIcono,
            ),
            if (atajo != null && atajo.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seleccionado
                      ? AppColors.accent.withAlpha(30)
                      : Colors.black.withAlpha(12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  atajo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: seleccionado
                        ? const Color(0xFFB45309)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                color: seleccionado
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Franja horizontal del módulo actualmente activo con el mismo color que su icono
  Widget _buildBannerModuloActivo() {
    final color = _obtenerColorModulo(_moduloSeleccionado);
    final String tituloBanner = _moduloSeleccionado == 'Ventas'
        ? 'VENTA - Ticket 1'
        : _moduloSeleccionado.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _obtenerIconoModulo(_moduloSeleccionado),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            tituloBanner,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTurno(CorteCaja corte) {
    final hora = '${corte.fechaApertura.hour.toString().padLeft(2, '0')}:${corte.fechaApertura.minute.toString().padLeft(2, '0')}';
    final cajero = corte.nombreUsuario ?? _usuarioActivo.nombreCompleto;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'Corte #${corte.idCorte} • $cajero • $hora • Fondo: \$${corte.fondoInicial.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoControlTurno extends StatefulWidget {
  final int idUsuario;
  final String nombreUsuario;

  const _DialogoControlTurno({
    required this.idUsuario,
    required this.nombreUsuario,
  });

  @override
  State<_DialogoControlTurno> createState() => _DialogoControlTurnoState();
}

class _DialogoControlTurnoState extends State<_DialogoControlTurno> {
  bool _modoNuevoTurno = false;
  bool _cargando = false;
  String? _mensajeAviso;
  final _fondoController = TextEditingController(text: '500.00');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _fondoController.dispose();
    super.dispose();
  }

  Future<void> _continuarTurno() async {
    setState(() {
      _cargando = true;
      _mensajeAviso = null;
    });
    try {
      final corte = await CortesCajaRepository.instance.continuarCorteAbierto();
      if (corte != null) {
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _cargando = false;
          _modoNuevoTurno = true;
          _mensajeAviso = 'No hay ningún corte abierto previo. Por favor inicia un turno nuevo.';
        });
      }
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeAviso = 'Error al consultar corte abierto: $e';
      });
    }
  }

  Future<void> _iniciarNuevoTurno() async {
    if (!_formKey.currentState!.validate()) return;
    final fondo = double.tryParse(_fondoController.text.trim()) ?? 0.0;
    setState(() {
      _cargando = true;
      _mensajeAviso = null;
    });
    try {
      await CortesCajaRepository.instance.iniciarCorteNuevo(
        idUsuario: widget.idUsuario,
        fondoInicial: fondo,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeAviso = 'Error al iniciar turno: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _modoNuevoTurno ? 'Iniciar Turno Nuevo' : 'Control de Turno de Caja',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _modoNuevoTurno
                    ? 'Ingresa el efectivo inicial en caja para comenzar el turno de ${widget.nombreUsuario}:'
                    : '¿Deseas iniciar un turno nuevo o continuar con el turno anterior?',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (_mensajeAviso != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mensajeAviso!,
                          style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_modoNuevoTurno) ...[
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _fondoController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Efectivo inicial en caja (fondo_inicial)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      final n = double.tryParse(val?.trim() ?? '');
                      if (n == null || n < 0) {
                        return 'Ingresa un monto válido (>= 0)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _modoNuevoTurno
            ? [
                TextButton(
                  onPressed: _cargando
                      ? null
                      : () => setState(() {
                            _modoNuevoTurno = false;
                            _mensajeAviso = null;
                          }),
                  child: const Text('Volver'),
                ),
                ElevatedButton.icon(
                  onPressed: _cargando ? null : _iniciarNuevoTurno,
                  icon: _cargando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Confirmar e Iniciar Turno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]
            : [
                OutlinedButton.icon(
                  onPressed: _cargando ? null : _continuarTurno,
                  icon: _cargando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.history_rounded),
                  label: const Text('Continuar turno anterior'),
                ),
                ElevatedButton.icon(
                  onPressed: _cargando ? null : () => setState(() {
                            _modoNuevoTurno = true;
                            _mensajeAviso = null;
                          }),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Turno nuevo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
      ),
    );
  }
}

class _DialogoMovimientoCaja extends StatefulWidget {
  final int idUsuario;
  const _DialogoMovimientoCaja({required this.idUsuario});

  @override
  State<_DialogoMovimientoCaja> createState() => _DialogoMovimientoCajaState();
}

class _DialogoMovimientoCajaState extends State<_DialogoMovimientoCaja> {
  String _tipo = 'Entrada';
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await CortesCajaRepository.instance.registrarMovimientoCaja(
        idUsuario: widget.idUsuario,
        tipoMovimiento: _tipo,
        monto: double.parse(_montoCtrl.text.trim()),
        concepto: _conceptoCtrl.text,
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_vert_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Movimiento de Caja'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Entrada', label: Text('Entrada (Cambio)'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'Salida', label: Text('Salida (Retiro/Pago)'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _montoCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto *',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Ingresa un monto mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _conceptoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Concepto *',
                  hintText: 'Ej. Cambio inicial / Pago proveedor Bimbo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el concepto' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _guardando ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Guardar'),
        ),
      ],
    );
  }
}
