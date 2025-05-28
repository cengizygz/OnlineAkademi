import 'package:flutter/material.dart';

class AppColors {
  // Ana Renk (Primary): Lacivert / Gece Mavisi
  static const Color primary = Color(0xFF1E293B);
  
  // İkincil Renk (Secondary): Açık Gri
  static const Color secondary = Color(0xFFE2E8F0);
  
  // Vurgu Rengi (Accent): Mavi
  static const Color accent = Color(0xFF3B82F6);
  
  // Yazı Rengi (Text): Neredeyse siyah
  static const Color text = Color(0xFF111827);
  
  // Arka Plan (Background): Çok açık gri / beyaza yakın
  static const Color background = Color(0xFFF8FAFC);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        background: AppColors.background,
        surface: AppColors.background,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: AppColors.text,
        onSurface: AppColors.text,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.text),
        bodySmall: TextStyle(color: AppColors.text),
        displayLarge: TextStyle(color: AppColors.text),
        displayMedium: TextStyle(color: AppColors.text),
        displaySmall: TextStyle(color: AppColors.text),
        headlineLarge: TextStyle(color: AppColors.text),
        headlineMedium: TextStyle(color: AppColors.text),
        headlineSmall: TextStyle(color: AppColors.text),
        titleLarge: TextStyle(color: AppColors.text),
        titleMedium: TextStyle(color: AppColors.text),
        titleSmall: TextStyle(color: AppColors.text),
        labelLarge: TextStyle(color: AppColors.text),
        labelMedium: TextStyle(color: AppColors.text),
        labelSmall: TextStyle(color: AppColors.text),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondary,
        disabledColor: Colors.grey,
        selectedColor: AppColors.accent,
        secondarySelectedColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(color: AppColors.text),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        brightness: Brightness.light,
      ),
    );
  }
} 