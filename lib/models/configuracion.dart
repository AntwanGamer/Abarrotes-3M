import 'helpers.dart';

/// Modelo de datos para [tbl_configuracion].
class ConfiguracionNegocio {
  final int idConfiguracion;
  final String nombreNegocio;
  final String? direccionNegocio;
  final String? telefonoNegocio;
  final String? mensajeTicket;
  final bool imprimirTicket;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const ConfiguracionNegocio({
    required this.idConfiguracion,
    required this.nombreNegocio,
    this.direccionNegocio,
    this.telefonoNegocio,
    this.mensajeTicket,
    this.imprimirTicket = true,
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  factory ConfiguracionNegocio.fromMap(Map<String, dynamic> map) {
    return ConfiguracionNegocio(
      idConfiguracion: parseIntSafe(map['id_configuracion']),
      nombreNegocio: parsePgString(map['nombre_negocio']),
      direccionNegocio: parsePgNullableString(map['direccion_negocio']),
      telefonoNegocio: parsePgNullableString(map['telefono_negocio']),
      mensajeTicket: parsePgNullableString(map['mensaje_ticket']),
      imprimirTicket: parseBool(map['imprimir_ticket']),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
    );
  }
}

