import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';

import '../models/helpers.dart';
import '../models/producto.dart';
import '../services/database_service.dart';

/// Fila agrupada para el reporte de Ventas por Periodo.
class VentaPorPeriodoItem {
  final String codigo;
  final String descripcion;
  final String departamento;
  final double cantidadVendida;
  final double totalVendido;
  final double utilidadEstimada;

  const VentaPorPeriodoItem({
    required this.codigo,
    required this.descripcion,
    required this.departamento,
    required this.cantidadVendida,
    required this.totalVendido,
    required this.utilidadEstimada,
  });
}

/// Producto con nombre de departamento para catálogo y vistas.
class ProductoConDepartamento {
  final Producto producto;
  final String nombreDepartamento;

  const ProductoConDepartamento({
    required this.producto,
    required this.nombreDepartamento,
  });
}

/// Repositorio de Productos – 100 % local-first.
///
/// Todas las operaciones leen y escriben contra PostgreSQL local.
/// Los registros nuevos/modificados se marcan con `sincronizado = false`
/// para que el [SyncService] los suba a Supabase.
class ProductosRepository {
  final DatabaseService _db;

  ProductosRepository(this._db);

  static ProductosRepository? _instance;
  static ProductosRepository get instance {
    _instance ??= ProductosRepository(DatabaseService.instance);
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  /// Obtiene todos los productos activos, ordenados por descripción.
  Future<List<Producto>> obtenerTodos() async {
    if (_db.isCloudOnlyMode) {
      final result = await _db.supabase
          .from('tbl_productos')
          .select()
          .eq('estatus', 'Activo')
          .order('descripcion', ascending: true);
      return (result as List).map((row) => Producto.fromMap(row as Map<String, dynamic>)).toList();
    }

    final result = await _db.query(
      "SELECT * FROM tbl_productos WHERE estatus::text = 'Activo' ORDER BY descripcion",
    );
    return result.map((row) => Producto.fromMap(row.toColumnMap())).toList();
  }

  /// Obtiene todos los productos activos acompañados del nombre de su departamento.
  Future<List<ProductoConDepartamento>> obtenerCatalogoCompleto({int? idDepartamento, String? busqueda}) async {
    if (_db.isCloudOnlyMode) {
      var query = _db.supabase
          .from('tbl_productos')
          .select('*, tbl_departamentos(nombre_departamento)')
          .eq('estatus', 'Activo');

      if (idDepartamento != null && idDepartamento > 0) {
        query = query.eq('id_departamento', idDepartamento);
      }
      if (busqueda != null && busqueda.trim().isNotEmpty) {
        final clean = busqueda.trim();
        query = query.or('descripcion.ilike.%$clean%,codigo_barras.ilike.%$clean%');
      }

      final res = await query.order('descripcion', ascending: true);
      return (res as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final dept = m['tbl_departamentos'];
        final deptoNom = (dept is Map ? dept['nombre_departamento'] : null)?.toString() ?? 'Sin Departamento';
        return ProductoConDepartamento(
          producto: Producto.fromMap(m),
          nombreDepartamento: deptoNom,
        );
      }).toList();
    }

    String sql = '''
      SELECT p.*, COALESCE(d.nombre_departamento, 'Sin Departamento') AS nombre_departamento
      FROM tbl_productos p
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE p.estatus::text = 'Activo'
    ''';
    final params = <String, dynamic>{};

    if (idDepartamento != null && idDepartamento > 0) {
      sql += ' AND p.id_departamento = @depto';
      params['depto'] = idDepartamento;
    }

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      sql += ' AND (LOWER(p.descripcion) LIKE @q OR p.codigo_barras LIKE @q)';
      params['q'] = '%${busqueda.trim().toLowerCase()}%';
    }

    sql += ' ORDER BY p.descripcion ASC';

