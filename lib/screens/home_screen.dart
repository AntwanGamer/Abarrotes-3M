import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/menu_card.dart';
import 'login_screen.dart';

/// Pantalla principal después del login.
/// Muestra las cards del menú: Ventas, Productos, Inventario.
class HomeScreen extends StatelessWidget {
  final String userType;

  const HomeScreen({super.key, required this.userType});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 3,
        shadowColor: Colors.black.withAlpha(50),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 26,
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'ABARROTES 3M',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Chip refinado con el tipo de usuario
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withAlpha(60),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    userType == 'Administrador'
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person_rounded,
                    size: 18,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botón cerrar sesión con contenedor estilizado
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, size: 22),
              tooltip: 'Cerrar sesión',
              color: AppColors.textOnPrimary,
              onPressed: () => _cerrarSesion(context),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Align(
                alignment: const Alignment(0, -0.32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Saludo dinámico con icono decorativo según el momento del día
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _obtenerIconoSaludo(),
                              color: AppColors.accent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _obtenerSaludo(),
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¿Qué acción realizarás?',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 38),

                      // Cards centradas con contornos definidos, sombra y diseño limpio
                      Wrap(
                        spacing: 32,
                        runSpacing: 32,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: 270,
                            height: 285,
                            child: MenuCard(
                              icon: Icons.point_of_sale_rounded,
                              title: 'Ventas',
                              subtitle: 'Registrar y consultar ventas',
                              iconColor: AppColors.ventasIcon,
                              onTap: () {
                                _mostrarSnackBar(context, 'Ventas - Próximamente');
                              },
                            ),
                          ),
                          SizedBox(
                            width: 270,
                            height: 285,
                            child: MenuCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'Productos',
                              subtitle: 'Gestionar catálogo de productos',
                              iconColor: AppColors.productosIcon,
                              onTap: () {
                                _mostrarSnackBar(context, 'Productos - Próximamente');
                              },
                            ),
                          ),
                          SizedBox(
                            width: 270,
                            height: 285,
                            child: MenuCard(
                              icon: Icons.warehouse_outlined,
                              title: 'Inventario',
                              subtitle: 'Control de existencias',
                              iconColor: AppColors.inventarioIcon,
                              onTap: () {
                                _mostrarSnackBar(context, 'Inventario - Próximamente');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Muestra un SnackBar temporal.
  void _mostrarSnackBar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primaryDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
