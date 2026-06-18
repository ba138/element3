import 'package:flutter/material.dart';

/// Element 3 brand theme.
///
/// Placeholder palette — replace these with the exact values from Element 3's
/// brand guidelines (and drop the logo into `assets/branding/`).
class Element3Theme {
  Element3Theme._();

  static const Color brandGreen = Color(0xFF2E7D32);
  static const Color brandDark = Color(0xFF0E1A14);
  static const Color brandSurface = Color(0xFF152620);
  static const Color brandAccent = Color(0xFF66E0A3);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFE53935);

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.dark,
    ).copyWith(
      surface: brandDark,
      primary: brandAccent,
      secondary: brandGreen,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: brandDark,
      cardTheme: CardThemeData(
        color: brandSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: brandDark,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}
