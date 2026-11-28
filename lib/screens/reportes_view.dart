import 'dart:developer' as dev;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/helpers.dart';
import '../repositories/catalogos_repository.dart';
import '../repositories/usuarios_repository.dart';
import '../services/database_service.dart';

// ─────────────────────────── MODELOS DE REPORTE ─────────────────────────────

class _ProductoPopular {
  final int posicion;
  final String codigoBarras;
  final String descripcion;
  final String departamento;
  final double cantidadVendida;
  final double totalVendido;
  final double ganancia;

  const _ProductoPopular({
    required this.posicion,
    required this.codigoBarras,
    required this.descripcion,
    required this.departamento,
    required this.cantidadVendida,
    required this.totalVendido,
    required this.ganancia,
  });
}

class _DiaVentaResumen {
  final DateTime fecha;
  final String diaNombre;
  final String etiqueta;
  final int tickets;
  final double total;

  const _DiaVentaResumen({
    required this.fecha,
    required this.diaNombre,
    required this.etiqueta,
    required this.tickets,
    required this.total,
  });
}

class _DiaPagoMetodo {
  final DateTime fecha;
  final String etiqueta;
  final Map<String, double> metodos;
  final double total;

  const _DiaPagoMetodo({
    required this.fecha,
    required this.etiqueta,
    required this.metodos,
    required this.total,
  });
}

class _ResumenReporte {
  final double ventasTotales;
  final double gananciaTotal;
  final int numeroVentas;
  final double ventaPromedio;
  final double margenUtilidad;
  final double creditosOtorgados;
  final double abonosRecibidos;
  final double totalIva;

  // KPIs de Clientes
  final double ventasClientesRegistrados;
  final double ventasPublicoGeneral;
  final double gananciaClientesRegistrados;
  final double saldoTotalPorCobrar;

  // Desgloses
  final Map<String, double> ventasPorMetodo; // Netos = monto - cambio
  final List<Map<String, dynamic>> ventasEvolucion;
  final List<_DiaVentaResumen> ventasPorDia;
  final List<_DiaPagoMetodo> pagosPorDia;
  final List<_ProductoPopular> productosPopulares;
  final List<Map<String, dynamic>> ventasPorDepartamento;
  final List<Map<String, dynamic>> gananciaPorDepartamento;
  final List<Map<String, dynamic>> ventasPorCliente;

  const _ResumenReporte({
    this.ventasTotales = 0,
    this.gananciaTotal = 0,
    this.numeroVentas = 0,
    this.ventaPromedio = 0,
    this.margenUtilidad = 0,
    this.creditosOtorgados = 0,
    this.abonosRecibidos = 0,
    this.totalIva = 0,
    this.ventasClientesRegistrados = 0,
    this.ventasPublicoGeneral = 0,
    this.gananciaClientesRegistrados = 0,
    this.saldoTotalPorCobrar = 0,
    this.ventasPorMetodo = const {},
    this.ventasEvolucion = const [],
    this.ventasPorDia = const [],
    this.pagosPorDia = const [],
    this.productosPopulares = const [],
    this.ventasPorDepartamento = const [],
    this.gananciaPorDepartamento = const [],
    this.ventasPorCliente = const [],
  });
}

// ──────────────────────────── REPOSITORIO DE REPORTES ──────────────────────

class _ReportesDB {
  final DatabaseService _db;
  _ReportesDB(this._db);

