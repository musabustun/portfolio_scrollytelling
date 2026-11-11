import 'package:flutter/painting.dart';

/// Tek font ailesi (Inter, AGENTS.md §10.3) ve ağırlıkları; font adı başka hiçbir dosyada geçmez.
abstract final class AppFonts {
  static const String family = 'Inter';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}
