import 'package:flutter/material.dart';

/// OilMitra palette: cold-pressed olive green, warm amber oil, and a cream
/// paper background. Big numbers, soft cards, and one very dark hero card.
class AppColors {
  static const ink = Color(0xFF131A10);
  static const inkSoft = Color(0xFF2A3423);
  static const cream = Color(0xFFFBF7EC);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E2D3);
  static const muted = Color(0xFF77806B);

  static const amber = Color(0xFFF4A72C);
  static const amberDeep = Color(0xFFC97B05);
  static const amberSoft = Color(0xFFFFEBC6);
  static const gold = Color(0xFFFFC85C);

  static const olive = Color(0xFF4F6B2F);
  static const oliveSoft = Color(0xFFEAF1DA);
  static const teal = Color(0xFF1E7A68);
  static const tealSoft = Color(0xFFE1F2ED);

  static const open = Color(0xFF2E8B57);
  static const claimed = Color(0xFF3E63C8);
  static const collected = Color(0xFF6B7280);
  static const cancelled = Color(0xFFB3403A);
  static const expired = Color(0xFF9A7B2E);

  static Color forStatus(String s) => switch (s) {
        'open' => open,
        'claimed' || 'scheduled' => claimed,
        'collected' || 'completed' => collected,
        'cancelled' => cancelled,
        'expired' => expired,
        _ => muted,
      };

  static IconData iconFor(String s) => switch (s) {
        'open' => Icons.bolt_rounded,
        'claimed' || 'scheduled' => Icons.event_available_rounded,
        'collected' || 'completed' => Icons.verified_rounded,
        'cancelled' => Icons.close_rounded,
        'expired' => Icons.hourglass_bottom_rounded,
        _ => Icons.circle_outlined,
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.olive,
    primary: AppColors.ink,
    secondary: AppColors.amber,
    surface: AppColors.cream,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: const BorderSide(color: AppColors.line),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.ink, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.amberSoft,
      height: 72,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.cream,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: const BorderSide(color: AppColors.line),
      backgroundColor: Colors.white,
      selectedColor: AppColors.amberSoft,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
  );
}
