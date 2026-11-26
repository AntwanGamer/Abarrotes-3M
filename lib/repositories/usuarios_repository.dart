import 'dart:developer' as dev;
import 'package:bcrypt/bcrypt.dart';
import '../models/usuario_db.dart';
import '../models/permisos_ventanas.dart';
import '../services/database_service.dart';

/// Repositorio local-first para la gestión (CRUD) de usuarios en PostgreSQL.
///
/// Todas las operaciones leen y escriben contra la base de datos local
/// y marcan `sincronizado = false` para que [SyncService] suba los cambios a Supabase.
class UsuariosRepository {
  final DatabaseService _db;

  UsuariosRepository(this._db);

  static UsuariosRepository? _instance;
  static UsuariosRepository get instance {
    _instance ??= UsuariosRepository(DatabaseService.instance);
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  /// Obtiene todos los usuarios activos ordenados por nombre de usuario.
  Future<List<UsuarioDB>> obtenerTodos() async {
    final result = await _db.query(
      "SELECT * FROM tbl_usuarios WHERE estatus::text = 'Activo' ORDER BY nombre_usuario ASC",
    );
    return result.map((r) => UsuarioDB.fromMap(r.toColumnMap())).toList();
  }

  /// Busca un usuario por su ID primario.
  Future<UsuarioDB?> buscarPorId(int idUsuario) async {
    final result = await _db.query(
      "SELECT * FROM tbl_usuarios WHERE id_usuario = @id LIMIT 1",
      params: {'id': idUsuario},
    );
    if (result.isEmpty) return null;
    return UsuarioDB.fromMap(result.first.toColumnMap());
  }

  /// Busca un usuario activo por su nombre de usuario (case-insensitive).
  Future<UsuarioDB?> buscarPorNombreUsuario(String nombreUsuario) async {
    final normalizado = nombreUsuario.trim().toLowerCase();
    final result = await _db.query(
      "SELECT * FROM tbl_usuarios WHERE LOWER(nombre_usuario) = @nombre AND estatus::text = 'Activo' LIMIT 1",
      params: {'nombre': normalizado},
    );
    if (result.isEmpty) return null;
    return UsuarioDB.fromMap(result.first.toColumnMap());
  }

  /// Verifica si ya existe un nombre de usuario registrado.
  Future<bool> existeNombreUsuario(String nombreUsuario, {int? excluirId}) async {
    final normalizado = nombreUsuario.trim().toLowerCase();
    final result = await _db.query(
      '''SELECT id_usuario FROM tbl_usuarios
         WHERE LOWER(nombre_usuario) = @nombre
           AND (@excluirId::bigint IS NULL OR id_usuario <> @excluirId)
         LIMIT 1''',
      params: {
        'nombre': normalizado,
        'excluirId': excluirId,
      },
    );
    return result.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Escritura (CRUD Local-First)
  // ---------------------------------------------------------------------------

  /// Crea un nuevo usuario en PostgreSQL local:
  /// - Encripta la contraseña con [bcrypt].
  /// - Serializa los permisos a JSONB.
  /// - Guarda `nombre_usuario` y marca `sincronizado = false`.
  Future<UsuarioDB> crear({
    required String nombreCompleto,
    required String nombreUsuario,
    required String plainPassword,
    required PermisosVentanas permisos,
  }) async {
    final limpio = nombreUsuario.trim();
    final completo = nombreCompleto.trim().isEmpty ? limpio : nombreCompleto.trim();
    if (limpio.isEmpty) {
      throw ArgumentError('El nombre de usuario no puede estar vacío');
    }
    if (limpio.contains(' ')) {
      throw ArgumentError('El nombre de usuario no puede contener espacios');
    }

    final hash = BCrypt.hashpw(plainPassword.trim(), BCrypt.gensalt());
    final now = DateTime.now().toIso8601String();
    final terminalId = _db.terminalId;

    final result = await _db.query(
      '''INSERT INTO tbl_usuarios
         (nombre_completo, nombre_usuario, hash_password, permisos_ventanas, estatus,
          fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
         VALUES
         (@completo, @nombre, @hash, @permisos::jsonb, 'Activo',
          @now, @now, FALSE, @terminal)
         RETURNING *''',
      params: {
        'completo': completo,
        'nombre': limpio,
        'hash': hash,
        'permisos': permisos.toJsonString(),
        'now': now,
        'terminal': terminalId,
      },
    );

    dev.log('[UsuariosRepository] ✅ Usuario creado localmente: $limpio');
    return UsuarioDB.fromMap(result.first.toColumnMap());
  }

  /// Actualiza los datos y permisos de un usuario existente en PostgreSQL local:
  /// - Si se envía [nuevaPlainPassword], la re-encripta con [bcrypt].
  /// - Actualiza los permisos JSONB.
  /// - Marca `sincronizado = false` para que el SyncService lo suba a Supabase.
  Future<UsuarioDB> actualizar({
    required int idUsuario,
    required String nombreCompleto,
    required String nombreUsuario,
    String? nuevaPlainPassword,
    required PermisosVentanas permisos,
    String estatus = 'Activo',
  }) async {
    final limpio = nombreUsuario.trim();
    final completo = nombreCompleto.trim().isEmpty ? limpio : nombreCompleto.trim();
    if (limpio.isEmpty) {
      throw ArgumentError('El nombre de usuario no puede estar vacío');
    }
    if (limpio.contains(' ')) {
      throw ArgumentError('El nombre de usuario no puede contener espacios');
    }

    final now = DateTime.now().toIso8601String();
    final terminalId = _db.terminalId;

    if (nuevaPlainPassword != null && nuevaPlainPassword.trim().isNotEmpty) {
      final nuevoHash = BCrypt.hashpw(nuevaPlainPassword.trim(), BCrypt.gensalt());
      final result = await _db.query(
        '''UPDATE tbl_usuarios SET
           nombre_completo = @completo,
           nombre_usuario = @nombre,
           hash_password = @hash,
           permisos_ventanas = @permisos::jsonb,
           estatus = @estatus,
           fecha_actualizacion = @now,
           sincronizado = FALSE,
           terminal_origen = @terminal
           WHERE id_usuario = @id
           RETURNING *''',
        params: {
          'id': idUsuario,
          'completo': completo,
          'nombre': limpio,
          'hash': nuevoHash,
          'permisos': permisos.toJsonString(),
          'estatus': estatus,
          'now': now,
          'terminal': terminalId,
        },
      );
      dev.log('[UsuariosRepository] ✅ Usuario actualizado con nueva contraseña: $limpio');
      return UsuarioDB.fromMap(result.first.toColumnMap());
    } else {
      final result = await _db.query(
        '''UPDATE tbl_usuarios SET
           nombre_completo = @completo,
           nombre_usuario = @nombre,
           permisos_ventanas = @permisos::jsonb,
           estatus = @estatus,
           fecha_actualizacion = @now,
           sincronizado = FALSE,
           terminal_origen = @terminal
           WHERE id_usuario = @id
           RETURNING *''',
        params: {
          'id': idUsuario,
          'completo': completo,
          'nombre': limpio,
          'permisos': permisos.toJsonString(),
          'estatus': estatus,
          'now': now,
          'terminal': terminalId,
        },
      );
      dev.log('[UsuariosRepository] ✅ Usuario actualizado: $limpio');
      return UsuarioDB.fromMap(result.first.toColumnMap());
    }
  }

  /// Eliminación lógica de un usuario (cambio de estatus a 'Inactivo')
  Future<void> eliminar(int idUsuario) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_usuarios SET
         estatus = 'Inactivo',
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_usuario = @id''',
      params: {
        'id': idUsuario,
        'now': now,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[UsuariosRepository] ✅ Usuario desactivado (lógico): $idUsuario');
  }
}

