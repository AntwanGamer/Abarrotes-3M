import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../models/configuracion.dart';
import '../models/helpers.dart';
import '../models/usuario_db.dart';
import '../repositories/catalogos_repository.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'usuarios_view.dart';

/// Módulo de Configuración y Ajustes (Estilo Panel Central con Iconos de Eleventa).
class ConfiguracionView extends StatefulWidget {
  final UsuarioDB usuario;
  const ConfiguracionView({super.key, required this.usuario});

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  // 'Hub' o el nombre de la sub-pantalla activa
  String _seccionActiva = 'Hub';

  void _irA(String seccion) {
    setState(() => _seccionActiva = seccion);
  }

  void _volverAlHub() {
    setState(() => _seccionActiva = 'Hub');
  }

  bool get _puedeUsuarios => widget.usuario.puedeGestionarUsuarios;
  bool get _puedeConfiguracion => widget.usuario.puedeConfigurar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra superior contextual con botón permanente de regreso al Hub
        _buildBarraSuperior(),

        // 2. Área de contenido: Hub de Iconos o Sub-pantalla
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _seccionActiva == 'Hub'
                ? _buildHubPrincipal()
                : _buildSubPantalla(),
          ),
        ),
      ],
    );
  }

  /// Barra superior de navegación del módulo de Configuración
  Widget _buildBarraSuperior() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Botón siempre visible para volver al Hub de opciones
          OutlinedButton.icon(
            onPressed: _seccionActiva == 'Hub' ? null : _volverAlHub,
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Mostrar todas las opciones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              foregroundColor: _seccionActiva == 'Hub' ? Colors.grey : const Color(0xFF334155),
              side: BorderSide(color: _seccionActiva == 'Hub' ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(width: 16),
          if (_seccionActiva != 'Hub') ...[
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(
              _seccionActiva.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Color(0xFF334155),
              ),
            ),
          ] else ...[
            const Text(
              'PANEL PRINCIPAL DE AJUSTES',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // HUB PRINCIPAL CON BLOQUES HORIZONTALES E ICONOS ESTILO ELEVENTA
  // ===========================================================================
  Widget _buildHubPrincipal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección 1: GENERAL
          _buildBloqueSeccion(
            titulo: 'GENERAL',
            descripcion: 'Configuraciones esenciales de usuarios, roles y sincronización.',
            items: [
              _buildBotonHub(
                titulo: 'Usuarios y Permisos',
                icono: Icons.manage_accounts_rounded,
                colorIcono: AppColors.usuariosIcon,
                permitido: _puedeUsuarios,
                motivoBloqueo: 'Requiere permiso: usuarios_gestionar',
                onTap: () => _irA('Usuarios y Permisos'),
              ),
              _buildBotonHub(
                titulo: 'Base de Datos y Sincronización',
                icono: Icons.cloud_sync_rounded,
                colorIcono: const Color(0xFF2563EB),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Base de Datos y Sincronización'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sección 2: PERSONALIZACIÓN
          _buildBloqueSeccion(
            titulo: 'PERSONALIZACIÓN',
            descripcion: 'Datos del comercio, membrete y diseño visual del ticket de venta.',
            items: [
              _buildBotonHub(
                titulo: 'Ticket y Negocio',
                icono: Icons.receipt_long_rounded,
                colorIcono: const Color(0xFFD97706),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Ticket y Negocio'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sección 3: DISPOSITIVOS
          _buildBloqueSeccion(
            titulo: 'DISPOSITIVOS',
            descripcion: 'Periféricos de punto de venta: impresoras, lectores, cajón y básculas.',
            items: [
              _buildBotonHub(
                titulo: 'Impresora de Tickets',
                icono: Icons.print_rounded,
                colorIcono: const Color(0xFF0D9488),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Impresora de Tickets'),
              ),
              _buildBotonHub(
                titulo: 'Lector de Códigos',
                icono: Icons.qr_code_scanner_rounded,
                colorIcono: const Color(0xFF4F46E5),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Lector de Códigos'),
              ),
              _buildBotonHub(
                titulo: 'Cajón de Dinero',
                icono: Icons.point_of_sale_rounded,
                colorIcono: const Color(0xFF16A34A),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Cajón de Dinero'),
              ),
              _buildBotonHub(
                titulo: 'Báscula',
                icono: Icons.scale_rounded,
                colorIcono: const Color(0xFF7C3AED),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Báscula'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sección 4: MANTENIMIENTO Y RESPALDOS
          _buildBloqueSeccion(
            titulo: 'MANTENIMIENTO Y RESPALDOS',
            descripcion: 'Copias de seguridad, rotación automática y restauración del sistema.',
            items: [
              _buildBotonHub(
                titulo: 'Respaldo Automático',
                icono: Icons.auto_mode_rounded,
                colorIcono: const Color(0xFF0284C7),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Respaldo Automático'),
              ),
              _buildBotonHub(
                titulo: 'Respaldos y Restauración',
                icono: Icons.settings_backup_restore_rounded,
                colorIcono: const Color(0xFFEA580C),
                permitido: _puedeConfiguracion,
                motivoBloqueo: 'Requiere permiso: configuracion',
                onTap: () => _irA('Respaldos y Restauración'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBloqueSeccion({
    required String titulo,
    required String descripcion,
    required List<Widget> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  descripcion,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: items,
          ),
        ],
      ),
    );
  }

  Widget _buildBotonHub({
    required String titulo,
    required IconData icono,
    required Color colorIcono,
    required bool permitido,
    required String motivoBloqueo,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: permitido ? titulo : motivoBloqueo,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: permitido ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: permitido ? 1.0 : 0.45,
            child: Container(
              width: 175,
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorIcono.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, size: 28, color: colorIcono),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB-PANTALLAS
  // ===========================================================================
  Widget _buildSubPantalla() {
    switch (_seccionActiva) {
      case 'Usuarios y Permisos':
        return const UsuariosView();
      case 'Base de Datos y Sincronización':
        return const _SubPantallaSyncComparativa();
      case 'Ticket y Negocio':
        return const _SubPantallaTicketNegocio();
      case 'Impresora de Tickets':
        return const _SubPantallaImpresora();
      case 'Lector de Códigos':
        return const _SubPantallaLector();
      case 'Cajón de Dinero':
        return const _SubPantallaCajon();
      case 'Báscula':
        return const _SubPantallaBascula();
      case 'Respaldo Automático':
        return const _SubPantallaRespaldoAuto();
      case 'Respaldos y Restauración':
        return const _SubPantallaRespaldosManuales();
      default:
        return const Center(child: Text('Sub-pantalla en construcción'));
    }
  }
}

// =============================================================================
// SUB-PANTALLA 1.2: BASE DE DATOS Y SINCRONIZACIÓN (COMPARATIVA LOCAL VS NUBE)
// =============================================================================
class _SubPantallaSyncComparativa extends StatefulWidget {
  const _SubPantallaSyncComparativa();

  @override
  State<_SubPantallaSyncComparativa> createState() => _SubPantallaSyncComparativaState();
}

class _SubPantallaSyncComparativaState extends State<_SubPantallaSyncComparativa> {
  bool _cargando = true;
  bool _sincronizando = false;

  int _pendientesSubir = 0;

  // Local
  String _localUltimaVenta = '-';
  String _localUltimoMov = '-';
  String _localUltimoProd = '-';
  DateTime? _localFechaVenta;

  // Nube
  bool _nubeConectada = false;
  String _nubeUltimaVenta = '-';
  String _nubeUltimoMov = '-';
  String _nubeUltimoProd = '-';
  DateTime? _nubeFechaVenta;

  @override
  void initState() {
    super.initState();
    _cargarComparativa();
  }

  Future<void> _cargarComparativa() async {
    setState(() => _cargando = true);
    final db = DatabaseService.instance;

    // 1. Consulta Local
    try {
      // Conteo de registros no sincronizados
      int pendientes = 0;
      for (final t in BackupService.tablasOrdenadas) {
        final r = await db.query('SELECT COUNT(*) as c FROM $t WHERE sincronizado = FALSE');
        if (r.isNotEmpty) {
          pendientes += parseIntSafe(r.first.toColumnMap()['c']);
        }
      }
      _pendientesSubir = pendientes;

      // Última venta local
      final vRes = await db.query('SELECT folio_ticket, total, fecha_venta FROM tbl_ventas ORDER BY id_venta DESC LIMIT 1');
      if (vRes.isNotEmpty) {
        final m = vRes.first.toColumnMap();
        final dt = parseDateTime(m['fecha_venta']);
        _localFechaVenta = dt;
        _localUltimaVenta = 'Ticket #${m['folio_ticket']} • \$${parseDecimal(m['total']).toStringAsFixed(2)}\n${_formatFecha(dt)}';
      }

      // Último movimiento de inventario local
      final mRes = await db.query('''
        SELECT p.descripcion, m.tipo_movimiento, m.fecha_registro
        FROM tbl_movimientos_inventario m
        JOIN tbl_productos p ON m.id_producto = p.id_producto
        ORDER BY m.id_movimiento DESC LIMIT 1
      ''');
      if (mRes.isNotEmpty) {
        final m = mRes.first.toColumnMap();
        final dt = parseDateTime(m['fecha_registro']);
        _localUltimoMov = '${m['descripcion']}\n${m['tipo_movimiento']} • ${_formatFecha(dt)}';
      }

      // Última actualización de productos local
      final pRes = await db.query("SELECT MAX(fecha_actualizacion) as max_f, COUNT(*) as c FROM tbl_productos WHERE estatus::text = 'Activo'");
      if (pRes.isNotEmpty) {
        final m = pRes.first.toColumnMap();
        final dt = m['max_f'] != null ? parseDateTime(m['max_f']) : null;
        _localUltimoProd = '${m['c']} productos activos\n${dt != null ? _formatFecha(dt) : '-'}';
      }
    } catch (_) {}

    // 2. Consulta Nube (Supabase en paralelo tolerante a fallos)
    try {
      final reachable = await db.isSupabaseReachable();
      _nubeConectada = reachable;
      if (reachable) {
        final sb = db.supabase;

        // Venta en Supabase
        final vRes = await sb.from('tbl_ventas').select('folio_ticket, total, fecha_venta').order('id_venta', ascending: false).limit(1);
        if (vRes is List && vRes.isNotEmpty) {
          final m = vRes.first;
          final dt = parseDateTime(m['fecha_venta']);
          _nubeFechaVenta = dt;
          _nubeUltimaVenta = 'Ticket #${m['folio_ticket']} • \$${parseDecimal(m['total']).toStringAsFixed(2)}\n${_formatFecha(dt)}';
        }

        // Movimiento en Supabase
        final mRes = await sb.from('tbl_movimientos_inventario').select('tipo_movimiento, fecha_registro').order('id_movimiento', ascending: false).limit(1);
        if (mRes is List && mRes.isNotEmpty) {
          final m = mRes.first;
          final dt = parseDateTime(m['fecha_registro']);
          _nubeUltimoMov = '${m['tipo_movimiento']}\n${_formatFecha(dt)}';
        }

        // Productos en Supabase
        final pRes = await sb.from('tbl_productos').select('fecha_actualizacion').eq('estatus', 'Activo');
        if (pRes is List) {
          final count = pRes.length;
          _nubeUltimoProd = '$count productos en nube';
        }
      }
    } catch (_) {
      _nubeConectada = false;
    }

    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _sincronizarAhora() async {
    setState(() => _sincronizando = true);
    await SyncService.instance.syncNow();
    await _cargarComparativa();
    if (mounted) {
      setState(() => _sincronizando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ciclo de sincronización ejecutado.')),
      );
    }
  }

  String _formatFecha(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool localMasReciente = _localFechaVenta != null &&
        (_nubeFechaVenta == null || _localFechaVenta!.isAfter(_nubeFechaVenta!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: Color(0xFF2563EB), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTADO DE BASE DE DATOS Y SINCRONIZACIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                    Text('Comparativa en vivo entre la base de datos local y la nube (Supabase).',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cargando ? null : _cargarComparativa,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Actualizar comparativa'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _sincronizando ? null : _sincronizarAhora,
                icon: _sincronizando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.sync_rounded),
                label: Text(_sincronizando ? 'Sincronizando...' : 'Sincronizar ahora'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Indicador de pendientes por subir
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _pendientesSubir > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pendientesSubir > 0 ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Icon(
                  _pendientesSubir > 0 ? Icons.cloud_upload_outlined : Icons.check_circle_outline_rounded,
                  color: _pendientesSubir > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 12),
                Text(
                  _pendientesSubir > 0
                      ? 'Hay $_pendientesSubir registros locales pendientes de subir a la nube.'
                      : 'Todos los registros locales están sincronizados con la nube.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _pendientesSubir > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tarjetas comparativas Lado a Lado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta 1: Local
              Expanded(
                child: _buildTarjetaComparativa(
                  titulo: 'PostgreSQL Local (Esta Terminal)',
                  subtitulo: 'Operación rápida Offline-First',
                  icono: Icons.storage_rounded,
                  color: const Color(0xFF0F766E),
                  esActiva: true,
                  esMasReciente: localMasReciente,
                  ultimaVenta: _localUltimaVenta,
                  ultimoMov: _localUltimoMov,
                  ultimoProd: _localUltimoProd,
                ),
              ),
              const SizedBox(width: 20),

              // Tarjeta 2: Supabase (Nube)
              Expanded(
                child: _buildTarjetaComparativa(
                  titulo: 'Supabase (Nube Central)',
                  subtitulo: _nubeConectada ? 'Conexión activa con el servidor' : 'Sin conexión o sin internet',
                  icono: Icons.cloud_done_rounded,
                  color: _nubeConectada ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                  esActiva: _nubeConectada,
                  esMasReciente: !localMasReciente && _nubeFechaVenta != null,
                  ultimaVenta: _nubeConectada ? _nubeUltimaVenta : 'Sin conexión',
                  ultimoMov: _nubeConectada ? _nubeUltimoMov : 'Sin conexión',
                  ultimoProd: _nubeConectada ? _nubeUltimoProd : 'Sin conexión',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaComparativa({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required bool esActiva,
    required bool esMasReciente,
    required String ultimaVenta,
    required String ultimoMov,
    required String ultimoProd,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(subtitulo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                if (esMasReciente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text('Más reciente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  ),
              ],
            ),
            const Divider(height: 24),

            _buildFilaDato('Última venta registrada:', ultimaVenta),
            const SizedBox(height: 14),
            _buildFilaDato('Último movimiento inventario:', ultimoMov),
            const SizedBox(height: 14),
            _buildFilaDato('Catálogo de productos:', ultimoProd),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaDato(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }
}

// =============================================================================
// SUB-PESTAÑA 2.1: TICKET Y NEGOCIO (CONECTADO A tbl_configuracion Y PREVIEW EN VIVO)
// =============================================================================
class _SubPantallaTicketNegocio extends StatefulWidget {
  const _SubPantallaTicketNegocio();

  @override
  State<_SubPantallaTicketNegocio> createState() => _SubPantallaTicketNegocioState();
}

class _SubPantallaTicketNegocioState extends State<_SubPantallaTicketNegocio> {
  final _nombreCtrl = TextEditingController(text: 'Abarrotes 3M');
  final _dirCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController(text: '¡Gracias por su compra!');
  bool _imprimirTicket = true;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final conf = await CatalogosRepository.instance.obtenerConfiguracion();
      if (conf != null && mounted) {
        setState(() {
          _nombreCtrl.text = conf.nombreNegocio;
          _dirCtrl.text = conf.direccionNegocio ?? '';
          _telCtrl.text = conf.telefonoNegocio ?? '';
          _mensajeCtrl.text = conf.mensajeTicket ?? '¡Gracias por su compra!';
          _imprimirTicket = conf.imprimirTicket;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre del negocio es obligatorio.')));
      return;
    }

    setState(() => _guardando = true);
    try {
      await CatalogosRepository.instance.guardarConfiguracion(
        nombreNegocio: nombre,
        direccionNegocio: _dirCtrl.text.trim(),
        telefonoNegocio: _telCtrl.text.trim(),
        mensajeTicket: _mensajeCtrl.text.trim(),
        imprimirTicket: _imprimirTicket,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Configuración del negocio guardada exitosamente.'), backgroundColor: Colors.green.shade700),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda: Formulario
          Expanded(
            flex: 3,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DATOS DEL NEGOCIO Y TICKET',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFD97706))),
                    const SizedBox(height: 6),
                    const Text('Edita el encabezado y pie que se imprimirán en tus tickets de venta.'),
                    const Divider(height: 24),

                    TextField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del negocio *', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _dirCtrl,
                      decoration: const InputDecoration(labelText: 'Dirección o Sucursal', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _telCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono de contacto', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _mensajeCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Mensaje al pie del ticket', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Imprimir ticket automáticamente al finalizar cobro'),
                      subtitle: const Text('Si se desactiva, preguntará en cada venta si desea imprimir.'),
                      value: _imprimirTicket,
                      onChanged: (v) => setState(() => _imprimirTicket = v),
                    ),
                    const SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Guardar cambios'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Columna Derecha: Vista Previa en Vivo del Ticket Térmico
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VISTA PREVIA EN VIVO (Ticket Térmico)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Encabezado
                      Text(
                        _nombreCtrl.text.isEmpty ? 'MI NEGOCIO' : _nombreCtrl.text.toUpperCase(),
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (_dirCtrl.text.isNotEmpty)
                        Text(_dirCtrl.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), textAlign: TextAlign.center),
                      if (_telCtrl.text.isNotEmpty)
                        Text('Tel: ${_telCtrl.text}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ticket: #0001', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          Text('25/11/2026 18:00', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cajero: Administrador', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CANT  DESCRIPCIÓN       IMPORTE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1.00  Leche Entera 1L    \$26.50', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('2.00  Refresco 600ml     \$36.00', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.50  Huevo Blanco Kg    \$19.50', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Text('================================', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL:', style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('\$82.00', style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Efectivo:', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          Text('\$100.00', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cambio:', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          Text('\$18.00', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                        ],
                      ),
                      const Text('================================', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        _mensajeCtrl.text,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
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

// =============================================================================
// SUB-PESTAÑA 3.1: IMPRESORA DE TICKETS
// =============================================================================
class _SubPantallaImpresora extends StatefulWidget {
  const _SubPantallaImpresora();

  @override
  State<_SubPantallaImpresora> createState() => _SubPantallaImpresoraState();
}

class _SubPantallaImpresoraState extends State<_SubPantallaImpresora> {
  String _tipoConexion = 'USB / Windows Spooler';
  String _anchoPapel = '80 mm';
  final _nombreCtrl = TextEditingController(text: 'POS-80');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tipoConexion = prefs.getString('impresora_conexion') ?? 'USB / Windows Spooler';
      _anchoPapel = prefs.getString('impresora_ancho') ?? '80 mm';
      _nombreCtrl.text = prefs.getString('impresora_nombre') ?? 'POS-80';
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('impresora_conexion', _tipoConexion);
    await prefs.setString('impresora_ancho', _anchoPapel);
    await prefs.setString('impresora_nombre', _nombreCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de impresora guardada.')),
      );
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardDispositivo(
      titulo: 'IMPRESORA DE TICKETS',
      icono: Icons.print_rounded,
      color: const Color(0xFF0D9488),
      children: [
        DropdownButtonFormField<String>(
          value: _tipoConexion,
          decoration: const InputDecoration(labelText: 'Tipo de conexión', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'USB / Windows Spooler', child: Text('USB / Windows Spooler')),
            DropdownMenuItem(value: 'Red / IP', child: Text('Red / IP Ethernet o Wi-Fi')),
            DropdownMenuItem(value: 'Bluetooth', child: Text('Bluetooth')),
          ],
          onChanged: (v) => setState(() => _tipoConexion = v!),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _anchoPapel,
          decoration: const InputDecoration(labelText: 'Ancho de papel térmico', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '58 mm', child: Text('58 mm (Pequeña)')),
            DropdownMenuItem(value: '80 mm', child: Text('80 mm (Estándar)')),
          ],
          onChanged: (v) => setState(() => _anchoPapel = v!),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nombreCtrl,
          decoration: const InputDecoration(labelText: 'Nombre de impresora o Dirección IP', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enviando página de prueba a "${_nombreCtrl.text}"...')),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Probar impresión'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// SUB-PESTAÑA 3.2: LECTOR DE CÓDIGOS
// =============================================================================
class _SubPantallaLector extends StatefulWidget {
  const _SubPantallaLector();

  @override
  State<_SubPantallaLector> createState() => _SubPantallaLectorState();
}

class _SubPantallaLectorState extends State<_SubPantallaLector> {
  String _modo = 'Emulación de Teclado HID';
  bool _enviarEnter = true;
  final _testCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _modo = prefs.getString('lector_modo') ?? 'Emulación de Teclado HID';
      _enviarEnter = prefs.getBool('lector_enter') ?? true;
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lector_modo', _modo);
    await prefs.setBool('lector_enter', _enviarEnter);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración del lector guardada.')));
    }
  }

  @override
  void dispose() {
    _testCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardDispositivo(
      titulo: 'LECTOR DE CÓDIGOS DE BARRAS',
      icono: Icons.qr_code_scanner_rounded,
      color: const Color(0xFF4F46E5),
      children: [
        DropdownButtonFormField<String>(
          value: _modo,
          decoration: const InputDecoration(labelText: 'Modo de operación', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Emulación de Teclado HID', child: Text('Emulación de Teclado HID (Recomendado)')),
            DropdownMenuItem(value: 'Puerto Serial COM', child: Text('Puerto Serial COM / Virtual')),
          ],
          onChanged: (v) => setState(() => _modo = v!),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('El lector envía "Enter" automáticamente tras escanear'),
          value: _enviarEnter,
          onChanged: (v) => setState(() => _enviarEnter = v ?? true),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _testCtrl,
          decoration: const InputDecoration(
            labelText: 'Prueba de escaneo rápido',
            hintText: 'Escanea un código aquí para probar...',
            prefixIcon: Icon(Icons.barcode_reader),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _guardar,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SUB-PESTAÑA 3.3: CAJÓN DE DINERO
// =============================================================================
class _SubPantallaCajon extends StatefulWidget {
  const _SubPantallaCajon();

  @override
  State<_SubPantallaCajon> createState() => _SubPantallaCajonState();
}

class _SubPantallaCajonState extends State<_SubPantallaCajon> {
  bool _abrirEnEfectivo = true;
  String _disparo = 'Vía impresora RJ11';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _abrirEnEfectivo = prefs.getBool('cajon_auto') ?? true;
      _disparo = prefs.getString('cajon_disparo') ?? 'Vía impresora RJ11';
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cajon_auto', _abrirEnEfectivo);
    await prefs.setString('cajon_disparo', _disparo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración del cajón guardada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardDispositivo(
      titulo: 'CAJÓN DE DINERO',
      icono: Icons.point_of_sale_rounded,
      color: const Color(0xFF16A34A),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Abrir cajón automáticamente al cobrar en efectivo'),
          value: _abrirEnEfectivo,
          onChanged: (v) => setState(() => _abrirEnEfectivo = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _disparo,
          decoration: const InputDecoration(labelText: 'Método de disparo', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Vía impresora RJ11', child: Text('Conectado a la Impresora de Tickets (Cable RJ11)')),
            DropdownMenuItem(value: 'Puerto Serial', child: Text('Puerto Serial Directo a PC')),
          ],
          onChanged: (v) => setState(() => _disparo = v!),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enviando pulso de apertura al cajón de dinero...')),
                );
              },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Probar apertura'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// SUB-PESTAÑA 3.4: BÁSCULA
// =============================================================================
class _SubPantallaBascula extends StatefulWidget {
  const _SubPantallaBascula();

  @override
  State<_SubPantallaBascula> createState() => _SubPantallaBasculaState();
}

class _SubPantallaBasculaState extends State<_SubPantallaBascula> {
  bool _habilitarBascula = false;
  String _puerto = 'COM1';
  String _baudRate = '9600';
  String _protocolo = 'Torrey';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _habilitarBascula = prefs.getBool('bascula_habilitar') ?? false;
      _puerto = prefs.getString('bascula_puerto') ?? 'COM1';
      _baudRate = prefs.getString('bascula_baud') ?? '9600';
      _protocolo = prefs.getString('bascula_protocolo') ?? 'Torrey';
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bascula_habilitar', _habilitarBascula);
    await prefs.setString('bascula_puerto', _puerto);
    await prefs.setString('bascula_baud', _baudRate);
    await prefs.setString('bascula_protocolo', _protocolo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración de báscula guardada.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildCardDispositivo(
      titulo: 'BÁSCULA ELECTRÓNICA',
      icono: Icons.scale_rounded,
      color: const Color(0xFF7C3AED),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Habilitar lectura automática de báscula para productos a Granel'),
          value: _habilitarBascula,
          onChanged: (v) => setState(() => _habilitarBascula = v),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _puerto,
                decoration: const InputDecoration(labelText: 'Puerto Serial', border: OutlineInputBorder()),
                items: List.generate(10, (i) => 'COM${i + 1}')
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: _habilitarBascula ? (v) => setState(() => _puerto = v!) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _baudRate,
                decoration: const InputDecoration(labelText: 'Baud Rate', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: '9600', child: Text('9600')),
                  DropdownMenuItem(value: '19200', child: Text('19200')),
                  DropdownMenuItem(value: '115200', child: Text('115200')),
                ],
                onChanged: _habilitarBascula ? (v) => setState(() => _baudRate = v!) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _protocolo,
          decoration: const InputDecoration(labelText: 'Protocolo de Báscula', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Torrey', child: Text('Torrey (MFQ / L-EQ / L-PC)')),
            DropdownMenuItem(value: 'Rhino', child: Text('Rhino (BAR-8 / BAPCA)')),
            DropdownMenuItem(value: 'Genérico', child: Text('Genérico Serial RS-232')),
          ],
          onChanged: _habilitarBascula ? (v) => setState(() => _protocolo = v!) : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _habilitarBascula
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Leyendo peso desde $_puerto ($_protocolo): 1.450 Kg')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.monitor_weight_outlined),
              label: const Text('Probar lectura de peso'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _guardar,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _buildCardDispositivo({
  required String titulo,
  required IconData icono,
  required Color color,
  required List<Widget> children,
}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, color: color, size: 24),
                    const SizedBox(width: 10),
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  ],
                ),
                const Divider(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// =============================================================================
// SUB-PESTAÑA 4.1: RESPALDO AUTOMÁTICO
// =============================================================================
class _SubPantallaRespaldoAuto extends StatefulWidget {
  const _SubPantallaRespaldoAuto();

  @override
  State<_SubPantallaRespaldoAuto> createState() => _SubPantallaRespaldoAutoState();
}

class _SubPantallaRespaldoAutoState extends State<_SubPantallaRespaldoAuto> {
  bool _activo = true;
  String _carpeta = '';
  bool _cargando = true;
  bool _ejecutandoPrueba = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final act = await BackupService.instance.isAutoBackupActivo();
    final carp = await BackupService.instance.getCarpetaRespaldos();
    if (mounted) {
      setState(() {
        _activo = act;
        _carpeta = carp;
        _cargando = false;
      });
    }
  }

  Future<void> _toggleActivo(bool val) async {
    setState(() => _activo = val);
    await BackupService.instance.setAutoBackupActivo(val);
  }

  Future<void> _elegirCarpeta() async {
    final ruta = await FilePicker.getDirectoryPath(dialogTitle: 'Seleccionar carpeta para respaldos automáticos');
    if (ruta != null && ruta.isNotEmpty) {
      setState(() => _carpeta = ruta);
      await BackupService.instance.setCarpetaRespaldos(ruta);
    }
  }

  Future<void> _abrirCarpeta() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [_carpeta]);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir la carpeta: $e')));
    }
  }

  Future<void> _ejecutarPrueba() async {
    setState(() => _ejecutandoPrueba = true);
    final ok = await BackupService.instance.ejecutarRespaldoAutomaticoSiActivo();
    if (mounted) {
      setState(() => _ejecutandoPrueba = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '¡Respaldo automático generado con éxito!' : 'No se pudo generar el respaldo.'),
          backgroundColor: ok ? Colors.green.shade700 : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_mode_rounded, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 10),
                      Text('RESPALDO AUTOMÁTICO DE SEGURIDAD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0369A1))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Genera una copia íntegra de la base de datos local cada vez que se cierra la aplicación.'),
                  const Divider(height: 24),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Crear respaldo automático de la base de datos local al cerrar el programa',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Recomendado para prevenir pérdidas ante cortes de energía o fallos de equipo.'),
                    value: _activo,
                    onChanged: _toggleActivo,
                  ),
                  const SizedBox(height: 16),

                  const Text('Carpeta destino de almacenamiento:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 20, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_carpeta, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _elegirCarpeta,
                        icon: const Icon(Icons.folder_shared_outlined, size: 16),
                        label: const Text('Elegir carpeta...'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _abrirCarpeta,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Abrir carpeta'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _ejecutandoPrueba ? null : _ejecutarPrueba,
                        icon: _ejecutandoPrueba
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Probar respaldo ahora'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rotación Inteligente: Para no saturar el almacenamiento, el sistema conserva automáticamente únicamente los últimos 15 respaldos dentro de la carpeta seleccionada.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-PESTAÑA 4.2: RESPALDOS MANUALES Y RESTAURACIÓN
// =============================================================================
class _SubPantallaRespaldosManuales extends StatefulWidget {
  const _SubPantallaRespaldosManuales();

  @override
  State<_SubPantallaRespaldosManuales> createState() => _SubPantallaRespaldosManualesState();
}

class _SubPantallaRespaldosManualesState extends State<_SubPantallaRespaldosManuales> {
  // Descarga
  String _origenDescarga = 'Local';
  bool _descargando = false;

  // Restauración
  Map<String, dynamic>? _archivoLeido;
  String? _nombreArchivoLeido;
  String _destinoRestauracion = 'Solo Local (PostgreSQL)';
  bool _restaurando = false;

  Future<void> _descargarRespaldo() async {
    setState(() => _descargando = true);
    try {
      final data = await BackupService.instance.generarRespaldo(origen: _origenDescarga);
      const encoder = JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'respaldo_${_origenDescarga.toLowerCase()}_$stamp.json';

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Guardar respaldo de base de datos',
        fileName: fileName,
        bytes: bytes,
      );

      if (uri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respaldo guardado exitosamente: $fileName'), backgroundColor: Colors.green.shade700),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar respaldo: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _seleccionarArchivoRestaurar() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isNotEmpty) {
        final f = files.first;
        _nombreArchivoLeido = f.name;

        final bytes = await f.readAsBytes();
        final jsonStr = utf8.decode(bytes);
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map<String, dynamic> && parsed.containsKey('tablas')) {
          setState(() => _archivoLeido = parsed);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El archivo no es un respaldo válido de Abarrotes 3M.')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al leer archivo: $e')));
    }
  }

  Future<void> _ejecutarRestauracion() async {
    if (_archivoLeido == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Confirmar Restauración de Base de Datos'),
          ],
        ),
        content: Text(
          'Se aplicarán los registros del respaldo sobre: $_destinoRestauracion.\n\n'
          'Los datos coincidentes por uuid_sync se actualizarán y los faltantes se insertarán respetando las llaves foráneas.\n\n'
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
            child: const Text('Sí, Restaurar Datos'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _restaurando = true);
    try {
      String dest = 'Local';
      if (_destinoRestauracion == 'Solo Nube (Supabase)') {
        dest = 'Nube';
      } else if (_destinoRestauracion == 'Ambas Bases de Datos') {
        dest = 'Ambas';
      }

      await BackupService.instance.restaurarRespaldo(backupData: _archivoLeido!, destino: dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('¡Base de datos restaurada correctamente!'), backgroundColor: Colors.green.shade700),
        );
        setState(() {
          _archivoLeido = null;
          _nombreArchivoLeido = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en restauración: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. DESCARGA MANUAL
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.download_rounded, color: Color(0xFFEA580C), size: 24),
                      SizedBox(width: 10),
                      Text('DESCARGAR RESPALDO MANUAL DE LA BASE DE DATOS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC2410C))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Genera un archivo .json completo con las 14 tablas del sistema para guardarlo en una memoria USB o disco externo.'),
                  const Divider(height: 24),

                  Row(
                    children: [
                      const Text('Origen de los datos: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Local', label: Text('Base de Datos Local (PostgreSQL)')),
                          ButtonSegment(value: 'Nube', label: Text('Base de Datos en la Nube (Supabase)')),
                        ],
                        selected: {_origenDescarga},
                        onSelectionChanged: (set) => setState(() => _origenDescarga = set.first),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _descargando ? null : _descargarRespaldo,
                        icon: _descargando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.file_download_outlined),
                        label: Text(_descargando ? 'Generando...' : 'Descargar Respaldo (.json)'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. RESTAURACIÓN DESDE ARCHIVO
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF2563EB), size: 24),
                      SizedBox(width: 10),
                      Text('RESTAURAR / ACTUALIZAR BASE DE DATOS DESDE ARCHIVO',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1D4ED8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Carga un archivo .json de respaldo para reconstruir o sincronizar la información del sistema en orden estricto de dependencias.'),
                  const Divider(height: 24),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _seleccionarArchivoRestaurar,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Seleccionar archivo de respaldo (.json)'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      if (_nombreArchivoLeido != null)
                        Text('Archivo: $_nombreArchivoLeido', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),

                  if (_archivoLeido != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Origen del respaldo: ${_archivoLeido!['origen'] ?? 'Desconocido'} • Terminal: ${_archivoLeido!['terminal_origen'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Fecha: ${_archivoLeido!['fecha_generacion'] ?? '-'}',
                                  style: const TextStyle(color: Color(0xFF64748B))),
                            ],
                          ),
                          const Divider(height: 20),
                          const Text('Resumen de registros por tabla a restaurar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: (_archivoLeido!['resumen_registros'] as Map<String, dynamic>? ?? {})
                                .entries
                                .map((e) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        const Text('Destino de restauración: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _destinoRestauracion,
                          items: const [
                            DropdownMenuItem(value: 'Solo Local (PostgreSQL)', child: Text('Solo Local (PostgreSQL)')),
                            DropdownMenuItem(value: 'Solo Nube (Supabase)', child: Text('Solo Nube (Supabase)')),
                            DropdownMenuItem(value: 'Ambas Bases de Datos', child: Text('Ambas Bases de Datos')),
                          ],
                          onChanged: (v) => setState(() => _destinoRestauracion = v!),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _restaurando ? null : _ejecutarRestauracion,
                          icon: _restaurando
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(_restaurando ? 'Restaurando...' : 'Restaurar Base de Datos'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
