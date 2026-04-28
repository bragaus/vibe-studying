import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const background = Color(0xFF0C0615);
  static const panel = Color(0xCC1A1026);
  static const panelSoft = Color(0xAA221535);
  static const foreground = Color(0xFFE9F9FF);
  static const muted = Color(0xFF9A8AB1);
  static const neonPink = Color(0xFFFF2EA6);
  static const neonPurple = Color(0xFFAA63FF);
  static const neonCyan = Color(0xFF2CF6FF);
  static const neonYellow = Color(0xFFFFD84D);
  static const border = Color(0x66FF2EA6);
  static const success = Color(0xFF49F7AA);
}

class AppTheme {
  static ThemeData dark() {
    final baseText = GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme);
    final mono = GoogleFonts.jetBrainsMonoTextTheme(baseText);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.background,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.neonPink,
        secondary: AppPalette.neonCyan,
        surface: AppPalette.panel,
        onPrimary: AppPalette.background,
        onSecondary: AppPalette.background,
        onSurface: AppPalette.foreground,
      ),
      textTheme: mono.copyWith(
        headlineLarge: GoogleFonts.bungee(
          textStyle: mono.headlineLarge,
          color: AppPalette.foreground,
          fontSize: 34,
          letterSpacing: 1.5,
        ),
        headlineMedium: GoogleFonts.bungee(
          textStyle: mono.headlineMedium,
          color: AppPalette.foreground,
          fontSize: 26,
          letterSpacing: 1.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.panelSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.neonPink, width: 1.4),
        ),
        labelStyle: const TextStyle(color: AppPalette.muted),
      ),
      cardTheme: CardTheme(
        color: AppPalette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
    );
  }
}
