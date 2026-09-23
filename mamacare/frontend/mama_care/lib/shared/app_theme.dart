import 'package:flutter/material.dart';

/// Palette officielle MAMA-CARE — source unique des couleurs.
class AppColors {
  AppColors._();

  /// Couleur de marque (bordeaux).
  static const Color burgundy = Color(0xFF800020);

  /// Fond clair des écrans.
  static const Color pageBackground = Color(0xFFFCF9FA);

  /// Fond pastel des cartes/bannières (variante bordeaux clair).
  static const Color lightBurgundy = Color(0xFFF8EDF0);

  /// Bordure discrète des cartes et champs.
  static const Color softBorder = Color(0xFFF0E7E9);

  /// Bulle de message sortant (messagerie patiente/médecin).
  static const Color outgoingBubble = Color(0xFF7A1B2B);

  /// Bulle de message entrant (messagerie patiente/médecin).
  static const Color incomingBubble = Color(0xFFF0EEED);

  /// Niveau d'alerte critique.
  static const Color critical = Color(0xFFB3261E);

  /// Niveau d'alerte modéré.
  static const Color warning = Color(0xFFB54708);

  /// Niveau d'alerte OK / information.
  static const Color ok = Color(0xFF2E7D32);
}

/// Thème global de l'application MAMA-CARE.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.burgundy);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.pageBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: AppColors.burgundy),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.burgundy, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.burgundy.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.burgundy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.softBorder),
    );
  }
}