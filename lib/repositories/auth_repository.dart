import 'dart:developer' as dev;
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario_db.dart';
import '../models/permisos_ventanas.dart';
import '../services/database_service.dart';

/// Repositorio de autenticación y permisos de sesión activa.
///
/// Opera 100 % contra PostgreSQL local (offline-first).
/// Valida credenciales contra [tbl_usuarios] usando [nombre_usuario] y bcrypt.
class AuthRepository {
  final DatabaseService _db;

  static AuthRepository? _instance;
  static AuthRepository get instance {
    _instance ??= AuthRepository(DatabaseService.instance);
    return _instance!;
  }

  /// Usuario actualmente autenticado (en memoria).
  UsuarioDB? _usuarioActual;

  /// Permisos activos del usuario autenticado.
  PermisosVentanas? _permisosActivos;

  AuthRepository(this._db);

  /// Usuario autenticado actualmente.
  UsuarioDB? get usuarioActual => _usuarioActual;

  /// Permisos activos en memoria para proteger pantallas.
  PermisosVentanas? get permisosActivos => _permisosActivos;

  /// Indica si hay una sesión activa
  bool get estaAutenticado => _usuarioActual != null;

  // ---------------------------------------------------------------------------
  // Login Offline
  // ---------------------------------------------------------------------------

  /// Autentica al usuario contra la base de datos LOCAL:
  /// 1. Busca el usuario por [nombreUsuario] en `tbl_usuarios` con `estatus = 'Activo'`.
  /// 2. Valida la contraseña [plainPassword] con [bcrypt].
  /// 3. Carga el objeto [PermisosVentanas] en memoria para proteger la app.
  /// 4. Persiste la sesión en SharedPreferences.
  Future<UsuarioDB?> login(String nombreUsuario, String plainPassword) async {
    try {
      final normalizado = nombreUsuario.trim().toLowerCase();
      final result = await _db.query(
        "SELECT * FROM tbl_usuarios WHERE LOWER(nombre_usuario) = @nombre AND estatus::text = 'Activo' LIMIT 1",
        params: {
          'nombre': normalizado,
        },
      );

      if (result.isEmpty) {
        dev.log('[AuthRepository] ⚠️ Usuario no encontrado o inactivo: $nombreUsuario');
        return null;
      }

      final row = result.first.toColumnMap();
      final usuario = UsuarioDB.fromMap(row);

      // Validar contraseña con bcrypt
      final passwordValida = BCrypt.checkpw(plainPassword.trim(), usuario.hashPassword);
      if (!passwordValida) {
        dev.log('[AuthRepository] ⚠️ Contraseña incorrecta para: $nombreUsuario');
        return null;
      }

      // Actualizar último acceso en PostgreSQL local
      await _db.query(
        'UPDATE tbl_usuarios SET ultimo_acceso = CURRENT_TIMESTAMP WHERE id_usuario = @id',
        params: {'id': usuario.idUsuario},
      );

      // Login exitoso
      _usuarioActual = usuario;
      _permisosActivos = usuario.permisosVentanas;

      // Persistir sesión offline
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('session_user_id', usuario.idUsuario);
      await prefs.setString('session_user_uuid', usuario.uuidSync);
      await prefs.setString('session_username', usuario.nombreUsuario);

      dev.log('[AuthRepository] ✅ Login exitoso: ${usuario.nombreUsuario}');
      return usuario;
    } catch (e) {
      dev.log('[AuthRepository] ❌ Error en login: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Restaurar sesión offline
  // ---------------------------------------------------------------------------

  /// Intenta restaurar la sesión persistida en SharedPreferences.
  Future<UsuarioDB?> restaurarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('session_user_id');
      if (userId == null) return null;

      final result = await _db.query(
        "SELECT * FROM tbl_usuarios WHERE id_usuario = @id AND estatus::text = 'Activo' LIMIT 1",
        params: {'id': userId},
      );

      if (result.isEmpty) return null;

      final row = result.first.toColumnMap();
      _usuarioActual = UsuarioDB.fromMap(row);
      _permisosActivos = _usuarioActual!.permisosVentanas;

      dev.log('[AuthRepository] ✅ Sesión restaurada: ${_usuarioActual!.nombreUsuario}');
      return _usuarioActual;
    } catch (e) {
      dev.log('[AuthRepository] ⚠️ No se pudo restaurar sesión: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Verificación de permisos
  // ---------------------------------------------------------------------------

  /// Verifica si el usuario actual tiene acceso a una [ventana] o permiso específico.
  bool tieneAcceso(String permiso) {
    return _permisosActivos?.tieneAcceso(permiso) ?? false;
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  /// Cierra la sesión actual y limpia la persistencia.
  Future<void> logout() async {
    _usuarioActual = null;
    _permisosActivos = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    await prefs.remove('session_user_uuid');
    await prefs.remove('session_username');

    dev.log('[AuthRepository] Sesión cerrada.');
  }
}
