import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';
import '../models/helpers.dart';
import '../models/producto.dart';
import '../services/database_service.dart';

/// Modelo de fila para la visualización del Reporte de Inventario.
class ItemReporteInventario {
  final int idProducto;
  final String codigo;
  final String descripcion;
  final String departamento;
  final double costo;
  final double precioVenta;
  final double existencia;
  final double invMinimo;
  final double invMaximo;
  final bool usaInventario;

  const ItemReporteInventario({
    required this.idProducto,
    required this.codigo,
    required this.descripcion,
    required this.departamento,
    required this.costo,
    required this.precioVenta,
    required this.existencia,
    required this.invMinimo,
    required this.invMaximo,
    required this.usaInventario,
  });

  double get valorCosto => existencia * costo;
  double get valorVenta => existencia * precioVenta;
}

/// Modelo de fila para la visualización de Productos Bajos en Inventario.
class ItemBajoStock {
  final int idProducto;
  final String codigo;
  final String descripcion;
  final String departamento;
  final double existencia;
  final double invMinimo;
  final double? invMaximo;

  const ItemBajoStock({
    required this.idProducto,
    required this.codigo,
    required this.descripcion,
    required this.departamento,
    required this.existencia,
    required this.invMinimo,
    this.invMaximo,
  });

  double get sugerenciaResurtido {
    if (invMaximo != null && invMaximo! > existencia) {
      return invMaximo! - existencia;
    }
    if (invMinimo > existencia) {
      return invMinimo - existencia;
    }
    return 0.0;
  }
}

/// Modelo de fila para el Reporte de Movimientos y Kardex.
class MovimientoInventarioDetalle {
  final int idMovimiento;
  final DateTime fecha;
  final String codigoProducto;
  final String descripcionProducto;
  final String tipoMovimiento;
  final double cantidad;
  final double existenciaAnterior;
  final double existenciaNueva;
  final String motivo;
  final String usuario;

  const MovimientoInventarioDetalle({
    required this.idMovimiento,
    required this.fecha,
    required this.codigoProducto,
    required this.descripcionProducto,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.existenciaAnterior,
    required this.existenciaNueva,
    required this.motivo,
    required this.usuario,
  });
}

/// Repositorio local-first para la gestión de inventario, entradas, ajustes,
/// mermas, reportes y kardex contra PostgreSQL local.
class InventarioRepository {
  final DatabaseService _db;

  InventarioRepository(this._db);

  static InventarioRepository? _instance;
  static InventarioRepository get instance {
    _instance ??= InventarioRepository(DatabaseService.instance);
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  /// Obtiene los productos para el Reporte de Inventario (solo los que usan inventario y están activos).
  Future<List<ItemReporteInventario>> obtenerReporteInventario({int? idDepartamento}) async {
    if (_db.isCloudOnlyMode) {
      var query = _db.supabase
          .from('tbl_productos')
          .select('id_producto, codigo_barras, descripcion, precio_costo, precio_venta, existencia, inventario_minimo, inventario_maximo, usa_inventario, tbl_departamentos(nombre_departamento)')
          .eq('estatus', 'Activo')
          .eq('usa_inventario', true);

      if (idDepartamento != null && idDepartamento > 0) {
        query = query.eq('id_departamento', idDepartamento);
      }
      final res = await query.order('descripcion', ascending: true);
      return (res as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final dept = m['tbl_departamentos'];
        final deptoNom = (dept is Map ? dept['nombre_departamento'] : null)?.toString() ?? 'Sin Departamento';
        return ItemReporteInventario(
          idProducto: parseIntSafe(m['id_producto']),
          codigo: (m['codigo_barras'] ?? '').toString(),
          descripcion: (m['descripcion'] ?? '').toString(),
          departamento: deptoNom,
          costo: parseDecimal(m['precio_costo']),
          precioVenta: parseDecimal(m['precio_venta']),
          existencia: parseDecimal(m['existencia']),
          invMinimo: parseDecimal(m['inventario_minimo']),
          invMaximo: parseDecimal(m['inventario_maximo']),
          usaInventario: parseBool(m['usa_inventario']),
        );
      }).toList();
    }

    String sql = '''
      SELECT p.id_producto, p.codigo_barras, p.descripcion,
             COALESCE(d.nombre_departamento, 'Sin Departamento') AS departamento,
             p.precio_costo, p.precio_venta, p.existencia,
             p.inventario_minimo, p.inventario_maximo, p.usa_inventario
      FROM tbl_productos p
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE p.estatus::text = 'Activo'
        AND p.usa_inventario = TRUE
    ''';

    final params = <String, dynamic>{};
    if (idDepartamento != null && idDepartamento > 0) {
      sql += ' AND p.id_departamento = @depto';
      params['depto'] = idDepartamento;
    }
    sql += ' ORDER BY p.descripcion ASC';

    final res = await _db.query(sql, params: params);
    return res.map((r) {
      final m = r.toColumnMap();
      return ItemReporteInventario(
        idProducto: parseIntSafe(m['id_producto']),
        codigo: parsePgString(m['codigo_barras']),
        descripcion: parsePgString(m['descripcion']),
        departamento: parsePgString(m['departamento']),
        costo: parseDecimal(m['precio_costo']),
        precioVenta: parseDecimal(m['precio_venta']),
        existencia: parseDecimal(m['existencia']),
        invMinimo: parseDecimal(m['inventario_minimo']),
        invMaximo: parseDecimal(m['inventario_maximo']),
        usaInventario: parseBool(m['usa_inventario']),
      );
    }).toList();
  }

