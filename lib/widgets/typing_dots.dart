import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Nokta sayısı; her biri dalganın `1/3`'ü kadar geriden gelir.
const int _dotCount = 3;

/// Dalganın alt ve üst opaklığı; hareket azaltılmışsa noktalar [_stillOpacity]'de durur.
const double _minOpacity = 0.3;
const double _maxOpacity = 1;
const double _stillOpacity = 0.6;

/// Nokta [index]'in, dalga [value] (0..1, bir tur [AppDurations.typing]) anındaki opaklığı:
/// `0.3 ↔ 1` arasında kosinüs dalgası, her nokta bir öncekinden `1/3` tur geride (soldan sağa sırayla).
@visibleForTesting
double typingDotOpacityAt({required double value, required int index}) {
  final phase = (value - index / _dotCount) % 1;
  final wave = (1 - math.cos(2 * math.pi * phase)) / 2;
  return _minOpacity + (_maxOpacity - _minOpacity) * wave;
}

/// Sohbet cevabı beklenirken asistan satırında yan yana üç `textMuted` nokta; opaklıkları sırayla
/// dalgalanır (AGENTS.md §10.1 istisnası: sohbet cevabının akışı).
///
/// Hareket azaltılmışsa (AGENTS.md §10.6) dalga çalışmaz, noktalar sabit yarı opak durur. Ekran
/// okuyucu noktaları değil [AppStrings.typing]'i okur (canlı bölge).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: AppDurations.typing,
  );

  /// "Hareketi azalt" açık mı; açıksa [_wave] durur.
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = AppDurations.reduceMotionOf(context);
    if (_still) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: AppStrings.typing,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dotCount; i++) ...[
              if (i > 0) SizedBox(width: AppSizes.typingDotGap),
              _Dot(
                opacity: _still
                    ? _stillOpacity
                    : typingDotOpacityAt(value: _wave.value, index: i),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Tek nokta: `textMuted` daire; opaklık renkte (katman açmaz).
class _Dot extends StatelessWidget {
  const _Dot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSizes.typingDotSize,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textMuted.withValues(alpha: opacity),
      ),
    ),
  );
}
