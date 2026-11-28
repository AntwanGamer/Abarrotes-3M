import 'dart:developer' as dev;
import 'package:postgres/postgres.dart';

import '../models/helpers.dart';
import '../models/venta.dart';
import '../models/venta_detalle.dart';
import '../services/database_service.dart';

/// DTO para cada línea de la venta.
class LineaVenta {
  final int idProducto;
  final int? idPromocion;
  final String descripcionProducto;
  final double cantidad;
  final double precioUnitario;
  final double costoUnitario;
  final double descuento;

  const LineaVenta({
    required this.idProducto,
    this.idPromocion,
    required this.descripcionProducto,
    required this.cantidad,
    required this.precioUnitario,
    this.costoUnitario = 0.0,
    this.descuento = 0.0,
  });

  double get importe => (cantidad * precioUnitario) - descuento;
}

/// DTO para cada pago registrado en [tbl_pagos_venta].
class PagoVentaInput {
  final String nombreFormaPago; // 'Efectivo' | 'Tarjeta' | 'Transferencia' | 'Crédito' | 'Vales'
  final double monto;
  final double cambio;

  const PagoVentaInput({
    required this.nombreFormaPago,
    required this.monto,
    this.cambio = 0.0,
  });
}

/// Repositorio de Ventas – 100 % local-first con transacción ACID
/// según Diccionario de Datos - Abarrotes 3M.
class VentasRepository {
  final DatabaseService _db;

  VentasRepository(this._db);

  static VentasRepository? _instance;
  static VentasRepository get instance {
    _instance ??= VentasRepository(DatabaseService.instance);
    return _instance!;
  }