  /// Obtiene productos bajos en inventario (existencia <= inventario_minimo).
  Future<List<ItemBajoStock>> obtenerProductosBajosStock() async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_productos')
          .select('id_producto, codigo_barras, descripcion, existencia, inventario_minimo, inventario_maximo, tbl_departamentos(nombre_departamento)')
          .eq('estatus', 'Activo')
          .eq('usa_inventario', true)
          .order('existencia', ascending: true);

      final list = <ItemBajoStock>[];
      for (final r in (res as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final ext = parseDecimal(m['existencia']);
        final min = parseDecimal(m['inventario_minimo']);
        if (ext <= min) {
          final dept = m['tbl_departamentos'];
          final deptoNom = (dept is Map ? dept['nombre_departamento'] : null)?.toString() ?? 'Sin Departamento';
          list.add(ItemBajoStock(
            idProducto: parseIntSafe(m['id_producto']),
            codigo: (m['codigo_barras'] ?? '').toString(),
            descripcion: (m['descripcion'] ?? '').toString(),
            departamento: deptoNom,
            existencia: ext,
            invMinimo: min,
            invMaximo: m['inventario_maximo'] != null ? parseDecimal(m['inventario_maximo']) : null,
          ));
        }
      }
      return list;
    }

    const sql = '''
      SELECT p.id_producto, p.codigo_barras, p.descripcion,
             COALESCE(d.nombre_departamento, 'Sin Departamento') AS departamento,
             p.existencia, p.inventario_minimo, p.inventario_maximo
      FROM tbl_productos p
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE p.estatus::text = 'Activo'
        AND p.usa_inventario = TRUE
        AND p.existencia <= p.inventario_minimo
      ORDER BY p.existencia ASC
    ''';

