import 'package:flutter/material.dart';

class ThemeUtils {
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }

  static ThemeData createTheme({
    required String primaryColorHex,
    required String accentColorHex,
    required Brightness brightness,
  }) {
    final primaryColor = hexToColor(primaryColorHex);
    final accentColor = hexToColor(accentColorHex);

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: accentColor,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light 
            ? primaryColor.withValues(alpha: 0.1)
            : primaryColor.withValues(alpha: 0.2),
        foregroundColor: brightness == Brightness.light 
            ? primaryColor 
            : Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
      ),
    );
  }

  static ThemeMode getThemeMode(String themeMode) {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static List<Color> generateColorPalette(Color baseColor) {
    return [
      baseColor,
      baseColor.withValues(alpha: 0.8),
      baseColor.withValues(alpha: 0.6),
      baseColor.withValues(alpha: 0.4),
      baseColor.withValues(alpha: 0.2),
    ];
  }

  static List<String> getPredefinedColors() {
    return [
      '#6750A4', // Purple
      '#FF6B6B', // Red
      '#4ECDC4', // Teal
      '#45B7D1', // Blue
      '#96CEB4', // Green
      '#FFEAA7', // Yellow
      '#DDA0DD', // Plum
      '#98D8C8', // Mint
      '#F7DC6F', // Gold
      '#BB8FCE', // Lavender
    ];
  }

  static List<String> getPredefinedAccentColors() {
    return [
      '#FF6B6B', // Red
      '#4ECDC4', // Teal
      '#45B7D1', // Blue
      '#96CEB4', // Green
      '#FFEAA7', // Yellow
      '#DDA0DD', // Plum
      '#98D8C8', // Mint
      '#F7DC6F', // Gold
      '#BB8FCE', // Lavender
      '#6750A4', // Purple
    ];
  }
} 