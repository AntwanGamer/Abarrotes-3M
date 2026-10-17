import 'package:flutter/material.dart';

/// Modelo de datos para representar a un Usuario del sistema Punto de Venta.
/// Contiene datos de acceso (Usuario, Contraseña), datos generales (Nombres, Apellidos, Teléfono)
/// y el rol asignado (Usuario o Administrador).
class Usuario {
  final int id;
  String nombreUsuario;
  String contrasena;
  String nombres;
  String apellidos;
  String telefono;
  String rol; // 'Administrador' o 'Empleado'
  final DateTime fechaRegistro;

  Usuario({
    required this.id,
    required this.nombreUsuario,
    required this.contrasena,
    required this.nombres,
    this.apellidos = '',
    this.telefono = '',
    this.rol = 'Empleado',
    DateTime? fechaRegistro,
  }) : fechaRegistro = fechaRegistro ?? DateTime.now();

  /// Retorna si el usuario tiene privilegios de Administrador
  bool get esAdmin => rol.toLowerCase() == 'administrador';

  /// Nombre completo (Nombres + Apellidos) o Nombre de Usuario si está vacío
  String get nombreCompleto {
    final completo = '$nombres $apellidos'.trim();
    return completo.isNotEmpty ? completo : nombreUsuario;
  }

  /// Inicial para el avatar circular
  String get inicial {
    final n = nombres.trim();
    if (n.isNotEmpty) return n[0].toUpperCase();
    final u = nombreUsuario.trim();
    if (u.isNotEmpty) return u[0].toUpperCase();
    return 'U';
  }

  /// Color representativo del avatar según el ID y Rol
  Color get avatarColor {
    if (esAdmin) {
      return const Color(0xFF5B45B2); // Púrpura característico admin
    }
    const colores = [
      Color(0xFF2563EB), // Azul brillante
      Color(0xFF0D9488), // Teal
      Color(0xFFD97706), // Ámbar / naranja
      Color(0xFF059669), // Esmeralda
      Color(0xFFDC2626), // Rojo carmesí
      Color(0xFF4F46E5), // Índigo
    ];
    return colores[id % colores.length];
  }

  /// Copia con cambios
  Usuario copyWith({
    int? id,
    String? nombreUsuario,
    String? contrasena,
    String? nombres,
    String? apellidos,
    String? telefono,
    String? rol,
    DateTime? fechaRegistro,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      contrasena: contrasena ?? this.contrasena,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
    );
  }
}
