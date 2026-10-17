import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abarrotes3m/screens/home_screen.dart';

void main() {
  group('Control de Acceso al módulo Usuarios en HomeScreen', () {
    testWidgets('Muestra el botón Usuarios solo cuando userType es Administrador', (tester) async {
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

      // Debe encontrar el texto y botón "Usuarios" para Administrador
      expect(find.text('Usuarios'), findsOneWidget);

      // Si cambiamos a perfil "Empleado"
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(userType: 'Empleado'),
        ),
      );
      await tester.pumpAndSettle();

      // No debe existir el botón "Usuarios" para perfil Empleado
      expect(find.text('Usuarios'), findsNothing);
    });
  });
}
