import 'package:flutter/material.dart';
import '../models/usuario_db.dart';
import '../models/permisos_ventanas.dart';
import '../repositories/usuarios_repository.dart';

/// Servicio centralizado y reactivo de Usuarios.
/// Conectado directamente a PostgreSQL local a través de [UsuariosRepository].
class UsuarioService extends ChangeNotifier {
  static final UsuarioService _instance = UsuarioService._internal();
  factory UsuarioService() => _instance;

  final UsuariosRepository _repo = UsuariosRepository.instance;

  UsuarioService._internal() {
    cargarUsuarios();
  }

  final List<UsuarioDB> _usuarios = [];
  bool _cargando = false;

  List<UsuarioDB> get usuarios => List.unmodifiable(_usuarios);
  bool get cargando => _cargando;
  int get totalUsuarios => _usuarios.length;

  /// Carga los usuarios desde PostgreSQL local
  Future<void> cargarUsuarios() async {
    _cargando = true;
    notifyListeners();
    try {
      final list = await _repo.obtenerTodos();
      _usuarios.clear();
      _usuarios.addAll(list);
    } catch (_) {
      // Si la BD no está disponible aún, mantiene lista actual
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Verifica si ya existe un nombre de usuario
  bool existeNombreUsuario(String nombreUsuario, {int? excluirId}) {
    final norm = nombreUsuario.trim().toLowerCase();
    return _usuarios.any(
      (u) =>
          u.nombreUsuario.trim().toLowerCase() == norm &&
          (excluirId == null || u.idUsuario != excluirId),
    );
  }

  /// Agrega un nuevo usuario en PostgreSQL local
  Future<UsuarioDB> agregarUsuario({
    String? nombreCompleto,
    required String nombreUsuario,
    required String contrasena,
    required PermisosVentanas permisos,
  }) async {
    final nuevo = await _repo.crear(
      nombreCompleto: nombreCompleto ?? nombreUsuario,
      nombreUsuario: nombreUsuario,
      plainPassword: contrasena,
      permisos: permisos,
    );
    _usuarios.add(nuevo);
    _usuarios.sort((a, b) => a.nombreUsuario.toLowerCase().compareTo(b.nombreUsuario.toLowerCase()));
    notifyListeners();
    return nuevo;
  }

  /// Actualiza los datos y permisos de un usuario existente
  Future<UsuarioDB> actualizarUsuario({
    required int idUsuario,
    String? nombreCompleto,
    required String nombreUsuario,
    String? contrasena,
    required PermisosVentanas permisos,
    String estatus = 'Activo',
  }) async {
    final actualizado = await _repo.actualizar(
      idUsuario: idUsuario,
      nombreCompleto: nombreCompleto ?? nombreUsuario,
      nombreUsuario: nombreUsuario,
      nuevaPlainPassword: (contrasena != null && contrasena.trim().isNotEmpty) ? contrasena : null,
      permisos: permisos,
      estatus: estatus,
    );
    final index = _usuarios.indexWhere((u) => u.idUsuario == idUsuario);
    if (index != -1) {
      _usuarios[index] = actualizado;
      _usuarios.sort((a, b) => a.nombreUsuario.toLowerCase().compareTo(b.nombreUsuario.toLowerCase()));
      notifyListeners();
    }
    return actualizado;
  }

  /// Desactiva (eliminación lógica) un usuario en PostgreSQL local
  Future<bool> eliminarUsuario(int idUsuario) async {
    final index = _usuarios.indexWhere((u) => u.idUsuario == idUsuario);
    if (index == -1) return false;

    // Regla de seguridad: evitar eliminar al último usuario que puede gestionar usuarios
    final usuariosConGestion = _usuarios.where((u) => u.puedeGestionarUsuarios).length;
    if (_usuarios[index].puedeGestionarUsuarios && usuariosConGestion <= 1) {
      return false;
    }

    await _repo.eliminar(idUsuario);
    _usuarios.removeAt(index);
    notifyListeners();
    return true;
  }

  /// Busca un usuario en la memoria local por ID
  UsuarioDB? buscarPorId(int idUsuario) {
    try {
      return _usuarios.firstWhere((u) => u.idUsuario == idUsuario);
    } catch (_) {
      return null;
    }
  }

  /// Busca un usuario en la memoria local por nombre de usuario
  UsuarioDB? buscarPorNombreUsuario(String nombreUsuario) {
    final norm = nombreUsuario.trim().toLowerCase();
    try {
      return _usuarios.firstWhere((u) => u.nombreUsuario.trim().toLowerCase() == norm);
    } catch (_) {
      return null;
    }
  }
}
