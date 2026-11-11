import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_breakpoints.dart';

/// Gutter, 8 px dikey ritim ve içerik maksimum genişlikleri (AGENTS.md §10.5 "Ortak").
abstract final class AppSpacing {
  /// Yatay kenar boşluğu: masaüstü 64, mobil 20.
  static double get gutter => (AppBreakpoints.isMobile ? 20 : 64).w;

  static double get xs => 8.r;
  static double get sm => 16.r;
  static double get md => 24.r;
  static double get lg => 32.r;
  static double get xl => 48.r;

  /// Sayfa içeriği maksimum genişlik.
  static double get contentMaxWidth => 1280.w;

  /// Text bölümü cümlesi maksimum genişlik (AGENTS.md §10.5).
  static double get statementMaxWidth => 880.w;
}
