import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';

/// Motor de sincronización bidireccional entre PostgreSQL local y Supabase.
///
/// Funciona como un singleton con un [Timer.periodic] cada 30 segundos.
/// También expone [syncNow] para disparar manualmente.
///
/// ## Flujo de sincronización:
/// 1. **Detección de conexión**: Ping ligero a Supabase.
/// 2. **PUSH (Local → Supabase)**: Sube registros con `sincronizado = false`.
/// 3. **PULL (Supabase → Local)**: Baja cambios desde `last_pull_timestamp`.
class SyncService {
  static SyncService? _instance;
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  SyncService._();

  late final DatabaseService _db;
  Timer? _timer;
  bool _syncing = false;

  /// Indica si hay una sincronización en progreso.
  bool get isSyncing => _syncing;

  /// Última vez que se completó una sincronización exitosa.
  DateTime? lastSyncTime;

  // ---------------------------------------------------------------------------
  // Inicialización y control del Timer
  // ---------------------------------------------------------------------------

  /// Inicia el servicio de sincronización.
  /// Debe llamarse una sola vez después de [DatabaseService.init].
  void init(DatabaseService db) {
    _db = db;

    // Timer periódico cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncNow();
    });

    dev.log('[SyncService] ✅ Iniciado con timer de 30 segundos.');

    // Ejecutar una primera sincronización inmediata
    syncNow();
  }

  /// Detiene el timer de sincronización.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    dev.log('[SyncService] Timer detenido.');
  }

  // ---------------------------------------------------------------------------
  // Sincronización manual
  // ---------------------------------------------------------------------------

  /// Ejecuta un ciclo completo de sincronización (PUSH + PULL).
  /// Si ya hay una sincronización en curso, no hace nada.
  Future<void> syncNow() async {
    if (_syncing) {
      dev.log('[SyncService] ⏭️ Sincronización ya en curso, saltando...');
      return;
    }

    _syncing = true;

    try {
      // 1. Verificar conectividad real
      final reachable = await _db.isSupabaseReachable();
      if (!reachable) {
        dev.log('[SyncService] 📡 Sin conexión a Supabase, abortando silenciosamente.');
        return;
      }

      dev.log('[SyncService] 🔄 Iniciando sincronización...');

      // 2. PUSH: Local → Supabase
      await _push();

      // 3. PULL: Supabase → Local
      await _pull();

      lastSyncTime = DateTime.now();
      dev.log('[SyncService] ✅ Sincronización completada a las $lastSyncTime');
    } catch (e) {
      dev.log('[SyncService] ❌ Error en sincronización: $e');
    } finally {
      _syncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // PUSH: Local → Supabase
  // ---------------------------------------------------------------------------

  /// Sube registros locales con `sincronizado = false` a Supabase,
  /// respetando el orden de dependencias de FK.
  Future<void> _push() async {
    dev.log('[SyncService] ⬆️ PUSH iniciado (14 tablas)...');

    // Nivel 1: Tablas catálogo/maestras sin FK externas
    await _pushTable(table: 'tbl_usuarios', idColumn: 'id_usuario', uuidColumn: 'uuid_sync');
    await _pushTable(table: 'tbl_departamentos', idColumn: 'id_departamento', uuidColumn: 'uuid_sync');
    await _pushTable(table: 'tbl_clientes', idColumn: 'id_cliente', uuidColumn: 'uuid_sync');
    await _pushTable(table: 'tbl_formas_pago', idColumn: 'id_forma_pago', uuidColumn: 'uuid_sync');
    await _pushTable(table: 'tbl_configuracion', idColumn: 'id_configuracion', uuidColumn: 'uuid_sync');

    // Nivel 2: Productos y Cortes de Caja
    await _pushTableWithFk(
      table: 'tbl_productos',
      idColumn: 'id_producto',
      fkMappings: {
        'id_departamento': FkMapping(parentTable: 'tbl_departamentos', parentIdCol: 'id_departamento'),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_cortes_caja',
      idColumn: 'id_corte',
      fkMappings: {
        'id_usuario': FkMapping(parentTable: 'tbl_usuarios', parentIdCol: 'id_usuario'),
      },
    );

    // Nivel 3: Promociones, Movimientos de Caja y Ventas
    await _pushTableWithFk(
      table: 'tbl_promociones',
      idColumn: 'id_promocion',
      fkMappings: {
        'id_producto': FkMapping(parentTable: 'tbl_productos', parentIdCol: 'id_producto'),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_movimientos_caja',
      idColumn: 'id_movimiento_caja',
      fkMappings: {
        'id_corte': FkMapping(parentTable: 'tbl_cortes_caja', parentIdCol: 'id_corte'),
        'id_usuario': FkMapping(parentTable: 'tbl_usuarios', parentIdCol: 'id_usuario'),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_ventas',
      idColumn: 'id_venta',
      fkMappings: {
        'id_usuario': FkMapping(parentTable: 'tbl_usuarios', parentIdCol: 'id_usuario'),
        'id_cliente': FkMapping(parentTable: 'tbl_clientes', parentIdCol: 'id_cliente', nullable: true),
        'id_corte': FkMapping(parentTable: 'tbl_cortes_caja', parentIdCol: 'id_corte', nullable: true),
      },
    );

    // Nivel 4: Detalle de Ventas, Pagos de Venta, Abonos y Kardex
    await _pushTableWithFk(
      table: 'tbl_detalle_ventas',
      idColumn: 'id_detalle_venta',
      fkMappings: {
        'id_venta': FkMapping(parentTable: 'tbl_ventas', parentIdCol: 'id_venta'),
        'id_producto': FkMapping(parentTable: 'tbl_productos', parentIdCol: 'id_producto'),
        'id_promocion': FkMapping(parentTable: 'tbl_promociones', parentIdCol: 'id_promocion', nullable: true),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_pagos_venta',
      idColumn: 'id_pago_venta',
      fkMappings: {
        'id_venta': FkMapping(parentTable: 'tbl_ventas', parentIdCol: 'id_venta'),
        'id_forma_pago': FkMapping(parentTable: 'tbl_formas_pago', parentIdCol: 'id_forma_pago'),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_abonos_clientes',
      idColumn: 'id_abono',
      fkMappings: {
        'id_cliente': FkMapping(parentTable: 'tbl_clientes', parentIdCol: 'id_cliente'),
        'id_usuario': FkMapping(parentTable: 'tbl_usuarios', parentIdCol: 'id_usuario'),
        'id_corte': FkMapping(parentTable: 'tbl_cortes_caja', parentIdCol: 'id_corte', nullable: true),
        'id_forma_pago': FkMapping(parentTable: 'tbl_formas_pago', parentIdCol: 'id_forma_pago'),
      },
    );
    await _pushTableWithFk(
      table: 'tbl_movimientos_inventario',
      idColumn: 'id_movimiento',
      fkMappings: {
        'id_producto': FkMapping(parentTable: 'tbl_productos', parentIdCol: 'id_producto'),
        'id_usuario': FkMapping(parentTable: 'tbl_usuarios', parentIdCol: 'id_usuario'),
      },
    );

    dev.log('[SyncService] ⬆️ PUSH completado.');
  }

  /// Sube registros de una tabla sin FK externas (roles, categorías, clientes).
  Future<void> _pushTable({
    required String table,
    required String idColumn,
    required String uuidColumn,
  }) async {
    try {
      // Consultar registros no sincronizados en local
      final result = await _db.query(
        'SELECT * FROM $table WHERE sincronizado = FALSE',
      );

      if (result.isEmpty) return;

      dev.log('[SyncService] ⬆️ $table: ${result.length} registros pendientes');

      for (final row in result) {
        final map = Map<String, dynamic>.from(row.toColumnMap());
        final uuid = map[uuidColumn] as String;

        // Remover el ID local para evitar colisiones de BIGSERIAL
        map.remove(idColumn);

        // Sanitizar y preparar los datos para Supabase
        final datosParaSupabase = _prepararParaSupabase(map);

        // Upsert por uuid_sync en Supabase
        await _db.supabase.from(table).upsert(
          datosParaSupabase,
          onConflict: uuidColumn,
        );

        // Marcar como sincronizado en local
        await _db.query(
          'UPDATE $table SET sincronizado = TRUE WHERE $uuidColumn = @uuid',
          params: {'uuid': uuid},
        );
      }
    } catch (e) {
      dev.log('[SyncService] ❌ Error en PUSH $table: $e');
    }
  }

  /// Sube registros de una tabla que tiene FK hacia otras tablas.
  /// Resuelve cada FK local buscando el uuid_sync del padre en Supabase.
  Future<void> _pushTableWithFk({
    required String table,
    required String idColumn,
    required Map<String, FkMapping> fkMappings,
  }) async {
    try {
      final result = await _db.query(
        'SELECT * FROM $table WHERE sincronizado = FALSE',
      );

      if (result.isEmpty) return;

      dev.log('[SyncService] ⬆️ $table: ${result.length} registros pendientes (con FK)');

      for (final row in result) {
        final map = Map<String, dynamic>.from(row.toColumnMap());
        final uuid = map['uuid_sync'] as String;

        // Remover el ID local
        map.remove(idColumn);

        // Resolver cada FK: buscar el uuid_sync del padre local,
        // luego buscar el ID remoto en Supabase por ese uuid.
        bool fkResuelta = true;
        for (final entry in fkMappings.entries) {
          final fkColumnName = entry.key;      // e.g. 'id_usuario'
          final fkInfo = entry.value;
          final localFkValue = map[fkColumnName];

          if (localFkValue == null) {
            if (fkInfo.nullable) continue;
            fkResuelta = false;
            break;
          }

          // Buscar uuid_sync del padre en la BD local
          final parentResult = await _db.query(
            'SELECT uuid_sync FROM ${fkInfo.parentTable} WHERE ${fkInfo.parentIdCol} = @id LIMIT 1',
            params: {'id': localFkValue},
          );

          if (parentResult.isEmpty) {
            dev.log('[SyncService] ⚠️ FK padre no encontrado: ${fkInfo.parentTable}.${fkInfo.parentIdCol} = $localFkValue');
            fkResuelta = false;
            break;
          }

          final parentUuid = parentResult.first.toColumnMap()['uuid_sync'] as String;

          // Buscar el ID remoto en Supabase por uuid_sync
          final remoteParent = await _db.supabase
              .from(fkInfo.parentTable)
              .select(fkInfo.parentIdCol)
              .eq('uuid_sync', parentUuid)
              .limit(1)
              .maybeSingle();

          if (remoteParent == null) {
            dev.log('[SyncService] ⚠️ FK padre no encontrado en Supabase: ${fkInfo.parentTable}.uuid_sync = $parentUuid');
            fkResuelta = false;
            break;
          }

          // Reemplazar el ID local con el ID remoto
          map[fkColumnName] = remoteParent[fkInfo.parentIdCol];
        }

        if (!fkResuelta) {
          dev.log('[SyncService] ⏭️ Saltando registro de $table (FK no resuelta): $uuid');
          continue;
        }

        // Sanitizar y preparar los datos para Supabase
        final datosParaSupabase = _prepararParaSupabase(map);

        // Upsert en Supabase
        await _db.supabase.from(table).upsert(
          datosParaSupabase,
          onConflict: 'uuid_sync',
        );

        // Marcar como sincronizado en local
        await _db.query(
          'UPDATE $table SET sincronizado = TRUE WHERE uuid_sync = @uuid',
          params: {'uuid': uuid},
        );
      }
    } catch (e) {
      dev.log('[SyncService] ❌ Error en PUSH $table: $e');
    }
  }

  /// Sanitiza y prepara una fila de PostgreSQL local para enviarse a Supabase:
  /// 1. Si value is [UndecodedBytes]: convierte con [asString] (decodifica ENUMs como `estatus`).
  /// 2. Si value is [DateTime]: convierte con [toIso8601String] (serializable en JSON).
  /// 3. Garantiza que la columna [sincronizado] se envíe como `true` a la nube.
  /// 4. Si contiene [permisos_ventanas] en formato String, lo decodifica a Map para jsonb.
  Map<String, dynamic> _prepararParaSupabase(Map<String, dynamic> row) {
    final sanitizado = <String, dynamic>{};

    for (final entry in row.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'sincronizado') {
        sanitizado[key] = true;
      } else if (value is UndecodedBytes) {
        sanitizado[key] = value.asString;
      } else if (value is DateTime) {
        sanitizado[key] = value.toIso8601String();
      } else if (key == 'permisos_ventanas' && value is String) {
        try {
          sanitizado[key] = jsonDecode(value);
        } catch (_) {
          sanitizado[key] = value;
        }
      } else {
        sanitizado[key] = value;
      }
    }

    sanitizado['sincronizado'] = true;
    return sanitizado;
  }

  // ---------------------------------------------------------------------------
  // PULL: Supabase → Local
  // ---------------------------------------------------------------------------

  /// Descarga registros modificados en Supabase desde el último pull.
  /// Aplica INSERT ... ON CONFLICT (uuid_sync) DO UPDATE en local.
  Future<void> _pull() async {
    dev.log('[SyncService] ⬇️ PULL iniciado...');

    final prefs = await SharedPreferences.getInstance();
    final lastPullStr = prefs.getString('last_pull_timestamp');
    final lastPull = lastPullStr ?? '1970-01-01T00:00:00Z';

    // Tablas a bajar (orden de dependencias - 14 tablas)
    final tablesToPull = [
      _PullConfig('tbl_usuarios', 'id_usuario', [
        'nombre_completo', 'nombre_usuario', 'hash_password', 'permisos_ventanas',
        'ultimo_acceso', 'estatus', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_departamentos', 'id_departamento', [
        'nombre_departamento', 'estatus', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_clientes', 'id_cliente', [
        'nombre', 'telefono', 'tiene_limite_credito', 'limite_credito', 'saldo_actual',
        'estatus', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_formas_pago', 'id_forma_pago', [
        'nombre_forma_pago', 'estatus', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_configuracion', 'id_configuracion', [
        'nombre_negocio', 'direccion_negocio', 'telefono_negocio', 'mensaje_ticket',
        'imprimir_ticket', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_productos', 'id_producto', [
        'codigo_barras', 'descripcion', 'id_departamento', 'tipo_venta',
        'precio_costo', 'precio_venta', 'precio_mayoreo', 'cantidad_mayoreo',
        'usa_inventario', 'existencia', 'inventario_minimo', 'inventario_maximo',
        'aplica_iva', 'tasa_iva', 'estatus', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_cortes_caja', 'id_corte', [
        'id_usuario', 'fecha_apertura', 'fecha_cierre', 'fondo_inicial',
        'total_ventas', 'total_entradas', 'total_salidas', 'efectivo_esperado',
        'efectivo_contado', 'diferencia', 'estatus_corte',
        'fecha_registro', 'fecha_actualizacion', 'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_promociones', 'id_promocion', [
        'nombre_promocion', 'id_producto', 'tipo_promocion', 'cantidad_minima',
        'cantidad_paga', 'valor_descuento', 'fecha_inicio', 'fecha_fin',
        'estatus', 'fecha_registro', 'fecha_actualizacion', 'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_movimientos_caja', 'id_movimiento_caja', [
        'id_corte', 'id_usuario', 'tipo_movimiento', 'monto', 'concepto',
        'fecha_registro', 'sincronizado', 'terminal_origen',
      ], timestampColumn: 'fecha_registro'),
      _PullConfig('tbl_ventas', 'id_venta', [
        'folio_ticket', 'id_usuario', 'id_cliente', 'id_corte', 'fecha_venta',
        'subtotal', 'descuento', 'iva', 'total', 'es_credito', 'estatus_venta',
        'motivo_cancelacion', 'fecha_registro', 'fecha_actualizacion',
        'sincronizado', 'terminal_origen',
      ]),
      _PullConfig('tbl_detalle_ventas', 'id_detalle_venta', [
        'id_venta', 'id_producto', 'id_promocion', 'descripcion_producto',
        'cantidad', 'precio_unitario', 'costo_unitario', 'descuento', 'importe',
        'sincronizado', 'terminal_origen',
      ], timestampColumn: null),
      _PullConfig('tbl_pagos_venta', 'id_pago_venta', [
        'id_venta', 'id_forma_pago', 'monto', 'cambio',
        'fecha_registro', 'sincronizado', 'terminal_origen',
      ], timestampColumn: 'fecha_registro'),
      _PullConfig('tbl_abonos_clientes', 'id_abono', [
        'id_cliente', 'id_usuario', 'id_corte', 'id_forma_pago', 'monto',
        'saldo_posterior', 'fecha_registro', 'sincronizado', 'terminal_origen',
      ], timestampColumn: 'fecha_registro'),
      _PullConfig('tbl_movimientos_inventario', 'id_movimiento', [
        'id_producto', 'id_usuario', 'tipo_movimiento', 'cantidad',
        'existencia_anterior', 'existencia_nueva', 'id_referencia', 'motivo',
        'fecha_registro', 'sincronizado', 'terminal_origen',
      ], timestampColumn: 'fecha_registro'),
    ];

    for (final config in tablesToPull) {
      await _pullTable(config, lastPull);
    }

    // Actualizar timestamp del último pull
    await prefs.setString(
      'last_pull_timestamp',
      DateTime.now().toUtc().toIso8601String(),
    );

    dev.log('[SyncService] ⬇️ PULL completado.');
  }

  /// Descarga y aplica registros de una tabla específica.
  Future<void> _pullTable(_PullConfig config, String lastPull) async {
    try {
      // Consultar registros modificados después del último pull
      final List<dynamic> remoteRows;
      if (config.timestampColumn != null) {
        remoteRows = await _db.supabase
            .from(config.table)
            .select()
            .gt(config.timestampColumn!, lastPull)
            .order(config.timestampColumn!);
      } else {
        remoteRows = await _db.supabase
            .from(config.table)
            .select()
            .order(config.idColumn);
      }

      if (remoteRows.isEmpty) return;

      dev.log('[SyncService] ⬇️ ${config.table}: ${remoteRows.length} registros nuevos/actualizados');

      for (final remoteRow in remoteRows) {
        final uuid = remoteRow['uuid_sync'] as String;
        final map = Map<String, dynamic>.from(remoteRow);

        // Construir las columnas de SET para el ON CONFLICT DO UPDATE
        final setClauses = config.updateColumns
            .map((col) => '$col = EXCLUDED.$col')
            .toList();
        // Forzar sincronizado = TRUE para evitar ciclos infinitos
        setClauses.add('sincronizado = TRUE');

        // Construir los nombres de columnas y placeholders
        // No incluimos el id local del remoto (podría no coincidir)
        map.remove(config.idColumn);
        map['sincronizado'] = true; // Marcar como sincronizado al bajar

        final columns = map.keys.toList();
        final placeholders = columns.map((c) => '@$c').toList();

        final sql = '''
          INSERT INTO ${config.table} (${columns.join(', ')})
          VALUES (${placeholders.join(', ')})
          ON CONFLICT (uuid_sync) DO UPDATE SET
          ${setClauses.join(', ')}
        ''';

        // Convertir valores JSONB (como permisos_ventanas) a String para postgres
        final params = <String, dynamic>{};
        for (final col in columns) {
          var value = map[col];
          if (value is Map || value is List) {
            // postgres v3 acepta estos tipos directamente como JSONB
            params[col] = value;
          } else {
            params[col] = value;
          }
        }

        await _db.query(sql, params: params);
      }
    } catch (e) {
      dev.log('[SyncService] ❌ Error en PULL ${config.table}: $e');
    }
  }
}

// =============================================================================
// Modelos auxiliares internos
// =============================================================================

/// Mapeo de una FK hacia su tabla padre.
class FkMapping {
  final String parentTable;
  final String parentIdCol;
  final bool nullable;

  const FkMapping({
    required this.parentTable,
    required this.parentIdCol,
    this.nullable = false,
  });
}

/// Configuración para hacer PULL de una tabla.
class _PullConfig {
  final String table;
  final String idColumn;
  final List<String> updateColumns;
  final String? timestampColumn;

  const _PullConfig(
    this.table,
    this.idColumn,
    this.updateColumns, {
    this.timestampColumn = 'fecha_actualizacion',
  });
}

