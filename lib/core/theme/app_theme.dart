import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFF581845);
  static const Color accent = Color(0xFFE5A995);
  static const Color ink = Color(0xFF231F20);
  static const Color muted = Color(0xFF767676);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE8E8E8);
  static const Color background = Color(0xFFFAF8F5);

  static ThemeData get lightTheme {
    const textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: muted),
      bodySmall: TextStyle(fontSize: 12, color: muted),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );

    return ThemeData(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(primary: brand, secondary: accent, surface: surface),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      dividerColor: border,
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(color: ink, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brand),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    // High-contrast text so labels stay readable on near-black surfaces
    const darkInk = Color(0xFFFFFFFF);
    const darkMuted = Color(0xFFBDBDBD);
    const darkSurface = Color(0xFF121212);
    const darkCard = Color(0xFF1E1E1E);
    const darkBorder = Color(0xFF2C2C2C);

    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: darkInk,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: darkInk,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: darkInk,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkInk,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: darkInk),
      bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: darkMuted),
      bodySmall: TextStyle(fontSize: 12, color: darkMuted),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );

    return ThemeData(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: brand,
        secondary: accent,
        surface: darkCard,
        onSurface: darkInk,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkInk,
      ),
      dividerColor: darkBorder,
      cardColor: darkCard,
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(color: darkInk, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brand),
        ),
      ),
    );
  }
}
