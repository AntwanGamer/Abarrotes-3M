import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/helpers.dart';
import 'database_service.dart';

/// Servicio para la creación, descarga, restauración y rotación automática de respaldos
/// de las 14 tablas del sistema (Offline-First en PostgreSQL y Supabase).
class BackupService {
  static BackupService? _instance;
  static BackupService get instance {
    _instance ??= BackupService(DatabaseService.instance);
    return _instance!;
  }

  final DatabaseService _db;
  BackupService(this._db);

  static const String keyAutoBackupActivo = 'backup_auto_activo';
  static const String keyAutoBackupCarpeta = 'backup_auto_carpeta';

  /// Las 14 tablas oficiales en estricto orden de dependencias para respaldos y restauración.
  static const List<String> tablasOrdenadas = [
    // Nivel 1: Catálogos maestros sin dependencias foráneas
    'tbl_usuarios',
    'tbl_departamentos',
    'tbl_clientes',
    'tbl_formas_pago',
    'tbl_configuracion',
    // Nivel 2: Dependen del Nivel 1
    'tbl_productos',
    'tbl_cortes_caja',
    // Nivel 3: Dependen de Niveles 1 y 2
    'tbl_promociones',
    'tbl_movimientos_caja',
    'tbl_ventas',
    // Nivel 4: Transaccionales y Kardex
    'tbl_detalle_ventas',
    'tbl_pagos_venta',
    'tbl_abonos_clientes',
    'tbl_movimientos_inventario',
  ];

  // ---------------------------------------------------------------------------
  // Configuración de Respaldo Automático en SharedPreferences
  // ---------------------------------------------------------------------------

  /// Ruta predeterminada para guardar los respaldos automáticos.
  String get rutaPredeterminadaRespaldos {
    final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.';
    return '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}Abarrotes3M${Platform.pathSeparator}Respaldos';
  }

