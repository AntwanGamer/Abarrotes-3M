import 'package:flutter/material.dart';
import '../models/usuario.dart';

/// Servicio centralizado y reactivo de Usuarios.
/// Gestiona la creación, edición, eliminación y autenticación de usuarios.
class UsuarioService extends ChangeNotifier {
  static final UsuarioService _instance = UsuarioService._internal();
  factory UsuarioService() => _instance;

  UsuarioService._internal() {
    _cargarUsuariosIniciales();
  }

  final List<Usuario> _usuarios = [];

  List<Usuario> get usuarios => List.unmodifiable(_usuarios);

  int get totalUsuarios => _usuarios.length;
  int get totalAdmins => _usuarios.where((u) => u.esAdmin).length;
  int get totalEmpleados => _usuarios.where((u) => !u.esAdmin).length;
  int get totalCajeros => totalEmpleados;

  void _cargarUsuariosIniciales() {
    _usuarios.addAll([
      Usuario(
        id: 1,
        nombreUsuario: 'admin',
        contrasena: 'admin123',
        nombres: 'Carlos',
        apellidos: 'Mendoza Pérez',
        telefono: '55 1234 5678',
        rol: 'Administrador',
      ),
      Usuario(
        id: 2,
        nombreUsuario: 'cajero1',
        contrasena: 'caja123',
        nombres: 'María',
        apellidos: 'García Ruiz',
        telefono: '55 9876 5432',
        rol: 'Empleado',
      ),
      Usuario(
        id: 3,
        nombreUsuario: 'cajero2',
        contrasena: 'caja456',
        nombres: 'Roberto',
        apellidos: 'Silva Hernández',
        telefono: '55 4433 2211',
        rol: 'Empleado',
      ),
    ]);
  }

  /// Verifica si ya existe un nombre de usuario (ignorando mayúsculas y minúsculas)
  bool existeNombreUsuario(String nombreUsuario, {int? excluirId}) {
    final normalizado = nombreUsuario.trim().toLowerCase();
    return _usuarios.any(
      (u) =>
          u.nombreUsuario.trim().toLowerCase() == normalizado &&
          (excluirId == null || u.id != excluirId),
    );
  }

  /// Agrega un nuevo usuario y notifica a los listeners
  Usuario agregarUsuario({
    required String nombreUsuario,
    required String contrasena,
    required String nombres,
    String apellidos = '',
    String telefono = '',
    String rol = 'Empleado',
  }) {
    final siguienteId = _usuarios.isEmpty
        ? 1
        : (_usuarios.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1);

    final nuevoUsuario = Usuario(
      id: siguienteId,
      nombreUsuario: nombreUsuario.trim(),
      contrasena: contrasena.trim(),
      nombres: nombres.trim(),
      apellidos: apellidos.trim(),
      telefono: telefono.trim(),
      rol: rol.trim(),
    );

    _usuarios.add(nuevoUsuario);
    notifyListeners();
    return nuevoUsuario;
  }

  /// Actualiza los datos de un usuario existente
  void actualizarUsuario(Usuario usuarioActualizado) {
    final index = _usuarios.indexWhere((u) => u.id == usuarioActualizado.id);
    if (index != -1) {
      _usuarios[index] = usuarioActualizado;
      notifyListeners();
    }
  }

  /// Elimina un usuario por su ID
  /// Retorna false si se intenta eliminar el último administrador del sistema
  bool eliminarUsuario(int id) {
    final index = _usuarios.indexWhere((u) => u.id == id);
    if (index == -1) return false;

    final usuarioAEliminar = _usuarios[index];

    // Protección para no quedarse sin administradores
    if (usuarioAEliminar.esAdmin && totalAdmins <= 1) {
      return false;
    }

    _usuarios.removeAt(index);
    notifyListeners();
    return true;
  }

  /// Busca un usuario por su ID
  Usuario? buscarPorId(int id) {
    try {
      return _usuarios.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Busca un usuario por su nombre de usuario
  Usuario? buscarPorNombreUsuario(String nombreUsuario) {
    final normalizado = nombreUsuario.trim().toLowerCase();
    try {
      return _usuarios.firstWhere(
        (u) => u.nombreUsuario.trim().toLowerCase() == normalizado,
      );
    } catch (_) {
      return null;
    }
  }

  /// Valida credenciales para inicio de sesión
  Usuario? autenticar(String nombreUsuario, String contrasena, [String? rolRequerido]) {
    final usuario = buscarPorNombreUsuario(nombreUsuario);
    if (usuario == null) return null;

    if (usuario.contrasena == contrasena) {
      if (rolRequerido != null &&
          usuario.rol.toLowerCase() != rolRequerido.toLowerCase()) {
        return null;
      }
      return usuario;
    }
    return null;
  }
}
