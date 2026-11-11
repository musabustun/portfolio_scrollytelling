import 'package:flutter/widgets.dart';

/// Hareket süreleri ve eğrileri (AGENTS.md §10.6).
///
/// Widget'lar sabitleri değil `...Of(context)` getter'larını okur: işletim sistemi "hareketi azalt"
/// açıkken (`prefers-reduced-motion: reduce` → `MediaQueryData.disableAnimations`) süre sıfırdır.
abstract final class AppDurations {
  /// Bölüm geçişi ve sohbet buton ↔ panel.
  static const Duration crossfade = Duration(milliseconds: 250);
  static const Curve crossfadeCurve = Curves.easeOutCubic;

  /// Buton hover; yalnızca renk.
  static const Duration hover = Duration(milliseconds: 150);
  static const Curve hoverCurve = Curves.easeOut;

  /// `ScrollProgress.animateToChapter` kaydırması.
  static const Duration navScroll = Duration(milliseconds: 700);
  static const Curve navScrollCurve = Curves.easeInOutCubic;

  /// Sohbet "yazıyor" göstergesinin bir dalga turu (`TypingDots`). Hareket azaltılmışsa gösterge
  /// hiç dönmez; süre o yüzden `...Of(context)` getter'ı istemez.
  static const Duration typing = Duration(milliseconds: 1200);

  /// "Hareketi azalt" açık mı; `MediaQuery` yoksa `false`.
  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [crossfade]; hareket azaltılmışsa `Duration.zero`.
  static Duration crossfadeOf(BuildContext context) =>
      reduceMotionOf(context) ? Duration.zero : crossfade;

  /// [hover]; hareket azaltılmışsa `Duration.zero`.
  static Duration hoverOf(BuildContext context) =>
      reduceMotionOf(context) ? Duration.zero : hover;
}
