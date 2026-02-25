import 'package:flutter/material.dart';

import 'website_palette.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: WebsitePalette.accent,
    scaffoldBackgroundColor: WebsitePalette.bgBottom,
    colorScheme: const ColorScheme.dark(
      primary: WebsitePalette.accent,
      onPrimary: Colors.white,
      secondary: WebsitePalette.sun,
      onSecondary: Colors.black,
      tertiary: WebsitePalette.mint,
      onTertiary: Colors.black,
      surface: WebsitePalette.panel,
      onSurface: WebsitePalette.ink,
      outline: WebsitePalette.line,
      error: WebsitePalette.danger,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D2C42),
      foregroundColor: WebsitePalette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xCC0B2639),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WebsitePalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WebsitePalette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: WebsitePalette.accent, width: 1.3),
      ),
      labelStyle: const TextStyle(color: WebsitePalette.inkSoft),
      prefixIconColor: WebsitePalette.inkSoft,
      suffixIconColor: WebsitePalette.inkSoft,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xCC0B2639),
      selectedIconTheme: IconThemeData(color: WebsitePalette.accent),
      selectedLabelTextStyle: TextStyle(
        color: WebsitePalette.accent,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: WebsitePalette.inkSoft),
      unselectedLabelTextStyle: TextStyle(color: WebsitePalette.inkSoft),
      indicatorColor: Color(0x4433CC33),
    ),
    cardTheme: CardThemeData(
      color: WebsitePalette.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: WebsitePalette.ink,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: WebsitePalette.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(color: WebsitePalette.ink),
      bodyLarge: TextStyle(color: WebsitePalette.ink),
      bodyMedium: TextStyle(color: WebsitePalette.ink),
      bodySmall: TextStyle(color: WebsitePalette.inkSoft),
      labelLarge: TextStyle(
        color: WebsitePalette.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: const DividerThemeData(color: WebsitePalette.line),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: WebsitePalette.panel,
      contentTextStyle: const TextStyle(color: WebsitePalette.ink),
      actionTextColor: WebsitePalette.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: WebsitePalette.line),
      ),
    ),
  );
}
