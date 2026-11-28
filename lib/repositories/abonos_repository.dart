import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';
import '../models/abono.dart';
import '../models/helpers.dart';
import '../services/database_service.dart';

/// Movimiento unificado para el estado de cuenta del cliente (VENTA o ABONO).
class MovimientoEstadoCuenta {
  final String tipo; // 'VENTA' | 'ABONO'
  final int idReferencia; // id_venta o id_abono
  final DateTime fecha;
  final double monto;
  final double saldoResultante;
  final String cajero;
  final String? formaPago;

  const MovimientoEstadoCuenta({
    required this.tipo,
    required this.idReferencia,
    required this.fecha,
    required this.monto,
    required this.saldoResultante,
    required this.cajero,
    this.formaPago,
  });
}

/// Detalle de un producto dentro de un ticket de venta ([tbl_detalle_ventas]).
class ProductoTicketDetalle {
  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double importe;

  const ProductoTicketDetalle({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.importe,
  });
}

/// Repositorio local-first para abonos generales ([tbl_abonos_clientes]) y estado de cuenta.
class AbonosRepository {
  final DatabaseService _db;

  AbonosRepository(this._db);

  static AbonosRepository? _instance;
  static AbonosRepository get instance {
    _instance ??= AbonosRepository(DatabaseService.instance);
    return _instance!;
  }

  /// Registra un abono general al saldo del cliente en una transacción ACID (o directo en Supabase).
  Future<AbonoCliente> registrarAbono({
    required int idCliente,
    required int idUsuario,
    required int? idCorte,
    required double monto,
    required String nombreFormaPago, // 'Efectivo' | 'Tarjeta' | 'Transferencia'
  }) async {
    final terminalId = _db.terminalId;

    if (_db.isCloudOnlyMode) {
      final now = DateTime.now().toIso8601String();

      // 1. Obtener id_forma_pago
      final fpRes = await _db.supabase
          .from('tbl_formas_pago')
          .select('id_forma_pago')
          .ilike('nombre_forma_pago', nombreFormaPago.trim())
          .maybeSingle();
      final idFormaPago = fpRes != null ? parseIntSafe(fpRes['id_forma_pago']) : 1;

      // 2. Leer saldo actual
      final cliRes = await _db.supabase
          .from('tbl_clientes')
          .select('saldo_actual')
          .eq('id_cliente', idCliente)
          .single();
      final saldoActual = parseDecimal(cliRes['saldo_actual']);
      final saldoPosterior = (saldoActual - monto) < 0 ? 0.0 : (saldoActual - monto);

      // 3. Insertar abono
      final insertData = {
        'id_cliente': idCliente,
        'id_usuario': idUsuario,
        'id_corte': idCorte,
        'id_forma_pago': idFormaPago,
        'monto': monto,
        'saldo_posterior': saldoPosterior,
        'fecha_registro': now,
        'sincronizado': true,
        'terminal_origen': terminalId,
      };
      final res = await _db.supabase.from('tbl_abonos_clientes').insert(insertData).select().single();

      // 4. Actualizar saldo del cliente
      await _db.supabase.from('tbl_clientes').update({
        'saldo_actual': saldoPosterior,
        'fecha_actualizacion': now,
      }).eq('id_cliente', idCliente);

      // 5. Si fue en efectivo y hay corte abierto, actualizar efectivo_esperado
      if (nombreFormaPago.toLowerCase().contains('efectivo') && idCorte != null) {
        final corte = await _db.supabase
            .from('tbl_cortes_caja')
            .select('efectivo_esperado')
            .eq('id_corte', idCorte)
            .maybeSingle();
        if (corte != null) {
          final efEsperado = parseDecimal(corte['efectivo_esperado']);
          await _db.supabase.from('tbl_cortes_caja').update({
            'efectivo_esperado': efEsperado + monto,
            'fecha_actualizacion': now,
          }).eq('id_corte', idCorte);
        }
      }

      dev.log('[AbonosRepository] ✅ Abono en Supabase #${res['id_abono']} por \$$monto registrado.');
      return AbonoCliente.fromMap(res);
    }

    final abono = await _db.transaction<AbonoCliente>((tx) async {
      // 1. Obtener id_forma_pago
      final fpRes = await tx.execute(
        Sql.named('SELECT id_forma_pago FROM tbl_formas_pago WHERE LOWER(nombre_forma_pago) = @nombre LIMIT 1'),
        parameters: {'nombre': nombreFormaPago.trim().toLowerCase()},
      );
      final idFormaPago = fpRes.isNotEmpty
          ? parseIntSafe(fpRes.first.toColumnMap()['id_forma_pago'])
          : 1;

      // 2. Leer saldo_actual del cliente
      final cliRes = await tx.execute(
        Sql.named('SELECT saldo_actual FROM tbl_clientes WHERE id_cliente = @id FOR UPDATE'),
        parameters: {'id': idCliente},
      );
      final saldoActual = cliRes.isNotEmpty
          ? parseDecimal(cliRes.first.toColumnMap()['saldo_actual'])
          : 0.0;
      final saldoPosterior = (saldoActual - monto) < 0 ? 0.0 : (saldoActual - monto);

      // 3. Insertar en tbl_abonos_clientes
      final res = await tx.execute(
        Sql.named('''INSERT INTO tbl_abonos_clientes
           (id_cliente, id_usuario, id_corte, id_forma_pago, monto, saldo_posterior,
            fecha_registro, sincronizado, terminal_origen)
           VALUES
           (@idCliente, @idUsuario, @idCorte, @idFormaPago, @monto, @saldoPosterior,
            CURRENT_TIMESTAMP, FALSE, @terminal)
           RETURNING *'''),
        parameters: {
          'idCliente': idCliente,
          'idUsuario': idUsuario,
          'idCorte': idCorte,
          'idFormaPago': idFormaPago,
          'monto': monto,
          'saldoPosterior': saldoPosterior,
          'terminal': terminalId,
        },
      );

      // 4. Actualizar saldo_actual en tbl_clientes
      await tx.execute(
        Sql.named('''UPDATE tbl_clientes
           SET saldo_actual = @saldoPosterior,
               fecha_actualizacion = CURRENT_TIMESTAMP,
               sincronizado = FALSE
           WHERE id_cliente = @idCliente'''),
        parameters: {
          'saldoPosterior': saldoPosterior,
          'idCliente': idCliente,
        },
      );

      return AbonoCliente.fromMap(res.first.toColumnMap());
    });

    dev.log('[AbonosRepository] ✅ Abono #${abono.idAbono} por \$${monto.toStringAsFixed(2)} registrado.');
    return abono;
  }

