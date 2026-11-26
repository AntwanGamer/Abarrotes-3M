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

  /// Registra una venta completa dentro de una transacción ACID:
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

  /// Obtiene las ventas del día desde PostgreSQL local.
  Future<List<Venta>> obtenerVentasDelDia() async {
    final result = await _db.query(
      '''SELECT * FROM tbl_ventas
         WHERE DATE(fecha_venta) = CURRENT_DATE
         ORDER BY fecha_venta DESC''',
    );
    return result.map((row) => Venta.fromMap(row.toColumnMap())).toList();
  }

  /// Obtiene el detalle de líneas de una venta específica.
  Future<List<VentaDetalle>> obtenerDetalle(int idVenta) async {
    final result = await _db.query(
      'SELECT * FROM tbl_detalle_ventas WHERE id_venta = @id ORDER BY id_detalle_venta',
      params: {'id': idVenta},
    );
    return result.map((row) => VentaDetalle.fromMap(row.toColumnMap())).toList();
  }

  /// Cancela una venta y marca `sincronizado = false`.
  Future<void> cancelarVenta(int idVenta, {String motivo = 'Cancelada en caja'}) async {
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
}
