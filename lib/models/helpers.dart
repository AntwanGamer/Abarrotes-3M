/// Helpers de mapeo para campos devueltos por el paquete `postgres`.
///
/// El paquete `postgres` v3 devuelve:
/// - DECIMAL(10,2) / NUMERIC como [String]
/// - Columnas ENUM o tipos personalizados como [UndecodedBytes]
///
/// Estos helpers previenen excepciones de casteo en tiempo de ejecución.
library;

import 'package:postgres/postgres.dart';

/// Convierte de forma segura cualquier valor obtenido de PostgreSQL a [String].
/// Decodifica instancias de [UndecodedBytes] (usadas por postgres para ENUMs y tipos personalizados).
String parsePgString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  if (value is UndecodedBytes) return value.asString;
  return value.toString();
}

/// Convierte de forma segura cualquier valor obtenido de PostgreSQL a [String?].
/// Retorna `null` si el valor es nulo.
String? parsePgNullableString(dynamic value) {
  if (value == null) return null;
  if (value is UndecodedBytes) return value.asString;
  return value.toString();
}

/// Parsea un valor dinámico (String | num | UndecodedBytes | null) a [double].
/// Retorna 0.0 si el valor no es parseable.
double parseDecimal(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is UndecodedBytes) {
    return double.tryParse(value.asString) ?? 0.0;
  }
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Parsea un valor dinámico a [int]. Retorna 0 si no es parseable.
int parseIntSafe(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is UndecodedBytes) {
    return int.tryParse(value.asString) ?? 0;
  }
  return int.tryParse(value.toString()) ?? 0;
}

/// Parsea un valor dinámico a [DateTime].
/// Retorna [DateTime.now()] si no es parseable.
DateTime parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is UndecodedBytes) {
    return DateTime.tryParse(value.asString) ?? DateTime.now();
  }
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}

/// Parsea un valor dinámico a [bool]. Retorna [false] si es null.
bool parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is UndecodedBytes) {
    final s = value.asString.toLowerCase();
    return s == 'true' || s == '1' || s == 't';
  }
  final s = value.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 't';
}
