import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';
import 'app_text_styles.dart';

/// Token'lardan `ThemeData` üretir; `accent` ve `background` story.json `meta`'dan ezilebilir.
/// Tema katmanı story modelini import etmez; renkler parametre olarak gelir.
abstract final class AppTheme {
  static ThemeData build({Color? accent, Color? background}) {
    final primary = accent ?? AppColors.accent;
    final bg = background ?? AppColors.bg;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppFonts.family,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: AppColors.onAccent,
        secondary: primary,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.error,
        onError: AppColors.text,
        outline: AppColors.border,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.transparent,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.h1,
        titleLarge: AppTextStyles.statement,
        bodyMedium: AppTextStyles.body,
        labelSmall: AppTextStyles.label,
      ),
    );
  }
}

/// Katılımcının ezebildiği iki renk; widget'lar `context.accent` / `context.bg` okur.
extension AppThemeContext on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
}
