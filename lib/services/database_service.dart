import 'dart:developer' as dev;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado de conexión a bases de datos.
///
/// Gestiona:
/// - Pool de conexiones a PostgreSQL local (paquete `postgres` v3).
/// - Cliente de Supabase para la nube.
/// - Acceso al `terminalId` configurado en `.env`.
class DatabaseService {
  static DatabaseService? _instance;

  late final Pool _localPool;
  SupabaseClient? _supabaseClient;
  late final String terminalId;

  bool _initialized = false;

  DatabaseService._();

  /// Singleton global.
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Indica si ya se completó la inicialización.
  bool get isInitialized => _initialized;

  /// Pool de conexiones a PostgreSQL local (API v3).
  Pool get localPool => _localPool;

  /// Indica si Supabase fue configurado con credenciales válidas.
  bool get isSupabaseConfigured => _supabaseClient != null;

  /// Cliente de Supabase.
  SupabaseClient get supabase {
    if (_supabaseClient == null) {
      throw StateError('Supabase no ha sido inicializado. Verifica las credenciales en .env');
    }
    return _supabaseClient!;
  }

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------

  /// Inicializa ambas conexiones. Debe llamarse una sola vez en [main].
  Future<void> init() async {
    if (_initialized) return;

    // 1. Leer variables de entorno
    final host = dotenv.env['LOCAL_DB_HOST'] ?? 'localhost';
    final port = int.tryParse(dotenv.env['LOCAL_DB_PORT'] ?? '5432') ?? 5432;
    final dbName = dotenv.env['LOCAL_DB_NAME'] ?? 'abarrotes3m';
    final user = dotenv.env['LOCAL_DB_USER'] ?? 'postgres';
    final password = dotenv.env['LOCAL_DB_PASSWORD'] ?? '';

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    terminalId = dotenv.env['TERMINAL_ID'] ?? 'CAJA_01';

    // 2. Crear Pool local (postgres v3 API)
    _localPool = Pool.withEndpoints(
      [
        Endpoint(
          host: host,
          port: port,
          database: dbName,
          username: user,
          password: password,
        ),
      ],
      settings: PoolSettings(
        maxConnectionCount: 5,
        sslMode: SslMode.disable,
      ),
    );

    // 3. Verificar conexión local con un ping
    try {
      await _localPool.execute(Sql.named('SELECT 1'));
      dev.log('[DatabaseService] ✅ PostgreSQL local conectado ($host:$port/$dbName)');
    } catch (e) {
      dev.log('[DatabaseService] ⚠️ PostgreSQL local no disponible: $e');
      // No lanzamos excepción: la app puede seguir con datos en caché.
    }

    // 4. Inicializar Supabase de forma segura (tolerante a fallos si está offline o sin configurar)
    if (supabaseUrl.isNotEmpty && !supabaseUrl.contains('tu-proyecto')) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
        _supabaseClient = Supabase.instance.client;
        dev.log('[DatabaseService] ✅ Supabase inicializado ($supabaseUrl)');
      } catch (e) {
        dev.log('[DatabaseService] ⚠️ Supabase no disponible en el arranque: $e');
      }
    } else {
      dev.log('[DatabaseService] ℹ️ Supabase no configurado en .env (operando en modo 100% offline)');
    }

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Helpers de ejecución local
  // ---------------------------------------------------------------------------

  /// Ejecuta una consulta SQL con parámetros nombrados en PostgreSQL local.
  /// Retorna una [Result] iterable de filas.
  Future<Result> query(String sql, {Map<String, dynamic>? params}) async {
    return _localPool.execute(
      Sql.named(sql),
      parameters: params ?? {},
    );
  }

  /// Ejecuta una transacción ACID en PostgreSQL local.
  Future<T> transaction<T>(
    Future<T> Function(TxSession session) action,
  ) async {
    return _localPool.runTx(action);
  }

  // ---------------------------------------------------------------------------
  // Helpers de Supabase
  // ---------------------------------------------------------------------------

  /// Verifica si Supabase es alcanzable haciendo una consulta ligera.
  /// Retorna `true` si hay conexión real a la nube.
  Future<bool> isSupabaseReachable() async {
    if (_supabaseClient == null) return false;
    try {
      // Consulta ultra-ligera: solo verifica que Supabase responda.
      await _supabaseClient!
          .from('tbl_departamentos')
          .select('id_departamento')
          .limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Limpieza
  // ---------------------------------------------------------------------------

  /// Cierra las conexiones. Llamar al cerrar la app si es necesario.
  Future<void> dispose() async {
    await _localPool.close();
    dev.log('[DatabaseService] Pool local cerrado.');
  }
}