  /// Registra una venta completa (en transacción local o directo en Supabase):
  /// 1. Genera `folio_ticket` (ej. `T-000001`) e inserta en `tbl_ventas`.
  /// 2. Inserta cada línea en `tbl_detalle_ventas`.
  /// 3. Inserta cada forma de pago en `tbl_pagos_venta`.
  /// 4. Para productos con `usa_inventario = TRUE`, registra Kardex en `tbl_movimientos_inventario`
  ///    y descuenta `existencia` en `tbl_productos`.
  /// 5. Si `esCredito == true`, suma `total` a `tbl_clientes.saldo_actual`.
  /// 6. Actualiza `total_ventas` (y `efectivo_esperado` si hubo pago en efectivo) en `tbl_cortes_caja`.
  Future<int> registrarVenta({
    required int idUsuario,
    int? idCliente,
    int? idCorte,
    required List<LineaVenta> lineas,
    required List<PagoVentaInput> pagos,
    double descuentoGlobal = 0.0,
    double iva = 0.0,
    bool esCredito = false,
  }) async {
    final subtotal = lineas.fold(0.0, (acc, l) => acc + l.importe);
    final total = (subtotal - descuentoGlobal + iva).clamp(0.0, double.infinity);
    final terminalId = _db.terminalId;

    if (_db.isCloudOnlyMode) {
      final now = DateTime.now().toIso8601String();

      // 1. Folio secuencial
      final lastV = await _db.supabase
          .from('tbl_ventas')
          .select('id_venta')
          .order('id_venta', ascending: false)
          .limit(1)
          .maybeSingle();
      final nextId = (lastV != null ? parseIntSafe(lastV['id_venta']) : 0) + 1;
      final folioTicket = 'T-${nextId.toString().padLeft(6, '0')}';

      // 2. Insertar venta
      final ventaInsert = {
        'folio_ticket': folioTicket,
        'id_usuario': idUsuario,
        'id_cliente': idCliente,
        'id_corte': idCorte,
        'fecha_venta': now,
        'subtotal': subtotal,
        'descuento': descuentoGlobal,
        'iva': iva,
        'total': total,
        'es_credito': esCredito,
        'estatus_venta': 'Completada',
        'fecha_registro': now,
        'fecha_actualizacion': now,
        'sincronizado': true,
        'terminal_origen': terminalId,
      };
      final ventaRes = await _db.supabase.from('tbl_ventas').insert(ventaInsert).select('id_venta').single();
      final idVenta = parseIntSafe(ventaRes['id_venta']);

      // 3. Detalle y Kardex
      for (final linea in lineas) {
        await _db.supabase.from('tbl_detalle_ventas').insert({
          'id_venta': idVenta,
          'id_producto': linea.idProducto,
          'id_promocion': linea.idPromocion,
          'descripcion_producto': linea.descripcionProducto,
          'cantidad': linea.cantidad,
          'precio_unitario': linea.precioUnitario,
          'costo_unitario': linea.costoUnitario,
          'descuento': linea.descuento,
          'importe': linea.importe,
          'fecha_registro': now,
          'sincronizado': true,
          'terminal_origen': terminalId,
        });

        final prodRes = await _db.supabase
            .from('tbl_productos')
            .select('usa_inventario, existencia')
            .eq('id_producto', linea.idProducto)
            .maybeSingle();

        if (prodRes != null) {
          final usaInv = prodRes['usa_inventario'] == true;
          if (usaInv) {
            final existAnt = parseDecimal(prodRes['existencia']);
            final existNueva = existAnt - linea.cantidad;

            await _db.supabase.from('tbl_movimientos_inventario').insert({
              'id_producto': linea.idProducto,
              'id_usuario': idUsuario,
              'tipo_movimiento': 'Venta',
              'cantidad': -linea.cantidad,
              'existencia_anterior': existAnt,
              'existencia_nueva': existNueva,
              'id_referencia': idVenta,
              'motivo': 'Venta $folioTicket',
              'fecha_registro': now,
              'fecha_movimiento': now,
              'fecha_actualizacion': now,
              'sincronizado': true,
              'terminal_origen': terminalId,
            });

            await _db.supabase.from('tbl_productos').update({
              'existencia': existNueva,
              'fecha_actualizacion': now,
            }).eq('id_producto', linea.idProducto);
          }
        }
      }

      // 4. Pagos
      double efectivoNeto = 0.0;
      for (final pago in pagos) {
        final fpRes = await _db.supabase
            .from('tbl_formas_pago')
            .select('id_forma_pago')
            .ilike('nombre_forma_pago', pago.nombreFormaPago.trim())
            .maybeSingle();
        final idFormaPago = fpRes != null ? parseIntSafe(fpRes['id_forma_pago']) : 1;

        await _db.supabase.from('tbl_pagos_venta').insert({
          'id_venta': idVenta,
          'id_forma_pago': idFormaPago,
          'monto': pago.monto,
          'cambio': pago.cambio,
          'fecha_registro': now,
          'sincronizado': true,
          'terminal_origen': terminalId,
        });

        if (pago.nombreFormaPago.toLowerCase() == 'efectivo') {
          efectivoNeto += (pago.monto - pago.cambio).clamp(0.0, double.infinity);
        }
      }

      // 5. Crédito a cliente
      if (esCredito && idCliente != null) {
        final cliRes = await _db.supabase.from('tbl_clientes').select('saldo_actual').eq('id_cliente', idCliente).single();
        final saldoAct = parseDecimal(cliRes['saldo_actual']);
        await _db.supabase.from('tbl_clientes').update({
          'saldo_actual': saldoAct + total,
          'fecha_actualizacion': now,
        }).eq('id_cliente', idCliente);
      }

      // 6. Actualizar corte de caja
      if (idCorte != null) {
        final corteRes = await _db.supabase.from('tbl_cortes_caja').select('total_ventas, efectivo_esperado').eq('id_corte', idCorte).maybeSingle();
        if (corteRes != null) {
          final tVentas = parseDecimal(corteRes['total_ventas']);
          final eEsperado = parseDecimal(corteRes['efectivo_esperado']);
          await _db.supabase.from('tbl_cortes_caja').update({
            'total_ventas': tVentas + total,
            'efectivo_esperado': eEsperado + efectivoNeto,
            'fecha_actualizacion': now,
          }).eq('id_corte', idCorte);
        }
      }

      dev.log('[VentasRepository] ✅ Venta en Supabase $folioTicket (#$idVenta) registrada (\$$total).');
      return idVenta;
    }

    return _db.transaction<int>((session) async {
      // 1. Generar folio_ticket secuencial
      final seqRes = await session.execute(
        Sql.named('SELECT COALESCE(MAX(id_venta), 0) + 1 AS next_id FROM tbl_ventas'),
      );
      final nextId = parseIntSafe(seqRes.first.toColumnMap()['next_id']);
      final folioTicket = 'T-${nextId.toString().padLeft(6, '0')}';

      // 2. Insertar cabecera en tbl_ventas
      final ventaResult = await session.execute(
        Sql.named('''INSERT INTO tbl_ventas
             (folio_ticket, id_usuario, id_cliente, id_corte, fecha_venta,
              subtotal, descuento, iva, total, es_credito,
              estatus_venta, fecha_registro, fecha_actualizacion,
              sincronizado, terminal_origen)
             VALUES
             (@folio, @id_usuario, @id_cliente, @id_corte, CURRENT_TIMESTAMP,
              @subtotal, @descuento, @iva, @total, @es_credito,
              'Completada', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
              FALSE, @terminal)
             RETURNING id_venta'''),
        parameters: {
          'folio': folioTicket,
          'id_usuario': idUsuario,
          'id_cliente': idCliente,
          'id_corte': idCorte,
          'subtotal': subtotal,
          'descuento': descuentoGlobal,
          'iva': iva,
          'total': total,
          'es_credito': esCredito,
          'terminal': terminalId,
        },
      );

      final idVenta = parseIntSafe(ventaResult.first.toColumnMap()['id_venta']);

      // 3. Insertar detalle y Kardex
      for (final linea in lineas) {
        await session.execute(
          Sql.named('''INSERT INTO tbl_detalle_ventas
               (id_venta, id_producto, id_promocion, descripcion_producto,
                cantidad, precio_unitario, costo_unitario, descuento, importe,
                sincronizado, terminal_origen)
               VALUES
               (@id_venta, @id_producto, @id_promocion, @desc,
                @cantidad, @precio, @costo, @descuento, @importe,
                FALSE, @terminal)'''),
          parameters: {
            'id_venta': idVenta,
            'id_producto': linea.idProducto,
            'id_promocion': linea.idPromocion,
            'desc': linea.descripcionProducto,
            'cantidad': linea.cantidad,
            'precio': linea.precioUnitario,
            'costo': linea.costoUnitario,
            'descuento': linea.descuento,
            'importe': linea.importe,
            'terminal': terminalId,
          },
        );

        // Consultar existencia y usa_inventario del producto
        final prodRes = await session.execute(
          Sql.named('SELECT usa_inventario, existencia FROM tbl_productos WHERE id_producto = @id LIMIT 1'),
          parameters: {'id': linea.idProducto},
        );

        if (prodRes.isNotEmpty) {
          final pRow = prodRes.first.toColumnMap();
          final usaInv = pRow['usa_inventario'] != null ? parseBool(pRow['usa_inventario']) : true;
          if (usaInv) {
            final existAnt = parseDecimal(pRow['existencia']);
            final existNueva = existAnt - linea.cantidad;

            await session.execute(
              Sql.named('''INSERT INTO tbl_movimientos_inventario
                   (id_producto, id_usuario, tipo_movimiento, cantidad,
                    existencia_anterior, existencia_nueva, id_referencia, motivo,
                    fecha_registro, sincronizado, terminal_origen)
                   VALUES
                   (@id_producto, @id_usuario, 'Venta', @cantidad,
                    @exist_ant, @exist_nueva, @id_ref, @motivo,
                    CURRENT_TIMESTAMP, FALSE, @terminal)'''),
              parameters: {
                'id_producto': linea.idProducto,
                'id_usuario': idUsuario,
                'cantidad': -linea.cantidad,
                'exist_ant': existAnt,
                'exist_nueva': existNueva,
                'id_ref': idVenta,
                'motivo': 'Venta $folioTicket',
                'terminal': terminalId,
              },
            );

            await session.execute(
              Sql.named('''UPDATE tbl_productos
                   SET existencia = @exist_nueva,
                       fecha_actualizacion = CURRENT_TIMESTAMP,
                       sincronizado = FALSE,
                       terminal_origen = @terminal
                   WHERE id_producto = @id_producto'''),
              parameters: {
                'exist_nueva': existNueva,
                'terminal': terminalId,
                'id_producto': linea.idProducto,
              },
            );
          }
        }
      }

      // 4. Insertar pagos en tbl_pagos_venta
      double efectivoNeto = 0.0;
      for (final pago in pagos) {
        final fpRes = await session.execute(
          Sql.named("SELECT id_forma_pago FROM tbl_formas_pago WHERE LOWER(nombre_forma_pago) = @nombre LIMIT 1"),
          parameters: {'nombre': pago.nombreFormaPago.trim().toLowerCase()},
        );
        final idFormaPago = fpRes.isNotEmpty
            ? parseIntSafe(fpRes.first.toColumnMap()['id_forma_pago'])
            : 1;

        await session.execute(
          Sql.named('''INSERT INTO tbl_pagos_venta
               (id_venta, id_forma_pago, monto, cambio,
                fecha_registro, sincronizado, terminal_origen)
               VALUES
               (@id_venta, @id_fp, @monto, @cambio,
                CURRENT_TIMESTAMP, FALSE, @terminal)'''),
          parameters: {
            'id_venta': idVenta,
            'id_fp': idFormaPago,
            'monto': pago.monto,
            'cambio': pago.cambio,
            'terminal': terminalId,
          },
        );

        if (pago.nombreFormaPago.toLowerCase() == 'efectivo') {
          efectivoNeto += (pago.monto - pago.cambio).clamp(0.0, double.infinity);
        }
      }

      // 5. Si es crédito, incrementar saldo_actual del cliente
      if (esCredito && idCliente != null) {
        await session.execute(
          Sql.named('''UPDATE tbl_clientes
               SET saldo_actual = saldo_actual + @total,
                   fecha_actualizacion = CURRENT_TIMESTAMP,
                   sincronizado = FALSE
               WHERE id_cliente = @id_cliente'''),
          parameters: {
            'total': total,
            'id_cliente': idCliente,
          },
        );
      }

      // 6. Actualizar totales en tbl_cortes_caja
      if (idCorte != null) {
        await session.execute(
          Sql.named('''UPDATE tbl_cortes_caja
               SET total_ventas = total_ventas + @total,
                   efectivo_esperado = efectivo_esperado + @efectivoNeto,
                   fecha_actualizacion = CURRENT_TIMESTAMP,
                   sincronizado = FALSE
               WHERE id_corte = @id_corte'''),
          parameters: {
            'total': total,
            'efectivoNeto': efectivoNeto,
            'id_corte': idCorte,
          },
        );
      }

      dev.log('[VentasRepository] ✅ Venta $folioTicket (#$idVenta) registrada (\$${total.toStringAsFixed(2)}).');
      return idVenta;
    });
  }

