import 'dart:convert';
import 'package:postgres/postgres.dart';

/// Modelo para el campo JSONB [permisos_ventanas] de [tbl_usuarios].
///
/// Gestiona permisos granulares por módulo y acción:
/// - [punto_venta]: Acceso a la caja y cobro de tickets.
/// - [inventario_ver]: Acceso a la ventana de inventario (solo lectura / consulta de productos y stock).
/// - [inventario_editar]: Permiso para crear productos, modificar precios/datos y registrar entradas o salidas de stock.
/// - [clientes_ver]: Acceso a la ventana de clientes (consulta).
/// - [clientes_editar]: Permiso para crear o editar clientes.
/// - [reportes_ver]: Acceso a reportes de ventas, historial y cortes.
/// - [usuarios_gestionar]: Acceso a la administración de usuarios y asignación de permisos.
class PermisosVentanas {
  static const String puntoVentaKey = 'punto_venta';
  static const String inventarioVerKey = 'inventario_ver';
  static const String inventarioEditarKey = 'inventario_editar';
  static const String clientesVerKey = 'clientes_ver';
  static const String clientesEditarKey = 'clientes_editar';
  static const String reportesVerKey = 'reportes_ver';
  static const String usuariosGestionarKey = 'usuarios_gestionar';

  final Map<String, bool> _permisos;

  const PermisosVentanas(this._permisos);

  /// Construye desde el valor JSONB (puede ser Map, String, UndecodedBytes o null).
  factory PermisosVentanas.fromJsonb(dynamic value) {
    if (value == null) return PermisosVentanas(_defaultPermisos());
    dynamic raw = value;
    if (raw is UndecodedBytes) {
      raw = raw.asString;
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return PermisosVentanas(
            _normalizarPermisos(decoded.map((k, v) => MapEntry(k.toString(), v == true))),
          );
        }
      } catch (_) {
        return PermisosVentanas(_defaultPermisos());
      }
      return PermisosVentanas(_defaultPermisos());
    }
    if (raw is Map) {
      return PermisosVentanas(
        _normalizarPermisos(raw.map((k, v) => MapEntry(k.toString(), v == true))),
      );
    }
    return PermisosVentanas(_defaultPermisos());
  }

  /// Permisos por defecto para nuevo usuario (solo punto de venta).
  static Map<String, bool> _defaultPermisos() => {
        puntoVentaKey: true,
        inventarioVerKey: false,
        inventarioEditarKey: false,
        clientesVerKey: false,
        clientesEditarKey: false,
        reportesVerKey: false,
        usuariosGestionarKey: false,
      };

  /// Todos los permisos activos (para el usuario administrador o principal).
  factory PermisosVentanas.todos() => const PermisosVentanas({
        puntoVentaKey: true,
        inventarioVerKey: true,
        inventarioEditarKey: true,
        clientesVerKey: true,
        clientesEditarKey: true,
        reportesVerKey: true,
        usuariosGestionarKey: true,
      });

  /// Permisos para cajero estándar.
  factory PermisosVentanas.cajero() => const PermisosVentanas({
        puntoVentaKey: true,
        inventarioVerKey: true,
        inventarioEditarKey: false,
        clientesVerKey: true,
        clientesEditarKey: false,
        reportesVerKey: false,
        usuariosGestionarKey: false,
      });

  /// Normaliza y garantiza que todas las llaves existan y respeten dependencias.
  static Map<String, bool> _normalizarPermisos(Map<String, bool> mapa) {
    final res = Map<String, bool>.from(_defaultPermisos());
    for (final entry in mapa.entries) {
      res[entry.key.toLowerCase()] = entry.value;
    }
    // Reglas de dependencia:
    // Si editar inventario está activo, ver inventario debe estar activo.
    if (res[inventarioEditarKey] == true) {
      res[inventarioVerKey] = true;
    }
    // Si editar clientes está activo, ver clientes debe estar activo.
    if (res[clientesEditarKey] == true) {
      res[clientesVerKey] = true;
    }
    return res;
  }

  /// Verifica si el usuario tiene acceso a un permiso o ventana específica.
  bool tieneAcceso(String clave) {
    return _permisos[clave.toLowerCase()] ?? false;
  }

  // Getters tipados
  bool get puntoVenta => tieneAcceso(puntoVentaKey);
  bool get inventarioVer => tieneAcceso(inventarioVerKey);
  bool get inventarioEditar => tieneAcceso(inventarioEditarKey);
  bool get clientesVer => tieneAcceso(clientesVerKey);
  bool get clientesEditar => tieneAcceso(clientesEditarKey);
  bool get reportesVer => tieneAcceso(reportesVerKey);
  bool get usuariosGestionar => tieneAcceso(usuariosGestionarKey);

  /// Devuelve una copia con un permiso actualizado respetando dependencias:
  /// - Si activa inventario_editar -> activa inventario_ver.
  /// - Si desactiva inventario_ver -> desactiva inventario_editar.
  /// - Si activa clientes_editar -> activa clientes_ver.
  /// - Si desactiva clientes_ver -> desactiva clientes_editar.
  PermisosVentanas conPermiso(String clave, bool valor) {
    final nuevos = Map<String, bool>.from(_permisos);
    final keyNorm = clave.toLowerCase();
    nuevos[keyNorm] = valor;

    if (keyNorm == inventarioEditarKey && valor) {
      nuevos[inventarioVerKey] = true;
    } else if (keyNorm == inventarioVerKey && !valor) {
      nuevos[inventarioEditarKey] = false;
    }

    if (keyNorm == clientesEditarKey && valor) {
      nuevos[clientesVerKey] = true;
    } else if (keyNorm == clientesVerKey && !valor) {
      nuevos[clientesEditarKey] = false;
    }

    return PermisosVentanas(nuevos);
  }

  /// Devuelve el mapa completo inmodificable.
  Map<String, bool> get permisos => Map.unmodifiable(_permisos);

  /// Serializa a JSON string para guardar en PostgreSQL.
  String toJsonString() => jsonEncode(_permisos);

  /// Serializa a Map para Supabase.
  Map<String, bool> toMap() => Map<String, bool>.from(_permisos);

  PermisosVentanas copyWith({
    bool? puntoVenta,
    bool? inventarioVer,
    bool? inventarioEditar,
    bool? clientesVer,
    bool? clientesEditar,
    bool? reportesVer,
    bool? usuariosGestionar,
  }) {
    final nuevos = Map<String, bool>.from(_permisos);
    if (puntoVenta != null) nuevos[puntoVentaKey] = puntoVenta;
    if (inventarioVer != null) nuevos[inventarioVerKey] = inventarioVer;
    if (inventarioEditar != null) nuevos[inventarioEditarKey] = inventarioEditar;
    if (clientesVer != null) nuevos[clientesVerKey] = clientesVer;
    if (clientesEditar != null) nuevos[clientesEditarKey] = clientesEditar;
    if (reportesVer != null) nuevos[reportesVerKey] = reportesVer;
    if (usuariosGestionar != null) nuevos[usuariosGestionarKey] = usuariosGestionar;
    return PermisosVentanas(_normalizarPermisos(nuevos));
  }

  @override
  String toString() => 'PermisosVentanas($_permisos)';
}
