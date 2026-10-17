import 'package:flutter_test/flutter_test.dart';
import 'package:abarrotes3m/services/usuario_service.dart';

void main() {
  group('Pruebas de Usuario y UsuarioService', () {
    late UsuarioService service;

    setUp(() {
      service = UsuarioService();
    });

    test('Debe cargar usuarios iniciales con administradores y cajeros', () {
      expect(service.usuarios.isNotEmpty, true);
      expect(service.totalAdmins >= 1, true);
      expect(service.totalCajeros >= 1, true);
    });

    test('Debe registrar un nuevo usuario con la estructura solicitada', () {
      final inicialTotal = service.totalUsuarios;

      final nuevo = service.agregarUsuario(
        nombreUsuario: 'test_cajero',
        contrasena: 'clave123',
        nombres: 'Prueba',
        apellidos: 'De Sistema',
        telefono: '55 1122 3344',
        rol: 'Empleado',
      );

      expect(service.totalUsuarios, inicialTotal + 1);
      expect(nuevo.nombreUsuario, 'test_cajero');
      expect(nuevo.contrasena, 'clave123');
      expect(nuevo.nombres, 'Prueba');
      expect(nuevo.apellidos, 'De Sistema');
      expect(nuevo.telefono, '55 1122 3344');
      expect(nuevo.rol, 'Empleado');
      expect(nuevo.esAdmin, false);
      expect(nuevo.nombreCompleto, 'Prueba De Sistema');
    });

    test('Debe detectar nombres de usuario duplicados', () {
      expect(service.existeNombreUsuario('admin'), true);
      expect(service.existeNombreUsuario('ADMIN'), true);
      expect(service.existeNombreUsuario('usuario_inexistente_xyz'), false);
    });

    test('Debe actualizar los datos de un usuario existente', () {
      final usuario = service.buscarPorNombreUsuario('test_cajero');
      expect(usuario != null, true);

      final modificado = usuario!.copyWith(
        nombres: 'Prueba Modificada',
        telefono: '55 9999 8888',
        rol: 'Administrador',
      );

      service.actualizarUsuario(modificado);

      final recuperado = service.buscarPorId(usuario.id);
      expect(recuperado?.nombres, 'Prueba Modificada');
      expect(recuperado?.telefono, '55 9999 8888');
      expect(recuperado?.rol, 'Administrador');
      expect(recuperado?.esAdmin, true);
    });

    test('Debe permitir eliminar un usuario', () {
      final usuario = service.buscarPorNombreUsuario('test_cajero');
      expect(usuario != null, true);

      final totalAntes = service.totalUsuarios;
      final eliminado = service.eliminarUsuario(usuario!.id);

      expect(eliminado, true);
      expect(service.totalUsuarios, totalAntes - 1);
      expect(service.buscarPorNombreUsuario('test_cajero'), null);
    });

    test('No debe permitir eliminar el último administrador del sistema', () {
      // Dejar solo 1 admin
      final admins = service.usuarios.where((u) => u.esAdmin).toList();
      for (int i = 1; i < admins.length; i++) {
        service.eliminarUsuario(admins[i].id);
      }

      expect(service.totalAdmins, 1);
      final ultimoAdmin = service.usuarios.firstWhere((u) => u.esAdmin);

      // Intentar eliminar el último admin
      final eliminado = service.eliminarUsuario(ultimoAdmin.id);
      expect(eliminado, false);
      expect(service.totalAdmins, 1);
    });
  });
}
