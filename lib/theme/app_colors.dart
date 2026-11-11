import 'package:flutter/painting.dart';

/// AGENTS.md §10.2 paleti. `accent` ve `bg` widget'ta `context.accent` / `context.bg` ile okunur
/// (story.json `meta` ezebilir); diğer renkler doğrudan `AppColors.*` ile.
abstract final class AppColors {
  /// Video bölümlerinin zemini, sayfa arkası.
  static const Color bg = Color(0xFF0A0A0A);

  /// `text` / `projects` / `contact` bölümlerinin zemini.
  static const Color paper = Color(0xFF161616);

  /// Nav, sohbet paneli, kartlar.
  static const Color surface = Color(0xFF1E1E1E);

  /// Aktif nav pill'i, kullanıcı mesaj balonu.
  static const Color surfaceRaised = Color(0xFF2A2A2A);

  /// Beyaz %8: surface kenarlıkları, ayırıcı çizgiler.
  static const Color border = Color(0x14FFFFFF);

  /// Başlık ve birincil metin.
  static const Color text = Color(0xFFF2F2EE);

  /// Paragraf, etiket, ikincil metin.
  static const Color textMuted = Color(0xFF9A9A94);

  /// Reveal öncesi kelimeler; zemine yakın, soluk kalır.
  static const Color textDim = Color(0xFF2A2A28);

  /// Tek vurgu rengi; widget'ta `context.accent` ile okunur.
  static const Color accent = Color(0xFFC8F04E);

  /// Accent üstündeki yazı.
  static const Color onAccent = Color(0xFF0A0A0A);

  /// Yalnızca story.json hata kutusu.
  static const Color error = Color(0xFFE5322D);

  /// Tam şeffaf; widget'ta `Colors.transparent` yazılmaz.
  static const Color transparent = Color(0x00000000);

  /// `surface` %80; blur arkasındaki nav ve panel zemini.
  static const Color surfaceGlass = Color(0xCC1E1E1E);

  /// `text` %10; hover'da zeminin üstüne `Color.alphaBlend` ile biner.
  static const Color hoverOverlay = Color(0x1AF2F2EE);
}
