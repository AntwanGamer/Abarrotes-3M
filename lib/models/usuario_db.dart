import 'package:flutter/material.dart';
import 'helpers.dart';
import 'permisos_ventanas.dart';

/// Modelo de datos para [tbl_usuarios] según Diccionario de Datos - Abarrotes 3M.
class UsuarioDB {
  final int idUsuario;
  final String nombreCompleto;
  final String nombreUsuario;
  final String hashPassword;
  final PermisosVentanas permisosVentanas;
  final DateTime? ultimoAcceso;
  final String estatus; // 'Activo' | 'Inactivo'
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;

  // --- Campos de sincronización ---
  final String uuidSync;
  final bool sincronizado;
  final String? terminalOrigen;

  const UsuarioDB({
    required this.idUsuario,
    required this.nombreCompleto,
    required this.nombreUsuario,
    required this.hashPassword,
    required this.permisosVentanas,
    this.ultimoAcceso,
    this.estatus = 'Activo',
    required this.fechaRegistro,
    required this.fechaActualizacion,
    required this.uuidSync,
    this.sincronizado = false,
    this.terminalOrigen,
  });

  int get id => idUsuario;
  bool get esActivo => estatus.toLowerCase() == 'activo';
  bool get puedeGestionarUsuarios => permisosVentanas.usuariosGestionar;

  String get inicial {
    final u = nombreCompleto.trim().isNotEmpty ? nombreCompleto.trim() : nombreUsuario.trim();
    if (u.isNotEmpty) return u[0].toUpperCase();
    return 'U';
  }

  Color get avatarColor {
    if (puedeGestionarUsuarios) {
      return const Color(0xFF5B45B2);
    }
    const colores = [
      Color(0xFF2563EB),
      Color(0xFF0D9488),
      Color(0xFFD97706),
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFF4F46E5),
    ];
    return colores[idUsuario % colores.length];
  }

  bool tieneAcceso(String permiso) => permisosVentanas.tieneAcceso(permiso);

  factory UsuarioDB.fromMap(Map<String, dynamic> map) {
    return UsuarioDB(
      idUsuario: parseIntSafe(map['id_usuario']),
      nombreCompleto: parsePgString(map['nombre_completo'], defaultValue: parsePgString(map['nombre_usuario'])),
      nombreUsuario: parsePgString(map['nombre_usuario']),
      hashPassword: parsePgString(map['hash_password']),
      permisosVentanas: PermisosVentanas.fromJsonb(map['permisos_ventanas']),
      ultimoAcceso: map['ultimo_acceso'] != null ? parseDateTime(map['ultimo_acceso']) : null,
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
      'id_usuario': idUsuario,
      'nombre_completo': nombreCompleto,
      'nombre_usuario': nombreUsuario,
      'hash_password': hashPassword,
      'permisos_ventanas': permisosVentanas.toJsonString(),
      'ultimo_acceso': ultimoAcceso?.toIso8601String(),
      'estatus': estatus,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
      'uuid_sync': uuidSync,
      'sincronizado': sincronizado,
      'terminal_origen': terminalOrigen,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    final m = toMap();
    m.remove('id_usuario');
    m['permisos_ventanas'] = permisosVentanas.toMap();
    return m;
  }
}
