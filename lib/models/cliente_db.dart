import 'helpers.dart';

/// Modelo de datos para [tbl_clientes] según Diccionario de Datos - Abarrotes 3M.
class ClienteDB {
  final int idCliente;
  final String nombre;
  final String? telefono;
  final bool tieneLimiteCredito;
  final double limiteCredito;
  final double saldoActual;
  final String estatus;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const ClienteDB({
    required this.idCliente,
    required this.nombre,
    this.telefono,
    this.tieneLimiteCredito = false,
    this.limiteCredito = 0.0,
    this.saldoActual = 0.0,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  // Compatibilidad con referencias anteriores
  String get nombreCompleto => nombre;
  double get deudaActual => saldoActual;

  factory ClienteDB.fromMap(Map<String, dynamic> map) {
    return ClienteDB(
      idCliente: parseIntSafe(map['id_cliente']),
      nombre: parsePgString(map['nombre']),
      telefono: parsePgNullableString(map['telefono']),
      tieneLimiteCredito: parseBool(map['tiene_limite_credito']),
      limiteCredito: parseDecimal(map['limite_credito']),
      saldoActual: parseDecimal(map['saldo_actual']),
      estatus: parsePgString(map['estatus'], defaultValue: 'Activo'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'nombre': nombre,
      'telefono': telefono,
      'tiene_limite_credito': tieneLimiteCredito,
      'limite_credito': limiteCredito,
      'saldo_actual': saldoActual,
      'estatus': estatus,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'uuid_sync': uuidSync,
      'sincronizado': sincronizado,
      'terminal_origen': terminalOrigen,
    };
  }
}
