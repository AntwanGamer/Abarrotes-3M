import 'helpers.dart';

/// Modelo de datos para [tbl_ventas] según Diccionario de Datos - Abarrotes 3M.
class Venta {
  final int idVenta;
  final String folioTicket;
  final int idUsuario;
  final int? idCliente;
  final int? idCorte;
  final DateTime fechaVenta;
  final double subtotal;
  final double descuento;
  final double iva;
  final double total;
  final bool esCredito;
  final String estatusVenta; // 'Completada' | 'Cancelada'
  final String? motivoCancelacion;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const Venta({
    required this.idVenta,
    required this.folioTicket,
    required this.idUsuario,
    this.idCliente,
    this.idCorte,
    required this.fechaVenta,
    required this.subtotal,
    this.descuento = 0.0,
    this.iva = 0.0,
    required this.total,
    this.esCredito = false,
    this.estatusVenta = 'Completada',
    this.motivoCancelacion,
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      idVenta: parseIntSafe(map['id_venta']),
      folioTicket: parsePgString(map['folio_ticket']),
      idUsuario: parseIntSafe(map['id_usuario']),
      idCliente: map['id_cliente'] != null ? parseIntSafe(map['id_cliente']) : null,
      idCorte: map['id_corte'] != null ? parseIntSafe(map['id_corte']) : null,
      fechaVenta: parseDateTime(map['fecha_venta']),
      subtotal: parseDecimal(map['subtotal']),
      descuento: parseDecimal(map['descuento']),
      iva: parseDecimal(map['iva']),
      total: parseDecimal(map['total']),
      esCredito: parseBool(map['es_credito']),
      estatusVenta: parsePgString(map['estatus_venta'], defaultValue: 'Completada'),
      motivoCancelacion: parsePgNullableString(map['motivo_cancelacion']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}
