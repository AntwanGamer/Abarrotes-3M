import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/database_service.dart';
import '../models/helpers.dart';

// ─────────────────────────── MODELO DE REPORTE ─────────────────────────────

class _ResumenReporte {
  final double ventasTotales;
  final double gananciaTotal;
  final int numeroVentas;
  final double ventaPromedio;
  final double margenUtilidad;
  final Map<String, double> ventasPorMetodo;
  final List<Map<String, dynamic>> ventasPorDia;
  final List<Map<String, dynamic>> topProductos;
  final List<Map<String, dynamic>> ventasPorDepartamento;
  final List<Map<String, dynamic>> ventasPorCliente;

  const _ResumenReporte({
    this.ventasTotales = 0,
    this.gananciaTotal = 0,
    this.numeroVentas = 0,
    this.ventaPromedio = 0,
    this.margenUtilidad = 0,
    this.ventasPorMetodo = const {},
    this.ventasPorDia = const [],
    this.topProductos = const [],
    this.ventasPorDepartamento = const [],
    this.ventasPorCliente = const [],
  });
}

// ──────────────────────────── REPOSITORIO ──────────────────────────────────

class _ReportesDB {
  final DatabaseService _db;
  _ReportesDB(this._db);

  Future<_ResumenReporte> obtenerResumen({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final desdeStr = desde.toIso8601String();
    final hastaStr =
        DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59)
            .toIso8601String();

    // 1. KPIs globales
    final resKpi = await _db.query('''
      SELECT
        COUNT(DISTINCT v.id_venta) AS num_ventas,
        COALESCE(SUM(v.total), 0)  AS total_ventas,
        COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
      FROM tbl_ventas v
      LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});

    final kpi =
        resKpi.isNotEmpty ? resKpi.first.toColumnMap() : <String, dynamic>{};
    final totalVentas = parseDecimal(kpi['total_ventas']);
    final ganancia = parseDecimal(kpi['ganancia']);
    final numVentas = parseIntSafe(kpi['num_ventas']);
    final ventaPromedio = numVentas > 0 ? totalVentas / numVentas : 0.0;
    final margen =
        totalVentas > 0 ? (ganancia / totalVentas) * 100 : 0.0;

    // 2. Por método de pago
    final resPago = await _db.query('''
      SELECT fp.nombre_forma_pago, COALESCE(SUM(pv.monto), 0) AS subtotal
      FROM tbl_pagos_venta pv
      JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
      JOIN tbl_ventas v ON pv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
      GROUP BY fp.nombre_forma_pago
      ORDER BY subtotal DESC
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});
    final metodosMap = <String, double>{};
    for (final r in resPago) {
      final m = r.toColumnMap();
      metodosMap[parsePgString(m['nombre_forma_pago'])] =
          parseDecimal(m['subtotal']);
    }

