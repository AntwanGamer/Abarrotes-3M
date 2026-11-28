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
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_clientes')
          .select()
          .eq('estatus', 'Activo')
          .order('nombre', ascending: true);
      return (res as List).map((r) => ClienteDB.fromMap(r as Map<String, dynamic>)).toList();
    }

    final result = await _db.query(
      "SELECT * FROM tbl_clientes WHERE estatus::text = 'Activo' ORDER BY nombre ASC",
    );
    return result.map((r) => ClienteDB.fromMap(r.toColumnMap())).toList();
  }

  /// Busca clientes activos por nombre o teléfono.
  Future<List<ClienteDB>> buscar(String texto) async {
    final clean = texto.trim();
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_clientes')
          .select()
          .eq('estatus', 'Activo')
          .or('nombre.ilike.%$clean%,telefono.ilike.%$clean%')
          .order('nombre', ascending: true)
          .limit(50);
      return (res as List).map((r) => ClienteDB.fromMap(r as Map<String, dynamic>)).toList();
    }

    final q = '%${clean.toLowerCase()}%';
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

  /// Crea un nuevo cliente.
  Future<ClienteDB> crear({
    required String nombre,
    String? telefono,
    required bool tieneLimiteCredito,
    required double limiteCredito,
  }) async {
    final now = DateTime.now().toIso8601String();
    final limite = tieneLimiteCredito ? limiteCredito : 0.0;

    if (_db.isCloudOnlyMode) {
      final insertData = {
        'nombre': nombre.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
        'tiene_limite_credito': tieneLimiteCredito,
        'limite_credito': limite,
        'saldo_actual': 0.00,
        'estatus': 'Activo',
        'fecha_registro': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': _db.terminalId,
      };
      final res = await _db.supabase.from('tbl_clientes').insert(insertData).select().single();
      dev.log('[ClientesRepository] ✅ Cliente creado en Supabase: $nombre');
      return ClienteDB.fromMap(res);
    }

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

  /// Actualiza un cliente existente.
  Future<ClienteDB> actualizar({
    required int idCliente,
    required String nombre,
    String? telefono,
    required bool tieneLimiteCredito,
    required double limiteCredito,
  }) async {
    final now = DateTime.now().toIso8601String();
    final limite = tieneLimiteCredito ? limiteCredito : 0.0;

    if (_db.isCloudOnlyMode) {
      final updateData = {
        'nombre': nombre.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
        'tiene_limite_credito': tieneLimiteCredito,
        'limite_credito': limite,
        'fecha_actualizacion': now,
      };
      final res = await _db.supabase
          .from('tbl_clientes')
          .update(updateData)
          .eq('id_cliente', idCliente)
          .select()
          .single();
      dev.log('[ClientesRepository] ✅ Cliente actualizado en Supabase: $nombre');
      return ClienteDB.fromMap(res);
    }

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

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_clientes').update({
        'estatus': 'Inactivo',
        'fecha_actualizacion': now,
      }).eq('id_cliente', idCliente);
      return;
    }

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
