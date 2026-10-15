import 'package:flutter/material.dart';

/// Modelo de datos para representar a un Cliente en el sistema Punto de Venta.
class Cliente {
  final int folio;
  String nombres;
  String apellidos;
  String telefono;
  final DateTime fechaRegistro;

  Cliente({
    required this.folio,
    required this.nombres,
    this.apellidos = '',
    this.telefono = '',
    DateTime? fechaRegistro,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  /// Retorna el nombre completo (Nombres + Apellidos)
  String get nombreCompleto {
    final completo = '$nombres $apellidos'.trim();
    return completo.isNotEmpty ? completo : 'Cliente #$folio';
  }

  /// Inicial para el avatar circular
  String get inicial {
    final n = nombres.trim();
    if (n.isNotEmpty) return n[0].toUpperCase();
    final a = apellidos.trim();
    if (a.isNotEmpty) return a[0].toUpperCase();
    return '#';
  }

  /// Color distintivo para el avatar según el folio
  Color get avatarColor {
    const colores = [
      Color(0xFF6A1B9A), // Púrpura (como en eleventa)
      Color(0xFF1565C0), // Azul
      Color(0xFF00695C), // Verde azulado
      Color(0xFFE65100), // Naranja oscuro
      Color(0xFF2E7D32), // Verde bosque
      Color(0xFFC2185B), // Rosa fucsia
      Color(0xFF455A64), // Azul grisáceo
    ];
    return colores[folio % colores.length];
  }

  /// Copia con cambios
  Cliente copyWith({
    int? folio,
    String? nombres,
    String? apellidos,
    String? telefono,
    DateTime? fechaRegistro,
  }) {
    return Cliente(
      folio: folio ?? this.folio,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
