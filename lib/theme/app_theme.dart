import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final text = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );
    return base.copyWith(
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.dark(
        primary: C.primary,
        secondary: C.accent,
        surface: C.surface,
        error: C.danger,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: C.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: C.primary),
      ),
      cardTheme: CardThemeData(
        color: C.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: C.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: C.muted),
        hintStyle: const TextStyle(color: C.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700, fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: C.primary),
      ),
      dividerColor: C.border,
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: C.surfaceHi,
        side: const BorderSide(color: C.border),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