    final result = await _db.query(sql, params: params);
    return result.map((r) {
      final m = r.toColumnMap();
      return ProductoConDepartamento(
        producto: Producto.fromMap(m),
        nombreDepartamento: parsePgString(m['nombre_departamento']),
      );
    }).toList();
  }

  /// Busca un producto por su [codigoBarras] exacto.
  Future<Producto?> buscarPorCodigo(String codigoBarras) async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_productos')
          .select()
          .eq('codigo_barras', codigoBarras.trim())
          .eq('estatus', 'Activo')
          .maybeSingle();
      if (res == null) return null;
      return Producto.fromMap(res);
    }

    final result = await _db.query(
      "SELECT * FROM tbl_productos WHERE codigo_barras = @codigo AND estatus::text = 'Activo' LIMIT 1",
      params: {'codigo': codigoBarras.trim()},
    );
    if (result.isEmpty) return null;
    return Producto.fromMap(result.first.toColumnMap());
  }

  /// Busca productos cuya descripción contenga [texto] (case-insensitive).
  Future<List<Producto>> buscarPorDescripcion(String texto) async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_productos')
          .select()
          .ilike('descripcion', '%${texto.trim()}%')
          .eq('estatus', 'Activo')
          .order('descripcion', ascending: true)
          .limit(50);
      return (res as List).map((row) => Producto.fromMap(row as Map<String, dynamic>)).toList();
    }

    final result = await _db.query(
      "SELECT * FROM tbl_productos WHERE LOWER(descripcion) LIKE @texto AND estatus::text = 'Activo' ORDER BY descripcion LIMIT 50",
      params: {
        'texto': '%${texto.trim().toLowerCase()}%',
      },
    );
    return result.map((row) => Producto.fromMap(row.toColumnMap())).toList();
  }

  /// Obtiene productos con existencia por debajo del mínimo (alertas).
  Future<List<Producto>> obtenerBajoStock() async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_productos')
          .select()
          .eq('usa_inventario', true)
          .eq('estatus', 'Activo');
      final list = (res as List).map((row) => Producto.fromMap(row as Map<String, dynamic>)).toList();
      return list.where((p) => p.existencia <= p.inventarioMinimo).toList();
    }

    final result = await _db.query(
      "SELECT * FROM tbl_productos WHERE usa_inventario = TRUE AND existencia <= inventario_minimo AND estatus::text = 'Activo' ORDER BY existencia",
    );
    return result.map((row) => Producto.fromMap(row.toColumnMap())).toList();
  }

  /// Consulta agrupada sobre ventas por periodo.
  Future<List<VentaPorPeriodoItem>> obtenerVentasPorPeriodo({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int? idDepartamento,
  }) async {
    final fIni = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day, 0, 0, 0).toIso8601String();
    final fFin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day, 23, 59, 59).toIso8601String();

    if (_db.isCloudOnlyMode) {
      var query = _db.supabase
          .from('tbl_detalle_ventas')
          .select('cantidad, importe, costo_unitario, tbl_ventas!inner(fecha_venta, estatus_venta), tbl_productos!inner(codigo_barras, descripcion, id_departamento, tbl_departamentos(nombre_departamento))')
          .eq('tbl_ventas.estatus_venta', 'Completada')
          .gte('tbl_ventas.fecha_venta', fIni)
          .lte('tbl_ventas.fecha_venta', fFin);

      if (idDepartamento != null && idDepartamento > 0) {
        query = query.eq('tbl_productos.id_departamento', idDepartamento);
      }

      final res = await query;
      final mapItems = <String, Map<String, dynamic>>{};
      for (final r in res) {
        final p = r['tbl_productos'] as Map?;
        if (p == null) continue;
        final cod = (p['codigo_barras'] ?? '').toString();
        final desc = (p['descripcion'] ?? '').toString();
        final dept = p['tbl_departamentos'] as Map?;
        final deptoNom = (dept != null ? dept['nombre_departamento'] : null)?.toString() ?? 'Sin Departamento';
        final cant = parseDecimal(r['cantidad']);
        final imp = parseDecimal(r['importe']);
        final cost = parseDecimal(r['costo_unitario']);
        final util = imp - (cant * cost);

        if (!mapItems.containsKey(cod)) {
          mapItems[cod] = {
            'codigo': cod,
            'descripcion': desc,
            'departamento': deptoNom,
            'cantidad': 0.0,
            'total': 0.0,
            'utilidad': 0.0,
          };
        }
        mapItems[cod]!['cantidad'] = (mapItems[cod]!['cantidad'] as double) + cant;
        mapItems[cod]!['total'] = (mapItems[cod]!['total'] as double) + imp;
        mapItems[cod]!['utilidad'] = (mapItems[cod]!['utilidad'] as double) + util;
      }

      final items = mapItems.values.map((m) => VentaPorPeriodoItem(
        codigo: m['codigo'],
        descripcion: m['descripcion'],
        departamento: m['departamento'],
        cantidadVendida: m['cantidad'],
        totalVendido: m['total'],
        utilidadEstimada: m['utilidad'],
      )).toList();
      items.sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
      return items;
    }

    String sql = '''
      SELECT p.codigo_barras, p.descripcion,
             COALESCE(d.nombre_departamento, 'Sin Departamento') AS departamento,
             SUM(dv.cantidad) AS cantidad_vendida,
             SUM(dv.importe) AS total_vendido,
             SUM(dv.importe - (dv.cantidad * dv.costo_unitario)) AS utilidad_estimada
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      JOIN tbl_productos p ON dv.id_producto = p.id_producto
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE v.estatus_venta::text = 'Completada'
        AND v.fecha_venta >= @fIni
        AND v.fecha_venta <= @fFin
    ''';

    final params = <String, dynamic>{
      'fIni': fIni,
      'fFin': fFin,
    };

    if (idDepartamento != null && idDepartamento > 0) {
      sql += ' AND p.id_departamento = @depto';
      params['depto'] = idDepartamento;
    }

    sql += '''
      GROUP BY p.codigo_barras, p.descripcion, d.nombre_departamento
      ORDER BY total_vendido DESC
    ''';

    final res = await _db.query(sql, params: params);
    return res.map((r) {
      final m = r.toColumnMap();
      return VentaPorPeriodoItem(
        codigo: parsePgString(m['codigo_barras']),
        descripcion: parsePgString(m['descripcion']),
        departamento: parsePgString(m['departamento']),
        cantidadVendida: parseDecimal(m['cantidad_vendida']),
        totalVendido: parseDecimal(m['total_vendido']),
        utilidadEstimada: parseDecimal(m['utilidad_estimada']),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Escritura
  // ---------------------------------------------------------------------------

  /// Obtiene o crea el registro base oculto para artículos comunes no registrados.
  Future<Producto> obtenerOCrearArticuloComun() async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_productos')
          .select()
          .eq('codigo_barras', 'ART-COMUN')
          .maybeSingle();
      if (res != null) {
        return Producto.fromMap(res);
      }
      final deptoRes = await _db.supabase.from('tbl_departamentos').select('id_departamento').limit(1).maybeSingle();
      final deptoId = deptoRes != null ? parseIntSafe(deptoRes['id_departamento']) : 1;
      return crear(
        codigoBarras: 'ART-COMUN',
        descripcion: 'Artículo Común',
        idDepartamento: deptoId,
        tipoVenta: 'Unidad',
        precioCosto: 0.0,
        precioVenta: 0.0,
        usaInventario: false,
        existencia: 0.0,
        inventarioMinimo: 0.0,
        inventarioMaximo: 0.0,
        aplicaIva: false,
        tasaIva: 0.0,
        estatus: 'Inactivo',
      );
    }

    final res = await _db.query(
      "SELECT * FROM tbl_productos WHERE codigo_barras = 'ART-COMUN' LIMIT 1",
    );
    if (res.isNotEmpty) {
      return Producto.fromMap(res.first.toColumnMap());
    }

    final deptoRes = await _db.query("SELECT id_departamento FROM tbl_departamentos LIMIT 1");
    final deptoId = deptoRes.isNotEmpty ? parseIntSafe(deptoRes.first.toColumnMap()['id_departamento']) : 1;

    return crear(
      codigoBarras: 'ART-COMUN',
      descripcion: 'Artículo Común',
      idDepartamento: deptoId,
      tipoVenta: 'Unidad',
      precioCosto: 0.0,
      precioVenta: 0.0,
      usaInventario: false,
      existencia: 0.0,
      inventarioMinimo: 0.0,
      inventarioMaximo: 0.0,
      aplicaIva: false,
      tasaIva: 0.0,
      estatus: 'Inactivo',
    );
  }

  /// Crea un nuevo producto en la BD local o Supabase.
  Future<Producto> crear({
    required String codigoBarras,
    required String descripcion,
    required double precioCosto,
    required double precioVenta,
    double? precioMayoreo,
    double? cantidadMayoreo,
    required double existencia,
    required double inventarioMinimo,
    double inventarioMaximo = 0.0,
    bool usaInventario = true,
    String tipoVenta = 'Unidad',
    bool aplicaIva = false,
    double tasaIva = 0.0,
    required int idDepartamento,
    String estatus = 'Activo',
  }) async {
    final now = DateTime.now().toIso8601String();
    final terminalId = _db.terminalId;

    if (_db.isCloudOnlyMode) {
      final insertData = {
        'codigo_barras': codigoBarras.trim(),
        'descripcion': descripcion.trim(),
        'id_departamento': idDepartamento,
        'tipo_venta': tipoVenta,
        'precio_costo': precioCosto,
        'precio_venta': precioVenta,
        'precio_mayoreo': precioMayoreo,
        'cantidad_mayoreo': cantidadMayoreo,
        'usa_inventario': usaInventario,
        'existencia': existencia,
        'inventario_minimo': inventarioMinimo,
        'inventario_maximo': inventarioMaximo,
        'aplica_iva': aplicaIva,
        'tasa_iva': tasaIva,
        'estatus': estatus,
        'fecha_registro': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': terminalId,
      };
      final res = await _db.supabase.from('tbl_productos').insert(insertData).select().single();
      dev.log('[ProductosRepository] ✅ Producto creado en Supabase: $codigoBarras');
      return Producto.fromMap(res);
    }

    final result = await _db.query(
      '''INSERT INTO tbl_productos
         (codigo_barras, descripcion, id_departamento, tipo_venta,
          precio_costo, precio_venta, precio_mayoreo, cantidad_mayoreo,
          usa_inventario, existencia, inventario_minimo, inventario_maximo,
          aplica_iva, tasa_iva, estatus, fecha_registro, fecha_actualizacion,
          sincronizado, terminal_origen)
         VALUES
         (@codigo, @desc, @depto, @tipoVenta,
          @costo, @venta, @mayoreo, @cantMayoreo,
          @usaInv, @existencia, @min, @max,
          @aplicaIva, @tasaIva, @estatus, @now, @now,
          FALSE, @terminal)
         RETURNING *''',
      params: {
        'codigo': codigoBarras.trim(),
        'desc': descripcion.trim(),
        'depto': idDepartamento,
        'tipoVenta': tipoVenta,
        'costo': precioCosto,
        'venta': precioVenta,
        'mayoreo': precioMayoreo,
        'cantMayoreo': cantidadMayoreo,
        'usaInv': usaInventario,
        'existencia': existencia,
        'min': inventarioMinimo,
        'max': inventarioMaximo,
        'aplicaIva': aplicaIva,
        'tasaIva': tasaIva,
        'estatus': estatus,
        'now': now,
        'terminal': terminalId,
      },
    );

    dev.log('[ProductosRepository] ✅ Producto creado: $codigoBarras');
    return Producto.fromMap(result.first.toColumnMap());
  }

  /// Actualiza un producto existente y lo marca como no sincronizado.
  Future<void> actualizar(Producto producto) async {
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_productos').update({
        'codigo_barras': producto.codigoBarras,
        'descripcion': producto.descripcion,
        'id_departamento': producto.idDepartamento,
        'tipo_venta': producto.tipoVenta,
        'precio_costo': producto.precioCosto,
        'precio_venta': producto.precioVenta,
        'precio_mayoreo': producto.precioMayoreo,
        'cantidad_mayoreo': producto.cantidadMayoreo,
        'usa_inventario': producto.usaInventario,
        'existencia': producto.existencia,
        'inventario_minimo': producto.inventarioMinimo,
        'inventario_maximo': producto.inventarioMaximo,
        'aplica_iva': producto.aplicaIva,
        'tasa_iva': producto.tasaIva,
        'estatus': producto.estatus,
        'fecha_actualizacion': now,
      }).eq('id_producto', producto.idProducto);
      dev.log('[ProductosRepository] ✅ Producto actualizado en Supabase: ${producto.codigoBarras}');
      return;
    }

    await _db.query(
      '''UPDATE tbl_productos SET
         codigo_barras = @codigo,
         descripcion = @desc,
         id_departamento = @depto,
         tipo_venta = @tipoVenta,
         precio_costo = @costo,
         precio_venta = @venta,
         precio_mayoreo = @mayoreo,
         cantidad_mayoreo = @cantMayoreo,
         usa_inventario = @usaInv,
         existencia = @existencia,
         inventario_minimo = @min,
         inventario_maximo = @max,
         aplica_iva = @aplicaIva,
         tasa_iva = @tasaIva,
         estatus = @estatus,
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_producto = @id''',
      params: {
        'codigo': producto.codigoBarras,
        'desc': producto.descripcion,
        'depto': producto.idDepartamento,
        'tipoVenta': producto.tipoVenta,
        'costo': producto.precioCosto,
        'venta': producto.precioVenta,
        'mayoreo': producto.precioMayoreo,
        'cantMayoreo': producto.cantidadMayoreo,
        'usaInv': producto.usaInventario,
        'existencia': producto.existencia,
        'min': producto.inventarioMinimo,
        'max': producto.inventarioMaximo,
        'aplicaIva': producto.aplicaIva,
        'tasaIva': producto.tasaIva,
        'estatus': producto.estatus,
        'now': now,
        'terminal': _db.terminalId,
        'id': producto.idProducto,
      },
    );

    dev.log('[ProductosRepository] ✅ Producto actualizado: ${producto.codigoBarras}');
  }

  /// Elimina lógicamente un producto (cambia estatus a 'Inactivo').
  Future<void> eliminar(int idProducto) async {
    final now = DateTime.now().toIso8601String();

    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_productos').update({
        'estatus': 'Inactivo',
        'fecha_actualizacion': now,
      }).eq('id_producto', idProducto);
      dev.log('[ProductosRepository] Producto eliminado en Supabase: $idProducto');
      return;
    }

    await _db.query(
      '''UPDATE tbl_productos SET
         estatus = 'Inactivo',
         fecha_actualizacion = @now,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_producto = @id''',
      params: {
        'now': now,
        'terminal': _db.terminalId,
        'id': idProducto,
      },
    );

    dev.log('[ProductosRepository] Producto eliminado (lógico): $idProducto');
  }

  /// Importa una lista de productos desde datos CSV procesados.
  /// Crea los departamentos faltantes y realiza UPSERT en tbl_productos.
  Future<int> importarProductosCSV(List<Map<String, dynamic>> registros) async {
    final terminalId = _db.terminalId;
    final now = DateTime.now().toIso8601String();
    int count = 0;

    if (_db.isCloudOnlyMode) {
      final deptRes = await _db.supabase.from('tbl_departamentos').select('id_departamento, nombre_departamento').eq('estatus', 'Activo');
      final deptoMap = <String, int>{};
      for (final r in deptRes) {
        deptoMap[(r['nombre_departamento'] ?? '').toString().toLowerCase().trim()] = parseIntSafe(r['id_departamento']);
      }

      for (final reg in registros) {
        final codigo = (reg['codigo_barras'] ?? '').toString().trim();
        final desc = (reg['descripcion'] ?? '').toString().trim();
        if (codigo.isEmpty || desc.isEmpty) continue;

        final deptoNombre = (reg['departamento'] ?? 'General').toString().trim();
        final deptoNorm = deptoNombre.toLowerCase();

        int idDepto;
        if (deptoMap.containsKey(deptoNorm)) {
          idDepto = deptoMap[deptoNorm]!;
        } else {
          final nuevoDept = await _db.supabase.from('tbl_departamentos').insert({
            'nombre_departamento': deptoNombre,
            'estatus': 'Activo',
            'fecha_registro': now,
            'fecha_actualizacion': now,
            'sincronizado': true,
            'terminal_origen': terminalId,
          }).select('id_departamento').single();
          idDepto = parseIntSafe(nuevoDept['id_departamento']);
          deptoMap[deptoNorm] = idDepto;
        }

        final costo = parseDecimal(reg['precio_costo']);
        final venta = parseDecimal(reg['precio_venta']);
        final existencia = parseDecimal(reg['existencia']);
        final min = parseDecimal(reg['inventario_minimo']);

        final prodExist = await _db.supabase.from('tbl_productos').select('id_producto').eq('codigo_barras', codigo).limit(1).maybeSingle();

        if (prodExist != null) {
          final idProd = parseIntSafe(prodExist['id_producto']);
          await _db.supabase.from('tbl_productos').update({
            'descripcion': desc,
            'id_departamento': idDepto,
            'precio_costo': costo,
            'precio_venta': venta,
            'existencia': existencia,
            'inventario_minimo': min,
            'estatus': 'Activo',
            'fecha_actualizacion': now,
          }).eq('id_producto', idProd);
        } else {
          await _db.supabase.from('tbl_productos').insert({
            'codigo_barras': codigo,
            'descripcion': desc,
            'id_departamento': idDepto,
            'tipo_venta': 'Unidad',
            'precio_costo': costo,
            'precio_venta': venta,
            'existencia': existencia,
            'inventario_minimo': min,
            'usa_inventario': true,
            'estatus': 'Activo',
            'fecha_registro': now,
            'fecha_actualizacion': now,
            'sincronizado': true,
            'terminal_origen': terminalId,
          });
        }
        count++;
      }
      dev.log('[ProductosRepository] ✅ Importación CSV en Supabase finalizada: $count productos procesados.');
      return count;
    }

    await _db.transaction((tx) async {
      // 1. Obtener mapa de departamentos existentes
      final deptRes = await tx.execute(Sql.named("SELECT id_departamento, LOWER(nombre_departamento) as nombre FROM tbl_departamentos WHERE estatus::text = 'Activo'"));
      final deptoMap = <String, int>{};
      for (final r in deptRes) {
        final m = r.toColumnMap();
        deptoMap[parsePgString(m['nombre']).trim()] = parseIntSafe(m['id_departamento']);
      }

      for (final reg in registros) {
        final codigo = (reg['codigo_barras'] ?? '').toString().trim();
        final desc = (reg['descripcion'] ?? '').toString().trim();
        if (codigo.isEmpty || desc.isEmpty) continue;

        final deptoNombre = (reg['departamento'] ?? 'General').toString().trim();
        final deptoNorm = deptoNombre.toLowerCase();

        int idDepto;
        if (deptoMap.containsKey(deptoNorm)) {
          idDepto = deptoMap[deptoNorm]!;
        } else {
          // Crear departamento nuevo
          final nuevoDeptRes = await tx.execute(
            Sql.named('''INSERT INTO tbl_departamentos
               (nombre_departamento, estatus, fecha_registro, fecha_actualizacion, sincronizado, terminal_origen)
               VALUES (@nom, 'Activo', @now, @now, FALSE, @term) RETURNING id_departamento'''),
            parameters: {'nom': deptoNombre, 'now': now, 'term': terminalId},
          );
          idDepto = parseIntSafe(nuevoDeptRes.first.toColumnMap()['id_departamento']);
          deptoMap[deptoNorm] = idDepto;
        }

        final costo = parseDecimal(reg['precio_costo']);
        final venta = parseDecimal(reg['precio_venta']);
        final existencia = parseDecimal(reg['existencia']);
        final min = parseDecimal(reg['inventario_minimo']);

        // Verificar si existe el producto por código
        final prodExist = await tx.execute(
          Sql.named('SELECT id_producto FROM tbl_productos WHERE codigo_barras = @codigo LIMIT 1'),
          parameters: {'codigo': codigo},
        );

        if (prodExist.isNotEmpty) {
          final idProd = parseIntSafe(prodExist.first.toColumnMap()['id_producto']);
          await tx.execute(
            Sql.named('''UPDATE tbl_productos SET
               descripcion = @desc,
               id_departamento = @depto,
               precio_costo = @costo,
               precio_venta = @venta,
               existencia = @existencia,
               inventario_minimo = @min,
               estatus = 'Activo',
               fecha_actualizacion = @now,
               sincronizado = FALSE,
               terminal_origen = @term
               WHERE id_producto = @id'''),
            parameters: {
              'desc': desc,
              'depto': idDepto,
              'costo': costo,
              'venta': venta,
              'existencia': existencia,
              'min': min,
              'now': now,
              'term': terminalId,
              'id': idProd,
            },
          );
        } else {
          await tx.execute(
            Sql.named('''INSERT INTO tbl_productos
               (codigo_barras, descripcion, id_departamento, tipo_venta,
                precio_costo, precio_venta, existencia, inventario_minimo,
                usa_inventario, estatus, fecha_registro, fecha_actualizacion,
                sincronizado, terminal_origen)
               VALUES
               (@codigo, @desc, @depto, 'Unidad',
                @costo, @venta, @existencia, @min,
                TRUE, 'Activo', @now, @now,
                FALSE, @term)'''),
            parameters: {
              'codigo': codigo,
              'desc': desc,
              'depto': idDepto,
              'costo': costo,
              'venta': venta,
              'existencia': existencia,
              'min': min,
              'now': now,
              'term': terminalId,
            },
          );
        }
        count++;
      }
    });

    dev.log('[ProductosRepository] ✅ Importación CSV finalizada: $count productos procesados.');
    return count;
  }

  // ---------------------------------------------------------------------------
  // Helpers de stock
  // ---------------------------------------------------------------------------

  /// Descuenta stock de un producto dentro de una transacción.
  Future<void> descontarStockTx(
    TxSession session,
    int idProducto,
    double cantidad,
    String terminalId,
  ) async {
    final now = DateTime.now().toIso8601String();

    await session.execute(
      Sql.named(
        '''UPDATE tbl_productos SET
           existencia = existencia - @cantidad,
           fecha_actualizacion = @now,
           sincronizado = FALSE,
           terminal_origen = @terminal
           WHERE id_producto = @id''',
      ),
      parameters: {
        'cantidad': cantidad,
        'now': now,
        'terminal': terminalId,
        'id': idProducto,
      },
    );
  }
}
