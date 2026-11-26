import 'dart:developer' as dev;
import '../models/cliente_db.dart';
import '../services/database_service.dart';

/// Repositorio local-first para la gestión de clientes ([tbl_clientes])
/// según Diccionario de Datos - Abarrotes 3M.
class ClientesRepository {
  final DatabaseService _db;

  ClientesRepository(this._db);

  static ClientesRepository? _instance;
  static ClientesRepository get instance {
    _instance ??= ClientesRepository(DatabaseService.instance);
    return _instance!;
  }

  /// Obtiene todos los clientes activos ordenados por nombre.
  Future<List<ClienteDB>> obtenerTodos() async {
    final result = await _db.query(
      "SELECT * FROM tbl_clientes WHERE estatus::text = 'Activo' ORDER BY nombre ASC",
    );
    return result.map((r) => ClienteDB.fromMap(r.toColumnMap())).toList();
  }

  /// Busca clientes activos por nombre o teléfono.
  Future<List<ClienteDB>> buscar(String texto) async {
    final q = '%${texto.trim().toLowerCase()}%';
    final result = await _db.query(
      '''SELECT * FROM tbl_clientes
         WHERE estatus::text = 'Activo'
           AND (LOWER(nombre) LIKE @q OR LOWER(COALESCE(telefono, '')) LIKE @q)
         ORDER BY nombre ASC
         LIMIT 50''',
      params: {'q': q},
    );
    return result.map((r) => ClienteDB.fromMap(r.toColumnMap())).toList();
  }

  /// Crea un nuevo cliente en PostgreSQL local.
  Future<ClienteDB> crear({
    required String nombre,
    String? telefono,
    required bool tieneLimiteCredito,
    required double limiteCredito,
  }) async {
    final now = DateTime.now().toIso8601String();
    final limite = tieneLimiteCredito ? limiteCredito : 0.0;
    final res = await _db.query(
      '''INSERT INTO tbl_clientes
         (nombre, telefono, tiene_limite_credito, limite_credito, saldo_actual,
          estatus, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
         VALUES
         (@nombre, @telefono, @tieneLimite, @limite, 0.00,
          'Activo', @now, @now, FALSE, @terminal)
         RETURNING *''',
      params: {
        'nombre': nombre.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
        'tieneLimite': tieneLimiteCredito,
        'limite': limite,
        'now': now,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[ClientesRepository] ✅ Cliente creado: $nombre');
    return ClienteDB.fromMap(res.first.toColumnMap());
  }

  /// Actualiza un cliente existente en PostgreSQL local.
  Future<ClienteDB> actualizar({
    required int idCliente,
    required String nombre,
    String? telefono,
    required bool tieneLimiteCredito,
    required double limiteCredito,
  }) async {
    final now = DateTime.now().toIso8601String();
    final limite = tieneLimiteCredito ? limiteCredito : 0.0;
    final res = await _db.query(
      '''UPDATE tbl_clientes SET
         nombre = @nombre,
         telefono = @telefono,
         tiene_limite_credito = @tieneLimite,
         limite_credito = @limite,
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_cliente = @id
         RETURNING *''',
      params: {
        'id': idCliente,
        'nombre': nombre.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
        'tieneLimite': tieneLimiteCredito,
        'limite': limite,
        'now': now,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[ClientesRepository] ✅ Cliente actualizado: $nombre');
    return ClienteDB.fromMap(res.first.toColumnMap());
  }

  /// Eliminación lógica de un cliente.
  Future<void> eliminar(int idCliente) async {
    final now = DateTime.now().toIso8601String();
    await _db.query(
      '''UPDATE tbl_clientes SET
         estatus = 'Inactivo',
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_cliente = @id''',
      params: {
        'id': idCliente,
        'now': now,
        'terminal': _db.terminalId,
      },
    );
  }
}
