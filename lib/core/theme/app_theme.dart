import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const Color brand = Color(0xFF00A651);
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
    // High contrast: pure black surfaces, pure white text/icons, white borders
    const darkInk = Color(0xFFFFFFFF);
    const darkMuted = Color(0xFFB0B0B0);
    const darkSurface = Color(0xFF000000);
    const darkCard = Color(0xFF0A0A0A);
    const darkBorder = Color(0xFFFFFFFF);
    const darkField = Color(0xFF111111);

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
      bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: darkInk),
      bodySmall: TextStyle(fontSize: 12, color: darkMuted),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: darkInk,
      ),
      labelMedium: TextStyle(fontSize: 13, color: darkInk),
      labelSmall: TextStyle(fontSize: 11, color: darkMuted),
    );

    final whiteBorderBtn = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: darkBorder, width: 1),
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
      canvasColor: darkSurface,
      cardColor: darkCard,
      dividerColor: darkBorder,
      primaryColor: brand,
      iconTheme: const IconThemeData(color: darkInk, size: 24),
      primaryIconTheme: const IconThemeData(color: darkInk),
      colorScheme: const ColorScheme.dark(
        primary: brand,
        secondary: accent,
        surface: darkCard,
        onSurface: darkInk,
        onPrimary: darkInk,
        onSecondary: darkInk,
        outline: darkBorder,
        error: Color(0xFFFF5252),
        onError: darkInk,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkInk,
        iconTheme: IconThemeData(color: darkInk),
        actionsIconTheme: IconThemeData(color: darkInk),
        titleTextStyle: TextStyle(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkField,
        selectedColor: brand.withValues(alpha: 0.35),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(color: darkInk, fontSize: 14),
        secondaryLabelStyle: const TextStyle(color: darkInk),
        deleteIconColor: darkInk,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkField,
          foregroundColor: darkInk,
          elevation: 0,
          shape: whiteBorderBtn,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkField,
          foregroundColor: darkInk,
          shape: whiteBorderBtn,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: darkField,
          foregroundColor: darkInk,
          side: const BorderSide(color: darkBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkInk),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkField,
        foregroundColor: darkInk,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        titleTextStyle: TextStyle(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: darkInk),
        iconColor: darkInk,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        modalBackgroundColor: darkCard,
        showDragHandle: true,
        dragHandleColor: darkMuted,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: brand,
        unselectedItemColor: darkMuted,
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: IconThemeData(color: brand),
        unselectedIconTheme: IconThemeData(color: darkMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: brand.withValues(alpha: 0.25),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return const IconThemeData(color: brand);
          }
          return const IconThemeData(color: darkInk);
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: darkInk, fontSize: 12),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkInk,
        iconColor: darkInk,
        subtitleTextStyle: TextStyle(color: darkMuted),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: brand,
        unselectedLabelColor: darkMuted,
        indicatorColor: brand,
        dividerColor: darkBorder,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(darkInk),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return brand;
          return darkField;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return brand;
          return darkField;
        }),
        checkColor: WidgetStateProperty.all(darkInk),
        side: const BorderSide(color: darkBorder),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(brand),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand,
        circularTrackColor: darkField,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: TextStyle(color: darkInk),
        actionTextColor: brand,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkCard,
        textStyle: TextStyle(color: darkInk),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 0.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkField,
        hintStyle: const TextStyle(color: darkMuted),
        labelStyle: const TextStyle(color: darkMuted),
        prefixIconColor: darkInk,
        suffixIconColor: darkInk,
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
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }


}