  /// Obtiene el historial cronológico unificado (ventas a crédito + abonos)
  /// ordenado del más reciente al más antiguo.
  Future<List<MovimientoEstadoCuenta>> obtenerEstadoCuenta(int idCliente) async {
    final crudos = <Map<String, dynamic>>[];

    if (_db.isCloudOnlyMode) {
      final ventasRes = await _db.supabase
          .from('tbl_ventas')
          .select('id_venta, total, fecha_venta, tbl_usuarios(nombre_completo, nombre_usuario)')
          .eq('id_cliente', idCliente)
          .eq('es_credito', true)
          .eq('estatus_venta', 'Completada');

      for (final v in ventasRes) {
        final u = v['tbl_usuarios'];
        final cajero = (u is Map ? (u['nombre_completo'] ?? u['nombre_usuario']) : null)?.toString() ?? 'Cajero';
        crudos.add({
          'tipo': 'VENTA',
          'id': parseIntSafe(v['id_venta']),
          'fecha': parseDateTime(v['fecha_venta']),
          'monto': parseDecimal(v['total']),
          'cajero': cajero,
          'forma_pago': 'Crédito',
        });
      }

      final abonosRes = await _db.supabase
          .from('tbl_abonos_clientes')
          .select('id_abono, monto, saldo_posterior, fecha_registro, tbl_usuarios(nombre_completo, nombre_usuario), tbl_formas_pago(nombre_forma_pago)')
          .eq('id_cliente', idCliente);

      for (final a in abonosRes) {
        final u = a['tbl_usuarios'];
        final fp = a['tbl_formas_pago'];
        final cajero = (u is Map ? (u['nombre_completo'] ?? u['nombre_usuario']) : null)?.toString() ?? 'Cajero';
        final formaPago = (fp is Map ? fp['nombre_forma_pago'] : null)?.toString() ?? 'Efectivo';
        crudos.add({
          'tipo': 'ABONO',
          'id': parseIntSafe(a['id_abono']),
          'fecha': parseDateTime(a['fecha_registro']),
          'monto': parseDecimal(a['monto']),
          'cajero': cajero,
          'forma_pago': formaPago,
        });
      }
    } else {
      final ventasRes = await _db.query(
        '''SELECT v.id_venta, v.total, v.fecha_venta, COALESCE(u.nombre_completo, u.nombre_usuario) AS cajero
           FROM tbl_ventas v
           LEFT JOIN tbl_usuarios u ON v.id_usuario = u.id_usuario
           WHERE v.id_cliente = @id AND v.es_credito = TRUE AND v.estatus_venta::text = 'Completada' ''',
        params: {'id': idCliente},
      );

      final abonosRes = await _db.query(
        '''SELECT a.id_abono, a.monto, a.saldo_posterior, a.fecha_registro,
                  COALESCE(u.nombre_completo, u.nombre_usuario) AS cajero,
                  fp.nombre_forma_pago
           FROM tbl_abonos_clientes a
           LEFT JOIN tbl_usuarios u ON a.id_usuario = u.id_usuario
           LEFT JOIN tbl_formas_pago fp ON a.id_forma_pago = fp.id_forma_pago
           WHERE a.id_cliente = @id''',
        params: {'id': idCliente},
      );

      for (final r in ventasRes) {
        final m = r.toColumnMap();
        crudos.add({
          'tipo': 'VENTA',
          'id': parseIntSafe(m['id_venta']),
          'fecha': parseDateTime(m['fecha_venta']),
          'monto': parseDecimal(m['total']),
          'cajero': parsePgString(m['cajero'], defaultValue: 'Cajero'),
          'forma_pago': 'Crédito',
        });
      }

      for (final r in abonosRes) {
        final m = r.toColumnMap();
        crudos.add({
          'tipo': 'ABONO',
          'id': parseIntSafe(m['id_abono']),
          'fecha': parseDateTime(m['fecha_registro']),
          'monto': parseDecimal(m['monto']),
          'cajero': parsePgString(m['cajero'], defaultValue: 'Cajero'),
          'forma_pago': parsePgString(m['nombre_forma_pago'], defaultValue: 'Efectivo'),
        });
      }
    }

    crudos.sort((a, b) => (a['fecha'] as DateTime).compareTo(b['fecha'] as DateTime));

    double saldo = 0.0;
    final movimientos = <MovimientoEstadoCuenta>[];
    for (final item in crudos) {
      final tipo = item['tipo'] as String;
      final monto = item['monto'] as double;
      if (tipo == 'VENTA') {
        saldo += monto;
      } else {
        saldo = (saldo - monto) < 0 ? 0.0 : (saldo - monto);
      }
      movimientos.add(MovimientoEstadoCuenta(
        tipo: tipo,
        idReferencia: item['id'] as int,
        fecha: item['fecha'] as DateTime,
        monto: monto,
        saldoResultante: saldo,
        cajero: item['cajero'] as String,
        formaPago: item['forma_pago'] as String?,
      ));
    }

    return movimientos.reversed.toList();
  }

