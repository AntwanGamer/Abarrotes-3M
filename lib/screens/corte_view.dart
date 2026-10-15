import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Modelo para registrar movimientos de efectivo (Entradas y Salidas de caja)
class MovimientoEfectivo {
  final String tipo; // 'Entrada' o 'Salida'
  final double monto;
  final String motivo;
  final DateTime hora;

  MovimientoEfectivo({
    required this.tipo,
    required this.monto,
    required this.motivo,
    DateTime? hora,
  }) : hora = hora ?? DateTime.now();
}

/// Vista del módulo de Corte (Corte de Caja / Turno estilo Eleventa Punto de Venta).
/// Muestra métricas financieras, dinero en caja, desglose por métodos de pago y arqueo de turno.
class CorteView extends StatefulWidget {
  const CorteView({super.key});

  @override
  State<CorteView> createState() => _CorteViewState();
}

class _CorteViewState extends State<CorteView> {
  // Tipo de corte seleccionado: 'cajero' o 'dia'
  String _tipoCorte = 'cajero';

  // Datos de caja representativos
  double _fondoCaja = 500.00;
  final double _ventasEfectivo = 0.00;
  final double _abonosEfectivo = 0.00;
  final double _devolucionesEfectivo = 0.00;

  // Desglose de ventas por método de pago
  final double _ventasTarjeta = 0.00;
  final double _ventasCredito = 0.00;
  final double _ventasVales = 0.00;
  final double _ventasTransferencia = 0.00;
  final double _ventasCheque = 0.00;
  final double _devolucionesVentas = 0.00;

  // Ganancia e impuestos
  final double _gananciaTotal = 0.00;

  // Lista de movimientos de efectivo durante el turno
  final List<MovimientoEfectivo> _movimientos = [];

  // Cálculos dinámicos
  double get _totalEntradas => _movimientos
      .where((m) => m.tipo == 'Entrada')
      .fold(0.0, (acc, m) => acc + m.monto);

  double get _totalSalidas => _movimientos
      .where((m) => m.tipo == 'Salida')
      .fold(0.0, (acc, m) => acc + m.monto);

  double get _totalVentas =>
      _ventasEfectivo +
      _ventasTarjeta +
      _ventasCredito +
      _ventasVales +
      _ventasTransferencia +
      _ventasCheque -
      _devolucionesVentas;

  double get _dineroEnCaja =>
      _fondoCaja +
      _ventasEfectivo +
      _abonosEfectivo +
      _totalEntradas -
      _totalSalidas -
      _devolucionesEfectivo;

  String _formatoMoneda(double valor) {
    return '\$${valor.toStringAsFixed(2)}';
  }

