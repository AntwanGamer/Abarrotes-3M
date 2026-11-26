import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/usuario_db.dart';
import '../models/permisos_ventanas.dart';
import '../services/usuario_service.dart';

/// Vista del módulo de Gestión de Usuarios.
///
/// Permite listar, crear, editar y dar de baja usuarios en PostgreSQL local.
/// Los roles fueron eliminados y reemplazados por una asignación granular
/// de permisos por ventana y acción (lectura vs escritura).
class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final UsuarioService _usuarioService = UsuarioService();

  // Controladores de formulario
  final _nombreCompletoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();
  final _buscarController = TextEditingController();

  // Estado del usuario seleccionado
  int? _idSeleccionado;
  bool _ocultarContrasena = true;
  bool _ocultarConfirmar = true;
  bool _guardando = false;

  // Permisos en edición del formulario
  PermisosVentanas _permisosEnEdicion = const PermisosVentanas({
    'punto_venta': true,
    'inventario_ver': false,
    'inventario_editar': false,
    'clientes_ver': false,
    'clientes_editar': false,
    'reportes_ver': false,
    'usuarios_gestionar': false,
    'configuracion': false,
  });

  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    _usuarioService.addListener(_onServiceChanged);

    // Inicializar cargando el primer usuario si existe
    if (_usuarioService.usuarios.isNotEmpty) {
      _cargarUsuarioEnFormulario(_usuarioService.usuarios.first);
    }
  }

  @override
  void dispose() {
    _usuarioService.removeListener(_onServiceChanged);
    _nombreCompletoController.dispose();
    _usuarioController.dispose();
    _contrasenaController.dispose();
    _confirmarContrasenaController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {
        if (_idSeleccionado != null &&
            !_usuarioService.usuarios.any((u) => u.idUsuario == _idSeleccionado)) {
          if (_usuarioService.usuarios.isNotEmpty) {
            _cargarUsuarioEnFormulario(_usuarioService.usuarios.first);
          } else {
            _iniciarNuevoUsuario();
          }
        }
      });
    }
  }

  List<UsuarioDB> get _usuariosFiltrados {
    final query = _filtroBusqueda.trim().toLowerCase();
    if (query.isEmpty) return _usuarioService.usuarios;
    return _usuarioService.usuarios.where((u) {
      return u.nombreUsuario.toLowerCase().contains(query);
    }).toList();
  }

  UsuarioDB? get _usuarioActual {
    if (_idSeleccionado == null) return null;
    return _usuarioService.buscarPorId(_idSeleccionado!);
  }

  void _cargarUsuarioEnFormulario(UsuarioDB usuario) {
    setState(() {
      _idSeleccionado = usuario.idUsuario;
      _nombreCompletoController.text = usuario.nombreCompleto;
      _usuarioController.text = usuario.nombreUsuario;
      _contrasenaController.clear();
      _confirmarContrasenaController.clear();
      _permisosEnEdicion = usuario.permisosVentanas;
      _ocultarContrasena = true;
      _ocultarConfirmar = true;
    });
  }

  void _iniciarNuevoUsuario() {
    setState(() {
      _idSeleccionado = null;
      _nombreCompletoController.clear();
      _usuarioController.clear();
      _contrasenaController.clear();
      _confirmarContrasenaController.clear();
      _permisosEnEdicion = const PermisosVentanas({
        'punto_venta': true,
        'inventario_ver': false,
        'inventario_editar': false,
        'clientes_ver': false,
        'clientes_editar': false,
        'reportes_ver': false,
        'usuarios_gestionar': false,
      });
      _ocultarContrasena = true;
      _ocultarConfirmar = true;
    });
    _mostrarMensaje('Formulario listo para nuevo usuario');
  }

  /// Actualiza un permiso en el formulario respetando las dependencias:
  /// - Activar editar -> activa ver.
  /// - Desactivar ver -> desactiva editar.
  void _actualizarPermiso(String clave, bool valor) {
    setState(() {
      _permisosEnEdicion = _permisosEnEdicion.conPermiso(clave, valor);
    });
  }

  Future<void> _guardarUsuario() async {
    final nombreCompleto = _nombreCompletoController.text.trim();
    final nombreUsuario = _usuarioController.text.trim();
    final contrasena = _contrasenaController.text.trim();
    final confirmar = _confirmarContrasenaController.text.trim();

    // 1. Validar nombre de usuario
    if (nombreUsuario.isEmpty) {
      _mostrarMensaje('El Nombre de Usuario no puede estar vacío', esError: true);
      return;
    }
    if (nombreUsuario.contains(' ')) {
      _mostrarMensaje('El Nombre de Usuario no puede contener espacios', esError: true);
      return;
    }

    if (_usuarioService.existeNombreUsuario(nombreUsuario, excluirId: _idSeleccionado)) {
      _mostrarMensaje('El nombre de usuario "$nombreUsuario" ya está registrado', esError: true);
      return;
    }

    // 2. Validar contraseña
    if (_idSeleccionado == null) {
      // Modo nuevo
      if (contrasena.isEmpty) {
        _mostrarMensaje('Ingresa una contraseña para el nuevo usuario', esError: true);
        return;
      }
      if (contrasena != confirmar) {
        _mostrarMensaje('Las contraseñas no coinciden', esError: true);
        return;
      }
    } else {
      // Modo edición: solo si escribe una nueva
      if (contrasena.isNotEmpty && contrasena != confirmar) {
        _mostrarMensaje('Las contraseñas no coinciden', esError: true);
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      if (_idSeleccionado == null) {
        // Crear usuario en PostgreSQL local
        final nuevo = await _usuarioService.agregarUsuario(
          nombreCompleto: nombreCompleto.isEmpty ? nombreUsuario : nombreCompleto,
          nombreUsuario: nombreUsuario,
          contrasena: contrasena,
          permisos: _permisosEnEdicion,
        );
        setState(() {
          _idSeleccionado = nuevo.idUsuario;
        });
        _mostrarMensaje('Usuario "$nombreUsuario" creado exitosamente en PostgreSQL local');
      } else {
        // Actualizar usuario en PostgreSQL local
        await _usuarioService.actualizarUsuario(
          idUsuario: _idSeleccionado!,
          nombreCompleto: nombreCompleto.isEmpty ? nombreUsuario : nombreCompleto,
          nombreUsuario: nombreUsuario,
          contrasena: contrasena.isNotEmpty ? contrasena : null,
          permisos: _permisosEnEdicion,
        );
        _mostrarMensaje('Usuario "$nombreUsuario" y permisos actualizados correctamente');
      }
    } catch (e) {
      _mostrarMensaje('Error al guardar en base de datos: $e', esError: true);
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _eliminarUsuario() async {
    final usuario = _usuarioActual;
    if (usuario == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Desactivar Usuario'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas desactivar la cuenta "@${usuario.nombreUsuario}"?\n'
          'El usuario ya no podrá iniciar sesión en el Punto de Venta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _guardando = true);
    try {
      final eliminado = await _usuarioService.eliminarUsuario(usuario.idUsuario);
      if (!eliminado) {
        _mostrarMensaje(
          'No puedes desactivar al único usuario con permiso para gestionar usuarios.',
          esError: true,
        );
      } else {
        _mostrarMensaje('Usuario "@${usuario.nombreUsuario}" desactivado correctamente');
        if (_usuarioService.usuarios.isNotEmpty) {
          _cargarUsuarioEnFormulario(_usuarioService.usuarios.first);
        } else {
          _iniciarNuevoUsuario();
        }
      }
    } catch (e) {
      _mostrarMensaje('Error al desactivar usuario: $e', esError: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? AppColors.error : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esModoNuevo = _idSeleccionado == null;

    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner superior informativo del módulo
          _buildBannerModulo(),
          const SizedBox(height: 12),

          // Área de trabajo: Lista izquierda | Formulario granular derecho
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Buscador y lista de usuarios
                SizedBox(
                  width: 320,
                  child: _buildPanelIzquierdo(),
                ),
                const SizedBox(width: 16),

                // Columna derecha: Formulario y permisos granulares
                Expanded(
                  child: _buildPanelDerecho(esModoNuevo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerModulo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.usuariosIcon.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              size: 22,
              color: AppColors.usuariosIcon,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRACIÓN DE USUARIOS Y ACCESOS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Control granular de permisos por ventana y acción (100% Offline-First en PostgreSQL local)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '${_usuarioService.totalUsuarios} usuarios activos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelIzquierdo() {
    final usuarios = _usuariosFiltrados;

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
          // Buscador
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _buscarController,
                onChanged: (val) => setState(() => _filtroBusqueda = val),
                decoration: InputDecoration(
                  hintText: 'Buscar nombre de usuario...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),
          ),

          // Encabezado lista
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                Text(
                  'Usuarios Registrados',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: _usuarioService.cargando
                ? const Center(child: CircularProgressIndicator())
                : usuarios.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay usuarios registrados',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: usuarios.length,
                        itemBuilder: (context, index) {
                          final u = usuarios[index];
                          final bool seleccionado = _idSeleccionado == u.idUsuario;

                          return InkWell(
                            onTap: () => _cargarUsuarioEnFormulario(u),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: seleccionado
                                    ? const Color(0xFF4338CA)
                                    : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                border: const Border(
                                  bottom: BorderSide(color: Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Avatar circular
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: seleccionado
                                        ? Colors.white24
                                        : u.avatarColor.withAlpha(35),
                                    child: Text(
                                      u.inicial,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: seleccionado ? Colors.white : u.avatarColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          u.nombreUsuario,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: seleccionado ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          u.puedeGestionarUsuarios
                                              ? 'Gestiona usuarios • Acceso amplio'
                                              : 'Punto de venta y operaciones',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: seleccionado ? Colors.white70 : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (u.puedeGestionarUsuarios)
                                    Icon(
                                      Icons.shield_rounded,
                                      size: 16,
                                      color: seleccionado ? Colors.white : AppColors.usuariosIcon,
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

  Widget _buildPanelDerecho(bool esModoNuevo) {
    final usuario = _usuarioActual;

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
          // Barra de acciones del formulario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildBotonToolbar(
                  label: 'Nuevo Usuario',
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: _iniciarNuevoUsuario,
                ),
                const SizedBox(width: 8),
                _buildBotonToolbar(
                  label: 'Desactivar',
                  icon: Icons.delete_outline_rounded,
                  color: esModoNuevo ? Colors.grey : AppColors.error,
                  onTap: esModoNuevo ? null : _eliminarUsuario,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarUsuario,
                  icon: _guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    esModoNuevo ? 'Crear Usuario' : 'Guardar Cambios',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // Contenido con scroll: Credenciales + Permisos Granulares
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título dinámico
                  Text(
                    esModoNuevo
                        ? 'Crear Cuenta de Usuario'
                        : 'Editando cuenta: @${usuario?.nombreUsuario ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN 1: CREDENCIALES
                  _buildSeccionHeader('1. CREDENCIALES DE ACCESO', Icons.lock_outline_rounded),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nombreCompletoController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      hintText: 'Ej. Juan Pérez',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre de usuario
                      Expanded(
                        child: TextField(
                          controller: _usuarioController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de usuario *',
                            hintText: 'Ej. cajero1 (sin espacios)',
                            prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Contraseña
                      Expanded(
                        child: TextField(
                          controller: _contrasenaController,
                          obscureText: _ocultarContrasena,
                          decoration: InputDecoration(
                            labelText: esModoNuevo
                                ? 'Contraseña *'
                                : 'Nueva Contraseña (opcional)',
                            prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarContrasena ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _ocultarContrasena = !_ocultarContrasena),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Confirmar contraseña
                      Expanded(
                        child: TextField(
                          controller: _confirmarContrasenaController,
                          obscureText: _ocultarConfirmar,
                          decoration: InputDecoration(
                            labelText: 'Confirmar Contraseña',
                            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarConfirmar ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // SECCIÓN 2: SELECTOR GRANULAR DE PERMISOS
                  _buildSeccionHeader(
                    '2. ASIGNACIÓN GRANULAR DE PERMISOS (JSONB)',
                    Icons.security_rounded,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona con precisión a qué ventanas y qué nivel de acción (solo lectura vs edición) tendrá este usuario.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Módulo: Punto de Venta
                  _buildModuloCard(
                    titulo: 'Punto de Venta / Caja',
                    icono: Icons.point_of_sale_rounded,
                    color: AppColors.ventasIcon,
                    items: [
                      _buildPermisoTile(
                        clave: PermisosVentanas.puntoVentaKey,
                        titulo: 'Acceso a Punto de Venta (punto_venta)',
                        descripcion: 'Permite abrir caja, escanear productos y cobrar tickets de venta.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Módulo: Inventario y Productos
                  _buildModuloCard(
                    titulo: 'Inventario y Catálogo de Productos',
                    icono: Icons.inventory_2_outlined,
                    color: AppColors.productosIcon,
                    items: [
                      _buildPermisoTile(
                        clave: PermisosVentanas.inventarioVerKey,
                        titulo: 'Ver Inventario (inventario_ver)',
                        descripcion: 'Solo lectura: consultar catálogo de productos, existencias y costos.',
                      ),
                      const Divider(height: 1),
                      _buildPermisoTile(
                        clave: PermisosVentanas.inventarioEditarKey,
                        titulo: 'Editar Inventario (inventario_editar)',
                        descripcion: 'Crear productos, modificar precios/datos y registrar entradas o salidas de stock.',
                        dependeDe: 'Al activarse, activa automáticamente "Ver Inventario".',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Módulo: Clientes
                  _buildModuloCard(
                    titulo: 'Directorio de Clientes',
                    icono: Icons.people_alt_rounded,
                    color: AppColors.clientesIcon,
                    items: [
                      _buildPermisoTile(
                        clave: PermisosVentanas.clientesVerKey,
                        titulo: 'Ver Clientes (clientes_ver)',
                        descripcion: 'Solo lectura: consultar listado y datos de contacto de clientes.',
                      ),
                      const Divider(height: 1),
                      _buildPermisoTile(
                        clave: PermisosVentanas.clientesEditarKey,
                        titulo: 'Editar Clientes (clientes_editar)',
                        descripcion: 'Crear nuevos clientes, actualizar datos y gestionar su crédito.',
                        dependeDe: 'Al activarse, activa automáticamente "Ver Clientes".',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Módulo: Reportes y Cortes
                  _buildModuloCard(
                    titulo: 'Reportes y Cortes de Caja',
                    icono: Icons.bar_chart_rounded,
                    color: AppColors.reportesIcon,
                    items: [
                      _buildPermisoTile(
                        clave: PermisosVentanas.reportesVerKey,
                        titulo: 'Ver Reportes y Cortes (reportes_ver)',
                        descripcion: 'Acceso a cortes de turno/día, historial de ventas y reportes financieros.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Módulo: Administración del Sistema
                  _buildModuloCard(
                    titulo: 'Administración del Sistema',
                    icono: Icons.manage_accounts_rounded,
                    color: AppColors.usuariosIcon,
                    items: [
                      _buildPermisoTile(
                        clave: PermisosVentanas.usuariosGestionarKey,
                        titulo: 'Gestionar Usuarios y Permisos (usuarios_gestionar)',
                        descripcion: 'Permite crear nuevos usuarios, editar contraseñas y asignar permisos.',
                      ),
                      const SizedBox(height: 8),
                      _buildPermisoTile(
                        clave: PermisosVentanas.configuracionKey,
                        titulo: 'Configuración del Sistema (configuracion)',
                        descripcion: 'Permite acceder a datos del negocio, ticket, periféricos y respaldos.',
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

  Widget _buildSeccionHeader(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildModuloCard({
    required String titulo,
    required IconData icono,
    required Color color,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildPermisoTile({
    required String clave,
    required String titulo,
    required String descripcion,
    String? dependeDe,
  }) {
    final valor = _permisosEnEdicion.tieneAcceso(clave);

    return SwitchListTile(
      value: valor,
      activeColor: AppColors.primary,
      onChanged: (nuevoValor) => _actualizarPermiso(clave, nuevoValor),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 13,
          fontWeight: valor ? FontWeight.bold : FontWeight.w500,
          color: valor ? AppColors.textPrimary : const Color(0xFF64748B),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            descripcion,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (dependeDe != null)
            Text(
              dependeDe,
              style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontStyle: FontStyle.italic),
            ),
        ],
      ),
      dense: true,
    );
  }

  Widget _buildBotonToolbar({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null ? Colors.grey : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