    final res = await _db.query(sql);
    return res.map((r) {
      final m = r.toColumnMap();
      final maxVal = m['inventario_maximo'] != null ? parseDecimal(m['inventario_maximo']) : null;
      return ItemBajoStock(
        idProducto: parseIntSafe(m['id_producto']),
        codigo: parsePgString(m['codigo_barras']),
        descripcion: parsePgString(m['descripcion']),
        departamento: parsePgString(m['departamento']),
        existencia: parseDecimal(m['existencia']),
        invMinimo: parseDecimal(m['inventario_minimo']),
        invMaximo: maxVal,
      );
    }).toList();
  }

  /// Obtiene los movimientos históricos de inventario con filtros opcionales.
  Future<List<MovimientoInventarioDetalle>> obtenerMovimientos({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? tipoMovimiento,
    int? idProducto,
  }) async {
    if (_db.isCloudOnlyMode) {
      var query = _db.supabase
          .from('tbl_movimientos_inventario')
          .select('id_movimiento, fecha_registro, tipo_movimiento, cantidad, existencia_anterior, existencia_nueva, motivo, tbl_productos(codigo_barras, descripcion), tbl_usuarios(nombre_completo, nombre_usuario)');

      if (idProducto != null) {
        query = query.eq('id_producto', idProducto);
      }
      if (tipoMovimiento != null && tipoMovimiento.isNotEmpty && tipoMovimiento != 'Todos') {
        query = query.eq('tipo_movimiento', tipoMovimiento);
      }
      if (fechaInicio != null) {
        final fIni = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day, 0, 0, 0).toIso8601String();
        query = query.gte('fecha_registro', fIni);
      }
      if (fechaFin != null) {
        final fFin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59).toIso8601String();
        query = query.lte('fecha_registro', fFin);
      }

      final res = await query.order('fecha_registro', ascending: false).limit(200);
      return (res as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final p = m['tbl_productos'];
        final u = m['tbl_usuarios'];
        final cod = (p is Map ? p['codigo_barras'] : null)?.toString() ?? '';
        final desc = (p is Map ? p['descripcion'] : null)?.toString() ?? '';
        final usr = (u is Map ? (u['nombre_completo'] ?? u['nombre_usuario']) : null)?.toString() ?? 'Sistema';

        return MovimientoInventarioDetalle(
          idMovimiento: parseIntSafe(m['id_movimiento']),
          fecha: parseDateTime(m['fecha_registro']),
          codigoProducto: cod,
          descripcionProducto: desc,
          tipoMovimiento: (m['tipo_movimiento'] ?? '').toString(),
          cantidad: parseDecimal(m['cantidad']),
          existenciaAnterior: parseDecimal(m['existencia_anterior']),
          existenciaNueva: parseDecimal(m['existencia_nueva']),
          motivo: (m['motivo'] ?? '').toString(),
          usuario: usr,
        );
      }).toList();
    }

    String sql = '''
      SELECT m.id_movimiento, m.fecha_registro,
             p.codigo_barras, p.descripcion,
             m.tipo_movimiento, m.cantidad,
             m.existencia_anterior, m.existencia_nueva,
             COALESCE(m.motivo, '') AS motivo,
             COALESCE(u.nombre_completo, u.nombre_usuario, 'Sistema') AS usuario
      FROM tbl_movimientos_inventario m
      JOIN tbl_productos p ON m.id_producto = p.id_producto
      LEFT JOIN tbl_usuarios u ON m.id_usuario = u.id_usuario
      WHERE 1=1
    ''';

    final params = <String, dynamic>{};

    if (idProducto != null) {
      sql += ' AND m.id_producto = @idProd';
      params['idProd'] = idProducto;
    }

    if (tipoMovimiento != null && tipoMovimiento.isNotEmpty && tipoMovimiento != 'Todos') {
      sql += ' AND m.tipo_movimiento::text = @tipo';
      params['tipo'] = tipoMovimiento;
    }

    if (fechaInicio != null) {
      sql += ' AND m.fecha_registro >= @fIni';
      params['fIni'] = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day, 0, 0, 0).toIso8601String();
    }

    if (fechaFin != null) {
      sql += ' AND m.fecha_registro <= @fFin';
      params['fFin'] = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59).toIso8601String();
    }

    sql += ' ORDER BY m.fecha_registro DESC LIMIT 200';

    final res = await _db.query(sql, params: params);
    return res.map((r) {
      final m = r.toColumnMap();
      return MovimientoInventarioDetalle(
        idMovimiento: parseIntSafe(m['id_movimiento']),
        fecha: parseDateTime(m['fecha_registro']),
        codigoProducto: parsePgString(m['codigo_barras']),
        descripcionProducto: parsePgString(m['descripcion']),
        tipoMovimiento: parsePgString(m['tipo_movimiento']),
        cantidad: parseDecimal(m['cantidad']),
        existenciaAnterior: parseDecimal(m['existencia_anterior']),
        existenciaNueva: parseDecimal(m['existencia_nueva']),
        motivo: parsePgString(m['motivo']),
        usuario: parsePgString(m['usuario']),
      );
    }).toList();
  }

  /// Obtiene el Kardex cronológico de un producto específico.
  Future<List<MovimientoInventarioDetalle>> obtenerKardex(int idProducto) async {
    return obtenerMovimientos(idProducto: idProducto);
  }

  // ---------------------------------------------------------------------------
  // Transacciones ACID de Entrada, Ajuste y Merma
  // ---------------------------------------------------------------------------

  /// Registra una Entrada de mercancía:
  /// Actualiza existencia = existencia + cantidad (y opcionalmente costo/precio),
  /// e inserta en tbl_movimientos_inventario.
  Future<void> registrarEntrada({
    required int idProducto,
    required double cantidad,
    double? nuevoCosto,
    double? nuevoPrecioVenta,
    required int idUsuario,
    String? motivo,
  }) async {
    final terminalId = _db.terminalId;
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      final prod = await _db.supabase
          .from('tbl_productos')
          .select('existencia, precio_costo, precio_venta')
          .eq('id_producto', idProducto)
          .single();

      final anterior = parseDecimal(prod['existencia']);
      final nueva = anterior + cantidad;
      final costoFinal = nuevoCosto ?? parseDecimal(prod['precio_costo']);
      final ventaFinal = nuevoPrecioVenta ?? parseDecimal(prod['precio_venta']);

      await _db.supabase.from('tbl_productos').update({
        'existencia': nueva,
        'precio_costo': costoFinal,
        'precio_venta': ventaFinal,
        'fecha_actualizacion': now,
      }).eq('id_producto', idProducto);

      await _db.supabase.from('tbl_movimientos_inventario').insert({
        'id_producto': idProducto,
        'id_usuario': idUsuario,
        'tipo_movimiento': 'Entrada',
        'cantidad': cantidad,
        'existencia_anterior': anterior,
        'existencia_nueva': nueva,
        'motivo': motivo ?? 'Entrada de mercancía',
        'fecha_registro': now,
        'fecha_movimiento': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': terminalId,
      });

      dev.log('[InventarioRepository] ✅ Entrada en Supabase registrada para prod #$idProducto: +$cantidad');
      return;
    }

    await _db.transaction((tx) async {
      // 1. Obtener producto actual con bloqueo
      final prodRes = await tx.execute(
        Sql.named('SELECT existencia, precio_costo, precio_venta FROM tbl_productos WHERE id_producto = @id FOR UPDATE'),
        parameters: {'id': idProducto},
      );
      if (prodRes.isEmpty) {
        throw StateError('El producto #$idProducto no existe.');
      }

      final pMap = prodRes.first.toColumnMap();
      final anterior = parseDecimal(pMap['existencia']);
      final nueva = anterior + cantidad;
      final costoFinal = nuevoCosto ?? parseDecimal(pMap['precio_costo']);
      final ventaFinal = nuevoPrecioVenta ?? parseDecimal(pMap['precio_venta']);

      // 2. Actualizar tbl_productos
      await tx.execute(
        Sql.named('''
          UPDATE tbl_productos
          SET existencia = @nueva,
              precio_costo = @costo,
              precio_venta = @venta,
              fecha_actualizacion = @now,
              sincronizado = FALSE,
              terminal_origen = @terminal
          WHERE id_producto = @id
        '''),
        parameters: {
          'nueva': nueva,
          'costo': costoFinal,
          'venta': ventaFinal,
          'now': now,
          'terminal': terminalId,
          'id': idProducto,
        },
      );

      // 3. Insertar movimiento en Kardex
      await tx.execute(
        Sql.named('''
          INSERT INTO tbl_movimientos_inventario
          (id_producto, id_usuario, tipo_movimiento, cantidad,
           existencia_anterior, existencia_nueva, motivo,
           fecha_registro, sincronizado, terminal_origen)
          VALUES
          (@idProd, @idUser, 'Entrada', @cant,
           @ant, @nueva, @motivo,
           @now, FALSE, @terminal)
        '''),
        parameters: {
          'idProd': idProducto,
          'idUser': idUsuario,
          'cant': cantidad,
          'ant': anterior,
          'nueva': nueva,
          'motivo': motivo ?? 'Entrada de mercancía',
          'now': now,
          'terminal': terminalId,
        },
      );
    });

    dev.log('[InventarioRepository] ✅ Entrada registrada para prod #$idProducto: +$cantidad');
  }

  /// Registra un Ajuste físico o Merma:
  /// - 'Ajuste': valor representa la existencia física real contada.
  /// - 'Merma': valor representa la cantidad a descontar (dañado/caducado).
  Future<void> registrarAjusteOMerma({
    required int idProducto,
    required String tipoMovimiento, // 'Ajuste' | 'Merma'
    required double valor,
    required String motivo,
    required int idUsuario,
  }) async {
    final terminalId = _db.terminalId;
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      final prod = await _db.supabase
          .from('tbl_productos')
          .select('existencia')
          .eq('id_producto', idProducto)
          .single();

      final anterior = parseDecimal(prod['existencia']);
      double nueva;
      double cantidadDelta;

      if (tipoMovimiento == 'Ajuste') {
        nueva = valor;
        cantidadDelta = nueva - anterior;
      } else {
        nueva = (anterior - valor) < 0 ? 0.0 : (anterior - valor);
        cantidadDelta = -valor;
      }

      await _db.supabase.from('tbl_productos').update({
        'existencia': nueva,
        'fecha_actualizacion': now,
      }).eq('id_producto', idProducto);

      await _db.supabase.from('tbl_movimientos_inventario').insert({
        'id_producto': idProducto,
        'id_usuario': idUsuario,
        'tipo_movimiento': tipoMovimiento,
        'cantidad': cantidadDelta,
        'existencia_anterior': anterior,
        'existencia_nueva': nueva,
        'motivo': motivo.trim(),
        'fecha_registro': now,
        'fecha_movimiento': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': terminalId,
      });

      dev.log('[InventarioRepository] ✅ $tipoMovimiento en Supabase registrado para prod #$idProducto.');
      return;
    }

    await _db.transaction((tx) async {
      // 1. Obtener producto actual con bloqueo
      final prodRes = await tx.execute(
        Sql.named('SELECT existencia FROM tbl_productos WHERE id_producto = @id FOR UPDATE'),
        parameters: {'id': idProducto},
      );
      if (prodRes.isEmpty) {
        throw StateError('El producto #$idProducto no existe.');
      }

      final anterior = parseDecimal(prodRes.first.toColumnMap()['existencia']);
      double nueva;
      double cantidadDelta;

      if (tipoMovimiento == 'Ajuste') {
        nueva = valor;
        cantidadDelta = nueva - anterior;
      } else {
        // Merma: descontar
        nueva = (anterior - valor) < 0 ? 0.0 : (anterior - valor);
        cantidadDelta = -valor;
      }

      // 2. Actualizar tbl_productos
      await tx.execute(
        Sql.named('''
          UPDATE tbl_productos
          SET existencia = @nueva,
              fecha_actualizacion = @now,
              sincronizado = FALSE,
              terminal_origen = @terminal
          WHERE id_producto = @id
        '''),
        parameters: {
          'nueva': nueva,
          'now': now,
          'terminal': terminalId,
          'id': idProducto,
        },
      );

      // 3. Insertar en Kardex
      await tx.execute(
        Sql.named('''
          INSERT INTO tbl_movimientos_inventario
          (id_producto, id_usuario, tipo_movimiento, cantidad,
           existencia_anterior, existencia_nueva, motivo,
           fecha_registro, sincronizado, terminal_origen)
          VALUES
          (@idProd, @idUser, @tipo, @cant,
           @ant, @nueva, @motivo,
           @now, FALSE, @terminal)
        '''),
        parameters: {
          'idProd': idProducto,
          'idUser': idUsuario,
          'tipo': tipoMovimiento,
          'cant': cantidadDelta,
          'ant': anterior,
          'nueva': nueva,
          'motivo': motivo.trim(),
          'now': now,
          'terminal': terminalId,
        },
      );
    });

    dev.log('[InventarioRepository] ✅ $tipoMovimiento registrado para prod #$idProducto.');
  }
}

