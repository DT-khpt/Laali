import 'package:flutter/material.dart';

class AppThemes {
  static const Color headerTeal = Color(0xFF00796B);
  static const Color actionBlue = Color(0xFF1976D2);

  /* =======================================================
                        LIGHT THEME
  ======================================================= */

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Roboto',

    colorScheme: ColorScheme.fromSeed(
      seedColor: headerTeal,
      brightness: Brightness.light,
    ),

    scaffoldBackgroundColor: const Color(0xFFF5F7FA),

    appBarTheme: const AppBarTheme(
      backgroundColor: headerTeal,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),


    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: headerTeal,
        side: const BorderSide(color: headerTeal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: actionBlue, width: 1.5),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge:
          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      headlineMedium:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge:
          TextStyle(fontSize: 16),
      bodyMedium:
          TextStyle(fontSize: 14),
    ),
  );

  /* =======================================================
                        DARK THEME
  ======================================================= */

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Roboto',

    colorScheme: ColorScheme.fromSeed(
      seedColor: headerTeal,
      brightness: Brightness.dark,
    ),

    scaffoldBackgroundColor: const Color(0xFF0F172A),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F172A),
      elevation: 0,
      centerTitle: true,
    ),

    

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: headerTeal,
        side: const BorderSide(color: headerTeal),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: actionBlue, width: 1.5),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge:
          TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      headlineMedium:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge:
          TextStyle(fontSize: 16, color: Colors.white70),
      bodyMedium:
          TextStyle(fontSize: 14, color: Colors.white60),
    ),
  );
}