  /// Diálogo para registrar una Entrada o Salida de efectivo
  void _mostrarDialogoMovimiento(String tipo) {
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a ingresar / retirar',
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
              backgroundColor: tipo == 'Entrada' ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final monto = double.tryParse(montoCtrl.text.replaceAll(',', '')) ?? 0.0;
              final motivo = motivoCtrl.text.trim();
              if (monto > 0) {
                setState(() {
                  _movimientos.add(
                    MovimientoEfectivo(
                      tipo: tipo,
                      monto: monto,
                      motivo: motivo.isNotEmpty ? motivo : 'Sin motivo especificado',
                    ),
                  );
                });
                Navigator.pop(ctx);
                _mostrarMensaje('$tipo de ${_formatoMoneda(monto)} registrada correctamente');
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para cambiar el Fondo Inicial de Caja
  void _mostrarDialogoFondoCaja() {
    final fondoCtrl = TextEditingController(text: _fondoCaja.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppColors.corteIcon),
            SizedBox(width: 8),
            Text('Ajustar Fondo Inicial de Caja'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: fondoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              final nuevoFondo = double.tryParse(fondoCtrl.text.replaceAll(',', '')) ?? _fondoCaja;
              setState(() {
                _fondoCaja = nuevoFondo;
              });
              Navigator.pop(ctx);
              _mostrarMensaje('Fondo de caja actualizado a ${_formatoMoneda(nuevoFondo)}');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo de Arqueo y Cierre de Turno
  void _mostrarDialogoCerrarTurno() {
    final efectivoContadoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final contado = double.tryParse(efectivoContadoCtrl.text.replaceAll(',', '')) ?? 0.0;
          final diferencia = contado - _dineroEnCaja;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          _formatoMoneda(_dineroEnCaja),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      const Text('Diferencia:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        diferencia == 0.0
                            ? 'Exacto (\$0.00)'
                            : (diferencia > 0
                                ? '+ ${_formatoMoneda(diferencia)} (Sobrante)'
                                : '- ${_formatoMoneda(diferencia.abs())} (Faltante)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: diferencia == 0.0
                              ? AppColors.success
                              : (diferencia > 0 ? Colors.blue : AppColors.error),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  _mostrarMensaje('Turno cerrado exitosamente. Corte registrado.');
                },
                child: const Text('Confirmar y Cerrar Turno'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Vista previa de impresión del corte estilo ticket
  void _mostrarVistaPreviaImpresion() {
    final horaActual = TimeOfDay.now().format(context);
    final fechaActual =
        '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    child: Text(
                      'ABARROTES 3M',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'PUNTO DE VENTA',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const Divider(height: 24),
                  Text('Tipo: ${_tipoCorte == 'cajero' ? 'CORTE DE CAJERO' : 'CORTE DEL DÍA'}'),
                  Text('Fecha: $fechaActual  Hora: $horaActual'),
                  const Divider(height: 20),
                  _buildFilaTicket('Fondo Inicial de Caja:', _formatoMoneda(_fondoCaja)),
                  _buildFilaTicket('Ventas Totales:', _formatoMoneda(_totalVentas)),
                  _buildFilaTicket('Ventas en Efectivo:', _formatoMoneda(_ventasEfectivo)),
                  _buildFilaTicket('Entradas de Efectivo:', '+ ${_formatoMoneda(_totalEntradas)}'),
                  _buildFilaTicket('Salidas de Efectivo:', '- ${_formatoMoneda(_totalSalidas)}'),
                  const Divider(height: 20),
                  _buildFilaTicket(
                    'TOTAL EN CAJA:',
                    _formatoMoneda(_dineroEnCaja),
                    esTotal: true,
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      '*** Fin del Reporte de Corte ***',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
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
              _mostrarMensaje('Enviando reporte de corte a la impresora térmica...');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilaTicket(String label, String valor, {bool esTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: esTotal ? 13 : 12,
              fontWeight: esTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: esTotal ? 14 : 12,
              fontWeight: esTotal ? FontWeight.bold : FontWeight.w600,
              color: esTotal ? AppColors.corteIcon : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.corteIcon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra de sub-opciones estilo Eleventa: [ Hacer corte de cajero ] [ Hacer corte del día ]
        _buildBarraSubOpciones(),

        // 2. Contenido principal con las dos columnas de reportes
        Expanded(
          child: Container(
            color: const Color(0xFFF8F9FA),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado del corte con horario y botones Imprimir / Cerrar turno
                  _buildEncabezadoCorte(),

                  const SizedBox(height: 16),

                  // Contenido en dos columnas
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna Izquierda: Ventas Totales, Dinero en Caja, Entradas, Departamentos, Impuestos
                      Expanded(
                        child: _buildColumnaIzquierda(),
                      ),

                      const SizedBox(width: 24),

                      // Columna Derecha: Ganancia, Desglose de Ventas, Ingresos Contado, Salidas, etc.
                      Expanded(
                        child: _buildColumnaDerecha(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Barra de sub-opciones superior con pestañas estilo Eleventa
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
          _buildBotonSubOpcion(
            id: 'cajero',
            titulo: 'Hacer corte de cajero',
            icono: Icons.content_cut_rounded,
          ),
          const SizedBox(width: 8),
          _buildBotonSubOpcion(
            id: 'dia',
            titulo: 'Hacer corte del día',
            icono: Icons.content_cut_rounded,
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
    final bool seleccionado = _tipoCorte == id;

    return InkWell(
      onTap: () {
        setState(() {
          _tipoCorte = id;
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
              color: seleccionado ? AppColors.corteIcon : const Color(0xFF64748B),
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

  /// Encabezado con información del período y botones de acción
  Widget _buildEncabezadoCorte() {
    final String titulo = _tipoCorte == 'cajero'
        ? 'Corte de Cajero (Turno actual)'
        : 'Corte del Día (Todas las ventas del día)';

    final String subtitulo = _tipoCorte == 'cajero'
        ? 'De las 08:00 hrs a las ${TimeOfDay.now().format(context)} hrs'
        : 'De las 00:00 hrs a las 23:59 hrs (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year})';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const Spacer(),

        // Botón Imprimir
        OutlinedButton.icon(
          onPressed: _mostrarVistaPreviaImpresion,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Imprimir', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        const SizedBox(width: 10),

        // Botón Cerrar Turno
        OutlinedButton.icon(
          onPressed: _mostrarDialogoCerrarTurno,
          icon: const Icon(Icons.lock_clock_outlined, size: 16),
          label: const Text('Cerrar turno...', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  /// Columna Izquierda: Ventas Totales, Dinero en Caja, Entradas, Departamentos, Impuestos
  Widget _buildColumnaIzquierda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Ventas Totales
        _buildEncabezadoMetrica(
          icono: Icons.attach_money_rounded,
          titulo: 'Ventas Totales',
          valor: _formatoMoneda(_totalVentas),
          colorValor: const Color(0xFF0284C7),
        ),

        const SizedBox(height: 20),

        // 2. Dinero en Caja
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
              _buildFilaDinero(
                'Fondo de caja',
                _formatoMoneda(_fondoCaja),
                onEditar: _mostrarDialogoFondoCaja,
              ),
              _buildFilaDinero(
                'Ventas en Efectivo',
                '+ ${_formatoMoneda(_ventasEfectivo)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Abonos en efectivo',
                '+ ${_formatoMoneda(_abonosEfectivo)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Entradas',
                '+ ${_formatoMoneda(_totalEntradas)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Salidas',
                '- ${_formatoMoneda(_totalSalidas)}',
                colorValor: AppColors.error,
              ),
              _buildFilaDinero(
                'Devoluciones en efectivo',
                '- ${_formatoMoneda(_devolucionesEfectivo)}',
                colorValor: AppColors.error,
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total en Caja:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    _formatoMoneda(_dineroEnCaja),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mostrarDialogoMovimiento('Entrada'),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Entrada', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mostrarDialogoMovimiento('Salida'),
                      icon: const Icon(Icons.remove_rounded, size: 14),
                      label: const Text('Salida', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Entradas de efectivo
        _buildSeccionTitulo(Icons.arrow_downward_rounded, 'Entradas de efectivo'),
        const SizedBox(height: 8),
        _buildCajaInformativa(
          _movimientos.any((m) => m.tipo == 'Entrada')
              ? '${_movimientos.where((m) => m.tipo == 'Entrada').length} entradas registradas (${_formatoMoneda(_totalEntradas)})'
              : '- No hubo Entradas en Efectivo -',
        ),

        const SizedBox(height: 20),

        // 4. Ventas por Departamento
        _buildSeccionTitulo(Icons.folder_outlined, 'Ventas por Departamento'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No se registró ninguna venta -'),

        const SizedBox(height: 20),

        // 5. Impuestos
        _buildSeccionTitulo(Icons.percent_rounded, 'Impuestos'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No hubo ventas -'),
      ],
    );
  }

  /// Columna Derecha: Ganancia, Ventas por Método, Ingresos Contado, Salidas, Clientes
  Widget _buildColumnaDerecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Ganancia
        _buildEncabezadoMetrica(
          icono: Icons.bar_chart_rounded,
          titulo: 'Ganancia',
          valor: _formatoMoneda(_gananciaTotal),
          colorValor: const Color(0xFF0284C7),
        ),

        const SizedBox(height: 20),

        // 2. Ventas desglosadas por método de pago
        _buildSeccionTitulo(Icons.shopping_cart_outlined, 'Ventas'),
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
              _buildFilaDinero(
                'En Efectivo',
                '+ ${_formatoMoneda(_ventasEfectivo)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Con Tarjeta de Crédito',
                '+ ${_formatoMoneda(_ventasTarjeta)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'A Crédito',
                '+ ${_formatoMoneda(_ventasCredito)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Con Vales de Despensa',
                '+ ${_formatoMoneda(_ventasVales)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Con Transferencia',
                '+ ${_formatoMoneda(_ventasTransferencia)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Con Cheque',
                '+ ${_formatoMoneda(_ventasCheque)}',
                colorValor: AppColors.success,
              ),
              _buildFilaDinero(
                'Devoluciones de Ventas',
                '- ${_formatoMoneda(_devolucionesVentas)}',
                colorValor: AppColors.error,
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    _formatoMoneda(_totalVentas),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. Ingresos de contado
        _buildSeccionTitulo(Icons.payments_outlined, 'Ingresos de contado'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No hubo ingresos de contado -', subtotal: _formatoMoneda(0.00)),

        const SizedBox(height: 20),

        // 4. Salidas de Efectivo
        _buildSeccionTitulo(Icons.arrow_upward_rounded, 'Salidas de Efectivo'),
        const SizedBox(height: 8),
        _buildCajaInformativa(
          _movimientos.any((m) => m.tipo == 'Salida')
              ? '${_movimientos.where((m) => m.tipo == 'Salida').length} salidas registradas (${_formatoMoneda(_totalSalidas)})'
              : '- No hubo Salidas en Efectivo -',
        ),

        const SizedBox(height: 20),

        // 5. Pagos de Créditos
        _buildSeccionTitulo(Icons.group_outlined, 'Pagos de Créditos'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No se recibieron pagos de créditos -'),

        const SizedBox(height: 20),

        // 6. Clientes con más ventas
        _buildSeccionTitulo(Icons.person_outline_rounded, 'Clientes con más ventas'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No hubo ventas -'),

        const SizedBox(height: 20),

        // 7. Clientes con más ganancia
        _buildSeccionTitulo(Icons.person_outline_rounded, 'Clientes con más ganancia'),
        const SizedBox(height: 8),
        _buildCajaInformativa('- No hubo ventas -'),
      ],
    );
  }

  /// Encabezado de métrica grande estilo "$ Ventas Totales   $0.00"
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
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const Spacer(),
        Text(
          valor,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: colorValor,
          ),
        ),
      ],
    );
  }

  /// Título de sección con icono estilo Eleventa
  Widget _buildSeccionTitulo(IconData icono, String titulo) {
    return Row(
      children: [
        Icon(icono, size: 18, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  /// Fila de monto monetario con etiqueta y opción de edición
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
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
              ),
              if (onEditar != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.edit_outlined, size: 13, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colorValor ?? const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  /// Caja informativa sombreada estilo Eleventa: "- No hubo Entradas en Efectivo -"
  Widget _buildCajaInformativa(String mensaje, {String? subtotal}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        if (subtotal != null) ...[
          const SizedBox(height: 4),
          Text(
            subtotal,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }
}
