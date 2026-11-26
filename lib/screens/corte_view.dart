import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/corte_caja.dart';
import '../models/movimiento_caja.dart';
import '../repositories/cortes_caja_repository.dart';
import '../services/database_service.dart';
import '../models/helpers.dart';

// ─────────────────────────── MODELO LOCAL DE RESUMEN ────────────────────────

/// Totales calculados en tiempo real desde PostgreSQL para el corte activo.
class _ResumenCorte {
  final double ventasTotales;
  final double ventasEfectivo;
  final double abonosEfectivo;
  final double gananciaTotal;
  final int numeroVentas;
  final Map<String, double> ventasPorMetodo;
  final List<Map<String, dynamic>> ventasPorDepartamento;

  const _ResumenCorte({
    this.ventasTotales = 0,
    this.ventasEfectivo = 0,
    this.abonosEfectivo = 0,
    this.gananciaTotal = 0,
    this.numeroVentas = 0,
    this.ventasPorMetodo = const {},
    this.ventasPorDepartamento = const [],
  });
}

// ─────────────────────────────── REPOSITORIO ──────────────────────────────

/// Consultas adicionales de resumen de corte (no incluidas en CortesCajaRepository).
class _CorteResumenDB {
  final DatabaseService _db;
  _CorteResumenDB(this._db);

  Future<_ResumenCorte> obtenerResumen({
    required int idCorte,
    bool esDia = false,
  }) async {
    final whereCorte =
        esDia ? "DATE(v.fecha_venta) = CURRENT_DATE" : "v.id_corte = @idCorte";

    // 1. Totales ventas
    final resVentas = await _db.query('''
      SELECT
        COUNT(*) AS num_ventas,
        COALESCE(SUM(v.total), 0)   AS total_ventas,
        COALESCE(SUM(dv.importe - dv.cantidad * dv.costo_unitario), 0) AS ganancia
      FROM tbl_ventas v
      LEFT JOIN tbl_detalle_ventas dv ON dv.id_venta = v.id_venta
      WHERE $whereCorte
        AND v.estatus_venta::text = 'Completada'
    ''', params: {'idCorte': idCorte});

    final rowV = resVentas.isNotEmpty ? resVentas.first.toColumnMap() : {};
    final totalVentas = parseDecimal(rowV['total_ventas']);
    final ganancia = parseDecimal(rowV['ganancia']);
    final numVentas = parseIntSafe(rowV['num_ventas']);

    // 2. Ventas en efectivo
    final resEfectivo = await _db.query('''
      SELECT COALESCE(SUM(pv.monto - COALESCE(pv.cambio,0)), 0) AS efe
      FROM tbl_pagos_venta pv
      JOIN tbl_ventas v ON pv.id_venta = v.id_venta
      JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
      WHERE $whereCorte
        AND LOWER(fp.nombre_forma_pago) LIKE '%efectivo%'
        AND v.estatus_venta::text = 'Completada'
    ''', params: {'idCorte': idCorte});
    final efVentas = parseDecimal(
      resEfectivo.isNotEmpty ? resEfectivo.first.toColumnMap()['efe'] : null,
    );

    // 3. Abonos en efectivo
    final resAbonos = await _db.query('''
      SELECT COALESCE(SUM(a.monto), 0) AS abo
      FROM tbl_abonos_clientes a
      JOIN tbl_formas_pago fp ON a.id_forma_pago = fp.id_forma_pago
      WHERE ${esDia ? "DATE(a.fecha_registro) = CURRENT_DATE" : "a.id_corte = @idCorte"}
        AND LOWER(fp.nombre_forma_pago) LIKE '%efectivo%'
    ''', params: {'idCorte': idCorte});
    final efAbonos = parseDecimal(
      resAbonos.isNotEmpty ? resAbonos.first.toColumnMap()['abo'] : null,
    );

    // 4. Desglose por forma de pago
    final resPago = await _db.query('''
      SELECT fp.nombre_forma_pago, COALESCE(SUM(pv.monto), 0) AS subtotal
      FROM tbl_pagos_venta pv
      JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
      JOIN tbl_ventas v ON pv.id_venta = v.id_venta
      WHERE $whereCorte
        AND v.estatus_venta::text = 'Completada'
      GROUP BY fp.nombre_forma_pago
      ORDER BY subtotal DESC
    ''', params: {'idCorte': idCorte});
    final metodosMap = <String, double>{};
    for (final r in resPago) {
      final m = r.toColumnMap();
      metodosMap[parsePgString(m['nombre_forma_pago'])] =
          parseDecimal(m['subtotal']);
    }

    // 5. Ventas por departamento
    final resDept = await _db.query('''
      SELECT COALESCE(d.nombre_departamento, 'Sin Departamento') AS depto,
             COALESCE(SUM(dv.importe), 0) AS subtotal
      FROM tbl_detalle_ventas dv
      JOIN tbl_ventas v ON dv.id_venta = v.id_venta
      LEFT JOIN tbl_productos p ON dv.id_producto = p.id_producto
      LEFT JOIN tbl_departamentos d ON p.id_departamento = d.id_departamento
      WHERE $whereCorte
        AND v.estatus_venta::text = 'Completada'
      GROUP BY d.nombre_departamento
      ORDER BY subtotal DESC
    ''', params: {'idCorte': idCorte});
    final deptos = resDept
        .map((r) {
          final m = r.toColumnMap();
          return {
            'nombre': parsePgString(m['depto'], defaultValue: 'Sin Departamento'),
            'subtotal': parseDecimal(m['subtotal']),
          };
        })
        .toList();

    return _ResumenCorte(
      ventasTotales: totalVentas,
      ventasEfectivo: efVentas,
      abonosEfectivo: efAbonos,
      gananciaTotal: ganancia,
      numeroVentas: numVentas,
      ventasPorMetodo: metodosMap,
      ventasPorDepartamento: deptos,
    );
  }

