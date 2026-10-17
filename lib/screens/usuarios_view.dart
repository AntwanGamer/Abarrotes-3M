import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';

/// Vista del módulo de Usuarios (Exclusiva para Administrador).
/// Permite listar, buscar, agregar, editar y eliminar usuarios del sistema.
/// Estructura del formulario:
/// - Usuario: Nombre de Usuario, Contraseña, Confirmar contraseña
/// - Datos generales: Nombres, Apellidos, Teléfono
/// - Rol: Empleado o Administrador
class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final UsuarioService _usuarioService = UsuarioService();

  // Controladores de texto para el formulario
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _buscarController = TextEditingController();

  // Estados del formulario
  int? _idSeleccionado = 1;
  String _rolSeleccionado = 'Empleado';
  bool _ocultarContrasena = true;
  bool _ocultarConfirmar = true;

  // Filtros
  String _filtroBusqueda = '';
  String _filtroRol = 'Todos'; // 'Todos', 'Administrador', 'Empleado'

  @override
  void initState() {
    super.initState();
    _usuarioService.addListener(_onServiceChanged);

    // Cargar por defecto el primer usuario si existe
    if (_usuarioService.usuarios.isNotEmpty) {
      _cargarUsuarioEnFormulario(_usuarioService.usuarios.first);
    }
  }

  @override
  void dispose() {
    _usuarioService.removeListener(_onServiceChanged);
    _usuarioController.dispose();
    _contrasenaController.dispose();
    _confirmarContrasenaController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _telefonoController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  /// Lista de usuarios filtrada por búsqueda y por rol
  List<Usuario> get _usuariosFiltrados {
    final query = _filtroBusqueda.trim().toLowerCase();
    return _usuarioService.usuarios.where((u) {
      final cumpleRol = _filtroRol == 'Todos' ||
          u.rol.toLowerCase() == _filtroRol.toLowerCase();

      if (!cumpleRol) return false;
      if (query.isEmpty) return true;

      return u.nombreUsuario.toLowerCase().contains(query) ||
          u.nombres.toLowerCase().contains(query) ||
          u.apellidos.toLowerCase().contains(query) ||
          u.telefono.toLowerCase().contains(query) ||
          u.rol.toLowerCase().contains(query);
    }).toList();
  }

  Usuario? get _usuarioActual {
    if (_idSeleccionado == null) return null;
    return _usuarioService.buscarPorId(_idSeleccionado!);
  }

  /// Carga los datos de un usuario en los campos del formulario para edición
  void _cargarUsuarioEnFormulario(Usuario usuario) {
    setState(() {
      _idSeleccionado = usuario.id;
      _usuarioController.text = usuario.nombreUsuario;
      _contrasenaController.text = usuario.contrasena;
      _confirmarContrasenaController.text = usuario.contrasena;
      _nombresController.text = usuario.nombres;
      _apellidosController.text = usuario.apellidos;
      _telefonoController.text = usuario.telefono;
      _rolSeleccionado = usuario.rol;
      _ocultarContrasena = true;
      _ocultarConfirmar = true;
    });
  }

  /// Limpia los campos para iniciar el registro de un nuevo usuario
  void _iniciarNuevoUsuario() {
    setState(() {
      _idSeleccionado = null;
      _usuarioController.clear();
      _contrasenaController.clear();
      _confirmarContrasenaController.clear();
      _nombresController.clear();
      _apellidosController.clear();
      _telefonoController.clear();
      _rolSeleccionado = 'Empleado';
      _ocultarContrasena = true;
      _ocultarConfirmar = true;
    });
    _mostrarMensaje('Formulario listo para nuevo usuario');
  }

  /// Guarda el usuario (crear nuevo o actualizar existente)
  void _guardarUsuario() {
    final nombreUsuario = _usuarioController.text.trim();
    final contrasena = _contrasenaController.text.trim();
    final confirmarContrasena = _confirmarContrasenaController.text.trim();
    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final telefono = _telefonoController.text.trim();
    final rol = _rolSeleccionado;

    // 1. Validaciones de Usuario
    if (nombreUsuario.isEmpty) {
      _mostrarMensaje('Por favor ingresa el Nombre de Usuario', esError: true);
      return;
    }

    if (_usuarioService.existeNombreUsuario(nombreUsuario, excluirId: _idSeleccionado)) {
      _mostrarMensaje('El nombre de usuario "$nombreUsuario" ya está registrado', esError: true);
      return;
    }

    // 2. Validaciones de Contraseña
    if (_idSeleccionado == null) {
      // Modo Nuevo: contraseña obligatoria
      if (contrasena.isEmpty) {
        _mostrarMensaje('La contraseña no puede estar vacía', esError: true);
        return;
      }
      if (contrasena != confirmarContrasena) {
        _mostrarMensaje('Las contraseñas no coinciden', esError: true);
        return;
      }
    } else {
      // Modo Edición: si escribió contraseña, debe coincidir
      if (contrasena.isNotEmpty && contrasena != confirmarContrasena) {
        _mostrarMensaje('Las contraseñas no coinciden', esError: true);
        return;
      }
    }

    // 3. Validaciones de Datos Generales
    if (nombres.isEmpty) {
      _mostrarMensaje('Por favor ingresa los Nombres del usuario', esError: true);
      return;
    }

    // 4. Guardar o Actualizar
    if (_idSeleccionado == null) {
      // Crear nuevo usuario
      final nuevo = _usuarioService.agregarUsuario(
        nombreUsuario: nombreUsuario,
        contrasena: contrasena,
        nombres: nombres,
        apellidos: apellidos,
        telefono: telefono,
        rol: rol,
      );
      setState(() {
        _idSeleccionado = nuevo.id;
      });
      _mostrarMensaje('Usuario "$nombreUsuario" registrado exitosamente');
    } else {
      // Actualizar usuario existente
      final usuarioActual = _usuarioActual;
      if (usuarioActual == null) return;

      final contrasenaFinal = contrasena.isNotEmpty ? contrasena : usuarioActual.contrasena;

      final usuarioModificado = usuarioActual.copyWith(
        nombreUsuario: nombreUsuario,
        contrasena: contrasenaFinal,
        nombres: nombres,
        apellidos: apellidos,
        telefono: telefono,
        rol: rol,
      );

      _usuarioService.actualizarUsuario(usuarioModificado);
      _mostrarMensaje('Usuario "$nombreUsuario" actualizado exitosamente');
    }
  }

  /// Elimina el usuario seleccionado con confirmación y reglas de seguridad
  void _eliminarUsuario() {
    final usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Selecciona un usuario para eliminar', esError: true);
      return;
    }

    // Regla de seguridad: no eliminar al único admin
    if (usuario.esAdmin && _usuarioService.totalAdmins <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Operación no permitida'),
            ],
          ),
          content: const Text(
            'No puedes eliminar al único Administrador del sistema. '
            'Debes asignar el rol de Administrador a otro usuario antes de eliminar este.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Eliminar Usuario'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar permanentemente la cuenta del usuario '
              '"${usuario.nombreUsuario}" (${usuario.nombreCompleto})?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rol: ${usuario.rol}  •  ID #${usuario.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final eliminado = _usuarioService.eliminarUsuario(usuario.id);
              if (eliminado) {
                if (_usuarioService.usuarios.isNotEmpty) {
                  _cargarUsuarioEnFormulario(_usuarioService.usuarios.first);
                } else {
                  _iniciarNuevoUsuario();
                }
                _mostrarMensaje('Usuario eliminado correctamente');
              } else {
                _mostrarMensaje('No se pudo eliminar el usuario', esError: true);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Pestaña de sub-opción superior estilo Eleventa
        _buildPestanaSubOpcion(),

        // 2. Contenido principal con el layout de dos columnas
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título principal, descripción y métricas rápidas
                  _buildEncabezadoModulo(),

                  const SizedBox(height: 14),

                  // Área de trabajo dividida: Lista a la izquierda | Formulario a la derecha
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda: Buscador, Filtros y Lista de Usuarios
                        SizedBox(
                          width: 340,
                          child: _buildPanelIzquierdo(),
                        ),

                        const SizedBox(width: 20),

                        // Columna derecha: Barra de herramientas superior y Formulario estructurado
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

  /// Pestaña superior: "Administración de usuarios" con insignia de Administrador
  Widget _buildPestanaSubOpcion() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.manage_accounts_rounded,
                  size: 17,
                  color: AppColors.usuariosIcon,
                ),
                SizedBox(width: 8),
                Text(
                  'Administración de Usuarios y Accesos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 14,
                  color: AppColors.usuariosIcon,
                ),
                SizedBox(width: 6),
                Text(
                  'Solo Administrador',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.usuariosIcon,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado con título del módulo y métricas rápidas de cuentas
  Widget _buildEncabezadoModulo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRACIÓN DE USUARIOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Gestiona las cuentas de acceso, roles (Administrador / Empleado) y datos del personal del negocio.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        // Mini tarjetas de resumen
        _buildResumenChip(
          titulo: 'Total',
          valor: '${_usuarioService.totalUsuarios}',
          icono: Icons.people_alt_rounded,
          color: const Color(0xFF475569),
        ),
        const SizedBox(width: 8),
        _buildResumenChip(
          titulo: 'Admins',
          valor: '${_usuarioService.totalAdmins}',
          icono: Icons.admin_panel_settings_rounded,
          color: AppColors.usuariosIcon,
        ),
        const SizedBox(width: 8),
        _buildResumenChip(
          titulo: 'Empleados',
          valor: '${_usuarioService.totalEmpleados}',
          icono: Icons.badge_outlined,
          color: AppColors.ventasIcon,
        ),
      ],
    );
  }

  Widget _buildResumenChip({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$titulo: ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Panel Izquierdo: Buscador, Filtro de Roles y Lista de Usuarios
  Widget _buildPanelIzquierdo() {
    final usuarios = _usuariosFiltrados;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Campo de búsqueda con icono
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _buscarController,
                onChanged: (val) {
                  setState(() {
                    _filtroBusqueda = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar usuario o nombre...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _filtroBusqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _buscarController.clear();
                            setState(() => _filtroBusqueda = '');
                          },
                        )
                      : null,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppColors.usuariosIcon, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // Chips de filtro por Rol: [Todos] [Admins] [Usuarios]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                _buildFiltroRolChip('Todos'),
                const SizedBox(width: 6),
                _buildFiltroRolChip('Administrador', label: 'Admins'),
                const SizedBox(width: 6),
                _buildFiltroRolChip('Empleado', label: 'Empleados'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Encabezado de la lista: Usuario | Rol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Usuario / Nombre',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                Text(
                  'Rol',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: usuarios.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 40, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text(
                            'No se encontraron usuarios',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: usuarios.length,
                    itemBuilder: (context, index) {
                      final usuario = usuarios[index];
                      final bool seleccionado = _idSeleccionado == usuario.id;

                      return InkWell(
                        onTap: () => _cargarUsuarioEnFormulario(usuario),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: seleccionado
                                ? const Color(0xFF4338CA) // Índigo oscuro seleccionado
                                : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                            border: const Border(
                              bottom: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar con icono de rol
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: seleccionado
                                      ? Colors.white.withAlpha(40)
                                      : usuario.avatarColor.withAlpha(30),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: seleccionado
                                        ? Colors.white70
                                        : usuario.avatarColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    usuario.esAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.person_rounded,
                                    size: 18,
                                    color: seleccionado
                                        ? Colors.white
                                        : usuario.avatarColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Datos del usuario (Nombre de Usuario y Nombre Completo)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '@${usuario.nombreUsuario}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: seleccionado
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      usuario.nombreCompleto,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: seleccionado
                                            ? Colors.white70
                                            : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (usuario.telefono.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_rounded,
                                            size: 10,
                                            color: seleccionado
                                                ? Colors.white60
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            usuario.telefono,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: seleccionado
                                                  ? Colors.white60
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Badge de Rol
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: seleccionado
                                      ? Colors.white.withAlpha(50)
                                      : (usuario.esAdmin
                                          ? const Color(0xFFEDE9FE)
                                          : const Color(0xFFEFF6FF)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: seleccionado
                                        ? Colors.white60
                                        : (usuario.esAdmin
                                            ? const Color(0xFFC4B5FD)
                                            : const Color(0xFFBFDBFE)),
                                  ),
                                ),
                                child: Text(
                                  usuario.rol,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: seleccionado
                                        ? Colors.white
                                        : (usuario.esAdmin
                                            ? AppColors.usuariosIcon
                                            : const Color(0xFF1D4ED8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Barra inferior informativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  '${usuarios.length} de ${_usuarioService.totalUsuarios} usuarios mostrados',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroRolChip(String rol, {String? label}) {
    final bool activo = _filtroRol == rol;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _filtroRol = rol;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: activo ? AppColors.usuariosIcon : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: activo ? AppColors.usuariosIcon : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: Text(
              label ?? rol,
              style: TextStyle(
                fontSize: 11,
                fontWeight: activo ? FontWeight.bold : FontWeight.w600,
                color: activo ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel Derecho: Barra de botones de acción y Formulario estructurado
  Widget _buildPanelDerecho() {
    final bool esModoNuevo = _idSeleccionado == null;
    final usuario = _usuarioActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de botones superior: [ Nuevo Usuario ] [ Eliminar ] [ Guardar ] [ Limpiar ]
        Row(
          children: [
            // Botón: Nuevo Usuario
            _buildBotonToolbar(
              label: 'Nuevo Usuario',
              icon: Icons.person_add_alt_1_rounded,
              iconColor: const Color(0xFF2563EB),
              onTap: _iniciarNuevoUsuario,
            ),
            const SizedBox(width: 8),

            // Botón: Eliminar
            _buildBotonToolbar(
              label: 'Eliminar',
              icon: Icons.delete_outline_rounded,
              iconColor: esModoNuevo ? const Color(0xFF94A3B8) : AppColors.error,
              onTap: esModoNuevo ? null : _eliminarUsuario,
            ),
            const SizedBox(width: 8),

            // Botón: Guardar
            _buildBotonToolbar(
              label: 'Guardar',
              icon: Icons.check_rounded,
              iconColor: AppColors.success,
              onTap: _guardarUsuario,
            ),
            const SizedBox(width: 8),

            // Botón: Limpiar / Recargar
            _buildBotonToolbar(
              label: esModoNuevo ? 'Limpiar' : 'Restablecer',
              icon: Icons.refresh_rounded,
              iconColor: const Color(0xFF64748B),
              onTap: () {
                if (esModoNuevo) {
                  _iniciarNuevoUsuario();
                } else if (usuario != null) {
                  _cargarUsuarioEnFormulario(usuario);
                  _mostrarMensaje('Formulario restablecido a los datos guardados');
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tarjeta contenedora del formulario estructurado
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título dinámico de la sección
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: esModoNuevo
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          esModoNuevo
                              ? Icons.person_add_alt_1_rounded
                              : Icons.edit_note_rounded,
                          color: esModoNuevo
                              ? const Color(0xFF2563EB)
                              : AppColors.usuariosIcon,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            esModoNuevo
                                ? 'Agregar Nuevo Usuario'
                                : 'Modificando Usuario: @${usuario?.nombreUsuario ?? ''}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: esModoNuevo
                                  ? const Color(0xFF1E293B)
                                  : AppColors.usuariosIcon,
                            ),
                          ),
                          Text(
                            esModoNuevo
                                ? 'Completa los siguientes apartados para crear la cuenta de acceso.'
                                : 'ID de cuenta #${usuario?.id} • Registrado el ${_formatearFecha(usuario?.fechaRegistro)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),

                  // ==========================================
                  // SECCIÓN 1: USUARIO
                  // ==========================================
                  _buildTituloSeccion(
                    numero: '1',
                    titulo: 'Usuario',
                    subtitulo: 'Credenciales para el inicio de sesión en el punto de venta',
                    icono: Icons.lock_outline_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 16),

                  // - Nombre de Usuario
                  _buildCampoFila(
                    label: 'Nombre de Usuario',
                    controller: _usuarioController,
                    hint: 'Ej. cajero1, admin_tienda',
                    icon: Icons.alternate_email_rounded,
                    ayuda: 'Nombre de cuenta único para ingresar al sistema.',
                  ),
                  const SizedBox(height: 16),

                  // - Contraseña
                  _buildCampoContrasenaFila(
                    label: 'Contraseña',
                    controller: _contrasenaController,
                    hint: esModoNuevo
                        ? 'Escribe una contraseña segura'
                        : 'Dejar en blanco para mantener la actual',
                    ocultar: _ocultarContrasena,
                    onToggleOcultar: () {
                      setState(() => _ocultarContrasena = !_ocultarContrasena);
                    },
                    icon: Icons.lock_rounded,
                  ),
                  const SizedBox(height: 16),

                  // - Confirmar contraseña
                  _buildCampoContrasenaFila(
                    label: 'Confirmar contraseña',
                    controller: _confirmarContrasenaController,
                    hint: 'Vuelve a escribir la contraseña',
                    ocultar: _ocultarConfirmar,
                    onToggleOcultar: () {
                      setState(() => _ocultarConfirmar = !_ocultarConfirmar);
                    },
                    icon: Icons.lock_reset_rounded,
                  ),

                  // Indicador de coincidencia de contraseñas
                  _buildIndicadorCoincidenciaContrasenas(),

                  const SizedBox(height: 28),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),

                  // ==========================================
                  // SECCIÓN 2: DATOS GENERALES
                  // ==========================================
                  _buildTituloSeccion(
                    numero: '2',
                    titulo: 'Datos generales',
                    subtitulo: 'Información personal y de contacto del colaborador',
                    icono: Icons.badge_outlined,
                    color: const Color(0xFF0D9488),
                  ),
                  const SizedBox(height: 16),

                  // - Nombres
                  _buildCampoFila(
                    label: 'Nombres',
                    controller: _nombresController,
                    hint: 'Ej. Carlos Alberto',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),

                  // - Apellidos
                  _buildCampoFila(
                    label: 'Apellidos',
                    controller: _apellidosController,
                    hint: 'Ej. Mendoza Pérez',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // - Teléfono
                  _buildCampoFila(
                    label: 'Teléfono',
                    controller: _telefonoController,
                    hint: 'Ej. 55 1234 5678',
                    icon: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 20),

                  // ==========================================
                  // SECCIÓN 3: ROL
                  // ==========================================
                  _buildTituloSeccion(
                    numero: '3',
                    titulo: 'Rol',
                    subtitulo: 'Nivel de acceso y permisos dentro de Abarrotes 3M',
                    icono: Icons.admin_panel_settings_outlined,
                    color: AppColors.usuariosIcon,
                  ),
                  const SizedBox(height: 16),

                  _buildSelectorRol(),

                  const SizedBox(height: 36),

                  // Botón grande de guardar al pie del formulario
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: esModoNuevo ? _iniciarNuevoUsuario : () {
                          if (usuario != null) _cargarUsuarioEnFormulario(usuario);
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _guardarUsuario,
                        icon: const Icon(Icons.save_rounded, size: 20),
                        label: Text(
                          esModoNuevo ? 'Guardar Nuevo Usuario' : 'Guardar Cambios',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Encabezado para cada sección del formulario
  Widget _buildTituloSeccion({
    required String numero,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              numero,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de campo de texto estándar con etiqueta alineada
  Widget _buildCampoFila({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? ayuda,
    TextInputType? teclado,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 42,
                child: TextField(
                  controller: controller,
                  keyboardType: teclado,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.usuariosIcon, width: 1.8),
                    ),
                  ),
                ),
              ),
              if (ayuda != null) ...[
                const SizedBox(height: 4),
                Text(
                  ayuda,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de campo de contraseña con botón para alternar visibilidad
  Widget _buildCampoContrasenaFila({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool ocultar,
    required VoidCallback onToggleOcultar,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              obscureText: ocultar,
              style: const TextStyle(fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
                suffixIcon: IconButton(
                  icon: Icon(
                    ocultar ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: onToggleOcultar,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.usuariosIcon, width: 1.8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Indicador visual cuando las contraseñas coinciden o no
  Widget _buildIndicadorCoincidenciaContrasenas() {
    final c1 = _contrasenaController.text;
    final c2 = _confirmarContrasenaController.text;

    if (c1.isEmpty && c2.isEmpty) return const SizedBox.shrink();

    final bool coinciden = c1 == c2 && c1.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 170),
      child: Row(
        children: [
          Icon(
            coinciden ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 15,
            color: coinciden ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 6),
          Text(
            coinciden
                ? 'Las contraseñas coinciden correctamente'
                : 'Las contraseñas no coinciden',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: coinciden ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  /// Selector visual de Rol (Usuario o Administrador)
  Widget _buildSelectorRol() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 170,
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Rol',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Tarjeta Rol: Empleado
              Expanded(
                child: _buildTarjetaOpcionRol(
                  rol: 'Empleado',
                  titulo: 'Empleado',
                  descripcion:
                      'Cajero u operador del mostrador. Puede realizar ventas, clientes y cobros.',
                  icono: Icons.badge_outlined,
                  color: AppColors.ventasIcon,
                ),
              ),
              const SizedBox(width: 16),
              // Tarjeta Rol: Administrador
              Expanded(
                child: _buildTarjetaOpcionRol(
                  rol: 'Administrador',
                  titulo: 'Administrador',
                  descripcion:
                      'Control total del sistema. Acceso a usuarios, cortes, reportes y configuración.',
                  icono: Icons.admin_panel_settings_outlined,
                  color: AppColors.usuariosIcon,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaOpcionRol({
    required String rol,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
  }) {
    final bool seleccionado = _rolSeleccionado == rol;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _rolSeleccionado = rol;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: seleccionado ? color.withAlpha(12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: seleccionado ? color : const Color(0xFFCBD5E1),
              width: seleccionado ? 2.0 : 1.0,
            ),
            boxShadow: seleccionado
                ? [
                    BoxShadow(
                      color: color.withAlpha(30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: seleccionado ? color : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icono,
                  size: 22,
                  color: seleccionado ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: seleccionado ? color : const Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        if (seleccionado)
                          Icon(Icons.check_circle_rounded, size: 18, color: color)
                        else
                          const Icon(Icons.radio_button_unchecked_rounded,
                              size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón estándar para la barra de herramientas superior
  Widget _buildBotonToolbar({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    final bool habilitado = onTap != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: habilitado ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
            boxShadow: habilitado
                ? const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: habilitado ? iconColor : const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: habilitado ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Hoy';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