  Future<bool> isAutoBackupActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAutoBackupActivo) ?? true;
  }

  Future<void> setAutoBackupActivo(bool activo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoBackupActivo, activo);
  }

  Future<String> getCarpetaRespaldos() async {
    final prefs = await SharedPreferences.getInstance();
    final carpeta = prefs.getString(keyAutoBackupCarpeta);
    if (carpeta != null && carpeta.trim().isNotEmpty) {
      return carpeta;
    }
    return rutaPredeterminadaRespaldos;
  }

  Future<void> setCarpetaRespaldos(String ruta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAutoBackupCarpeta, ruta);
  }

  // ---------------------------------------------------------------------------
  // Sanitización de Datos
  // ---------------------------------------------------------------------------

  dynamic sanitizarValor(dynamic val) {
    if (val == null) return null;
    if (val is UndecodedBytes) return val.asString;
    if (val is DateTime) return val.toIso8601String();
    if (val is num) return val;
    if (val is bool) return val;
    if (val is Map) {
      return val.map((k, v) => MapEntry(k.toString(), sanitizarValor(v)));
    }
    if (val is List) {
      return val.map((v) => sanitizarValor(v)).toList();
    }
    return val.toString();
  }

  // ---------------------------------------------------------------------------
  // Generación de Respaldo (Local o Nube)
  // ---------------------------------------------------------------------------

  /// Genera un mapa completo con las 14 tablas serializadas y metadatos del respaldo.
  Future<Map<String, dynamic>> generarRespaldo({required String origen}) async {
    final now = DateTime.now();
    final resumen = <String, int>{};
    final tablasData = <String, List<Map<String, dynamic>>>{};

    for (final tabla in tablasOrdenadas) {
      final List<Map<String, dynamic>> filas = [];

      if (origen == 'Local') {
        final res = await _db.query('SELECT * FROM $tabla');
        for (final r in res) {
          final m = r.toColumnMap();
          final limpia = m.map((k, v) => MapEntry(k, sanitizarValor(v)));
          filas.add(limpia);
        }
      } else {
        // Nube (Supabase)
        final res = await _db.supabase.from(tabla).select();
        for (final r in (res as List)) {
          if (r is Map) {
            final m = Map<String, dynamic>.from(r);
            final limpia = m.map((k, v) => MapEntry(k, sanitizarValor(v)));
            filas.add(limpia);
          }
        }
      }

      resumen[tabla] = filas.length;
      tablasData[tabla] = filas;
    }

    return {
      'version': '1.0',
      'origen': origen,
      'fecha_generacion': now.toIso8601String(),
      'terminal_origen': _db.terminalId,
      'total_tablas': tablasOrdenadas.length,
      'resumen_registros': resumen,
      'tablas': tablasData,
    };
  }

  /// Guarda el contenido del respaldo en un archivo .json en disco.
  Future<File> guardarRespaldoEnArchivo(Map<String, dynamic> datos, String rutaArchivo) async {
    final file = File(rutaArchivo);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    final jsonStr = encoder.convert(datos);
    return file.writeAsString(jsonStr);
  }

  // ---------------------------------------------------------------------------
  // Respaldo Automático al Salir con Rotación (Máx 15 archivos)
  // ---------------------------------------------------------------------------

  /// Ejecuta el respaldo automático si está activo y aplica la rotación de 15 archivos.
  Future<bool> ejecutarRespaldoAutomaticoSiActivo() async {
    try {
      final activo = await isAutoBackupActivo();
      if (!activo) return false;

      final carpeta = await getCarpetaRespaldos();
      final dir = Directory(carpeta);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'respaldo_auto_$stamp.json';
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';

      dev.log('[BackupService] 💾 Generando respaldo automático en: $filePath');
      final datos = await generarRespaldo(origen: 'Local');
      await guardarRespaldoEnArchivo(datos, filePath);

      // Rotación de los últimos 15 archivos
      rotarRespaldos(dir, maxArchivos: 15);
      dev.log('[BackupService] ✅ Respaldo automático completado con éxito.');
      return true;
    } catch (e) {
      dev.log('[BackupService] ⚠️ Error en respaldo automático: $e');
      return false;
    }
  }

  /// Mantiene a lo sumo [maxArchivos] respaldos automáticos en la carpeta, eliminando los más viejos.
  void rotarRespaldos(Directory dir, {int maxArchivos = 15}) {
    try {
      if (!dir.existsSync()) return;
      final archivos = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.json') && f.path.contains('respaldo_auto_'))
          .toList();

      if (archivos.length <= maxArchivos) return;

      // Ordenar por fecha de modificación más reciente primero
      archivos.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // Borrar los que excedan el límite
      for (int i = maxArchivos; i < archivos.length; i++) {
        try {
          archivos[i].deleteSync();
          dev.log('[BackupService] 🗑️ Respaldo antiguo rotado/eliminado: ${archivos[i].path}');
        } catch (_) {}
      }
    } catch (e) {
      dev.log('[BackupService] ⚠️ Error en rotación de respaldos: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Restauración de Base de Datos desde Respaldo
  // ---------------------------------------------------------------------------

  /// Restaura los datos del archivo en el destino indicado ('Local', 'Nube', 'Ambas').
  Future<void> restaurarRespaldo({
    required Map<String, dynamic> backupData,
    required String destino, // 'Local' | 'Nube' | 'Ambas'
  }) async {
    final tablas = backupData['tablas'] as Map<String, dynamic>?;
    if (tablas == null) throw StateError('El archivo no contiene la clave "tablas".');

    final bool enLocal = destino == 'Local' || destino == 'Ambas';
    final bool enNube = destino == 'Nube' || destino == 'Ambas';

    // 1. Restaurar en Local (PostgreSQL)
    if (enLocal) {
      await _restaurarLocal(tablas);
    }

    // 2. Restaurar en Nube (Supabase)
    if (enNube) {
      await _restaurarNube(tablas);
    }
  }

  Future<void> _restaurarLocal(Map<String, dynamic> tablas) async {
    final terminalId = _db.terminalId;

    await _db.transaction((tx) async {
      for (final tabla in tablasOrdenadas) {
        final filasRaw = tablas[tabla] as List?;
        if (filasRaw == null || filasRaw.isEmpty) continue;

        for (final item in filasRaw) {
          if (item is! Map) continue;
          final fila = Map<String, dynamic>.from(item);
          final uuid = fila['uuid_sync'] as String?;
          if (uuid == null || uuid.isEmpty) continue;

          // Verificar si ya existe por uuid_sync
          final existe = await tx.execute(
            Sql.named('SELECT uuid_sync FROM $tabla WHERE uuid_sync = @uuid LIMIT 1'),
            parameters: {'uuid': uuid},
          );

          // Remover la columna ID autoincremental para evitar conflictos
          final mapLimpio = Map<String, dynamic>.from(fila);
          final idCol = _obtenerColumnaId(tabla);
          mapLimpio.remove(idCol);
          mapLimpio['terminal_origen'] = terminalId;

          if (existe.isEmpty) {
            // INSERT
            final cols = mapLimpio.keys.toList();
            final colsStr = cols.join(', ');
            final paramsStr = cols.map((c) => '@$c').join(', ');
            final sql = 'INSERT INTO $tabla ($colsStr) VALUES ($paramsStr)';
            await tx.execute(Sql.named(sql), parameters: mapLimpio);
          } else {
            // UPDATE
            final cols = mapLimpio.keys.where((k) => k != 'uuid_sync').toList();
            final setStr = cols.map((c) => '$c = @$c').join(', ');
            final sql = 'UPDATE $tabla SET $setStr WHERE uuid_sync = @uuid_sync';
            await tx.execute(Sql.named(sql), parameters: mapLimpio);
          }
        }
      }
    });
    dev.log('[BackupService] ✅ Restauración en PostgreSQL local completada.');
  }

  Future<void> _restaurarNube(Map<String, dynamic> tablas) async {
    for (final tabla in tablasOrdenadas) {
      final filasRaw = tablas[tabla] as List?;
      if (filasRaw == null || filasRaw.isEmpty) continue;

      final batch = <Map<String, dynamic>>[];
      for (final item in filasRaw) {
        if (item is! Map) continue;
        final fila = Map<String, dynamic>.from(item);
        final idCol = _obtenerColumnaId(tabla);
        fila.remove(idCol);

        // Si la tabla tiene permisos_ventanas y viene como string, decodificar a Map
        if (fila.containsKey('permisos_ventanas') && fila['permisos_ventanas'] is String) {
          try {
            fila['permisos_ventanas'] = jsonDecode(fila['permisos_ventanas']);
          } catch (_) {}
        }

        batch.add(fila);
      }

      if (batch.isNotEmpty) {
        await _db.supabase.from(tabla).upsert(batch, onConflict: 'uuid_sync');
      }
    }
    dev.log('[BackupService] ✅ Restauración en Supabase completada.');
  }

  String _obtenerColumnaId(String tabla) {
    switch (tabla) {
      case 'tbl_usuarios':
        return 'id_usuario';
      case 'tbl_departamentos':
        return 'id_departamento';
      case 'tbl_clientes':
        return 'id_cliente';
      case 'tbl_formas_pago':
        return 'id_forma_pago';
      case 'tbl_configuracion':
        return 'id_configuracion';
      case 'tbl_productos':
        return 'id_producto';
      case 'tbl_cortes_caja':
        return 'id_corte';
      case 'tbl_promociones':
        return 'id_promocion';
      case 'tbl_movimientos_caja':
        return 'id_movimiento_caja';
      case 'tbl_ventas':
        return 'id_venta';
      case 'tbl_detalle_ventas':
        return 'id_detalle_venta';
      case 'tbl_pagos_venta':
        return 'id_pago_venta';
      case 'tbl_abonos_clientes':
        return 'id_abono';
      case 'tbl_movimientos_inventario':
        return 'id_movimiento';
      default:
        return 'id';
    }
  }
}
