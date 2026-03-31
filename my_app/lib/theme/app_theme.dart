import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light() {
    // Avoid ThemeData.light(useMaterial3: ...) to stay compatible across Flutter versions.
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF111827), // near-black
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF111827),
      surface: Colors.white,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w900),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w900),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w900),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.5),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
