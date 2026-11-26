import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'services/backup_service.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno desde .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[Main] ⚠️ No se pudo cargar .env: $e');
  }

  // 2. Inicializar conexión a PostgreSQL local + Supabase
  try {
    await DatabaseService.instance.init();
    // 3. Iniciar motor de sincronización en segundo plano
    SyncService.instance.init(DatabaseService.instance);
  } catch (e) {
    debugPrint('[Main] ⚠️ Error inicializando base de datos en arranque: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // Intercepción de salida para respaldo automático si está configurado
    try {
      await BackupService.instance.ejecutarRespaldoAutomaticoSiActivo();
    } catch (_) {}
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abarrotes 3M',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}
