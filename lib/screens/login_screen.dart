import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_screen.dart';

/// Pantalla de inicio de sesión.
/// Primero selecciona perfil, luego ingresa usuario y contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _ocultarContrasena = true;
  String? _errorMensaje;
  String _perfilSeleccionado = 'Usuario'; // Por defecto

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  void _login() {
    // Validación básica
    if (_usuarioController.text.trim().isEmpty ||
        _contrasenaController.text.trim().isEmpty) {
      setState(() {
        _errorMensaje = 'Por favor ingresa usuario y contraseña';
      });
      return;
    }

    setState(() {
      _errorMensaje = null;
    });

    // Sin lógica de autenticación real por ahora
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(userType: _perfilSeleccionado),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Ícono de la tienda
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 44,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  const Text(
                    'ABARROTES 3M',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Selector de perfil (arriba)
                  const Text(
                    'Tipo de perfil',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PerfilButton(
                          icon: Icons.person_outline_rounded,
                          label: 'Usuario',
                          seleccionado: _perfilSeleccionado == 'Usuario',
                          onTap: () {
                            setState(() => _perfilSeleccionado = 'Usuario');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PerfilButton(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Administrador',
                          seleccionado: _perfilSeleccionado == 'Administrador',
                          onTap: () {
                            setState(
                                () => _perfilSeleccionado = 'Administrador');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Campo de usuario
                  TextField(
                    controller: _usuarioController,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    onChanged: (_) {
                      if (_errorMensaje != null) {
                        setState(() => _errorMensaje = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de contraseña
                  TextField(
                    controller: _contrasenaController,
                    obscureText: _ocultarContrasena,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _ocultarContrasena = !_ocultarContrasena;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    onChanged: (_) {
                      if (_errorMensaje != null) {
                        setState(() => _errorMensaje = null);
                      }
                    },
                  ),

                  // Mensaje de error
                  if (_errorMensaje != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMensaje!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botón de ingresar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _login,
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: const Text('Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Versión
                  Text(
                    'v0.1.0',
                    style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón para seleccionar perfil (Usuario / Administrador).
class _PerfilButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _PerfilButton({
    required this.icon,
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado ? AppColors.primary : AppColors.border,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: seleccionado
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: seleccionado
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