  Future<List<MovimientoCaja>> obtenerMovimientos({
    required int idCorte,
    bool esDia = false,
  }) async {
    final res = await _db.query(
      esDia
          ? '''SELECT * FROM tbl_movimientos_caja
               WHERE DATE(fecha_registro) = CURRENT_DATE
               ORDER BY fecha_registro DESC'''
          : '''SELECT * FROM tbl_movimientos_caja
               WHERE id_corte = @idCorte
               ORDER BY fecha_registro DESC''',
      params: {'idCorte': idCorte},
    );
    return res.map((r) => MovimientoCaja.fromMap(r.toColumnMap())).toList();
  }

  Future<void> cerrarCorte({
    required int idCorte,
    required double efectivoContado,
    required double efectivoEsperado,
  }) async {
    final diferencia = efectivoContado - efectivoEsperado;
    await _db.query('''
      UPDATE tbl_cortes_caja SET
        estatus_corte       = 'Cerrado',
        fecha_cierre        = CURRENT_TIMESTAMP,
        efectivo_contado    = @contado,
        diferencia          = @dif,
        fecha_actualizacion = CURRENT_TIMESTAMP,
        sincronizado        = FALSE
      WHERE id_corte = @id
    ''', params: {
      'contado': efectivoContado,
      'dif': diferencia,
      'id': idCorte,
    });
  }
}

// ─────────────────────────────── WIDGET PRINCIPAL ─────────────────────────

/// Vista del módulo de Corte (Corte de Caja / Turno estilo Eleventa Punto de Venta).
/// Conectada a PostgreSQL local con arquitectura Offline-First.
class CorteView extends StatefulWidget {
  const CorteView({super.key});

  @override
  State<CorteView> createState() => _CorteViewState();
}

class _CorteViewState extends State<CorteView> {
  // ── estado ──
  String _tipoCorte = 'cajero';
  bool _cargando = true;
  String? _error;

  CorteCaja? _corteActivo;
  _ResumenCorte _resumen = const _ResumenCorte();
  List<MovimientoCaja> _movimientos = [];

  late final _CorteResumenDB _repo;

