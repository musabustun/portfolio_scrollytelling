import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'label_text.dart';

/// `story.json` okunamadığında tam ekran hata kutusu: `paper` zemin, sol `error` çizgi
/// (AGENTS.md §10.4).
///
/// Mesaj Inter `body` ile yazılır (ikinci font ailesi yok, AGENTS.md §10.7); seçilebilir,
/// kopyalanabilir.
class StoryErrorBox extends StatelessWidget {
  const StoryErrorBox({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.paper,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.statementMaxWidth),
        child: Container(
          margin: EdgeInsets.all(AppSpacing.gutter),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.error,
                width: AppSizes.errorBarWidth,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LabelText(
                AppStrings.storyErrorTitle,
                color: AppColors.error,
              ),
              SizedBox(height: AppSpacing.sm),
              SelectableText(message, style: AppTextStyles.body),
              SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.storyErrorHint,
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
