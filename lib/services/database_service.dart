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

  Pool? _localPool;
  SupabaseClient? _supabaseClient;
  late final String terminalId;

  bool _initialized = false;

  /// Bandera global que indica si la app opera exclusivamente contra Supabase
  /// sin requerir base de datos PostgreSQL local instalada o activa.
  bool isCloudOnlyMode = true;

  DatabaseService._();

  /// Singleton global.
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Indica si ya se completó la inicialización.
  bool get isInitialized => _initialized;

  /// Pool de conexiones a PostgreSQL local (API v3).
  Pool get localPool {
    if (_localPool == null) {
      throw StateError('PostgreSQL local no está disponible. Operando en Modo Solo Nube.');
    }
    return _localPool!;
  }

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

  /// Inicializa conexiones.
  /// Si PostgreSQL local no responde en 1.5 segundos o falla, activa automáticamente
  /// [isCloudOnlyMode = true] y continúa sin bloquear el arranque hacia el Login.
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

    // 2. Inicializar Supabase de forma prioritaria
    if (supabaseUrl.isNotEmpty && !supabaseUrl.contains('tu-proyecto')) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
        _supabaseClient = Supabase.instance.client;
        dev.log('[DatabaseService] ✅ Supabase inicializado correctamente ($supabaseUrl)');
      } catch (e) {
        dev.log('[DatabaseService] ⚠️ Supabase no disponible en arranque: $e');
      }
    } else {
      dev.log('[DatabaseService] ℹ️ Supabase no configurado en .env');
    }

    // 3. Probar conexión a PostgreSQL local con timeout estricto de 1.5 segundos
    try {
      final pool = Pool.withEndpoints(
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

      await pool.execute(Sql.named('SELECT 1')).timeout(const Duration(milliseconds: 1500));
      _localPool = pool;
      isCloudOnlyMode = false;
      dev.log('[DatabaseService] ✅ PostgreSQL local conectado ($host:$port/$dbName)');
    } catch (e) {
      _localPool = null;
      isCloudOnlyMode = true;
      dev.log('[DatabaseService] ☁️ PostgreSQL local no disponible tras timeout de 1.5s: $e. Activando Modo Solo Nube.');
    }

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Helpers de ejecución local
  // ---------------------------------------------------------------------------

  /// Ejecuta una consulta SQL con parámetros nombrados en PostgreSQL local.
  /// Retorna una [Result] iterable de filas.
  Future<Result> query(String sql, {Map<String, dynamic>? params}) async {
    if (_localPool == null) {
      throw StateError('PostgreSQL local no está conectado. Operando en Modo Solo Nube.');
    }
    return _localPool!.execute(
      Sql.named(sql),
      parameters: params ?? {},
    );
  }

  /// Ejecuta una transacción ACID en PostgreSQL local.
  Future<T> transaction<T>(
    Future<T> Function(TxSession session) action,
  ) async {
    if (_localPool == null) {
      throw StateError('PostgreSQL local no está conectado. Operando en Modo Solo Nube.');
    }
    return _localPool!.runTx(action);
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
    await _localPool?.close();
    dev.log('[DatabaseService] Pool local cerrado.');
  }
}

