import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abarrotes3m/models/usuario_db.dart';
import 'package:abarrotes3m/models/permisos_ventanas.dart';
import 'package:abarrotes3m/screens/home_screen.dart';

void main() {
  group('Control de Acceso al módulo Usuarios en HomeScreen con Permisos Granulares', () {
    testWidgets('Muestra el botón Usuarios solo cuando tiene el permiso usuarios_gestionar', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final usuarioConGestion = UsuarioDB(
        idUsuario: 1,
        nombreUsuario: 'admin',
        hashPassword: '',
        permisosVentanas: PermisosVentanas.todos(),
        fechaRegistro: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        uuidSync: 'uuid-1',
      );

      final usuarioSinGestion = UsuarioDB(
        idUsuario: 2,
        nombreUsuario: 'cajero1',
        hashPassword: '',
        permisosVentanas: PermisosVentanas.cajero(),
        fechaRegistro: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        uuidSync: 'uuid-2',
      );

      // Usuario con permiso de usuarios_gestionar
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(usuario: usuarioConGestion),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Usuarios'), findsOneWidget);

      // Usuario sin permiso de usuarios_gestionar
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(usuario: usuarioSinGestion),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Usuarios'), findsNothing);
    });

    testWidgets('Compatibilidad hacia atrás con userType Administrador vs Empleado', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(userType: 'Administrador'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usuarios'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(userType: 'Empleado'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Usuarios'), findsNothing);
    });
  });
}
