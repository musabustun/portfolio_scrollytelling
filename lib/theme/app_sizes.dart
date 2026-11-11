import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_breakpoints.dart';

/// Bileşen ölçüleri (AGENTS.md §10.4–10.6): nav, buton, tag, overlay, panel, ilerleme.
abstract final class AppSizes {
  static double get navHeight => 44.r;
  static double get navPadding => 6.r;
  static double get buttonHeight => 44.r;
  static double get buttonPaddingX => 20.r;
  static double get tagHeight => 28.r;
  static double get overlayMaxWidth => 560.w;

  /// Uzun tek paragrafın maksimum genişliği: başlıksız video overlay cümlesi (`overlayStatement`),
  /// masaüstü proje açıklaması ve iletişim detayı.
  static double get overlayStatementMaxWidth => 720.w;

  /// Overlay görünürken yukarı kayma miktarı (AGENTS.md §10.6).
  static double get overlayRise => 12.r;

  static double get chatPanelWidth => 380.w;
  static double get chatPanelHeight => 560.h;

  /// Sohbet panelinin `accent` daire gönder butonu çapı.
  static double get sendButtonSize => 36.r;

  /// Sohbet paneli başlık şeridi yüksekliği.
  static double get chatHeaderHeight => 56.r;

  /// Sohbet "yazıyor" göstergesinin nokta çapı ve noktalar arası boşluk (`TypingDots`).
  static double get typingDotSize => 6.r;
  static double get typingDotGap => 4.r;

  static double get progressLineWidth => 120.w;
  static double get ringStroke => 2.r;

  /// Mobil projeler bölümünde kapalı panelin yüksekliği: numara + ad tek satır (AGENTS.md §10.5).
  static double get projectPanelCollapsedHeight => 52.r;

  // Ölçeklenmeyen sabitler.
  static const double borderWidth = 1;
  static const double errorBarWidth = 3;

  /// Nav ve sohbet panelindeki `BackdropFilter` blur'u (AGENTS.md §10.4).
  static const double navBlurSigma = 16;

  /// Video bölümünün alt %40'ı gradyan scrim (AGENTS.md §10.4).
  static const double scrimFraction = 0.4;

  /// Video kırpma odağı (CSS object-position). Mobilde 16:9 video sağa kayar: özne sağ yarıda
  /// (AGENTS.md §10.8), dikey kadrajda ortadan kırpınca yüz dışarıda kalır. Bölümün dikey (9:16)
  /// mobil videosu varsa ([hasMobileVideo]) zaten kadraja uygundur, ortadan kırpılır.
  static String videoObjectPositionFor({required bool hasMobileVideo}) =>
      AppBreakpoints.isMobile && !hasMobileVideo
      ? _videoFocusMobile
      : _videoFocusDesktop;
  static const String _videoFocusMobile = '75% 50%';
  static const String _videoFocusDesktop = '50% 50%';
}
