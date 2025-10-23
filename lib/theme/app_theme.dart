import 'package:flutter/material.dart';

class AppTheme {
  // Palette choices
  static const Color terracotta = Color(0xFFE07A5F); // burnt orange
  static const Color mediumBrown = Color(0xFF6B4C3B); // medium brown for text
  static const Color warmBeige = Color(0xFFF7EDE2); // warm beige/cream background

  // Seed color for ColorScheme (Material 3)
  static const Color seedColor = terracotta;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // warm beige background across the app
      scaffoldBackgroundColor: warmBeige,
      // text should be medium brown
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: mediumBrown,
            displayColor: mediumBrown,
          ),
      // icons default to terracotta
      iconTheme: const IconThemeData(color: terracotta),
      appBarTheme: AppBarTheme(
        backgroundColor: warmBeige,
        foregroundColor: mediumBrown,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: mediumBrown),
        iconTheme: const IconThemeData(color: terracotta),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: terracotta,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: terracotta,
          side: BorderSide(color: terracotta.withOpacity(0.12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: terracotta,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: terracotta,
        textColor: mediumBrown,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: terracotta,
        unselectedLabelColor: mediumBrown.withOpacity(0.6),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: terracotta, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 24),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: warmBeige,
        selectedItemColor: terracotta,
        unselectedItemColor: mediumBrown.withOpacity(0.6),
        elevation: 8,
        showUnselectedLabels: true,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline.withOpacity(0.6), thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: mediumBrown),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: TextStyle(color: mediumBrown),
        actionTextColor: terracotta,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titleTextStyle: TextStyle(color: mediumBrown, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      shadowColor: Colors.black.withOpacity(0.12),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: mediumBrown,
            displayColor: mediumBrown,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: mediumBrown,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: terracotta),
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[900],
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[800],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey[900],
        selectedItemColor: terracotta,
        unselectedItemColor: mediumBrown.withOpacity(0.6),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.grey[900],
      ),
    );
  }
}
