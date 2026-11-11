import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'index_label.dart';
import 'label_text.dart';

/// Adım sayacı "01 / 03" ve 120 px ince ilerleme çizgisi (AGENTS.md §10.5); `progress`'i tween'siz
/// çizer.
class StepCounter extends StatelessWidget {
  const StepCounter({
    required this.current,
    required this.total,
    required this.progress,
    super.key,
  });

  /// 1 tabanlı aktif adım.
  final int current;

  final int total;

  /// Çizginin dolu oranı 0..1; dışı kırpılır.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LabelText('${twoDigits(current)} / ${twoDigits(total)}'),
        SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: AppSizes.progressLineWidth,
          height: AppSizes.borderWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.border),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: ColoredBox(color: context.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