  /// Consulta los productos comprados en un ticket específico desde [tbl_detalle_ventas].
  Future<List<ProductoTicketDetalle>> obtenerDetalleTicket(int idVenta) async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_detalle_ventas')
          .select('descripcion_producto, cantidad, precio_unitario, importe')
          .eq('id_venta', idVenta)
          .order('id_detalle_venta', ascending: true);

      return (res as List).map((r) {
        return ProductoTicketDetalle(
          descripcion: (r['descripcion_producto'] ?? '').toString(),
          cantidad: parseDecimal(r['cantidad']),
          precioUnitario: parseDecimal(r['precio_unitario']),
          importe: parseDecimal(r['importe']),
        );
      }).toList();
    }

    final res = await _db.query(
      '''SELECT descripcion_producto, cantidad, precio_unitario, importe
         FROM tbl_detalle_ventas
         WHERE id_venta = @idVenta
         ORDER BY id_detalle_venta ASC''',
      params: {'idVenta': idVenta},
    );

    return res.map((r) {
      final m = r.toColumnMap();
      return ProductoTicketDetalle(
        descripcion: parsePgString(m['descripcion_producto']),
        cantidad: parseDecimal(m['cantidad']),
        precioUnitario: parseDecimal(m['precio_unitario']),
        importe: parseDecimal(m['importe']),
      );
    }).toList();
  }
}
