import 'helpers.dart';

/// Modelo de datos para [tbl_cortes_caja] según Diccionario de Datos - Abarrotes 3M.
class CorteCaja {
  final int idCorte;
  final int idUsuario;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final double fondoInicial;
  final double totalVentas;
  final double totalEntradas;
  final double totalSalidas;
  final double efectivoEsperado;
  final double efectivoContado;
  final double diferencia;
  final String estatusCorte; // 'Abierto' | 'Cerrado'
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  // Auxiliar de JOIN con tbl_usuarios
  final String? nombreUsuario;

  const CorteCaja({
    required this.idCorte,
    required this.idUsuario,
    required this.fechaApertura,
    this.fechaCierre,
    required this.fondoInicial,
    this.totalVentas = 0.0,
    this.totalEntradas = 0.0,
    this.totalSalidas = 0.0,
    this.efectivoEsperado = 0.0,
    this.efectivoContado = 0.0,
    this.diferencia = 0.0,
    this.estatusCorte = 'Abierto',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
    this.nombreUsuario,
  });

  bool get estaAbierto => estatusCorte.toLowerCase() == 'abierto';

  factory CorteCaja.fromMap(Map<String, dynamic> map) {
    return CorteCaja(
      idCorte: parseIntSafe(map['id_corte']),
      idUsuario: parseIntSafe(map['id_usuario']),
      fechaApertura: parseDateTime(map['fecha_apertura']),
      fechaCierre: map['fecha_cierre'] != null ? parseDateTime(map['fecha_cierre']) : null,
      fondoInicial: parseDecimal(map['fondo_inicial']),
      totalVentas: parseDecimal(map['total_ventas']),
      totalEntradas: parseDecimal(map['total_entradas']),
      totalSalidas: parseDecimal(map['total_salidas']),
      efectivoEsperado: parseDecimal(map['efectivo_esperado']),
      efectivoContado: parseDecimal(map['efectivo_contado']),
      diferencia: parseDecimal(map['diferencia']),
      estatusCorte: parsePgString(map['estatus_corte'], defaultValue: 'Abierto'),
      fechaRegistro: parseDateTime(map['fecha_registro']),
      fechaActualizacion: parseDateTime(map['fecha_actualizacion']),
      uuidSync: parsePgString(map['uuid_sync']),
      sincronizado: parseBool(map['sincronizado']),
      terminalOrigen: parsePgNullableString(map['terminal_origen']),
      nombreUsuario: parsePgNullableString(map['nombre_usuario']),
    );
  }
}