  static String _nombreDiaSemana(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return '';
    }
  }

  Future<_ResumenReporte> obtenerResumen({
    required DateTime desde,
    required DateTime hasta,
    int? idUsuario,
    int? idDepartamento,
    required String periodoTipo,
  }) async {
    final desdeStr = DateTime(desde.year, desde.month, desde.day, 0, 0, 0).toIso8601String();
    final hastaStr = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59).toIso8601String();

    if (_db.isCloudOnlyMode) {
      return _obtenerResumenSupabase(
        desdeStr: desdeStr,
        hastaStr: hastaStr,
        desde: desde,
        hasta: hasta,
        idUsuario: idUsuario,
        idDepartamento: idDepartamento,
        periodoTipo: periodoTipo,
      );
    } else {
      return _obtenerResumenLocal(
        desdeStr: desdeStr,
        hastaStr: hastaStr,
        desde: desde,
        hasta: hasta,
        idUsuario: idUsuario,
        idDepartamento: idDepartamento,
        periodoTipo: periodoTipo,
      );
    }
  }

  /// Consulta y agregación directa contra Supabase (Modo Solo Nube)
  Future<_ResumenReporte> _obtenerResumenSupabase({
    required String desdeStr,
    required String hastaStr,
    required DateTime desde,
    required DateTime hasta,
    int? idUsuario,
    int? idDepartamento,
    required String periodoTipo,
  }) async {
    // 1. Consultar ventas completadas con detalle, cliente y usuario
    var vQuery = _db.supabase
        .from('tbl_ventas')
        .select('''
          id_venta, folio_ticket, id_usuario, id_cliente, fecha_venta, total, subtotal, iva, es_credito,
          tbl_detalle_ventas(
            id_producto, descripcion_producto, cantidad, precio_unitario, costo_unitario, importe,
            tbl_productos(codigo_barras, id_departamento, tipo_venta, tbl_departamentos(nombre_departamento))
          ),
          tbl_clientes(id_cliente, nombre, saldo_actual),
          tbl_usuarios(nombre_completo, nombre_usuario)
        ''')
        .eq('estatus_venta', 'Completada')
        .gte('fecha_venta', desdeStr)
        .lte('fecha_venta', hastaStr);

    if (idUsuario != null && idUsuario > 0) {
      vQuery = vQuery.eq('id_usuario', idUsuario);
    }

    final ventasRes = await vQuery.order('fecha_venta', ascending: true);
    final ventasList = List<Map<String, dynamic>>.from(ventasRes);

    // 2. Pagos de las ventas (CORRECCIÓN CRÍTICA: neto = monto - cambio)
    final idsVentas = ventasList.map((v) => v['id_venta']).toList();
    final metodosMap = <String, double>{};
    // Map de id_venta -> List<{metodo, neto}>
    final Map<int, List<Map<String, dynamic>>> pagosPorVentaId = {};

    if (idsVentas.isNotEmpty) {
      final pagosRes = await _db.supabase
          .from('tbl_pagos_venta')
          .select('id_venta, monto, cambio, tbl_formas_pago(nombre_forma_pago)')
          .inFilter('id_venta', idsVentas);

      for (final p in pagosRes) {
        final idV = parseIntSafe(p['id_venta']);
        final fp = p['tbl_formas_pago'];
        final fpNombre = (fp is Map ? fp['nombre_forma_pago'] : null)?.toString() ?? 'Efectivo';
        final monto = parseDecimal(p['monto']);
        final cambio = parseDecimal(p['cambio']);
        // Ingreso neto real
        final neto = math.max(0.0, monto - cambio);

        metodosMap[fpNombre] = (metodosMap[fpNombre] ?? 0.0) + neto;

        pagosPorVentaId.putIfAbsent(idV, () => []).add({
          'metodo': fpNombre,
          'neto': neto,
        });
      }
    }

    // 3. Abonos recibidos en el periodo (general y por cliente)
    var aQuery = _db.supabase
        .from('tbl_abonos_clientes')
        .select('id_cliente, monto')
        .gte('fecha_registro', desdeStr)
        .lte('fecha_registro', hastaStr);
    if (idUsuario != null && idUsuario > 0) {
      aQuery = aQuery.eq('id_usuario', idUsuario);
    }
    final abonosRes = await aQuery;
    double abonosRecibidos = 0.0;
    final Map<int, double> abonosPorClienteMap = {};
    for (final a in abonosRes) {
      final m = parseDecimal(a['monto']);
      abonosRecibidos += m;
      final idC = parseIntSafe(a['id_cliente']);
      if (idC > 0) {
        abonosPorClienteMap[idC] = (abonosPorClienteMap[idC] ?? 0.0) + m;
      }
    }

    // 4. Saldo total por cobrar de tbl_clientes
    double saldoTotalPorCobrar = 0.0;
    try {
      final clientesDbRes = await _db.supabase
          .from('tbl_clientes')
          .select('id_cliente, saldo_actual')
          .eq('estatus', 'Activo');
      for (final c in clientesDbRes) {
        saldoTotalPorCobrar += parseDecimal(c['saldo_actual']);
      }
    } catch (_) {}

    // 5. Procesar métricas, evolución, productos, días y clientes
    double ventasTotales = 0.0;
    double gananciaTotal = 0.0;
    int numeroVentas = 0;
    double creditosOtorgados = 0.0;
    double totalIva = 0.0;

    double ventasClientesRegistrados = 0.0;
    double ventasPublicoGeneral = 0.0;
    double gananciaClientesRegistrados = 0.0;

    final Map<String, Map<String, dynamic>> evolucionMap = {};
    final Map<String, _ProductoPopular> prodMap = {};
    final Map<String, double> deptoVentasMap = {};
    final Map<String, double> deptoGananciasMap = {};
    final Map<String, Map<String, dynamic>> diaVentasMap = {};
    final Map<String, Map<String, dynamic>> diaPagosMap = {};
    final Map<String, Map<String, dynamic>> clienteMap = {};

    final esAgrupacionMensual = periodoTipo == 'Año actual';

    for (final v in ventasList) {
      final idV = parseIntSafe(v['id_venta']);
      final totalVenta = parseDecimal(v['total']);
      final ivaVenta = parseDecimal(v['iva']);
      final esCredito = v['es_credito'] == true;
      final fecha = parseDateTime(v['fecha_venta']);
      final clienteObj = v['tbl_clientes'] as Map?;
      final int? idCliente = clienteObj != null ? parseIntSafe(clienteObj['id_cliente']) : null;
      final String clienteNom = (clienteObj != null && clienteObj['nombre'] != null)
          ? clienteObj['nombre'].toString()
          : 'Público General';
      final double saldoCliente = clienteObj != null ? parseDecimal(clienteObj['saldo_actual']) : 0.0;

      final detalles = v['tbl_detalle_ventas'] as List? ?? [];

      // Filtrar detalles si se seleccionó un departamento específico
      final detallesFiltrados = detalles.where((d) {
        if (idDepartamento == null || idDepartamento <= 0) return true;
        final p = d['tbl_productos'];
        if (p is Map) {
          return parseIntSafe(p['id_departamento']) == idDepartamento;
        }
        return false;
      }).toList();

      if (idDepartamento != null && idDepartamento > 0 && detallesFiltrados.isEmpty) {
        continue;
      }

      ventasTotales += totalVenta;
      totalIva += ivaVenta;
      numeroVentas++;
      if (esCredito) creditosOtorgados += totalVenta;

      if (idCliente != null && idCliente > 0) {
        ventasClientesRegistrados += totalVenta;
      } else {
        ventasPublicoGeneral += totalVenta;
      }

      // Clave de evolución (Día o Mes)
      final String evoKey;
      if (esAgrupacionMensual) {
        const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        evoKey = meses[(fecha.month - 1).clamp(0, 11)];
      } else {
        evoKey = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
      }

      if (!evolucionMap.containsKey(evoKey)) {
        evolucionMap[evoKey] = {'etiqueta': evoKey, 'ventas': 0.0, 'ganancia': 0.0, 'tickets': 0};
      }
      evolucionMap[evoKey]!['ventas'] = (evolucionMap[evoKey]!['ventas'] as double) + totalVenta;
      evolucionMap[evoKey]!['tickets'] = (evolucionMap[evoKey]!['tickets'] as int) + 1;

      // Clave exacta de día para tabla "Ventas por día" y "Pagos apilados por día"
      final diaKey = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      final diaEtiqueta = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
      final diaNombre = _nombreDiaSemana(fecha.weekday);

      // Desglose de Ventas por Día
      if (!diaVentasMap.containsKey(diaKey)) {
        diaVentasMap[diaKey] = {
          'fecha': DateTime(fecha.year, fecha.month, fecha.day),
          'diaNombre': diaNombre,
          'etiqueta': diaEtiqueta,
          'tickets': 0,
          'total': 0.0,
        };
      }
      diaVentasMap[diaKey]!['tickets'] = (diaVentasMap[diaKey]!['tickets'] as int) + 1;
      diaVentasMap[diaKey]!['total'] = (diaVentasMap[diaKey]!['total'] as double) + totalVenta;

      // Desglose de Pagos por Día para Gráfica de Barras Apiladas
      if (!diaPagosMap.containsKey(diaKey)) {
        diaPagosMap[diaKey] = {
          'fecha': DateTime(fecha.year, fecha.month, fecha.day),
          'etiqueta': diaEtiqueta,
          'metodos': <String, double>{},
          'total': 0.0,
        };
      }
      final pagosVenta = pagosPorVentaId[idV] ?? [];
      final mapMetodosDia = diaPagosMap[diaKey]!['metodos'] as Map<String, double>;
      for (final pv in pagosVenta) {
        final mNom = pv['metodo'] as String;
        final mNeto = pv['neto'] as double;
        mapMetodosDia[mNom] = (mapMetodosDia[mNom] ?? 0.0) + mNeto;
        diaPagosMap[diaKey]!['total'] = (diaPagosMap[diaKey]!['total'] as double) + mNeto;
      }

      double gananciaEstaVenta = 0.0;

      for (final d in detallesFiltrados) {
        final cant = parseDecimal(d['cantidad']);
        final imp = parseDecimal(d['importe']);
        final costo = parseDecimal(d['costo_unitario']);
        final g = imp - (cant * costo);
        gananciaEstaVenta += g;

        final prod = d['tbl_productos'] as Map?;
        final cod = (prod != null ? prod['codigo_barras'] : null)?.toString() ?? 'SIN-COD';
        final desc = (d['descripcion_producto'] ?? '').toString();

        String deptoNom = '- Sin Departamento -';
        if (prod != null && prod['tbl_departamentos'] is Map) {
          final nom = (prod['tbl_departamentos']['nombre_departamento'] ?? '').toString().trim();
          if (nom.isNotEmpty) deptoNom = nom;
        }

        // Departamentos: Ventas y Ganancias
        deptoVentasMap[deptoNom] = (deptoVentasMap[deptoNom] ?? 0.0) + imp;
        deptoGananciasMap[deptoNom] = (deptoGananciasMap[deptoNom] ?? 0.0) + g;

        // Productos
        final prodKey = '$cod|$desc';
        if (!prodMap.containsKey(prodKey)) {
          prodMap[prodKey] = _ProductoPopular(
            posicion: 0,
            codigoBarras: cod,
            descripcion: desc,
            departamento: deptoNom,
            cantidadVendida: cant,
            totalVendido: imp,
            ganancia: g,
          );
        } else {
          final prev = prodMap[prodKey]!;
          prodMap[prodKey] = _ProductoPopular(
            posicion: 0,
            codigoBarras: cod,
            descripcion: desc,
            departamento: deptoNom,
            cantidadVendida: prev.cantidadVendida + cant,
            totalVendido: prev.totalVendido + imp,
            ganancia: prev.ganancia + g,
          );
        }
      }

      gananciaTotal += gananciaEstaVenta;
      evolucionMap[evoKey]!['ganancia'] = (evolucionMap[evoKey]!['ganancia'] as double) + gananciaEstaVenta;

      if (idCliente != null && idCliente > 0) {
        gananciaClientesRegistrados += gananciaEstaVenta;
      }

      // Clientes Agrupados
      final clienteKey = idCliente != null && idCliente > 0 ? 'c_$idCliente' : 'publico_general';
      if (!clienteMap.containsKey(clienteKey)) {
        clienteMap[clienteKey] = {
          'id_cliente': idCliente,
          'nombre': clienteNom,
          'tickets': 1,
          'total': totalVenta,
          'ganancia': gananciaEstaVenta,
          'abonos': idCliente != null ? (abonosPorClienteMap[idCliente] ?? 0.0) : 0.0,
          'saldo_actual': saldoCliente,
          'ultima_compra': fecha,
        };
      } else {
        clienteMap[clienteKey]!['tickets'] = (clienteMap[clienteKey]!['tickets'] as int) + 1;
        clienteMap[clienteKey]!['total'] = (clienteMap[clienteKey]!['total'] as double) + totalVenta;
        clienteMap[clienteKey]!['ganancia'] = (clienteMap[clienteKey]!['ganancia'] as double) + gananciaEstaVenta;
      }
    }

    final ventaPromedio = numeroVentas > 0 ? ventasTotales / numeroVentas : 0.0;
    final margen = ventasTotales > 0 ? (gananciaTotal / ventasTotales) * 100 : 0.0;

    // Ordenar ranking de productos
    final sortedProds = prodMap.values.toList()
      ..sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
    final productosPopulares = <_ProductoPopular>[];
    for (int i = 0; i < sortedProds.length; i++) {
      final p = sortedProds[i];
      productosPopulares.add(_ProductoPopular(
        posicion: i + 1,
        codigoBarras: p.codigoBarras,
        descripcion: p.descripcion,
        departamento: p.departamento,
        cantidadVendida: p.cantidadVendida,
        totalVendido: p.totalVendido,
        ganancia: p.ganancia,
      ));
    }

    // Departamentos: Ventas y Porcentajes
    final totalDeptosVentas = deptoVentasMap.values.fold(0.0, (acc, v) => acc + v);
    final ventasPorDepartamento = deptoVentasMap.entries.map((e) {
      final pct = totalDeptosVentas > 0 ? (e.value / totalDeptosVentas) * 100 : 0.0;
      return {
        'nombre': e.key,
        'subtotal': e.value,
        'porcentaje': pct,
      };
    }).toList()
      ..sort((a, b) => (b['subtotal'] as double).compareTo(a['subtotal'] as double));

    // Departamentos: Ganancia y Porcentajes
    final totalDeptosGanancia = deptoGananciasMap.values.fold(0.0, (acc, v) => acc + v);
    final gananciaPorDepartamento = deptoGananciasMap.entries.map((e) {
      final pct = totalDeptosGanancia > 0 ? (e.value / totalDeptosGanancia) * 100 : 0.0;
      return {
        'nombre': e.key,
        'ganancia': e.value,
        'porcentaje': pct,
      };
    }).toList()
      ..sort((a, b) => (b['ganancia'] as double).compareTo(a['ganancia'] as double));

    // Ventas por día ordenadas cronológicamente
    final sortedDias = diaVentasMap.keys.toList()..sort();
    final ventasPorDia = sortedDias.map((k) {
      final m = diaVentasMap[k]!;
      return _DiaVentaResumen(
        fecha: m['fecha'] as DateTime,
        diaNombre: m['diaNombre'] as String,
        etiqueta: m['etiqueta'] as String,
        tickets: m['tickets'] as int,
        total: m['total'] as double,
      );
    }).toList();

    // Pagos apilados por día
    final sortedDiasPagos = diaPagosMap.keys.toList()..sort();
    final pagosPorDia = sortedDiasPagos.map((k) {
      final m = diaPagosMap[k]!;
      return _DiaPagoMetodo(
        fecha: m['fecha'] as DateTime,
        etiqueta: m['etiqueta'] as String,
        metodos: m['metodos'] as Map<String, double>,
        total: m['total'] as double,
      );
    }).toList();

    // Clientes ordenados por volumen comprado
    final clientesList = clienteMap.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    return _ResumenReporte(
      ventasTotales: ventasTotales,
      gananciaTotal: gananciaTotal,
      numeroVentas: numeroVentas,
      ventaPromedio: ventaPromedio,
      margenUtilidad: margen,
      creditosOtorgados: creditosOtorgados,
      abonosRecibidos: abonosRecibidos,
      totalIva: totalIva,
      ventasClientesRegistrados: ventasClientesRegistrados,
      ventasPublicoGeneral: ventasPublicoGeneral,
      gananciaClientesRegistrados: gananciaClientesRegistrados,
      saldoTotalPorCobrar: saldoTotalPorCobrar,
      ventasPorMetodo: metodosMap,
      ventasEvolucion: evolucionMap.values.toList(),
      ventasPorDia: ventasPorDia,
      pagosPorDia: pagosPorDia,
      productosPopulares: productosPopulares,
      ventasPorDepartamento: ventasPorDepartamento,
      gananciaPorDepartamento: gananciaPorDepartamento,
      ventasPorCliente: clientesList,
    );
  }

  /// Consulta agregada contra PostgreSQL local
  Future<_ResumenReporte> _obtenerResumenLocal({
    required String desdeStr,
    required String hastaStr,
    required DateTime desde,
    required DateTime hasta,
    int? idUsuario,
    int? idDepartamento,
    required String periodoTipo,
  }) async {
    String whereExtra = '';
    final params = <String, dynamic>{'desde': desdeStr, 'hasta': hastaStr};

    if (idUsuario != null && idUsuario > 0) {
      whereExtra += ' AND v.id_usuario = @idUser';
      params['idUser'] = idUsuario;
    }
    if (idDepartamento != null && idDepartamento > 0) {
      whereExtra += ' AND p.id_departamento = @idDepto';
      params['idDepto'] = idDepartamento;
    }

    // 1. KPIs Generales
    final resKpi = await _db.query('''
      SELECT
        COUNT(DISTINCT v.id_venta) AS num_ventas,
        COALESCE(SUM(v.total), 0)  AS total_ventas,
        COALESCE(SUM(v.iva), 0)    AS total_iva,
        COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia,
        COALESCE(SUM(CASE WHEN v.es_credito = TRUE THEN v.total ELSE 0 END), 0) AS creditos,
        COALESCE(SUM(CASE WHEN v.id_cliente IS NOT NULL THEN v.total ELSE 0 END), 0) AS ventas_clientes,
        COALESCE(SUM(CASE WHEN v.id_cliente IS NULL THEN v.total ELSE 0 END), 0) AS ventas_publico,
        COALESCE(SUM(CASE WHEN v.id_cliente IS NOT NULL THEN dv.importe - dv.cantidad * dv.costo_unitario ELSE 0 END), 0) AS ganancia_clientes
      FROM tbl_ventas v
      LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
      LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        $whereExtra
    ''', params: params);

    final kpi = resKpi.isNotEmpty ? resKpi.first.toColumnMap() : <String, dynamic>{};
    final totalVentas = parseDecimal(kpi['total_ventas']);
    final totalIva = parseDecimal(kpi['total_iva']);
    final ganancia = parseDecimal(kpi['ganancia']);
    final numVentas = parseIntSafe(kpi['num_ventas']);
    final creditos = parseDecimal(kpi['creditos']);
    final ventasClientes = parseDecimal(kpi['ventas_clientes']);
    final ventasPublico = parseDecimal(kpi['ventas_publico']);
    final gananciaClientes = parseDecimal(kpi['ganancia_clientes']);

    final ventaPromedio = numVentas > 0 ? totalVentas / numVentas : 0.0;
    final margen = totalVentas > 0 ? (ganancia / totalVentas) * 100 : 0.0;

    // 2. Abonos en el periodo y saldo total por cobrar
    final resAbonos = await _db.query('''
      SELECT COALESCE(SUM(monto), 0) AS abonos
      FROM tbl_abonos_clientes
      WHERE fecha_registro BETWEEN @desde AND @hasta
      ${idUsuario != null && idUsuario > 0 ? ' AND id_usuario = @idUser' : ''}
    ''', params: params);
    final abonos = parseDecimal(resAbonos.isNotEmpty ? resAbonos.first.toColumnMap()['abonos'] : 0);

    final resSaldo = await _db.query('''
      SELECT COALESCE(SUM(saldo_actual), 0) AS saldo_total
      FROM tbl_clientes
      WHERE estatus::text = 'Activo'
    ''');
    final saldoTotalPorCobrar = parseDecimal(resSaldo.isNotEmpty ? resSaldo.first.toColumnMap()['saldo_total'] : 0);

    // 3. Ventas por método de pago (CORRECCIÓN CRÍTICA: SUM(monto - cambio))
    final resPago = await _db.query('''
      SELECT fp.nombre_forma_pago,
             COALESCE(SUM(pv.monto - COALESCE(pv.cambio, 0)), 0) AS subtotal
      FROM tbl_pagos_venta pv
      JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
      JOIN tbl_ventas v ON pv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        ${idUsuario != null && idUsuario > 0 ? ' AND v.id_usuario = @idUser' : ''}
      GROUP BY fp.nombre_forma_pago
      ORDER BY subtotal DESC
    ''', params: params);

    final metodosMap = <String, double>{};
    for (final r in resPago) {
      final m = r.toColumnMap();
      metodosMap[parsePgString(m['nombre_forma_pago'])] = parseDecimal(m['subtotal']);
    }

    // 4. Evolución Ventas vs Ganancia
    final esAnio = periodoTipo == 'Año actual';
    final sqlEvo = esAnio
        ? '''
          SELECT TO_CHAR(v.fecha_venta, 'Mon') AS etiqueta,
                 DATE_TRUNC('month', v.fecha_venta) AS periodo,
                 COALESCE(SUM(v.total), 0) AS ventas,
                 COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
          FROM tbl_ventas v
          LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
          LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
          WHERE v.fecha_venta BETWEEN @desde AND @hasta
            AND v.estatus_venta::text = 'Completada'
            $whereExtra
          GROUP BY TO_CHAR(v.fecha_venta, 'Mon'), DATE_TRUNC('month', v.fecha_venta)
          ORDER BY periodo ASC
        '''
        : '''
          SELECT TO_CHAR(v.fecha_venta, 'DD/MM') AS etiqueta,
                 DATE(v.fecha_venta) AS periodo,
                 COALESCE(SUM(v.total), 0) AS ventas,
                 COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
          FROM tbl_ventas v
          LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
          LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
          WHERE v.fecha_venta BETWEEN @desde AND @hasta
            AND v.estatus_venta::text = 'Completada'
            $whereExtra
          GROUP BY TO_CHAR(v.fecha_venta, 'DD/MM'), DATE(v.fecha_venta)
          ORDER BY periodo ASC
        ''';

    final resEvo = await _db.query(sqlEvo, params: params);
    final evolucionList = resEvo.map((r) {
      final m = r.toColumnMap();
      return {
        'etiqueta': parsePgString(m['etiqueta']),
        'ventas': parseDecimal(m['ventas']),
        'ganancia': parseDecimal(m['ganancia']),
      };
    }).toList();

    // 5. Ventas por Día (Desglose tabular)
    final resDias = await _db.query('''
      SELECT DATE(v.fecha_venta) AS fecha,
             TO_CHAR(v.fecha_venta, 'DD/MM') AS etiqueta,
             COUNT(DISTINCT v.id_venta) AS tickets,
             COALESCE(SUM(v.total), 0) AS total
      FROM tbl_ventas v
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        ${idUsuario != null && idUsuario > 0 ? ' AND v.id_usuario = @idUser' : ''}
      GROUP BY DATE(v.fecha_venta), TO_CHAR(v.fecha_venta, 'DD/MM')
      ORDER BY fecha ASC
    ''', params: params);

    final ventasPorDia = resDias.map((r) {
      final m = r.toColumnMap();
      final f = parseDateTime(m['fecha']);
      return _DiaVentaResumen(
        fecha: f,
        diaNombre: _nombreDiaSemana(f.weekday),
        etiqueta: parsePgString(m['etiqueta']),
        tickets: parseIntSafe(m['tickets']),
        total: parseDecimal(m['total']),
      );
    }).toList();

    // 6. Pagos apilados por día
    final resPagosDia = await _db.query('''
      SELECT DATE(v.fecha_venta) AS fecha,
             TO_CHAR(v.fecha_venta, 'DD/MM') AS etiqueta,
             fp.nombre_forma_pago,
             COALESCE(SUM(pv.monto - COALESCE(pv.cambio, 0)), 0) AS subtotal
      FROM tbl_pagos_venta pv
      JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
      JOIN tbl_ventas v ON pv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        ${idUsuario != null && idUsuario > 0 ? ' AND v.id_usuario = @idUser' : ''}
      GROUP BY DATE(v.fecha_venta), TO_CHAR(v.fecha_venta, 'DD/MM'), fp.nombre_forma_pago
      ORDER BY fecha ASC
    ''', params: params);

    final Map<String, _DiaPagoMetodo> pagosDiaMap = {};
    for (final r in resPagosDia) {
      final m = r.toColumnMap();
      final fecha = parseDateTime(m['fecha']);
      final key = parsePgString(m['etiqueta']);
      final fpNom = parsePgString(m['nombre_forma_pago']);
      final sub = parseDecimal(m['subtotal']);

      if (!pagosDiaMap.containsKey(key)) {
        pagosDiaMap[key] = _DiaPagoMetodo(
          fecha: fecha,
          etiqueta: key,
          metodos: {fpNom: sub},
          total: sub,
        );
      } else {
        final prev = pagosDiaMap[key]!;
        final newMap = Map<String, double>.from(prev.metodos);
        newMap[fpNom] = (newMap[fpNom] ?? 0.0) + sub;
        pagosDiaMap[key] = _DiaPagoMetodo(
          fecha: prev.fecha,
          etiqueta: prev.etiqueta,
          metodos: newMap,
          total: prev.total + sub,
        );
      }
    }

    // 7. Ranking Productos Populares
    final resProds = await _db.query('''
      SELECT p.codigo_barras, dv.descripcion_producto,
             COALESCE(d.nombre_departamento, '- Sin Departamento -') AS depto,
             COALESCE(SUM(dv.cantidad), 0) AS cantidad_vendida,
             COALESCE(SUM(dv.importe), 0)  AS total_vendido,
             COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        $whereExtra
      GROUP BY p.codigo_barras, dv.descripcion_producto, d.nombre_departamento
      ORDER BY total_vendido DESC
      LIMIT 100
    ''', params: params);

    final productosPopulares = <_ProductoPopular>[];
    for (int i = 0; i < resProds.length; i++) {
      final m = resProds[i].toColumnMap();
      productosPopulares.add(_ProductoPopular(
        posicion: i + 1,
        codigoBarras: parsePgString(m['codigo_barras']),
        descripcion: parsePgString(m['descripcion_producto']),
        departamento: parsePgString(m['depto']),
        cantidadVendida: parseDecimal(m['cantidad_vendida']),
        totalVendido: parseDecimal(m['total_vendido']),
        ganancia: parseDecimal(m['ganancia']),
      ));
    }

    // 8. Ventas y Ganancias por Departamento
    final resDept = await _db.query('''
      SELECT COALESCE(d.nombre_departamento, '- Sin Departamento -') AS depto,
             COALESCE(SUM(dv.importe), 0) AS subtotal,
             COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        ${idUsuario != null && idUsuario > 0 ? ' AND v.id_usuario = @idUser' : ''}
      GROUP BY d.nombre_departamento
      ORDER BY subtotal DESC
    ''', params: params);

    final totalD = resDept.fold(0.0, (acc, r) => acc + parseDecimal(r.toColumnMap()['subtotal']));
    final totalG = resDept.fold(0.0, (acc, r) => acc + parseDecimal(r.toColumnMap()['ganancia']));

    final deptListVentas = resDept.map((r) {
      final m = r.toColumnMap();
      final sub = parseDecimal(m['subtotal']);
      final pct = totalD > 0 ? (sub / totalD) * 100 : 0.0;
      return {
        'nombre': parsePgString(m['depto'], defaultValue: '- Sin Departamento -'),
        'subtotal': sub,
        'porcentaje': pct,
      };
    }).toList();

    final deptListGanancias = List<Map<String, dynamic>>.from(resDept.map((r) {
      final m = r.toColumnMap();
      final g = parseDecimal(m['ganancia']);
      final pct = totalG > 0 ? (g / totalG) * 100 : 0.0;
      return {
        'nombre': parsePgString(m['depto'], defaultValue: '- Sin Departamento -'),
        'ganancia': g,
        'porcentaje': pct,
      };
    }))..sort((a, b) => (b['ganancia'] as double).compareTo(a['ganancia'] as double));

    // 9. Ventas por Cliente Detalladas
    final resCliente = await _db.query('''
      SELECT c.id_cliente,
             COALESCE(c.nombre, 'Público General') AS nombre,
             COUNT(DISTINCT v.id_venta) AS tickets,
             COALESCE(SUM(v.total), 0) AS total_ventas,
             COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia,
             COALESCE(c.saldo_actual, 0) AS saldo_actual,
             COALESCE((
               SELECT SUM(monto) FROM tbl_abonos_clientes a
               WHERE a.id_cliente = c.id_cliente
                 AND a.fecha_registro BETWEEN @desde AND @hasta
             ), 0) AS abonos_periodo
      FROM tbl_ventas v
      LEFT JOIN tbl_clientes c ON v.id_cliente = c.id_cliente
      LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
        $whereExtra
      GROUP BY c.id_cliente, c.nombre, c.saldo_actual
      ORDER BY total_ventas DESC
      LIMIT 100
    ''', params: params);

    final clientesList = resCliente.map((r) {
      final m = r.toColumnMap();
      return {
        'id_cliente': m['id_cliente'],
        'nombre': parsePgString(m['nombre'], defaultValue: 'Público General'),
        'tickets': parseIntSafe(m['tickets']),
        'total': parseDecimal(m['total_ventas']),
        'ganancia': parseDecimal(m['ganancia']),
        'abonos': parseDecimal(m['abonos_periodo']),
        'saldo_actual': parseDecimal(m['saldo_actual']),
      };
    }).toList();

    return _ResumenReporte(
      ventasTotales: totalVentas,
      gananciaTotal: ganancia,
      numeroVentas: numVentas,
      ventaPromedio: ventaPromedio,
      margenUtilidad: margen,
      creditosOtorgados: creditos,
      abonosRecibidos: abonos,
      totalIva: totalIva,
      ventasClientesRegistrados: ventasClientes,
      ventasPublicoGeneral: ventasPublico,
      gananciaClientesRegistrados: gananciaClientes,
      saldoTotalPorCobrar: saldoTotalPorCobrar,
      ventasPorMetodo: metodosMap,
      ventasEvolucion: evolucionList,
      ventasPorDia: ventasPorDia,
      pagosPorDia: pagosDiaMap.values.toList(),
      productosPopulares: productosPopulares,
      ventasPorDepartamento: deptListVentas,
      gananciaPorDepartamento: deptListGanancias,
      ventasPorCliente: clientesList,
    );
  }
}

