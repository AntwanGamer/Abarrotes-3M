import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../repositories/auth_repository.dart';
import 'home_screen.dart';

/// Pantalla de inicio de sesión conectada a PostgreSQL local.
///
/// El sistema de roles fue eliminado por completo:
/// - La autenticación se realiza únicamente con [nombre_usuario] y contraseña.
/// - Los permisos específicos se cargan automáticamente desde `permisos_ventanas` (JSONB).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _authRepo = AuthRepository.instance;

  bool _ocultarContrasena = true;
  bool _cargando = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usuarioController.text.trim();
    final password = _contrasenaController.text.trim();

    // 1. Validaciones
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMensaje = 'Por favor ingresa usuario y contraseña';
      });
      return;
    }

    if (username.contains(' ')) {
      setState(() {
        _errorMensaje = 'El nombre de usuario no puede contener espacios';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      // 2. Autenticación contra PostgreSQL local
      final usuario = await _authRepo.login(username, password);

      if (!mounted) return;

      if (usuario == null) {
        setState(() {
          _errorMensaje = 'Usuario o contraseña incorrectos, o cuenta inactiva';
          _cargando = false;
        });
        return;
      }

      // 3. Inicio exitoso: navegar al HomeScreen con el usuario y sus permisos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(usuario: usuario),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMensaje = 'Error al conectar con la base de datos local: $e';
        _cargando = false;
      });
    }
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
                  const SizedBox(height: 6),
                  const Text(
                    'PUNTO DE VENTA OFFLINE-FIRST',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Campo de Nombre de Usuario
                  TextField(
                    controller: _usuarioController,
                    enabled: !_cargando,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      hintText: 'Ej. cajero1',
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
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

                  // Campo de Contraseña
                  TextField(
                    controller: _contrasenaController,
                    enabled: !_cargando,
                    obscureText: _ocultarContrasena,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botón de ingresar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _cargando ? null : _login,
                      icon: _cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 20),
                      label: Text(_cargando ? 'Iniciando sesión...' : 'Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Versión
                  Text(
                    'v0.2.0 • Offline-First Granular',
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