  /// Obtiene las ventas del día desde PostgreSQL local o Supabase.
  Future<List<Venta>> obtenerVentasDelDia() async {
    if (_db.isCloudOnlyMode) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final res = await _db.supabase
          .from('tbl_ventas')
          .select()
          .gte('fecha_venta', todayStart)
          .order('fecha_venta', ascending: false);
      return (res as List).map((row) => Venta.fromMap(row as Map<String, dynamic>)).toList();
    }

    final result = await _db.query(
      '''SELECT * FROM tbl_ventas
         WHERE DATE(fecha_venta) = CURRENT_DATE
         ORDER BY fecha_venta DESC''',
    );
    return result.map((row) => Venta.fromMap(row.toColumnMap())).toList();
  }

  /// Obtiene el detalle de líneas de una venta específica.
  Future<List<VentaDetalle>> obtenerDetalle(int idVenta) async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_detalle_ventas')
          .select()
          .eq('id_venta', idVenta)
          .order('id_detalle_venta', ascending: true);
      return (res as List).map((row) => VentaDetalle.fromMap(row as Map<String, dynamic>)).toList();
    }

    final result = await _db.query(
      'SELECT * FROM tbl_detalle_ventas WHERE id_venta = @id ORDER BY id_detalle_venta',
      params: {'id': idVenta},
    );
    return result.map((row) => VentaDetalle.fromMap(row.toColumnMap())).toList();
  }

  /// Cancela una venta y marca `sincronizado = false`.
  Future<void> cancelarVenta(int idVenta, {String motivo = 'Cancelada en caja'}) async {
    if (_db.isCloudOnlyMode) {
      await _db.supabase.from('tbl_ventas').update({
        'estatus_venta': 'Cancelada',
        'motivo_cancelacion': motivo,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      }).eq('id_venta', idVenta);
      dev.log('[VentasRepository] Venta cancelada en Supabase: #$idVenta');
      return;
    }

    await _db.query(
      '''UPDATE tbl_ventas SET
         estatus_venta = 'Cancelada',
         motivo_cancelacion = @motivo,
         fecha_actualizacion = CURRENT_TIMESTAMP,
         sincronizado = FALSE,
         terminal_origen = @terminal
         WHERE id_venta = @id''',
      params: {
        'id': idVenta,
        'motivo': motivo,
        'terminal': _db.terminalId,
      },
    );
    dev.log('[VentasRepository] Venta cancelada: #$idVenta');
  }

  /// Cancela una venta, devuelve las existencias en [tbl_productos], registra
  /// el movimiento en [tbl_movimientos_inventario] con tipo 'Cancelacion' y revierte saldos/cortes.
  Future<void> cancelarVentaConDevolucion({
    required int idVenta,
    required int idUsuario,
    String motivo = 'Devolución / Cancelación en caja',
  }) async {
    final terminalId = _db.terminalId;

    if (_db.isCloudOnlyMode) {
      final now = DateTime.now().toIso8601String();
      final vRes = await _db.supabase.from('tbl_ventas').select().eq('id_venta', idVenta).maybeSingle();
      if (vRes == null) throw Exception('Venta no encontrada');
      if (vRes['estatus_venta'] == 'Cancelada') {
        throw Exception('La venta ya se encuentra cancelada.');
      }
      final total = parseDecimal(vRes['total']);
      final esCredito = vRes['es_credito'] == true;
      final idCliente = vRes['id_cliente'] != null ? parseIntSafe(vRes['id_cliente']) : null;
      final idCorte = vRes['id_corte'] != null ? parseIntSafe(vRes['id_corte']) : null;

      await _db.supabase.from('tbl_ventas').update({
        'estatus_venta': 'Cancelada',
        'motivo_cancelacion': motivo,
        'fecha_actualizacion': now,
      }).eq('id_venta', idVenta);

      final detRes = await _db.supabase.from('tbl_detalle_ventas').select().eq('id_venta', idVenta);
      for (final m in detRes) {
        final idProd = parseIntSafe(m['id_producto']);
        final cant = parseDecimal(m['cantidad']);
        final prod = await _db.supabase.from('tbl_productos').select('usa_inventario, existencia').eq('id_producto', idProd).maybeSingle();
        if (prod != null && prod['usa_inventario'] == true) {
          final existAnt = parseDecimal(prod['existencia']);
          final existNueva = existAnt + cant;
          await _db.supabase.from('tbl_productos').update({
            'existencia': existNueva,
            'fecha_actualizacion': now,
          }).eq('id_producto', idProd);

          await _db.supabase.from('tbl_movimientos_inventario').insert({
            'id_producto': idProd,
            'tipo_movimiento': 'Cancelacion',
            'cantidad': cant,
            'id_usuario': idUsuario,
            'motivo': motivo,
            'existencia_anterior': existAnt,
            'existencia_nueva': existNueva,
            'id_referencia': idVenta,
            'fecha_movimiento': now,
            'fecha_registro': now,
            'fecha_actualizacion': now,
            'sincronizado': true,
            'terminal_origen': terminalId,
          });
        }
      }

      if (esCredito && idCliente != null) {
        final cRes = await _db.supabase.from('tbl_clientes').select('saldo_actual').eq('id_cliente', idCliente).single();
        final act = parseDecimal(cRes['saldo_actual']);
        await _db.supabase.from('tbl_clientes').update({
          'saldo_actual': (act - total) < 0 ? 0.0 : (act - total),
          'fecha_actualizacion': now,
        }).eq('id_cliente', idCliente);
      }

      if (idCorte != null) {
        final pagosRes = await _db.supabase.from('tbl_pagos_venta').select('monto, cambio, tbl_formas_pago(nombre_forma_pago)').eq('id_venta', idVenta);
        double efe = 0.0;
        for (final p in pagosRes) {
          final fp = p['tbl_formas_pago'];
          final fpNom = (fp is Map ? fp['nombre_forma_pago'] : null)?.toString() ?? '';
          if (fpNom.toLowerCase().contains('efectivo')) {
            efe += (parseDecimal(p['monto']) - parseDecimal(p['cambio'])).clamp(0.0, double.infinity);
          }
        }

        final corte = await _db.supabase.from('tbl_cortes_caja').select('total_ventas, efectivo_esperado').eq('id_corte', idCorte).maybeSingle();
        if (corte != null) {
          final tV = parseDecimal(corte['total_ventas']);
          final eE = parseDecimal(corte['efectivo_esperado']);
          await _db.supabase.from('tbl_cortes_caja').update({
            'total_ventas': (tV - total) < 0 ? 0.0 : (tV - total),
            'efectivo_esperado': (eE - efe) < 0 ? 0.0 : (eE - efe),
            'fecha_actualizacion': now,
          }).eq('id_corte', idCorte);
        }
      }

      dev.log('[VentasRepository] ✅ Venta #$idVenta cancelada en Supabase con devolución de inventario');
      return;
    }

    await _db.transaction((session) async {
      final vRes = await session.execute(
        Sql.named('SELECT * FROM tbl_ventas WHERE id_venta = @id FOR UPDATE'),
        parameters: {'id': idVenta},
      );
      if (vRes.isEmpty) throw Exception('Venta no encontrada');
      final vMap = vRes.first.toColumnMap();
      final estatusActual = parsePgString(vMap['estatus_venta']);
      if (estatusActual == 'Cancelada') {
        throw Exception('La venta ya se encuentra cancelada.');
      }
      final total = parseDecimal(vMap['total']);
      final esCredito = vMap['es_credito'] == true;
      final idCliente = vMap['id_cliente'] != null ? parseIntSafe(vMap['id_cliente']) : null;
      final idCorte = vMap['id_corte'] != null ? parseIntSafe(vMap['id_corte']) : null;

      await session.execute(
        Sql.named('''UPDATE tbl_ventas SET
             estatus_venta = 'Cancelada',
             motivo_cancelacion = @motivo,
             fecha_actualizacion = CURRENT_TIMESTAMP,
             sincronizado = FALSE,
             terminal_origen = @terminal
             WHERE id_venta = @id'''),
        parameters: {
          'id': idVenta,
          'motivo': motivo,
          'terminal': terminalId,
        },
      );

      final detRes = await session.execute(
        Sql.named('SELECT * FROM tbl_detalle_ventas WHERE id_venta = @id'),
        parameters: {'id': idVenta},
      );

      for (final r in detRes) {
        final m = r.toColumnMap();
        final idProd = parseIntSafe(m['id_producto']);
        final cant = parseDecimal(m['cantidad']);

        final pRes = await session.execute(
          Sql.named('SELECT usa_inventario FROM tbl_productos WHERE id_producto = @p'),
          parameters: {'p': idProd},
        );
        if (pRes.isNotEmpty && pRes.first.toColumnMap()['usa_inventario'] == true) {
          await session.execute(
            Sql.named('''UPDATE tbl_productos
                 SET existencia = existencia + @cant,
                     fecha_actualizacion = CURRENT_TIMESTAMP,
                     sincronizado = FALSE
                 WHERE id_producto = @p'''),
            parameters: {'cant': cant, 'p': idProd},
          );

          await session.execute(
            Sql.named('''INSERT INTO tbl_movimientos_inventario
                 (id_producto, tipo_movimiento, cantidad, id_usuario, motivo,
                  fecha_movimiento, fecha_registro, fecha_actualizacion,
                  sincronizado, terminal_origen)
                 VALUES
                 (@p, 'Cancelacion', @cant, @u, @motivo,
                  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                  FALSE, @terminal)'''),
            parameters: {
              'p': idProd,
              'cant': cant,
              'u': idUsuario,
              'motivo': motivo,
              'terminal': terminalId,
            },
          );
        }
      }

      if (esCredito && idCliente != null) {
        await session.execute(
          Sql.named('''UPDATE tbl_clientes
               SET saldo_actual = GREATEST(0, saldo_actual - @total),
                   fecha_actualizacion = CURRENT_TIMESTAMP,
                   sincronizado = FALSE
               WHERE id_cliente = @c'''),
          parameters: {'total': total, 'c': idCliente},
        );
      }

      if (idCorte != null) {
        final pagosEfeRes = await session.execute(
          Sql.named('''SELECT COALESCE(SUM(monto - cambio), 0) AS efe
               FROM tbl_pagos_venta pv
               JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
               WHERE pv.id_venta = @id AND fp.nombre_forma_pago = 'Efectivo' '''),
          parameters: {'id': idVenta},
        );
        final efe = pagosEfeRes.isNotEmpty ? parseDecimal(pagosEfeRes.first.toColumnMap()['efe']) : 0.0;

        await session.execute(
          Sql.named('''UPDATE tbl_cortes_caja
               SET total_ventas = GREATEST(0, total_ventas - @total),
                   efectivo_esperado = GREATEST(0, efectivo_esperado - @efe),
                   fecha_actualizacion = CURRENT_TIMESTAMP,
                   sincronizado = FALSE
               WHERE id_corte = @corte'''),
          parameters: {
            'total': total,
            'efe': efe,
            'corte': idCorte,
          },
        );
      }
    });
    dev.log('[VentasRepository] ✅ Venta #$idVenta cancelada con devolución de inventario');
  }

  /// Consulta la última venta completada con su detalle y pagos para reimpresión.
  Future<Map<String, dynamic>?> obtenerUltimaVentaCompletada() async {
    if (_db.isCloudOnlyMode) {
      final res = await _db.supabase
          .from('tbl_ventas')
          .select('*, tbl_usuarios(nombre_completo, nombre_usuario), tbl_clientes(nombre)')
          .eq('estatus_venta', 'Completada')
          .order('id_venta', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      final ventaMap = Map<String, dynamic>.from(res);
      final idVenta = parseIntSafe(ventaMap['id_venta']);
      final detalles = await obtenerDetalle(idVenta);
      final pagosRes = await _db.supabase
          .from('tbl_pagos_venta')
          .select('*, tbl_formas_pago(nombre_forma_pago)')
          .eq('id_venta', idVenta);

      final u = ventaMap['tbl_usuarios'];
      final c = ventaMap['tbl_clientes'];

      return {
        'venta': Venta.fromMap(ventaMap),
        'usuario_nombre': (u is Map ? (u['nombre_completo'] ?? u['nombre_usuario']) : null)?.toString() ?? 'Cajero',
        'cliente_nombre': (c is Map ? c['nombre'] : null)?.toString() ?? 'Público General',
        'detalles': detalles,
        'pagos': (pagosRes as List).map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final fp = m['tbl_formas_pago'];
          if (fp is Map && fp['nombre_forma_pago'] != null) {
            m['nombre_forma_pago'] = fp['nombre_forma_pago'];
          }
          return m;
        }).toList(),
      };
    }

    final res = await _db.query(
      '''SELECT v.*, u.nombre_completo AS usuario_nombre, c.nombre AS cliente_nombre
         FROM tbl_ventas v
         LEFT JOIN tbl_usuarios u ON v.id_usuario = u.id_usuario
         LEFT JOIN tbl_clientes c ON v.id_cliente = c.id_cliente
         WHERE v.estatus_venta::text = 'Completada'
         ORDER BY v.id_venta DESC
         LIMIT 1''',
    );
    if (res.isEmpty) return null;
    final ventaMap = res.first.toColumnMap();
    final idVenta = parseIntSafe(ventaMap['id_venta']);
    final detalles = await obtenerDetalle(idVenta);
    final pagosRes = await _db.query(
      '''SELECT pv.*, fp.nombre_forma_pago
         FROM tbl_pagos_venta pv
         LEFT JOIN tbl_formas_pago fp ON pv.id_forma_pago = fp.id_forma_pago
         WHERE pv.id_venta = @id''',
      params: {'id': idVenta},
    );
    return {
      'venta': Venta.fromMap(ventaMap),
      'usuario_nombre': parsePgString(ventaMap['usuario_nombre']),
      'cliente_nombre': parsePgString(ventaMap['cliente_nombre']),
      'detalles': detalles,
      'pagos': pagosRes.map((r) => r.toColumnMap()).toList(),
    };
  }
}