    // 3. Ventas por día
    final resDia = await _db.query('''
      SELECT DATE(v.fecha_venta) AS dia,
             COUNT(*) AS tickets,
             COALESCE(SUM(v.total), 0) AS total
      FROM tbl_ventas v
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
      GROUP BY DATE(v.fecha_venta)
      ORDER BY dia ASC
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});
    final diasList = resDia.map((r) {
      final m = r.toColumnMap();
      return {
        'dia': m['dia'],
        'tickets': parseIntSafe(m['tickets']),
        'total': parseDecimal(m['total']),
      };
    }).toList();

    // 4. Top 10 productos más vendidos
    final resProd = await _db.query('''
      SELECT dv.descripcion_producto,
             COALESCE(SUM(dv.cantidad), 0)  AS qty,
             COALESCE(SUM(dv.importe), 0)   AS total_importe
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
      GROUP BY dv.descripcion_producto
      ORDER BY total_importe DESC
      LIMIT 10
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});
    final productosTop = resProd.map((r) {
      final m = r.toColumnMap();
      return {
        'nombre': parsePgString(m['descripcion_producto']),
        'qty': parseDecimal(m['qty']),
        'total': parseDecimal(m['total_importe']),
      };
    }).toList();

    // 5. Ventas por departamento
    final resDept = await _db.query('''
      SELECT COALESCE(d.nombre_departamento, 'Sin Departamento') AS depto,
             COALESCE(SUM(dv.importe), 0) AS subtotal
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
      GROUP BY d.nombre_departamento
      ORDER BY subtotal DESC
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});
    final deptList = resDept.map((r) {
      final m = r.toColumnMap();
      return {
        'nombre': parsePgString(m['depto'], defaultValue: 'Sin Departamento'),
        'subtotal': parseDecimal(m['subtotal']),
      };
    }).toList();

    // 6. Ventas por cliente (top 10)
    final resCliente = await _db.query('''
      SELECT COALESCE(c.nombre, 'Público General') AS nombre,
             COUNT(v.id_venta) AS tickets,
             COALESCE(SUM(v.total), 0) AS total_ventas,
             COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia,
             MAX(v.fecha_venta) AS ultima_compra
      FROM tbl_ventas v
      LEFT JOIN tbl_clientes c ON v.id_cliente = c.id_cliente
      LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
      WHERE v.fecha_venta BETWEEN @desde AND @hasta
        AND v.estatus_venta::text = 'Completada'
      GROUP BY c.nombre
      ORDER BY total_ventas DESC
      LIMIT 10
    ''', params: {'desde': desdeStr, 'hasta': hastaStr});
    final clientesList = resCliente.map((r) {
      final m = r.toColumnMap();
      return {
        'nombre': parsePgString(m['nombre'], defaultValue: 'Público General'),
        'tickets': parseIntSafe(m['tickets']),
        'total': parseDecimal(m['total_ventas']),
        'ganancia': parseDecimal(m['ganancia']),
        'ultima_compra': m['ultima_compra'],
      };
    }).toList();

    return _ResumenReporte(
      ventasTotales: totalVentas,
      gananciaTotal: ganancia,
      numeroVentas: numVentas,
      ventaPromedio: ventaPromedio,
      margenUtilidad: margen,
      ventasPorMetodo: metodosMap,
      ventasPorDia: diasList,
      topProductos: productosTop,
      ventasPorDepartamento: deptList,
      ventasPorCliente: clientesList,
    );
  }
}

// ──────────────────────────── VISTA PRINCIPAL ──────────────────────────────

/// Vista del módulo de Reportes (Pantalla estilo Eleventa Punto de Venta).
/// Conectada a PostgreSQL local con arquitectura Offline-First.
class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  String _subOpcion = 'ventas';
  String _periodoSeleccionado = 'Mes Actual';
  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  bool _cargando = true;
  String? _error;
  _ResumenReporte _resumen = const _ResumenReporte();

  late final _ReportesDB _repo;

  final _buscarCtrl = TextEditingController();
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    _repo = _ReportesDB(DatabaseService.instance);
    _establecerFechasPorPeriodo('Mes Actual');
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  void _establecerFechasPorPeriodo(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoSeleccionado = periodo;
      switch (periodo) {
        case 'Hoy':
          _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
          _fechaFin = _fechaInicio;
        case 'Ayer':
          final ayer = hoy.subtract(const Duration(days: 1));
          _fechaInicio = DateTime(ayer.year, ayer.month, ayer.day);
          _fechaFin = _fechaInicio;
        case 'Semana Actual':
          _fechaInicio =
              hoy.subtract(Duration(days: hoy.weekday - 1));
          _fechaFin = _fechaInicio.add(const Duration(days: 6));
        case 'Mes Actual':
          _fechaInicio = DateTime(hoy.year, hoy.month, 1);
          _fechaFin = DateTime(hoy.year, hoy.month + 1, 0);
        case 'Mes Anterior':
          _fechaInicio = DateTime(hoy.year, hoy.month - 1, 1);
          _fechaFin = DateTime(hoy.year, hoy.month, 0);
        case 'Año actual':
          _fechaInicio = DateTime(hoy.year, 1, 1);
          _fechaFin = DateTime(hoy.year, 12, 31);
        default:
          _fechaInicio = DateTime(hoy.year, hoy.month, 1);
          _fechaFin = DateTime(hoy.year, hoy.month + 1, 0);
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
          desde: _fechaInicio, hasta: _fechaFin);
      if (mounted) setState(() {
        _resumen = r;
        _cargando = false;
      });
    } catch (e, st) {
      dev.log('[ReportesView] Error: $e', error: e, stackTrace: st);
      if (mounted) setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  void _navegarPeriodo(int paso) {
    setState(() {
      if (_periodoSeleccionado == 'Hoy' ||
          _periodoSeleccionado == 'Ayer') {
        _fechaInicio =
            _fechaInicio.add(Duration(days: paso));
        _fechaFin = _fechaInicio;
      } else if (_periodoSeleccionado == 'Semana Actual') {
        _fechaInicio =
            _fechaInicio.add(Duration(days: 7 * paso));
        _fechaFin = _fechaFin.add(Duration(days: 7 * paso));
      } else if (_periodoSeleccionado == 'Mes Actual' ||
          _periodoSeleccionado == 'Mes Anterior') {
        final nuevo = DateTime(
            _fechaInicio.year, _fechaInicio.month + paso, 1);
        _fechaInicio = nuevo;
        _fechaFin =
            DateTime(nuevo.year, nuevo.month + 1, 0);
      } else if (_periodoSeleccionado == 'Año actual') {
        final anio = _fechaInicio.year + paso;
        _fechaInicio = DateTime(anio, 1, 1);
        _fechaFin = DateTime(anio, 12, 31);
      }
    });
    _cargarDatos();
  }

  // ── formatos ──
  String _fm(double v) => '\$${v.toStringAsFixed(2)}';

  String _fmFecha(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  String _nombreMes(int m) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return meses[(m - 1).clamp(0, 11)];
  }

  String _rangoFechas() =>
      '${_fechaInicio.day} ${_nombreMes(_fechaInicio.month)} ${_fechaInicio.year}'
      ' — ${_fechaFin.day} ${_nombreMes(_fechaFin.month)} ${_fechaFin.year}';

  String _tituloPeriodo() {
    switch (_periodoSeleccionado) {
      case 'Hoy':
        return 'Ventas de Hoy';
      case 'Ayer':
        return 'Ventas de Ayer';
      case 'Semana Actual':
        return 'Ventas de la Semana Actual';
      case 'Mes Actual':
        return 'Ventas del Mes Actual';
      case 'Mes Anterior':
        return 'Ventas del Mes Anterior';
      case 'Año actual':
        return 'Ventas del Año Actual';
      default:
        return 'Reporte de Ventas';
    }
  }

  // ── DIALOGO PERIODO PERSONALIZADO ──
  void _mostrarDialogoPeriodo() {
    DateTime tempI = _fechaInicio;
    DateTime tempF = _fechaFin;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setMod) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.date_range_rounded,
                  color: AppColors.reportesIcon),
              SizedBox(width: 8),
              Text('Seleccionar Período'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Atajos rápidos:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final atajo in [
                      'Hoy',
                      'Ayer',
                      'Esta semana',
                      'Semana pasada',
                      'Este mes',
                      'Mes pasado',
                      'Este año',
                    ])
                      ActionChip(
                        label: Text(atajo,
                            style: const TextStyle(fontSize: 11.5)),
                        backgroundColor:
                            const Color(0xFFF1F5F9),
                        side: const BorderSide(
                            color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(6)),
                        onPressed: () {
                          final hoy = DateTime.now();
                          DateTime i, f;
                          switch (atajo) {
                            case 'Hoy':
                              i = DateTime(hoy.year,
                                  hoy.month, hoy.day);
                              f = i;
                            case 'Ayer':
                              final ayer = hoy.subtract(
                                  const Duration(days: 1));
                              i = DateTime(ayer.year,
                                  ayer.month, ayer.day);
                              f = i;
                            case 'Esta semana':
                              i = hoy.subtract(Duration(
                                  days: hoy.weekday - 1));
                              f = i.add(
                                  const Duration(days: 6));
                            case 'Semana pasada':
                              final lp = hoy.subtract(
                                  Duration(
                                      days: hoy.weekday + 6));
                              i = DateTime(lp.year, lp.month,
                                  lp.day);
                              f = i.add(
                                  const Duration(days: 6));
                            case 'Este mes':
                              i = DateTime(
                                  hoy.year, hoy.month, 1);
                              f = DateTime(hoy.year,
                                  hoy.month + 1, 0);
                            case 'Mes pasado':
                              i = DateTime(
                                  hoy.year, hoy.month - 1, 1);
                              f = DateTime(
                                  hoy.year, hoy.month, 0);
                            default: // Este año
                              i = DateTime(hoy.year, 1, 1);
                              f = DateTime(hoy.year, 12, 31);
                          }
                          setMod(() {
                            tempI = i;
                            tempF = f;
                          });
                        },
                      ),
                  ],
                ),
                const Divider(height: 24),
                const Text('Rango personalizado:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF475569))),
                const SizedBox(height: 10),
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
                          if (p != null) {
                            setMod(() => tempI = p);
                          }
                        },
                        icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16),
                        label: Text(
                            'Desde: ${tempI.day}/${tempI.month}/${tempI.year}',
                            style: const TextStyle(
                                fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
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
                          if (p != null) {
                            setMod(() => tempF = p);
                          }
                        },
                        icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16),
                        label: Text(
                            'Hasta: ${tempF.day}/${tempF.month}/${tempF.year}',
                            style: const TextStyle(
                                fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
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
              label: const Text('Aplicar Período'),
              onPressed: () {
                setState(() {
                  _fechaInicio = tempI;
                  _fechaFin = tempF;
                  _periodoSeleccionado = 'Personalizado';
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

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBarraSubOpciones(),
        if (_subOpcion == 'ventas') _buildBarraPeriodo(),
        Expanded(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.reportesIcon))
              : _error != null
                  ? _buildError()
                  : _subOpcion == 'ventas'
                      ? _buildContenidoVentas()
                      : _buildContenidoClientes(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Error desconocido',
              style: const TextStyle(fontSize: 13)),
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

  // ── BARRA SUB-OPCIONES ──
  Widget _buildBarraSubOpciones() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          _buildBotonSubPestana(
              id: 'ventas',
              titulo: 'Reporte de Ventas',
              icono: Icons.bar_chart_rounded),
          const SizedBox(width: 8),
          _buildBotonSubPestana(
              id: 'clientes',
              titulo: 'Ventas por Cliente',
              icono: Icons.people_outline_rounded),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar',
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFF1F3F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel
                ? const Color(0xFFCBD5E1)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono,
                size: 16,
                color: sel
                    ? AppColors.reportesIcon
                    : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel
                    ? AppColors.textPrimary
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BARRA DE PERÍODO ──
  Widget _buildBarraPeriodo() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tituloPeriodo(),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        size: 14, color: AppColors.reportesIcon),
                    const SizedBox(width: 6),
                    Text(
                      _rangoFechas(),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildBotonNav(Icons.chevron_left_rounded, -1),
              const SizedBox(width: 6),
              _buildBotonNav(Icons.chevron_right_rounded, 1),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in [
                ('Hoy', Icons.today_rounded),
                ('Semana Actual', Icons.calendar_view_week_rounded),
                ('Mes Actual', Icons.calendar_view_month_rounded),
                ('Mes Anterior', Icons.history_rounded),
                ('Año actual', Icons.calendar_today_rounded),
              ])
                _buildPeriodoPill(p.$1, p.$2),
              _buildPeriodoPill(
                  'Personalizado', Icons.tune_rounded,
                  esPersonalizado: true),
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
          child: Icon(icono,
              size: 18, color: const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildPeriodoPill(String id, IconData icono,
      {bool esPersonalizado = false}) {
    final bool activo = _periodoSeleccionado == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (esPersonalizado) {
            _mostrarDialogoPeriodo();
          } else {
            _establecerFechasPorPeriodo(id);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: activo
                ? AppColors.reportesIcon
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo
                  ? AppColors.reportesIcon
                  : const Color(0xFFCBD5E1),
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
              Icon(icono,
                  size: 14,
                  color:
                      activo ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                esPersonalizado ? 'Periodo...' : id,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: activo
                        ? Colors.white
                        : const Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONTENIDO VENTAS ──
  Widget _buildContenidoVentas() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs superiores
          _buildKpis(),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), thickness: 1),
          const SizedBox(height: 16),
          // Dos columnas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildColumnaIzquierda()),
              const SizedBox(width: 32),
              Expanded(child: _buildColumnaDerecha()),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildFilaMetrica(
                  'Ventas Totales', _fm(_resumen.ventasTotales),
                  esGrande: true),
              const SizedBox(height: 6),
              _buildFilaMetrica(
                  'Número de Tickets', '${_resumen.numeroVentas}'),
              const SizedBox(height: 6),
              _buildFilaMetrica(
                  'Venta Promedio', _fm(_resumen.ventaPromedio)),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          child: Column(
            children: [
              _buildFilaMetrica(
                  'Ganancia', _fm(_resumen.gananciaTotal),
                  esGrande: true),
              const SizedBox(height: 6),
              _buildFilaMetrica('Margen de Utilidad',
                  '${_resumen.margenUtilidad.toStringAsFixed(2)}%'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilaMetrica(String label, String valor,
      {bool esGrande = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: esGrande ? 14 : 12.5,
                fontWeight: esGrande
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: esGrande
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFF475569))),
        Text(valor,
            style: TextStyle(
                fontSize: esGrande ? 15 : 12.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildColumnaIzquierda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ventas por día
        _buildTituloSeccion('Ventas por Día'),
        const SizedBox(height: 8),
        _resumen.ventasPorDia.isEmpty
            ? _buildVacio('- No se registraron ventas en este período -')
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: _resumen.ventasPorDia.map((d) {
                    final dia = d['dia'];
                    String diaStr = dia?.toString() ?? '';
                    if (dia is DateTime) {
                      diaStr = _fmFecha(dia);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(diaStr,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155))),
                          Text(
                            _fm(d['total'] as double),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

        const SizedBox(height: 24),

        // Ventas por forma de pago
        _buildTituloSeccion('Ventas por Forma de Pago'),
        const SizedBox(height: 8),
        _resumen.ventasPorMetodo.isEmpty
            ? _buildVacio('- No se registraron ventas -')
            : Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    ..._resumen.ventasPorMetodo.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF475569))),
                            Text(_fm(e.value),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(_fm(_resumen.ventasTotales),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E293B))),
                      ],
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildColumnaDerecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top productos
        _buildTituloSeccion('Productos Más Vendidos (Top 10)'),
        const SizedBox(height: 8),
        _resumen.topProductos.isEmpty
            ? _buildVacio('- No se registraron ventas -')
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: _resumen.topProductos
                      .asMap()
                      .entries
                      .map((e) {
                    final idx = e.key + 1;
                    final prod = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: idx <= 3
                                  ? AppColors.reportesIcon
                                  : const Color(0xFFE2E8F0),
                              borderRadius:
                                  BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text('$idx',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: idx <= 3
                                          ? Colors.white
                                          : const Color(
                                              0xFF64748B))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              prod['nombre'] as String? ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _fm(prod['total'] as double),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

        const SizedBox(height: 24),

        // Ventas por departamento
        _buildTituloSeccion('Ventas por Departamento'),
        const SizedBox(height: 8),
        _resumen.ventasPorDepartamento.isEmpty
            ? _buildVacio('- No se registraron ventas -')
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: _resumen.ventasPorDepartamento
                      .map((d) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined,
                              size: 14,
                              color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d['nombre'] as String? ??
                                  'Sin Departamento',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            _fm(d['subtotal'] as double),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  // ── CONTENIDO CLIENTES ──
  Widget _buildContenidoClientes() {
    final filtrados = _filtroBusqueda.isEmpty
        ? _resumen.ventasPorCliente
        : _resumen.ventasPorCliente
            .where((c) => (c['nombre'] as String? ?? '')
                .toLowerCase()
                .contains(_filtroBusqueda.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Buscador
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: TextField(
            controller: _buscarCtrl,
            onChanged: (v) =>
                setState(() => _filtroBusqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _buscarCtrl.clear();
                        setState(() => _filtroBusqueda = '');
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        // Tabla
        Expanded(
          child: filtrados.isEmpty
              ? _buildVacioCenter(
                  _filtroBusqueda.isNotEmpty
                      ? 'No se encontraron clientes con "$_filtroBusqueda"'
                      : '- No hubo ventas en este período -')
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Encabezado de tabla
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFE2E8F0))),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Text('Cliente',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(
                                              0xFF475569)))),
                              Expanded(
                                  flex: 1,
                                  child: Text('Tickets',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(
                                              0xFF475569)))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Total Ventas',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(
                                              0xFF475569)))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Ganancia',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(
                                              0xFF475569)))),
                            ],
                          ),
                        ),
                        // Filas
                        ...filtrados.asMap().entries.map((e) {
                          final c = e.value;
                          final esPar = e.key % 2 == 0;
                          return Container(
                            color: esPar
                                ? Colors.white
                                : const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                      c['nombre'] as String? ??
                                          '',
                                      style: const TextStyle(
                                          fontSize: 12.5),
                                      overflow:
                                          TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                      '${c['tickets']}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12.5)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      _fm(c['total'] as double),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight:
                                              FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                      _fm(c['ganancia'] as double),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: AppColors
                                              .success)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── HELPERS UI ──
  Widget _buildTituloSeccion(String titulo) {
    return Text(titulo,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50)));
  }

  Widget _buildVacio(String msg) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(msg,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildVacioCenter(String msg) {
    return Center(
      child: Text(msg,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic)),
    );
  }
}
