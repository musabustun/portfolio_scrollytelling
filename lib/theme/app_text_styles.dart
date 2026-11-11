import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_breakpoints.dart';
import 'app_colors.dart';
import 'app_fonts.dart';

/// AGENTS.md §10.3 tipografi hiyerarşisi; boyut breakpoint'e göre seçilir, `.sp` ile ölçeklenir.
/// `label`'ın BÜYÜK HARF'i burada değil, widget'ta `upperTr` (label_text.dart) ile uygulanır.
abstract final class AppTextStyles {
  /// Kapak başlığı: 112 / 56, 700, -0.04em, satır 0.95.
  static TextStyle get display => _style(
    desktop: 112,
    mobile: 56,
    weight: AppFonts.bold,
    tracking: -0.04,
    height: 0.95,
  );

  /// Bölüm başlığı: 64 / 40, 600, -0.03em, satır 1.0.
  static TextStyle get h1 => _style(
    desktop: 64,
    mobile: 40,
    weight: AppFonts.semiBold,
    tracking: -0.03,
    height: 1,
  );

  /// Text bölümü cümlesi, kapalı proje panelinin dikey adı ve iletişimdeki büyük e-posta:
  /// 48 / 28, 500, -0.02em, satır 1.15.
  static TextStyle get statement => _style(
    desktop: 48,
    mobile: 28,
    weight: AppFonts.medium,
    tracking: -0.02,
    height: 1.15,
  );

  /// Gövde metni: 17 / 16, 400, 0, satır 1.6.
  static TextStyle get body => _body();

  /// Sohbet giriş kutusu: `body` ile aynı, ama ölçekli boyut [_minInputFontSize]'ın altına inmez.
  /// iOS Safari, yazısı 16 CSS px'ten küçük bir girişe odaklanınca sayfayı yakınlaştırır.
  static TextStyle get input => _body(minSize: _minInputFontSize);

  /// iOS odak yakınlaştırmasının eşiği; mantıksal piksel (= CSS px), bilerek ölçeklenmez.
  static const double _minInputFontSize = 16;

  static TextStyle _body({double minSize = 0}) => _style(
    desktop: 17,
    mobile: 16,
    weight: AppFonts.regular,
    tracking: 0,
    height: 1.6,
    minSize: minSize,
  );

  /// Etiket, nav, sayaç: 11, 500, +0.14em, satır 1.0, `textMuted`.
  static TextStyle get label => _style(
    desktop: 11,
    mobile: 11,
    weight: AppFonts.medium,
    tracking: 0.14,
    height: 1,
    color: AppColors.textMuted,
  );

  /// Kapak selamlaması: 16 / 13, 500, +0.14em, satır 1.0, `textMuted`; BÜYÜK HARF widget'ta `upperTr`.
  static TextStyle get eyebrow => _style(
    desktop: 16,
    mobile: 13,
    weight: AppFonts.medium,
    tracking: 0.14,
    height: 1,
    color: AppColors.textMuted,
  );

  /// Kapak gövdesi, proje paneli açıklaması, öne çıkanlar ve link satırı, iletişim detayı:
  /// 22 / 18, 400, 0, satır 1.5.
  static TextStyle get lead => _style(
    desktop: 22,
    mobile: 18,
    weight: AppFonts.regular,
    tracking: 0,
    height: 1.5,
  );

  /// Başlıksız video overlay cümlesi: 40 / 26, 500, -0.02em, satır 1.2.
  static TextStyle get overlayStatement => _style(
    desktop: 40,
    mobile: 26,
    weight: AppFonts.medium,
    tracking: -0.02,
    height: 1.2,
  );

  /// Pill buton yazısı: 13 / 13, 500, +0.02em, satır 1.0.
  static TextStyle get button => _style(
    desktop: 13,
    mobile: 13,
    weight: AppFonts.medium,
    tracking: 0.02,
    height: 1,
  );

  /// Harf aralığı em cinsinden verilir; `tracking × ölçekli fontSize` ile px'e çevrilir.
  /// [minSize]: ölçekli boyutun alt sınırı (ölçeklenmez); harf aralığı sınırlanmış boyuttan hesaplanır.
  static TextStyle _style({
    required double desktop,
    required double mobile,
    required FontWeight weight,
    required double tracking,
    required double height,
    Color color = AppColors.text,
    double minSize = 0,
  }) {
    final size = math.max(
      (AppBreakpoints.isMobile ? mobile : desktop).sp,
      minSize,
    );
    return TextStyle(
      fontFamily: AppFonts.family,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking * size,
      height: height,
      color: color,
    );
  }
}
