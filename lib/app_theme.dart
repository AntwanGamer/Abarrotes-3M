import 'package:flutter/material.dart';

/// Clase centralizada con todos los colores y estilos de la aplicación.
/// Para cambiar la paleta de colores, solo modifica los valores aquí.
class AppColors {
  // Colores principales
  static const Color primary = Color(0xFF2E7D5B);       // Verde bosque
  static const Color primaryDark = Color(0xFF1B5E3B);    // Verde oscuro
  static const Color primaryLight = Color(0xFF4CAF7D);   // Verde claro
  static const Color accent = Color(0xFFF9A825);         // Amarillo dorado

  // Fondos
  static const Color background = Color(0xFFF5F5F0);     // Crema suave
  static const Color surface = Color(0xFFFFFFFF);         // Blanco
  static const Color cardBackground = Color(0xFFFFFFFF);  // Blanco para cards

  // Textos
  static const Color textPrimary = Color(0xFF2D3436);     // Casi negro
  static const Color textSecondary = Color(0xFF636E72);   // Gris medio
  static const Color textOnPrimary = Color(0xFFFFFFFF);   // Blanco sobre primario

  // Bordes y divisores
  static const Color border = Color(0xFFE0E0E0);         // Gris claro
  static const Color divider = Color(0xFFEEEEEE);        // Gris muy claro

  // Estados
  static const Color error = Color(0xFFE74C3C);          // Rojo
  static const Color success = Color(0xFF27AE60);         // Verde éxito

  // Iconos de las cards del menú
  static const Color ventasIcon = Color(0xFF2E7D5B);     // Verde principal
  static const Color productosIcon = Color(0xFFF9A825);  // Amarillo dorado
  static const Color inventarioIcon = Color(0xFF3498DB); // Azul
}

/// Clase con los estilos de texto reutilizables.
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
  );
}

/// Genera el ThemeData de la aplicación a partir de los colores definidos.
class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.buttonText,
        ),
      ),
    );
  }
}
