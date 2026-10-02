import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import 'login_screen.dart';
import 'productos_view.dart';
import 'ventas_view.dart';
import 'inventario_view.dart';

/// Pantalla principal después del login (Punto de Venta).
/// Barra de botones superior estilo Eleventa: Ventas, Productos, Inventario.
class HomeScreen extends StatefulWidget {
  final String userType;

  const HomeScreen({super.key, required this.userType});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _moduloSeleccionado = 'Ventas';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _cerrarSesion(BuildContext context) {
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
      case 'Productos':
        return AppColors.productosIcon;
      case 'Inventario':
        return AppColors.inventarioIcon;
      default:
        return AppColors.primary;
    }
  }

  IconData _obtenerIconoModulo(String modulo) {
    switch (modulo) {
      case 'Ventas':
        return Icons.point_of_sale_rounded;
      case 'Productos':
        return Icons.inventory_2_outlined;
      case 'Inventario':
        return Icons.warehouse_outlined;
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
            if (event.logicalKey == LogicalKeyboardKey.f1) {
              setState(() => _moduloSeleccionado = 'Ventas');
            } else if (event.logicalKey == LogicalKeyboardKey.f2) {
              setState(() => _moduloSeleccionado = 'Productos');
            } else if (event.logicalKey == LogicalKeyboardKey.f3) {
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
                  : (_moduloSeleccionado == 'Productos'
                      ? const ProductosView()
                      : const InventarioView()),
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
                  widget.userType == 'Administrador'
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  size: 18,
                  color: AppColors.textOnPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.userType,
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
          // Botón 1: Ventas
          _buildBotonModulo(
            titulo: 'Ventas',
            atajo: 'F1',
            icono: Icons.point_of_sale_rounded,
            colorIcono: AppColors.ventasIcon,
          ),
          const SizedBox(width: 8),

          // Botón 2: Productos
          _buildBotonModulo(
            titulo: 'Productos',
            atajo: 'F2',
            icono: Icons.inventory_2_outlined,
            colorIcono: AppColors.productosIcon,
          ),
          const SizedBox(width: 8),

          // Botón 3: Inventario
          _buildBotonModulo(
            titulo: 'Inventario',
            atajo: 'F3',
            icono: Icons.warehouse_outlined,
            colorIcono: AppColors.inventarioIcon,
          ),

          const SizedBox(width: 16),

          // Saludo dinámico (Buenos días / tardes / noches) al lado derecho de los 3 botones
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

          const Spacer(),

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
    required String atajo,
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
}