  // ── inicialización ──
  @override
  void initState() {
    super.initState();
    _repo = _CorteResumenDB(DatabaseService.instance);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final corte = await CortesCajaRepository.instance.continuarCorteAbierto();
      _corteActivo = corte;

      if (corte != null) {
        final resumen = await _repo.obtenerResumen(
          idCorte: corte.idCorte,
          esDia: _tipoCorte == 'dia',
        );
        final movs = await _repo.obtenerMovimientos(
          idCorte: corte.idCorte,
          esDia: _tipoCorte == 'dia',
        );
        if (mounted) {
          setState(() {
            _resumen = resumen;
            _movimientos = movs;
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e, st) {
      dev.log('[CorteView] Error cargando datos: $e', error: e, stackTrace: st);
      if (mounted) setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // ── formatos ──
  String _fm(double v) => '\$${v.toStringAsFixed(2)}';

  String _fmFecha(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ── acciones ──
  void _mostrarDialogoMovimiento(String tipo) {
    if (_corteActivo == null) {
      _mostrarMensaje('No hay un corte de caja abierto.');
      return;
    }
    final montoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              tipo == 'Entrada'
                  ? Icons.arrow_circle_down_rounded
                  : Icons.arrow_circle_up_rounded,
              color: tipo == 'Entrada' ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text('Registrar $tipo de Efectivo'),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo / Concepto',
                  hintText: 'Ej. Pago a proveedor, cambio, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  tipo == 'Entrada' ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final monto =
                  double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
              final motivo = motivoCtrl.text.trim();
              if (monto <= 0) return;

              Navigator.pop(ctx);
              try {
                // Obtener id usuario activo (desde corte activo)
                final idUsuario = _corteActivo!.idUsuario;
                await CortesCajaRepository.instance.registrarMovimientoCaja(
                  idUsuario: idUsuario,
                  tipoMovimiento: tipo,
                  monto: monto,
                  concepto:
                      motivo.isNotEmpty ? motivo : 'Sin motivo especificado',
                );
                _mostrarMensaje(
                    '$tipo de ${_fm(monto)} registrada correctamente');
                _cargarDatos();
              } catch (e) {
                _mostrarMensaje('Error: $e');
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoFondoCaja() {
    final c = _corteActivo;
    if (c == null) return;
    final fondoCtrl =
        TextEditingController(text: c.fondoInicial.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.corteIcon),
            SizedBox(width: 8),
            Text('Fondo Inicial de Caja'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: fondoCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Monto de fondo de caja',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _mostrarMensaje(
                  'El fondo inicial se configura al abrir un corte nuevo.');
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCerrarTurno() {
    final c = _corteActivo;
    if (c == null) {
      _mostrarMensaje('No hay un corte abierto para cerrar.');
      return;
    }
    final efectivoContadoCtrl = TextEditingController();
    final efectivoEsperado = c.efectivoEsperado;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final contado =
              double.tryParse(efectivoContadoCtrl.text.replaceAll(',', '')) ??
                  0.0;
          final diferencia = contado - efectivoEsperado;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: AppColors.corteIcon),
                SizedBox(width: 8),
                Text('Cerrar Turno / Arqueo de Caja'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Efectivo esperado en caja:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          _fm(efectivoEsperado),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.corteIcon,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: efectivoContadoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: '¿Cuánto efectivo hay físicamente en caja?',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Diferencia:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        diferencia == 0.0
                            ? 'Exacto (\$0.00)'
                            : (diferencia > 0
                                ? '+ ${_fm(diferencia)} (Sobrante)'
                                : '- ${_fm(diferencia.abs())} (Faltante)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: diferencia == 0.0
                              ? AppColors.success
                              : (diferencia > 0
                                  ? Colors.blue
                                  : AppColors.error),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.corteIcon,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _repo.cerrarCorte(
                      idCorte: c.idCorte,
                      efectivoContado: contado,
                      efectivoEsperado: efectivoEsperado,
                    );
                    CortesCajaRepository.instance.limpiarCorte();
                    _mostrarMensaje(
                        'Turno cerrado. Diferencia: ${_fm(diferencia)}');
                    _cargarDatos();
                  } catch (e) {
                    _mostrarMensaje('Error al cerrar turno: $e');
                  }
                },
                child: const Text('Confirmar y Cerrar Turno'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarVistaPreviaImpresion() {
    final c = _corteActivo;
    final horaActual = TimeOfDay.now().format(context);
    final fechaActual = _fmFecha(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.receipt_rounded, color: AppColors.corteIcon),
            SizedBox(width: 8),
            Text('Ticket de Corte de Caja'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('ABARROTES 3M',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const Center(
                    child: Text('PUNTO DE VENTA',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  const Divider(height: 24),
                  Text(
                      'Tipo: ${_tipoCorte == 'cajero' ? 'CORTE DE CAJERO' : 'CORTE DEL DÍA'}'),
                  Text('Fecha: $fechaActual  Hora: $horaActual'),
                  if (c != null) ...[
                    Text(
                        'Apertura: ${_fmFecha(c.fechaApertura)}  Cajero: ${c.nombreUsuario ?? ''}'),
                    Text('Corte #${c.idCorte}'),
                  ],
                  const Divider(height: 20),
                  _buildFilaTicket(
                      'Fondo Inicial:', _fm(c?.fondoInicial ?? 0)),
                  _buildFilaTicket('Ventas Totales:',
                      _fm(_resumen.ventasTotales)),
                  _buildFilaTicket(
                      'Ventas en Efectivo:', _fm(_resumen.ventasEfectivo)),
                  _buildFilaTicket('Abonos en Efectivo:',
                      _fm(_resumen.abonosEfectivo)),
                  _buildFilaTicket(
                      'Entradas de Efectivo:',
                      '+ ${_fm(_movimientos.where((m) => m.tipoMovimiento == 'Entrada').fold(0.0, (a, m) => a + m.monto))}'),
                  _buildFilaTicket(
                      'Salidas de Efectivo:',
                      '- ${_fm(_movimientos.where((m) => m.tipoMovimiento == 'Salida').fold(0.0, (a, m) => a + m.monto))}'),
                  const Divider(height: 20),
                  _buildFilaTicket(
                      'TOTAL EN CAJA:',
                      _fm(c?.efectivoEsperado ?? 0),
                      esTotal: true),
                  _buildFilaTicket(
                      'GANANCIA:', _fm(_resumen.gananciaTotal)),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('*** Fin del Reporte de Corte ***',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Imprimir'),
            onPressed: () {
              Navigator.pop(ctx);
              _mostrarMensaje(
                  'Enviando reporte de corte a la impresora térmica...');
            },
          ),
        ],
      ),
    );
  }

  // ── helpers de UI ──
  Widget _buildFilaTicket(String label, String valor,
      {bool esTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: esTotal ? 13 : 12,
                fontWeight:
                    esTotal ? FontWeight.bold : FontWeight.normal,
              )),
          Text(valor,
              style: TextStyle(
                fontSize: esTotal ? 14 : 12,
                fontWeight:
                    esTotal ? FontWeight.bold : FontWeight.w600,
                color: esTotal ? AppColors.corteIcon : Colors.black87,
              )),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.corteIcon,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBarraSubOpciones(),
        Expanded(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.corteIcon))
              : _error != null
                  ? _buildError()
                  : _corteActivo == null
                      ? _buildSinCorte()
                      : _buildContenido(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Error al cargar datos',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_error ?? '', style: const TextStyle(fontSize: 12)),
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

  Widget _buildSinCorte() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale_outlined,
              size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'No hay un corte de caja abierto',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inicia un nuevo corte para comenzar a registrar ventas.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.corteIcon,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Iniciar Corte Nuevo'),
            onPressed: _mostrarDialogoIniciarCorte,
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoIniciarCorte() {
    final fondoCtrl = TextEditingController(text: '500.00');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: AppColors.corteIcon),
            SizedBox(width: 8),
            Text('Iniciar Nuevo Corte'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ingresa el fondo inicial de caja para comenzar el turno.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fondoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Fondo inicial de caja',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.corteIcon,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final fondo =
                  double.tryParse(fondoCtrl.text.replaceAll(',', '')) ??
                      500.0;
              Navigator.pop(ctx);
              try {
                // Intentar obtener id_usuario del session actual
                // (usado el id del repositorio de auth o default 1)
                final corte =
                    await CortesCajaRepository.instance.iniciarCorteNuevo(
                  idUsuario: 1, // TODO: reemplazar con usuario de sesión activa
                  fondoInicial: fondo,
                );
                _mostrarMensaje(
                    'Corte #${corte.idCorte} iniciado. Fondo: ${_fm(fondo)}');
                _cargarDatos();
              } catch (e) {
                _mostrarMensaje('Error al iniciar corte: $e');
              }
            },
            child: const Text('Iniciar Turno'),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEncabezadoCorte(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildColumnaIzquierda()),
                const SizedBox(width: 24),
                Expanded(child: _buildColumnaDerecha()),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── BARRA SUB-OPCIONES ──
  Widget _buildBarraSubOpciones() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1)),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          _buildBotonSubOpcion(
              id: 'cajero',
              titulo: 'Hacer corte de cajero',
              icono: Icons.content_cut_rounded),
          const SizedBox(width: 8),
          _buildBotonSubOpcion(
              id: 'dia',
              titulo: 'Hacer corte del día',
              icono: Icons.today_rounded),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar datos',
            onPressed: _cargarDatos,
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonSubOpcion({
    required String id,
    required String titulo,
    required IconData icono,
  }) {
    final bool sel = _tipoCorte == id;
    return InkWell(
      onTap: () {
        setState(() => _tipoCorte = id);
        _cargarDatos();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              sel ? const Color(0xFFF1F3F5) : Colors.transparent,
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
                    ? AppColors.corteIcon
                    : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.w500,
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

  // ── ENCABEZADO ──
  Widget _buildEncabezadoCorte() {
    final c = _corteActivo!;
    final String titulo = _tipoCorte == 'cajero'
        ? 'Corte de Cajero — Turno #${c.idCorte}'
        : 'Corte del Día (${_fmFecha(DateTime.now())})';
    final String subtitulo = _tipoCorte == 'cajero'
        ? 'Apertura: ${_fmFecha(c.fechaApertura)} · Cajero: ${c.nombreUsuario ?? 'N/A'}'
        : 'Todas las ventas del día actual';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155))),
            const SizedBox(height: 3),
            Text(subtitulo,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _mostrarVistaPreviaImpresion,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Imprimir',
              style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(
                color: Color(0xFFCBD5E1), width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _mostrarDialogoCerrarTurno,
          icon:
              const Icon(Icons.lock_clock_outlined, size: 16),
          label: const Text('Cerrar turno...',
              style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(
                color: Color(0xFFCBD5E1), width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  // ── COLUMNA IZQUIERDA ──
  Widget _buildColumnaIzquierda() {
    final c = _corteActivo!;
    final totalEntradas = _movimientos
        .where((m) => m.tipoMovimiento == 'Entrada')
        .fold(0.0, (a, m) => a + m.monto);
    final totalSalidas = _movimientos
        .where((m) => m.tipoMovimiento == 'Salida')
        .fold(0.0, (a, m) => a + m.monto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEncabezadoMetrica(
          icono: Icons.attach_money_rounded,
          titulo: 'Ventas Totales (${_resumen.numeroVentas} tickets)',
          valor: _fm(_resumen.ventasTotales),
          colorValor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 20),
        _buildSeccionTitulo(Icons.calculate_outlined, 'Dinero en Caja'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildFilaDinero('Fondo de caja', _fm(c.fondoInicial),
                  onEditar: _mostrarDialogoFondoCaja),
              _buildFilaDinero('Ventas en Efectivo',
                  '+ ${_fm(_resumen.ventasEfectivo)}',
                  colorValor: AppColors.success),
              _buildFilaDinero('Abonos en efectivo',
                  '+ ${_fm(_resumen.abonosEfectivo)}',
                  colorValor: AppColors.success),
              _buildFilaDinero(
                  'Entradas', '+ ${_fm(totalEntradas)}',
                  colorValor: AppColors.success),
              _buildFilaDinero(
                  'Salidas', '- ${_fm(totalSalidas)}',
                  colorValor: AppColors.error),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total en Caja:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    _fm(c.efectivoEsperado),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _mostrarDialogoMovimiento('Entrada'),
                      icon:
                          const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Entrada',
                          style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(
                            color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _mostrarDialogoMovimiento('Salida'),
                      icon: const Icon(Icons.remove_rounded,
                          size: 14),
                      label: const Text('Salida',
                          style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Movimientos de efectivo
        _buildSeccionTitulo(
            Icons.arrow_downward_rounded, 'Entradas de efectivo'),
        const SizedBox(height: 8),
        _movimientos.any((m) => m.tipoMovimiento == 'Entrada')
            ? _buildListaMovimientos(
                _movimientos
                    .where((m) => m.tipoMovimiento == 'Entrada')
                    .toList())
            : _buildCajaInformativa(
                '- No hubo Entradas en Efectivo -'),

        const SizedBox(height: 20),

        // Ventas por Departamento
        _buildSeccionTitulo(
            Icons.folder_outlined, 'Ventas por Departamento'),
        const SizedBox(height: 8),
        _resumen.ventasPorDepartamento.isEmpty
            ? _buildCajaInformativa(
                '- No se registró ninguna venta -')
            : _buildListaDepartamentos(
                _resumen.ventasPorDepartamento),
      ],
    );
  }

  // ── COLUMNA DERECHA ──
  Widget _buildColumnaDerecha() {
    final totalSalidas = _movimientos
        .where((m) => m.tipoMovimiento == 'Salida')
        .fold(0.0, (a, m) => a + m.monto);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEncabezadoMetrica(
          icono: Icons.bar_chart_rounded,
          titulo: 'Ganancia',
          valor: _fm(_resumen.gananciaTotal),
          colorValor: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 20),

        // Desglose por método de pago
        _buildSeccionTitulo(
            Icons.shopping_cart_outlined, 'Ventas por Método de Pago'),
        const SizedBox(height: 10),
        _resumen.ventasPorMetodo.isEmpty
            ? _buildCajaInformativa('- No se registró ninguna venta -')
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
                      (e) => _buildFilaDinero(
                          e.key, '+ ${_fm(e.value)}',
                          colorValor: AppColors.success),
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(
                          _fm(_resumen.ventasTotales),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

        const SizedBox(height: 20),

        // Salidas de efectivo
        _buildSeccionTitulo(
            Icons.arrow_upward_rounded, 'Salidas de Efectivo'),
        const SizedBox(height: 8),
        _movimientos.any((m) => m.tipoMovimiento == 'Salida')
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildListaMovimientos(
                    _movimientos
                        .where((m) => m.tipoMovimiento == 'Salida')
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Text('Total salidas: ${_fm(totalSalidas)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error)),
                ],
              )
            : _buildCajaInformativa(
                '- No hubo Salidas en Efectivo -'),

        const SizedBox(height: 20),

        // Pagos de Créditos (abonos)
        _buildSeccionTitulo(
            Icons.group_outlined, 'Abonos de Créditos'),
        const SizedBox(height: 8),
        _buildCajaInformativa(
          _resumen.abonosEfectivo > 0
              ? 'Total recibido en efectivo: ${_fm(_resumen.abonosEfectivo)}'
              : '- No se recibieron abonos en este turno -',
        ),
      ],
    );
  }

  // ── WIDGETS HELPER ──
  Widget _buildEncabezadoMetrica({
    required IconData icono,
    required String titulo,
    required String valor,
    required Color colorValor,
  }) {
    return Row(
      children: [
        Icon(icono, size: 24, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155))),
        ),
        Text(valor,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: colorValor)),
      ],
    );
  }

  Widget _buildSeccionTitulo(IconData icono, String titulo) {
    return Row(
      children: [
        Icon(icono, size: 18, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildFilaDinero(
    String label,
    String valor, {
    Color? colorValor,
    VoidCallback? onEditar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF475569))),
              if (onEditar != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.edit_outlined,
                        size: 13, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
          Text(valor,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorValor ?? const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildCajaInformativa(String mensaje, {String? subtotal}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              mensaje,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic),
            ),
          ),
        ),
        if (subtotal != null) ...[
          const SizedBox(height: 4),
          Text(subtotal,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569))),
        ],
      ],
    );
  }

  Widget _buildListaMovimientos(List<MovimientoCaja> movs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: movs.map((m) {
          final esEntrada = m.tipoMovimiento == 'Entrada';
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                    esEntrada
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 14,
                    color: esEntrada
                        ? AppColors.success
                        : AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(m.concepto,
                        style: const TextStyle(fontSize: 12))),
                Text(
                    '${esEntrada ? '+' : '-'} ${_fm(m.monto)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: esEntrada
                            ? AppColors.success
                            : AppColors.error)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListaDepartamentos(
      List<Map<String, dynamic>> deptos) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: deptos.map((d) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        d['nombre']?.toString() ??
                            'Sin Departamento',
                        style: const TextStyle(fontSize: 12))),
                Text(
                    _fm((d['subtotal'] as double?) ?? 0.0),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
