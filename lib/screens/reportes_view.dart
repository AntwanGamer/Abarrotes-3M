import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Vista del módulo de Reportes (Pantalla estilo Eleventa Punto de Venta).
/// Cuenta con barra de período fija y unificada con la barra superior al deslizar,
/// selector interactivo de períodos con botones segmentados y atajos intuitivos.
class ReportesView extends StatefulWidget {
  const ReportesView({super.key});

  @override
  State<ReportesView> createState() => _ReportesViewState();
}

class _ReportesViewState extends State<ReportesView> {
  // Sub-opción activa: 'ventas' o 'clientes'
  String _subOpcion = 'ventas';

  // Filtro de periodo seleccionado
  String _periodoSeleccionado = 'Semana Actual';

  // Fechas del período activo
  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  // Buscador para la pestaña de ventas por cliente
  final _buscarClienteCtrl = TextEditingController();
  String _filtroCliente = '';

  @override
  void initState() {
    super.initState();
    _establecerFechasPorPeriodo('Semana Actual');
  }

  @override
  void dispose() {
    _buscarClienteCtrl.dispose();
    super.dispose();
  }

  /// Configura el rango de fechas según el período predeterminado
  void _establecerFechasPorPeriodo(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoSeleccionado = periodo;
      if (periodo == 'Semana Actual') {
        _fechaInicio = hoy.subtract(Duration(days: hoy.weekday - 1));
        _fechaFin = _fechaInicio.add(const Duration(days: 6));
      } else if (periodo == 'Mes Actual') {
        _fechaInicio = DateTime(hoy.year, hoy.month, 1);
        _fechaFin = DateTime(hoy.year, hoy.month + 1, 0);
      } else if (periodo == 'Mes Anterior') {
        _fechaInicio = DateTime(hoy.year, hoy.month - 1, 1);
        _fechaFin = DateTime(hoy.year, hoy.month, 0);
      } else if (periodo == 'Año actual') {
        _fechaInicio = DateTime(hoy.year, 1, 1);
        _fechaFin = DateTime(hoy.year, 12, 31);
      }
    });
  }

  /// Datos calculados dinámicamente según el período para dar vida a la interfaz
  double get _ventasTotales {
    switch (_periodoSeleccionado) {
      case 'Semana Actual':
        return 24.00;
      case 'Mes Actual':
        return 385.00;
      case 'Mes Anterior':
        return 520.00;
      case 'Año actual':
        return 2480.00;
      default:
        return 120.00;
    }
  }

  double get _gananciaTotal {
    switch (_periodoSeleccionado) {
      case 'Semana Actual':
        return 4.00;
      case 'Mes Actual':
        return 74.50;
      case 'Mes Anterior':
        return 112.00;
      case 'Año actual':
        return 510.00;
      default:
        return 22.00;
    }
  }

  int get _numeroVentas {
    switch (_periodoSeleccionado) {
      case 'Semana Actual':
        return 2;
      case 'Mes Actual':
        return 18;
      case 'Mes Anterior':
        return 29;
      case 'Año actual':
        return 124;
      default:
        return 6;
    }
  }

  double get _ventaPromedio => _numeroVentas > 0 ? _ventasTotales / _numeroVentas : 0.0;
  double get _margenUtilidad => _ventasTotales > 0 ? (_gananciaTotal / _ventasTotales) * 100 : 0.0;

  // Clientes para la segunda pestaña "Ventas por cliente"
  final List<Map<String, dynamic>> _ventasPorClienteData = [
    {
      'folio': 1,
      'nombre': 'Alejandro Morales Silva',
      'ventas': 24.00,
      'ganancia': 4.00,
      'tickets': 2,
      'ultimaCompra': 'Hoy 14:32 hrs',
    },
    {
      'folio': 2,
      'nombre': 'María García Ruiz',
      'ventas': 0.00,
      'ganancia': 0.00,
      'tickets': 0,
      'ultimaCompra': 'Sin compras en el período',
    },
    {
      'folio': 3,
      'nombre': 'Carlos Hernández',
      'ventas': 0.00,
      'ganancia': 0.00,
      'tickets': 0,
      'ultimaCompra': 'Sin compras en el período',
    },
  ];

  String _obtenerNombreMes(int mes) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return meses[(mes - 1).clamp(0, 11)];
  }

  String _obtenerTextoRangoFechas() {
    return '${_fechaInicio.day} ${_obtenerNombreMes(_fechaInicio.month)} ${_fechaInicio.year} - ${_fechaFin.day} ${_obtenerNombreMes(_fechaFin.month)} ${_fechaFin.year}';
  }

  String _obtenerTituloPeriodo() {
    switch (_periodoSeleccionado) {
      case 'Semana Actual':
        return 'Resumen de Ventas de la Semana Actual';
      case 'Mes Actual':
        return 'Resumen de Ventas del Mes Actual';
      case 'Mes Anterior':
        return 'Resumen de Ventas del Mes Anterior';
      case 'Año actual':
        return 'Resumen de Ventas del Año Actual';
      case 'Periodo...':
        return 'Resumen de Ventas del Periodo Personalizado';
      default:
        return 'Resumen de Ventas';
    }
  }

  /// Avanzar o retroceder período con flechas interactivas
  void _navegarPeriodo(int paso) {
    setState(() {
      if (_periodoSeleccionado == 'Semana Actual') {
        _fechaInicio = _fechaInicio.add(Duration(days: 7 * paso));
        _fechaFin = _fechaFin.add(Duration(days: 7 * paso));
      } else if (_periodoSeleccionado == 'Mes Actual' || _periodoSeleccionado == 'Mes Anterior') {
        final nuevoMes = DateTime(_fechaInicio.year, _fechaInicio.month + paso, 1);
        _fechaInicio = nuevoMes;
        _fechaFin = DateTime(nuevoMes.year, nuevoMes.month + 1, 0);
      } else if (_periodoSeleccionado == 'Año actual') {
        final nuevoAnio = _fechaInicio.year + paso;
        _fechaInicio = DateTime(nuevoAnio, 1, 1);
        _fechaFin = DateTime(nuevoAnio, 12, 31);
      }
    });
  }

  /// Diálogo intuitivo y completo para seleccionar un rango de fechas con atajos rápidos
  void _mostrarDialogoPeriodoIntuitivo() {
    DateTime tempInicio = _fechaInicio;
    DateTime tempFin = _fechaFin;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.date_range_rounded, color: AppColors.reportesIcon),
                SizedBox(width: 8),
                Text('Seleccionar Período de Ventas'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Atajos rápidos:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBotonAtajoModal('Hoy', () {
                        final hoy = DateTime.now();
                        setModalState(() {
                          tempInicio = DateTime(hoy.year, hoy.month, hoy.day);
                          tempFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59);
                        });
                      }),
                      _buildBotonAtajoModal('Ayer', () {
                        final ayer = DateTime.now().subtract(const Duration(days: 1));
                        setModalState(() {
                          tempInicio = DateTime(ayer.year, ayer.month, ayer.day);
                          tempFin = DateTime(ayer.year, ayer.month, ayer.day, 23, 59);
                        });
                      }),
                      _buildBotonAtajoModal('Esta semana', () {
                        final hoy = DateTime.now();
                        final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
                        setModalState(() {
                          tempInicio = DateTime(lunes.year, lunes.month, lunes.day);
                          tempFin = tempInicio.add(const Duration(days: 6));
                        });
                      }),
                      _buildBotonAtajoModal('Semana pasada', () {
                        final hoy = DateTime.now();
                        final lunesPasado = hoy.subtract(Duration(days: hoy.weekday + 6));
                        setModalState(() {
                          tempInicio = DateTime(lunesPasado.year, lunesPasado.month, lunesPasado.day);
                          tempFin = tempInicio.add(const Duration(days: 6));
                        });
                      }),
                      _buildBotonAtajoModal('Este mes', () {
                        final hoy = DateTime.now();
                        setModalState(() {
                          tempInicio = DateTime(hoy.year, hoy.month, 1);
                          tempFin = DateTime(hoy.year, hoy.month + 1, 0);
                        });
                      }),
                      _buildBotonAtajoModal('Mes pasado', () {
                        final hoy = DateTime.now();
                        setModalState(() {
                          tempInicio = DateTime(hoy.year, hoy.month - 1, 1);
                          tempFin = DateTime(hoy.year, hoy.month, 0);
                        });
                      }),
                      _buildBotonAtajoModal('Este año', () {
                        final hoy = DateTime.now();
                        setModalState(() {
                          tempInicio = DateTime(hoy.year, 1, 1);
                          tempFin = DateTime(hoy.year, 12, 31);
                        });
                      }),
                    ],
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Rango personalizado de fechas:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempInicio,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempInicio = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            'Desde: ${tempInicio.day}/${tempInicio.month}/${tempInicio.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempFin,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempFin = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            'Hasta: ${tempFin.day}/${tempFin.month}/${tempFin.year}',
                            style: const TextStyle(fontSize: 12),
                          ),
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
                label: const Text('Aplicar Período'),
                onPressed: () {
                  setState(() {
                    _fechaInicio = tempInicio;
                    _fechaFin = tempFin;
                    _periodoSeleccionado = 'Periodo...';
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBotonAtajoModal(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      onPressed: onTap,
    );
  }

  String _formatoMoneda(double valor) {
    return '\$${valor.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra superior de sub-pestañas: [ Reporte de Ventas ] [ Ventas por cliente ]
        _buildBarraSubOpciones(),

        // 2. Barrita de Periodo UNIFICADA en la cabecera (se mantiene fija junto a la de arriba al deslizar)
        if (_subOpcion == 'ventas') _buildBarraPeriodoIntuitiva(),

        // 3. Área de contenido con scroll suave continuo (gráficas, KPIs, desgloses)
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: _subOpcion == 'ventas'
                ? _buildContenidoReporteVentas()
                : _buildContenidoVentasPorCliente(),
          ),
        ),
      ],
    );
  }

  /// Barra de sub-opciones estilo Eleventa
  Widget _buildBarraSubOpciones() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFD9DDE2), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          _buildBotonSubPestana(
            id: 'ventas',
            titulo: 'Reporte de Ventas',
            icono: Icons.bar_chart_rounded,
          ),
          const SizedBox(width: 8),
          _buildBotonSubPestana(
            id: 'clientes',
            titulo: 'Ventas por cliente',
            icono: Icons.people_outline_rounded,
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
    final bool seleccionado = _subOpcion == id;

    return InkWell(
      onTap: () {
        setState(() {
          _subOpcion = id;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFFF1F3F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: seleccionado ? const Color(0xFFCBD5E1) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 16,
              color: seleccionado ? AppColors.reportesIcon : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                color: seleccionado ? AppColors.textPrimary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barrita de Periodo intuitiva y estilizada (fija en la cabecera junto a la barra de arriba)
  Widget _buildBarraPeriodoIntuitiva() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Título dinámico + Badge con rango de fechas + Controles anterior/siguiente
          Row(
            children: [
              Text(
                _obtenerTituloPeriodo(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 14),

              // Badge con el rango de fechas actual
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
                    const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.reportesIcon),
                    const SizedBox(width: 6),
                    Text(
                      _obtenerTextoRangoFechas(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botones de navegación temporal rápida: [ ◀ ] [ ▶ ]
              Tooltip(
                message: 'Período anterior',
                child: InkWell(
                  onTap: () => _navegarPeriodo(-1),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Período siguiente',
                child: InkWell(
                  onTap: () => _navegarPeriodo(1),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Fila 2: Selector intuitivo con botones segmentados / pills interactivos
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBotonSegmentoPeriodo(
                id: 'Semana Actual',
                label: 'Semana Actual',
                icono: Icons.calendar_view_week_rounded,
              ),
              _buildBotonSegmentoPeriodo(
                id: 'Mes Actual',
                label: 'Mes Actual',
                icono: Icons.calendar_view_month_rounded,
              ),
              _buildBotonSegmentoPeriodo(
                id: 'Mes Anterior',
                label: 'Mes Anterior',
                icono: Icons.history_rounded,
              ),
              _buildBotonSegmentoPeriodo(
                id: 'Año actual',
                label: 'Año actual',
                icono: Icons.calendar_today_rounded,
              ),
              _buildBotonSegmentoPeriodo(
                id: 'Periodo...',
                label: 'Periodo Personalizado...',
                icono: Icons.tune_rounded,
                esPersonalizado: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón segmentado individual de período con estilo tipo píldora
  Widget _buildBotonSegmentoPeriodo({
    required String id,
    required String label,
    required IconData icono,
    bool esPersonalizado = false,
  }) {
    final bool activo = _periodoSeleccionado == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (esPersonalizado) {
            _mostrarDialogoPeriodoIntuitivo();
          } else {
            _establecerFechasPorPeriodo(id);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 14,
                color: activo ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
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

  /// Pestaña 1: Reporte de Ventas con gráficas y desgloses
  Widget _buildContenidoReporteVentas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gráfica de barras principal: Ventas vs Ganancia
          _buildGraficaPrincipalVentasGanancia(),

          const SizedBox(height: 20),

          // Métricas KPI principales (Ventas Totales, Ganancia, Número de Ventas, etc.)
          _buildResumenMetricasKPI(),

          const SizedBox(height: 16),

          // Línea divisoria tenue
          const Divider(color: Color(0xFFE2E8F0), thickness: 1),

          const SizedBox(height: 16),

          // Desglose inferior en dos columnas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Ventas por día, Ventas por forma de pago, Impuestos
              Expanded(
                child: _buildColumnaIzquierda(),
              ),

              const SizedBox(width: 32),

              // Columna Derecha: Ventas por Departamento (Dona) y Ganancia por Departamento (Dona)
              Expanded(
                child: _buildColumnaDerecha(),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Gráfica de barras interactiva Ventas vs Ganancia
  Widget _buildGraficaPrincipalVentasGanancia() {
    final double escalaMax = _ventasTotales > 0 ? (_ventasTotales * 1.15) : 30.0;
    final double alturaVentas = (_ventasTotales / escalaMax) * 160;
    final double alturaGanancia = (_gananciaTotal / escalaMax) * 160;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leyenda superior derecha (Ventas / Ganancia)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildItemLeyenda(const Color(0xFF7C8FB5), 'Ventas'),
              const SizedBox(width: 14),
              _buildItemLeyenda(const Color(0xFF384E6E), 'Ganancia'),
            ],
          ),

          const SizedBox(height: 10),

          // Canvas de la gráfica con eje Y y barras
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Etiqueta vertical y valores del eje Y
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatoMoneda(escalaMax * 0.8), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(_formatoMoneda(escalaMax * 0.4), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    const Text('\$0.00', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),

                const SizedBox(width: 10),

                // Área principal de barras con líneas guía horizontales
                Expanded(
                  child: Stack(
                    children: [
                      // Líneas de cuadrícula
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(height: 1, color: const Color(0xFFF1F5F9)),
                          Container(height: 1, color: const Color(0xFFF1F5F9)),
                          Container(height: 1, color: const Color(0xFFCBD5E1)),
                        ],
                      ),

                      // Barras alineadas al fondo
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 30, bottom: 1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Barra Ventas
                              Tooltip(
                                message: 'Ventas: ${_formatoMoneda(_ventasTotales)}',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 44,
                                  height: alturaVentas.clamp(8, 175),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7C8FB5),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(2),
                                      topRight: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),

                              // Barra Ganancia
                              Tooltip(
                                message: 'Ganancia: ${_formatoMoneda(_gananciaTotal)}',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 44,
                                  height: alturaGanancia.clamp(8, 175),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF384E6E),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(2),
                                      topRight: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 80),

                              // Columnas vacías 1 y 2 (como en eleventa)
                              const SizedBox(width: 60),
                              const SizedBox(width: 60),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Etiquetas del eje X
          Padding(
            padding: const EdgeInsets.only(left: 65, top: 4),
            child: Row(
              children: const [
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      'Miércoles',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                SizedBox(width: 50),
                Text('1', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                SizedBox(width: 80),
                Text('2', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjetas de Resumen KPI (Ventas Totales, Ganancia, Número de Ventas, etc.)
  Widget _buildResumenMetricasKPI() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bloque Izquierdo
        Expanded(
          child: Column(
            children: [
              _buildFilaMetrica('Ventas Totales', _formatoMoneda(_ventasTotales), esGrande: true),
              const SizedBox(height: 6),
              _buildFilaMetrica('Número de Ventas', _numeroVentas.toString()),
              const SizedBox(height: 6),
              _buildFilaMetrica('Venta Promedio', _formatoMoneda(_ventaPromedio)),
            ],
          ),
        ),

        const SizedBox(width: 48),

        // Bloque Derecho
        Expanded(
          child: Column(
            children: [
              _buildFilaMetrica('Ganancia', _formatoMoneda(_gananciaTotal), esGrande: true),
              const SizedBox(height: 6),
              _buildFilaMetrica(
                'Margen de utilidad promedio',
                '${_margenUtilidad.toStringAsFixed(2)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilaMetrica(String label, String valor, {bool esGrande = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: esGrande ? 14 : 12.5,
            fontWeight: esGrande ? FontWeight.w600 : FontWeight.normal,
            color: esGrande ? const Color(0xFF1E3A5F) : const Color(0xFF475569),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: esGrande ? 15 : 12.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  /// Columna Izquierda: Ventas por día, Ventas por forma de pago, Impuestos
  Widget _buildColumnaIzquierda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ventas por día
        const Text(
          'Ventas por día',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Miércoles', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
              Text(
                _formatoMoneda(_ventasTotales),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 14),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatoMoneda(_ventasTotales),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 2. Ventas por forma de pago (con mini gráfica de barras cyan)
        const Text(
          'Ventas por forma de pago',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
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
              // Gráfica de barra de forma de pago
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    // Eje Y
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('\$25.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        Text('\$20.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        Text('\$15.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        Text('\$10.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        Text('\$5.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        Text('\$0.00', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Barra Efectivo Cyan
                    Expanded(
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Tooltip(
                              message: 'Efectivo: ${_formatoMoneda(_ventasTotales)}',
                              child: Container(
                                width: 75,
                                height: 135,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38BDF8), // Cyan de eleventa
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(2),
                                    topRight: Radius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Leyenda lateral de formas de pago
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMiniLeyenda(const Color(0xFF38BDF8), 'Efectivo'),
                        _buildMiniLeyenda(const Color(0xFFFBBF24), 'Vales'),
                        _buildMiniLeyenda(const Color(0xFFFB923C), 'Tarjeta'),
                        _buildMiniLeyenda(const Color(0xFF3B82F6), 'Crédito'),
                        _buildMiniLeyenda(const Color(0xFF14B8A6), 'Transferencia'),
                        _buildMiniLeyenda(const Color(0xFFDC2626), 'Cheque'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Miércoles',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),

              const Divider(height: 18),

              // Renglón de total en efectivo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Efectivo', style: TextStyle(fontSize: 12.5)),
                  Text(
                    _formatoMoneda(_ventasTotales),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Impuestos
        const Text(
          'Impuestos',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Center(
            child: Text(
              '- No se registró ninguna venta -',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }

  /// Columna Derecha: Ventas por Departamento (Dona) y Ganancia por Departamento (Dona)
  Widget _buildColumnaDerecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ventas por Departamento
        const Text(
          'Ventas por Departamento',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('- Sin Departamento -', style: TextStyle(fontSize: 12.5)),
              Text(
                _formatoMoneda(_ventasTotales),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Gráfica de Dona: Ventas por Departamento (Verde azulado / Mint)
        _buildGraficaDona(
          color: const Color(0xFF5EEAD4), // Mint / Verde azulado de eleventa
          etiqueta: '- Sin Departamento - (${_formatoMoneda(_ventasTotales)})',
        ),

        const SizedBox(height: 28),

        // 2. Ganancia por Departamento
        const Text(
          'Ganancia por Departamento',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('- Sin Departamento -', style: TextStyle(fontSize: 12.5)),
              Text(
                _formatoMoneda(_gananciaTotal),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Gráfica de Dona: Ganancia por Departamento (Púrpura / Borgoña)
        _buildGraficaDona(
          color: const Color(0xFF9E4770), // Púrpura / Borgoña de eleventa
          etiqueta: '- Sin Departamento - (${_formatoMoneda(_gananciaTotal)})',
        ),
      ],
    );
  }

  /// Gráfica de dona circular personalizada con hueco central y leyenda
  Widget _buildGraficaDona({
    required Color color,
    required String etiqueta,
  }) {
    return Row(
      children: [
        // Anillo de Dona
        CustomPaint(
          size: const Size(110, 110),
          painter: _DonutChartPainter(color: color),
        ),
        const SizedBox(width: 20),
        // Leyenda lateral
        Expanded(
          child: Row(
            children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  etiqueta,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pestaña 2: Ventas por cliente con buscador y tabla detallada
  Widget _buildContenidoVentasPorCliente() {
    final filtrados = _ventasPorClienteData.where((c) {
      final query = _filtroCliente.trim().toLowerCase();
      if (query.isEmpty) return true;
      final nombre = c['nombre'].toString().toLowerCase();
      final folio = c['folio'].toString();
      return nombre.contains(query) || folio.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reporte de Ventas por Cliente',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              // Buscador de clientes
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  controller: _buscarClienteCtrl,
                  onChanged: (val) => setState(() => _filtroCliente = val),
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tabla de clientes
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Encabezado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 50, child: Text('Folio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Total Ventas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Ganancia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 3, child: Text('Última Compra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                  ),

                  // Filas
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final c = filtrados[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  c['folio'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  c['nombre'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Expanded(flex: 2, child: Text('${c['tickets']} ventas', style: const TextStyle(fontSize: 12.5))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatoMoneda((c['ventas'] as num).toDouble()),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatoMoneda((c['ganancia'] as num).toDouble()),
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Expanded(flex: 3, child: Text(c['ultimaCompra'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemLeyenda(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
      ],
    );
  }

  Widget _buildMiniLeyenda(Color color, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 5),
          Text(texto, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}

/// CustomPainter para dibujar la gráfica de dona (anillo)
class _DonutChartPainter extends CustomPainter {
  final Color color;

  const _DonutChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 24.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Dibujar el arco completo (círculo donut)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      0,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => oldDelegate.color != color;
}