// ──────────────────────────── VISTA PRINCIPAL ──────────────────────────────

class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  String _subOpcion = 'ventas'; // 'ventas' | 'clientes'
  String _periodoSeleccionado = 'Semana actual';
  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  int? _filtroCajeroId;
  int? _filtroDepartamentoId;

  List<Map<String, dynamic>> _cajerosDisponibles = [];
  List<Map<String, dynamic>> _departamentosDisponibles = [];

  bool _cargando = true;
  String? _error;
  _ResumenReporte _resumen = const _ResumenReporte();

  // Ordenamiento en Ranking de Productos Populares ('unidades' | 'ingresos')
  String _ordenRanking = 'unidades';

  late final _ReportesDB _repo;
  final _buscarClienteCtrl = TextEditingController();
  String _filtroCliente = '';

  @override
  void initState() {
    super.initState();
    _repo = _ReportesDB(DatabaseService.instance);
    _establecerFechasPorPeriodo('Semana actual');
    _cargarCatalogosFiltros();
  }

  @override
  void dispose() {
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogosFiltros() async {
    try {
      final users = await UsuariosRepository.instance.obtenerTodos();
      final deptos = await CatalogosRepository.instance.obtenerDepartamentos();
      if (mounted) {
        setState(() {
          _cajerosDisponibles = users.map((u) => {
            'id': u.idUsuario,
            'nombre': u.nombreCompleto.isNotEmpty ? u.nombreCompleto : u.nombreUsuario,
          }).toList();

          _departamentosDisponibles = deptos.map((d) => {
            'id': d.idDepartamento,
            'nombre': d.nombreDepartamento,
          }).toList();
        });
      }
    } catch (_) {}
  }

  void _establecerFechasPorPeriodo(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoSeleccionado = periodo;
      switch (periodo) {
        case 'Semana actual':
          _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: hoy.weekday - 1));
          _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
        case 'Mes actual':
          _fechaInicio = DateTime(hoy.year, hoy.month, 1);
          _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
        case 'Mes anterior':
          _fechaInicio = DateTime(hoy.year, hoy.month - 1, 1);
          _fechaFin = DateTime(hoy.year, hoy.month, 0, 23, 59, 59);
        case 'Año actual':
          _fechaInicio = DateTime(hoy.year, 1, 1);
          _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
        default:
          break;
      }
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final r = await _repo.obtenerResumen(
        desde: _fechaInicio,
        hasta: _fechaFin,
        idUsuario: _filtroCajeroId,
        idDepartamento: _filtroDepartamentoId,
        periodoTipo: _periodoSeleccionado,
      );
      if (mounted) {
        setState(() {
          _resumen = r;
          _cargando = false;
        });
      }
    } catch (e, st) {
      dev.log('[ReportesView] Error: $e', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _navegarPeriodo(int paso) {
    setState(() {
      if (_periodoSeleccionado == 'Semana actual') {
        _fechaInicio = _fechaInicio.add(Duration(days: 7 * paso));
        _fechaFin = _fechaFin.add(Duration(days: 7 * paso));
      } else if (_periodoSeleccionado == 'Mes actual' || _periodoSeleccionado == 'Mes anterior') {
        final nuevoI = DateTime(_fechaInicio.year, _fechaInicio.month + paso, 1);
        _fechaInicio = nuevoI;
        _fechaFin = DateTime(nuevoI.year, nuevoI.month + 1, 0, 23, 59, 59);
      } else if (_periodoSeleccionado == 'Año actual') {
        final anio = _fechaInicio.year + paso;
        _fechaInicio = DateTime(anio, 1, 1);
        _fechaFin = DateTime(anio, 12, 31, 23, 59, 59);
      }
    });
    _cargarDatos();
  }

  String _fm(double v) => '\$${v.toStringAsFixed(2)}';

  String _rangoFechasTexto() =>
      '${_fechaInicio.day.toString().padLeft(2, '0')}/${_fechaInicio.month.toString().padLeft(2, '0')}/${_fechaInicio.year}'
      ' — ${_fechaFin.day.toString().padLeft(2, '0')}/${_fechaFin.month.toString().padLeft(2, '0')}/${_fechaFin.year}';

  // ── DIALOGO PERIODO PERSONALIZADO ──
  void _mostrarDialogoPorPeriodo() {
    DateTime tempI = _fechaInicio;
    DateTime tempF = _fechaFin;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMod) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.date_range_rounded, color: AppColors.reportesIcon),
              SizedBox(width: 8),
              Text('Seleccionar Período Personalizado'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rango de fechas para el reporte:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: tempI,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) setMod(() => tempI = p);
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text('Desde: ${tempI.day}/${tempI.month}/${tempI.year}',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: tempF,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) setMod(() => tempF = p);
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text('Hasta: ${tempF.day}/${tempF.month}/${tempF.year}',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.reportesIcon,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Aplicar'),
              onPressed: () {
                setState(() {
                  _fechaInicio = tempI;
                  _fechaFin = tempF;
                  _periodoSeleccionado = 'Por periodo';
                });
                Navigator.pop(ctx);
                _cargarDatos();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBarraSubPestanas(),
        // La barra de filtros de periodo aplica a ambas sub-pestañas
        _buildBarraFiltrosPeriodo(),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: AppColors.reportesIcon))
              : _error != null
                  ? _buildErrorWidget()
                  : _subOpcion == 'ventas'
                      ? _buildContenidoReporteVentas()
                      : _buildContenidoVentasPorCliente(),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Error al cargar reporte', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ── 1. BARRA SUPERIOR DE SUB-PESTAÑAS ──
  Widget _buildBarraSubPestanas() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          _buildBotonSubPestana(
            id: 'ventas',
            titulo: 'Reporte de Ventas y Finanzas',
            icono: Icons.insights_rounded,
          ),
          const SizedBox(width: 8),
          _buildBotonSubPestana(
            id: 'clientes',
            titulo: 'Ventas por Cliente',
            icono: Icons.people_outline_rounded,
          ),
          const Spacer(),
          if (DatabaseService.instance.isCloudOnlyMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_rounded, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Modo Nube (Supabase)', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar reporte',
            onPressed: _cargarDatos,
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonSubPestana({
    required String id,
    required String titulo,
    required IconData icono,
  }) {
    final bool sel = _subOpcion == id;
    return InkWell(
      onTap: () => setState(() => _subOpcion = id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFF1F3F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? const Color(0xFFCBD5E1) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: sel ? AppColors.reportesIcon : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? AppColors.textPrimary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── A. BARRA DE FILTROS DE PERÍODO (5 OPCIONES EXACTAS + FILTROS OPCIONALES) ──
  Widget _buildBarraFiltrosPeriodo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reporte: $_periodoSeleccionado',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 14, color: AppColors.reportesIcon),
                    const SizedBox(width: 6),
                    Text(
                      _rangoFechasTexto(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_periodoSeleccionado != 'Por periodo') ...[
                _buildBotonNav(Icons.chevron_left_rounded, -1),
                const SizedBox(width: 6),
                _buildBotonNav(Icons.chevron_right_rounded, 1),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 5 OPCIONES EXACTAS
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPeriodoChip('Semana actual', Icons.calendar_view_week_rounded),
                  _buildPeriodoChip('Mes actual', Icons.calendar_view_month_rounded),
                  _buildPeriodoChip('Mes anterior', Icons.history_rounded),
                  _buildPeriodoChip('Año actual', Icons.calendar_today_rounded),
                  _buildPeriodoChip('Por periodo', Icons.tune_rounded, esPersonalizado: true),
                ],
              ),
              const Spacer(),
              // FILTRO OPCIONAL POR CAJERO
              SizedBox(
                width: 170,
                height: 34,
                child: DropdownButtonFormField<int?>(
                  value: _filtroCajeroId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    labelText: 'Cajero',
                    labelStyle: TextStyle(fontSize: 11),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos los cajeros', style: TextStyle(fontSize: 12)),
                    ),
                    ..._cajerosDisponibles.map((c) => DropdownMenuItem<int?>(
                      value: c['id'] as int,
                      child: Text(c['nombre'] as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() => _filtroCajeroId = val);
                    _cargarDatos();
                  },
                ),
              ),
              if (_subOpcion == 'ventas') ...[
                const SizedBox(width: 10),
                // FILTRO OPCIONAL POR DEPARTAMENTO
                SizedBox(
                  width: 180,
                  height: 34,
                  child: DropdownButtonFormField<int?>(
                    value: _filtroDepartamentoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      labelText: 'Departamento',
                      labelStyle: TextStyle(fontSize: 11),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos los deptos.', style: TextStyle(fontSize: 12)),
                      ),
                      ..._departamentosDisponibles.map((d) => DropdownMenuItem<int?>(
                        value: d['id'] as int,
                        child: Text(d['nombre'] as String, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() => _filtroDepartamentoId = val);
                      _cargarDatos();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonNav(IconData icono, int paso) {
    return Tooltip(
      message: paso < 0 ? 'Período anterior' : 'Período siguiente',
      child: InkWell(
        onTap: () => _navegarPeriodo(paso),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(4),
            color: const Color(0xFFF8FAFC),
          ),
          child: Icon(icono, size: 18, color: const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildPeriodoChip(String id, IconData icono, {bool esPersonalizado = false}) {
    final bool activo = _periodoSeleccionado == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (esPersonalizado) {
            _mostrarDialogoPorPeriodo();
          } else {
            _establecerFechasPorPeriodo(id);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: activo ? AppColors.reportesIcon : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo ? AppColors.reportesIcon : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: AppColors.reportesIcon.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 14, color: activo ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                id,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                  color: activo ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONTENIDO PRINCIPAL: REPORTES DE VENTAS Y FINANZAS ──
  Widget _buildContenidoReporteVentas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // B. TARJETAS KPI RESUMEN
          _buildTarjetasKPI(),
          const SizedBox(height: 20),

          // C.1 GRÁFICA DE BARRAS — EVOLUCIÓN DE VENTAS Y GANANCIAS
          _buildGraficaEvolucionVentasGanancias(),
          const SizedBox(height: 20),

          // C. DEPARTAMENTOS: VENTAS (IZQ) Y GANANCIAS (DER)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCardGraficaDona(
                  titulo: 'Distribución (Ventas) por Departamento',
                  subtitulo: 'Ventas acumuladas por rubro',
                  icono: Icons.category_rounded,
                  segmentos: _generarSegmentosDepartamentosVentas(),
                  totalTexto: _fm(_resumen.ventasTotales),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildCardGraficaDona(
                  titulo: 'Ganancia por Departamento',
                  subtitulo: 'Ganancia neta acumulada por rubro',
                  icono: Icons.savings_rounded,
                  segmentos: _generarSegmentosDepartamentosGanancias(),
                  totalTexto: _fm(_resumen.gananciaTotal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // FILA 2: VENTAS POR DÍA (IZQ) Y VENTAS POR FORMA DE PAGO + IVA (DER)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLUMNA IZQUIERDA: A. VENTAS POR DÍA (TABLA DESGLOSADA)
              Expanded(
                flex: 5,
                child: _buildCardVentasPorDia(),
              ),
              const SizedBox(width: 20),

              // COLUMNA DERECHA: B. FORMAS DE PAGO (BARRAS APILADAS + DONA + LISTA) + D. IMPUESTOS (IVA)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildCardVentasPorFormaPagoCompleta(),
                    const SizedBox(height: 16),
                    _buildCardImpuestosIva(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // D. RANKING DE PRODUCTOS MÁS POPULARES / MÁS VENDIDOS
          _buildSeccionProductosPopulares(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── B. TARJETAS KPI RESUMEN ──
  Widget _buildTarjetasKPI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (3 * 16)) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            // KPI 1: Ventas Totales
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Ventas Totales',
              valor: _fm(_resumen.ventasTotales),
              subtitulo: 'Periodo seleccionado',
              icono: Icons.point_of_sale_rounded,
              colorIcono: const Color(0xFF2563EB),
              colorFondo: const Color(0xFFEFF6FF),
            ),
            // KPI 2: Ganancia Neta y Margen
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Ganancia Neta',
              valor: _fm(_resumen.gananciaTotal),
              subtitulo: 'Margen: ${_resumen.margenUtilidad.toStringAsFixed(1)}% de utilidad',
              icono: Icons.trending_up_rounded,
              colorIcono: const Color(0xFF059669),
              colorFondo: const Color(0xFFECFDF5),
            ),
            // KPI 3: Tickets y Ticket Promedio
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Tickets Realizados',
              valor: '${_resumen.numeroVentas}',
              subtitulo: 'Promedio: ${_fm(_resumen.ventaPromedio)} / ticket',
              icono: Icons.receipt_long_rounded,
              colorIcono: const Color(0xFF7C3AED),
              colorFondo: const Color(0xFFF5F3FF),
            ),
            // KPI 4: Créditos y Abonos
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Créditos y Abonos',
              valor: _fm(_resumen.creditosOtorgados),
              subtitulo: 'Abonos recibidos: ${_fm(_resumen.abonosRecibidos)}',
              icono: Icons.account_balance_wallet_rounded,
              colorIcono: const Color(0xFFD97706),
              colorFondo: const Color(0xFFFFFBEB),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String titulo,
    required String valor,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
    required Color colorFondo,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: colorIcono, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── C.1 GRÁFICA DE BARRAS: EVOLUCIÓN VENTAS VS GANANCIAS ──
  Widget _buildGraficaEvolucionVentasGanancias() {
    final datos = _resumen.ventasEvolucion;
    double maxValor = 0.0;
    for (final d in datos) {
      final v = (d['ventas'] as num).toDouble();
      final g = (d['ganancia'] as num).toDouble();
      if (v > maxValor) maxValor = v;
      if (g > maxValor) maxValor = g;
    }
    if (maxValor <= 0) maxValor = 100.0;
    final escalaMax = maxValor * 1.2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppColors.reportesIcon, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Evolución de Ventas y Ganancias',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              _buildLeyendaItem(const Color(0xFF3B82F6), 'Ventas Totales'),
              const SizedBox(width: 14),
              _buildLeyendaItem(const Color(0xFF10B981), 'Ganancia Neta'),
            ],
          ),
          const SizedBox(height: 16),

          if (datos.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text('- Sin ventas registradas en este periodo -',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fm(escalaMax), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(_fm(escalaMax * 0.66), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(_fm(escalaMax * 0.33), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const Text('\$0.00', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 18),
                    ],
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1.5, color: const Color(0xFFCBD5E1)),
                            const SizedBox(height: 18),
                          ],
                        ),

                        Positioned.fill(
                          bottom: 0,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: datos.map((d) {
                                final v = (d['ventas'] as num).toDouble();
                                final g = (d['ganancia'] as num).toDouble();
                                final etiqueta = d['etiqueta'].toString();

                                const maxBarHeight = 180.0;
                                final hVentas = ((v / escalaMax) * maxBarHeight).clamp(4.0, maxBarHeight);
                                final hGanancia = ((g / escalaMax) * maxBarHeight).clamp(4.0, maxBarHeight);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Tooltip(
                                            message: '$etiqueta\nVentas: ${_fm(v)}',
                                            child: Container(
                                              width: 18,
                                              height: hVentas,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  topRight: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Tooltip(
                                            message: '$etiqueta\nGanancia: ${_fm(g)}',
                                            child: Container(
                                              width: 18,
                                              height: hGanancia,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  topRight: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 44,
                                        child: Text(
                                          etiqueta,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ],
    );
  }

  // ── SECCIÓN A: VENTAS POR DÍA (TABLA DESGLOSADA) ──
  Widget _buildCardVentasPorDia() {
    final dias = _resumen.ventasPorDia;
    final totalTickets = dias.fold(0, (acc, d) => acc + d.tickets);
    final totalMonto = dias.fold(0.0, (acc, d) => acc + d.total);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppColors.reportesIcon, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ventas por día', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text('Desglose de actividad por fecha en el periodo', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (dias.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Text('- Sin actividad registrada en este periodo -',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Día / Fecha', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('Tickets', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        Expanded(flex: 3, child: Text('Total Vendido', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: dias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final d = dias[index];
                        final esPar = index % 2 == 0;
                        return Container(
                          color: esPar ? Colors.white : const Color(0xFFFAFAFA),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('${d.diaNombre} ${d.etiqueta}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${d.tickets}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(_fm(d.total),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Fila final con Total
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border(top: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                        Expanded(flex: 2, child: Text('$totalTickets', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                        Expanded(flex: 3, child: Text(_fm(totalMonto), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.reportesIcon))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SECCIÓN B: VENTAS POR FORMA DE PAGO COMPLETA (BARRAS APILADAS + DONA + LISTA) ──
  Widget _buildCardVentasPorFormaPagoCompleta() {
    final metodos = _resumen.ventasPorMetodo;
    final totalMetodos = metodos.values.fold(0.0, (acc, v) => acc + v);
    final segmentos = _generarSegmentosFormasPago();
    final bool vacio = metodos.isEmpty || totalMetodos <= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_rounded, color: AppColors.reportesIcon, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ventas por Forma de Pago', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text('Ingresos netos reales recibidos por método (monto - cambio)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (vacio)
            Container(
              height: 170,
              alignment: Alignment.center,
              child: Text('- Sin pagos registrados en este periodo -', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else ...[
            // Gráfica de Barras Apiladas por Día (si hay días registrados)
            if (_resumen.pagosPorDia.isNotEmpty) ...[
              _buildBarrasApiladasPorDia(),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
            ],

            // Dona + Leyenda / Lista Desglosada
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _MultiDonutChartPainter(segmentos: segmentos, strokeWidth: 20),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total Neto', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          Text(_fm(totalMetodos), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),

                // Lista Resumen con total neto de cada forma de pago
                Expanded(
                  child: Column(
                    children: segmentos.map((s) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.label,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${s.porcentaje.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fm(s.value),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Gráfica interactiva de Barras Apiladas por Día para Formas de Pago
  Widget _buildBarrasApiladasPorDia() {
    final pagosDia = _resumen.pagosPorDia;
    double maxDia = 0.0;
    for (final p in pagosDia) {
      if (p.total > maxDia) maxDia = p.total;
    }
    if (maxDia <= 0) maxDia = 100.0;
    final escalaMax = maxDia * 1.15;

    final colorMap = {
      'efectivo': const Color(0xFF10B981),
      'tarjeta': const Color(0xFF3B82F6),
      'crédito': const Color(0xFFF59E0B),
      'credito': const Color(0xFFF59E0B),
      'transferencia': const Color(0xFF8B5CF6),
      'vales': const Color(0xFFEC4899),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingresos diarios por método (Barras apiladas)',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: pagosDia.map((dia) {
                const maxH = 80.0;
                final hTotal = ((dia.total / escalaMax) * maxH).clamp(4.0, maxH);

                // Tooltip enriquecido
                final buffer = StringBuffer('${dia.etiqueta} - Total: ${_fm(dia.total)}\n');
                dia.metodos.forEach((k, v) {
                  if (v > 0) buffer.writeln('• $k: ${_fm(v)}');
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: buffer.toString().trim(),
                        child: Container(
                          width: 20,
                          height: hTotal,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: Column(
                            verticalDirection: VerticalDirection.up,
                            children: dia.metodos.entries.map((e) {
                              final metodoNeto = e.value;
                              if (dia.total <= 0 || metodoNeto <= 0) return const SizedBox.shrink();
                              final segHeight = (metodoNeto / dia.total) * hTotal;
                              final c = colorMap[e.key.toLowerCase().trim()] ?? const Color(0xFF64748B);
                              return Container(
                                width: 20,
                                height: segHeight,
                                color: c,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(dia.etiqueta, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── SECCIÓN D: TARJETA IMPUESTOS (IVA) ──
  Widget _buildCardImpuestosIva() {
    final tieneIva = _resumen.totalIva > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: tieneIva ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt_outlined, color: tieneIva ? const Color(0xFFD97706) : const Color(0xFF94A3B8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Impuestos (IVA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                if (tieneIva)
                  Text('IVA Trasladado en el periodo: ${_fm(_resumen.totalIva)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)))
                else
                  const Text('- No se registraron impuestos en este periodo -',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── C.2 & C.3 GRÁFICAS DE PASTEL / DONA PERSONALIZADAS ──

  List<_DonutSegment> _generarSegmentosDepartamentosVentas() {
    final colores = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFF6366F1),
      const Color(0xFF64748B),
    ];

    final deptos = _resumen.ventasPorDepartamento;
    final list = <_DonutSegment>[];
    for (int i = 0; i < deptos.length; i++) {
      final d = deptos[i];
      final color = colores[i % colores.length];
      list.add(_DonutSegment(
        label: d['nombre'].toString(),
        value: parseDecimal(d['subtotal']),
        color: color,
        porcentaje: parseDecimal(d['porcentaje']),
      ));
    }
    return list;
  }

  List<_DonutSegment> _generarSegmentosDepartamentosGanancias() {
    final colores = [
      const Color(0xFF10B981),
      const Color(0xFF059669),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFF475569),
    ];

    final deptos = _resumen.gananciaPorDepartamento;
    final list = <_DonutSegment>[];
    for (int i = 0; i < deptos.length; i++) {
      final d = deptos[i];
      final color = colores[i % colores.length];
      list.add(_DonutSegment(
        label: d['nombre'].toString(),
        value: parseDecimal(d['ganancia']),
        color: color,
        porcentaje: parseDecimal(d['porcentaje']),
      ));
    }
    return list;
  }

  List<_DonutSegment> _generarSegmentosFormasPago() {
    final colorMap = {
      'efectivo': const Color(0xFF10B981),
      'tarjeta': const Color(0xFF3B82F6),
      'crédito': const Color(0xFFF59E0B),
      'credito': const Color(0xFFF59E0B),
      'transferencia': const Color(0xFF8B5CF6),
      'vales': const Color(0xFFEC4899),
    };

    final metodos = _resumen.ventasPorMetodo;
    final total = metodos.values.fold(0.0, (acc, v) => acc + v);
    final list = <_DonutSegment>[];

    int idx = 0;
    metodos.forEach((nombre, monto) {
      final key = nombre.toLowerCase().trim();
      final color = colorMap[key] ?? [
        const Color(0xFF14B8A6),
        const Color(0xFF6366F1),
        const Color(0xFF64748B),
      ][idx % 3];
      final pct = total > 0 ? (monto / total) * 100 : 0.0;
      list.add(_DonutSegment(
        label: nombre,
        value: monto,
        color: color,
        porcentaje: pct,
      ));
      idx++;
    });
    return list;
  }

  Widget _buildCardGraficaDona({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required List<_DonutSegment> segmentos,
    required String totalTexto,
  }) {
    final bool vacio = segmentos.isEmpty || segmentos.every((s) => s.value <= 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: AppColors.reportesIcon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text(subtitulo, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (vacio)
            Container(
              height: 170,
              alignment: Alignment.center,
              child: Text('- Sin datos para graficar -', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(140, 140),
                        painter: _MultiDonutChartPainter(segmentos: segmentos, strokeWidth: 22),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          Text(totalTexto, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  child: SizedBox(
                    height: 150,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: segmentos.map((s) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${s.porcentaje.toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _fm(s.value),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── D. RANKING DE PRODUCTOS MÁS POPULARES / MÁS VENDIDOS ──
  Widget _buildSeccionProductosPopulares() {
    final prods = List<_ProductoPopular>.from(_resumen.productosPopulares);
    if (_ordenRanking == 'unidades') {
      prods.sort((a, b) => b.cantidadVendida.compareTo(a.cantidadVendida));
    } else {
      prods.sort((a, b) => b.totalVendido.compareTo(a.totalVendido));
    }

    final double maximoReferencia = prods.isNotEmpty
        ? (_ordenRanking == 'unidades' ? prods.first.cantidadVendida : prods.first.totalVendido)
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFEAB308), size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos Más Populares / Más Vendidos',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Ranking de demanda por unidades e ingresos generados',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'unidades',
                    label: Text('Por Unidades Vendidas', style: TextStyle(fontSize: 11.5)),
                    icon: Icon(Icons.numbers_rounded, size: 14),
                  ),
                  ButtonSegment(
                    value: 'ingresos',
                    label: Text('Por Ingresos Generados (\$)', style: TextStyle(fontSize: 11.5)),
                    icon: Icon(Icons.attach_money_rounded, size: 14),
                  ),
                ],
                selected: {_ordenRanking},
                onSelectionChanged: (s) => setState(() => _ordenRanking = s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (prods.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Text('- No hay datos de ventas en este periodo -',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 36, child: Text('#', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        SizedBox(width: 130, child: Text('Código de Barras', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        Expanded(flex: 3, child: Text('Descripción del Producto', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('Departamento', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('Demanda Relativa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        SizedBox(width: 90, child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        SizedBox(width: 100, child: Text('Total Vendido', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                        SizedBox(width: 100, child: Text('Ganancia', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prods.length.clamp(0, 25),
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final p = prods[index];
                      final pos = index + 1;
                      final esPar = index % 2 == 0;

                      final double ref = _ordenRanking == 'unidades' ? p.cantidadVendida : p.totalVendido;
                      final ratio = (ref / (maximoReferencia > 0 ? maximoReferencia : 1.0)).clamp(0.05, 1.0);

                      Color colorPos = const Color(0xFF64748B);
                      Color bgPos = const Color(0xFFF1F5F9);
                      if (pos == 1) {
                        colorPos = const Color(0xFFB45309);
                        bgPos = const Color(0xFFFEF3C7);
                      } else if (pos == 2) {
                        colorPos = const Color(0xFF475569);
                        bgPos = const Color(0xFFE2E8F0);
                      } else if (pos == 3) {
                        colorPos = const Color(0xFF7C2D12);
                        bgPos = const Color(0xFFFFEDD5);
                      }

                      return Container(
                        color: esPar ? Colors.white : const Color(0xFFFAFAFA),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: bgPos,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                child: Text('$pos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorPos)),
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(p.codigoBarras, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF475569))),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(p.descripcion, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(p.departamento, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      pos == 1
                                          ? const Color(0xFFF59E0B)
                                          : (pos <= 3 ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                p.cantidadVendida % 1 == 0
                                    ? p.cantidadVendida.toInt().toString()
                                    : p.cantidadVendida.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(_fm(p.totalVendido), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(_fm(p.ganancia), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── SECCIÓN VENTAS POR CLIENTE (SUB-PESTAÑA 2) ──
  Widget _buildContenidoVentasPorCliente() {
    final filtrados = _filtroCliente.isEmpty
        ? _resumen.ventasPorCliente
        : _resumen.ventasPorCliente
            .where((c) => (c['nombre'] as String? ?? '').toLowerCase().contains(_filtroCliente.toLowerCase()))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TARJETAS KPI DE CLIENTES
          _buildTarjetasKPIClientes(),
          const SizedBox(height: 20),

          // 2. GRÁFICA DE BARRAS: TOP 10 CLIENTES CON MAYOR COMPRA Y GANANCIA
          _buildGraficaTop10Clientes(),
          const SizedBox(height: 20),

          // 3. TABLA DETALLADA DE VENTAS POR CLIENTE
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: AppColors.reportesIcon, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detalle de Ventas por Cliente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text('Frecuencia de compra, rentabilidad, abonos y saldos', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 36,
                      child: TextField(
                        controller: _buscarClienteCtrl,
                        onChanged: (v) => setState(() => _filtroCliente = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _filtroCliente.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _buscarClienteCtrl.clear();
                                    setState(() => _filtroCliente = '');
                                  })
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (filtrados.isEmpty)
                  Container(
                    height: 140,
                    alignment: Alignment.center,
                    child: Text(
                      _filtroCliente.isNotEmpty
                          ? 'No se encontraron clientes con "$_filtroCliente"'
                          : '- No hubo ventas a clientes en este periodo -',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text('Cliente', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 80, child: Text('Tickets', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 120, child: Text('Total Comprado', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 120, child: Text('Ganancia', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 120, child: Text('Abonos Periodo', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 120, child: Text('Saldo Pendiente', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                            ],
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final c = filtrados[index];
                            final esPar = index % 2 == 0;
                            final saldo = parseDecimal(c['saldo_actual']);
                            final abonos = parseDecimal(c['abonos']);
                            final total = parseDecimal(c['total']);
                            final ganancia = parseDecimal(c['ganancia']);
                            final tickets = parseIntSafe(c['tickets']);
                            final nombre = c['nombre'] as String? ?? 'Público General';

                            return Container(
                              color: esPar ? Colors.white : const Color(0xFFFAFAFA),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: nombre == 'Público General'
                                              ? const Color(0xFFE2E8F0)
                                              : AppColors.reportesIcon.withAlpha(40),
                                          child: Text(
                                            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: nombre == 'Público General'
                                                  ? const Color(0xFF64748B)
                                                  : AppColors.reportesIcon,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            nombre,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('$tickets', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(_fm(total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(_fm(ganancia), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(_fm(abonos), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: abonos > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8))),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      _fm(saldo),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: saldo > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 1. TARJETAS KPI DE CLIENTES ──
  Widget _buildTarjetasKPIClientes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (3 * 16)) / 4;
        return Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Clientes Registrados',
              valor: _fm(_resumen.ventasClientesRegistrados),
              subtitulo: 'Ventas en el periodo',
              icono: Icons.badge_rounded,
              colorIcono: const Color(0xFF2563EB),
              colorFondo: const Color(0xFFEFF6FF),
            ),
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Público en General',
              valor: _fm(_resumen.ventasPublicoGeneral),
              subtitulo: 'Ventas sin cliente asignado',
              icono: Icons.storefront_rounded,
              colorIcono: const Color(0xFF64748B),
              colorFondo: const Color(0xFFF1F5F9),
            ),
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Ganancia por Clientes',
              valor: _fm(_resumen.gananciaClientesRegistrados),
              subtitulo: 'Utilidad clientes registrados',
              icono: Icons.monetization_on_rounded,
              colorIcono: const Color(0xFF059669),
              colorFondo: const Color(0xFFECFDF5),
            ),
            _buildKpiCard(
              width: itemWidth.clamp(200, 320),
              titulo: 'Saldo por Cobrar',
              valor: _fm(_resumen.saldoTotalPorCobrar),
              subtitulo: 'Deuda global en cartera',
              icono: Icons.pending_actions_rounded,
              colorIcono: const Color(0xFFDC2626),
              colorFondo: const Color(0xFFFEF2F2),
            ),
          ],
        );
      },
    );
  }

  // ── 2. GRÁFICA DE BARRAS: TOP 10 CLIENTES ──
  Widget _buildGraficaTop10Clientes() {
    // Tomar solo clientes registrados con mayor compra
    final top10 = _resumen.ventasPorCliente
        .where((c) => c['nombre'] != 'Público General')
        .take(10)
        .toList();

    double maxValor = 0.0;
    for (final c in top10) {
      final t = parseDecimal(c['total']);
      final g = parseDecimal(c['ganancia']);
      if (t > maxValor) maxValor = t;
      if (g > maxValor) maxValor = g;
    }
    if (maxValor <= 0) maxValor = 100.0;
    final escalaMax = maxValor * 1.2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded, color: AppColors.reportesIcon, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Top 10 Clientes con Mayor Volumen de Compra y Ganancia',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              _buildLeyendaItem(const Color(0xFF3B82F6), 'Total Comprado'),
              const SizedBox(width: 14),
              _buildLeyendaItem(const Color(0xFF10B981), 'Ganancia'),
            ],
          ),
          const SizedBox(height: 16),

          if (top10.isEmpty)
            Container(
              height: 150,
              alignment: Alignment.center,
              child: Text('- Sin compras de clientes registrados en este periodo -',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fm(escalaMax), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(_fm(escalaMax * 0.66), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text(_fm(escalaMax * 0.33), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const Text('\$0.00', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 22),
                    ],
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1, color: const Color(0xFFF1F5F9)),
                            Container(height: 1.5, color: const Color(0xFFCBD5E1)),
                            const SizedBox(height: 22),
                          ],
                        ),

                        Positioned.fill(
                          bottom: 0,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: top10.map((c) {
                                final total = parseDecimal(c['total']);
                                final ganancia = parseDecimal(c['ganancia']);
                                final nombre = (c['nombre'] as String? ?? '').trim();

                                const maxH = 160.0;
                                final hTotal = ((total / escalaMax) * maxH).clamp(4.0, maxH);
                                final hGanancia = ((ganancia / escalaMax) * maxH).clamp(4.0, maxH);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Tooltip(
                                            message: '$nombre\nTotal Comprado: ${_fm(total)}',
                                            child: Container(
                                              width: 20,
                                              height: hTotal,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  topRight: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Tooltip(
                                            message: '$nombre\nGanancia: ${_fm(ganancia)}',
                                            child: Container(
                                              width: 20,
                                              height: hGanancia,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(3),
                                                  topRight: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 58,
                                        child: Text(
                                          nombre,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────── PAINTER DE PASTEL / DONA ─────────────────────

class _DonutSegment {
  final String label;
  final double value;
  final Color color;
  final double porcentaje;

  const _DonutSegment({
    required this.label,
    required this.value,
    required this.color,
    required this.porcentaje,
  });
}

class _MultiDonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segmentos;
  final double strokeWidth;

  const _MultiDonutChartPainter({
    required this.segmentos,
    this.strokeWidth = 22.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final total = segmentos.fold(0.0, (acc, s) => acc + s.value);

    if (total <= 0) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final seg in segmentos) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MultiDonutChartPainter oldDelegate) => true;
}
