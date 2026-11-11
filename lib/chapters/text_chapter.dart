import 'package:flutter/widgets.dart';

import '../story/scroll_progress.dart';
import '../story/story.dart';
import '../theme/theme.dart';
import '../widgets/label_text.dart';
import '../widgets/reveal_text.dart';

/// Statement bölümü (AGENTS.md §10.5): `paper` zemin, ortada "— BAŞLIK" etiketi ve kelime kelime
/// dolan cümle.
///
/// Bölüm ilerlemesini `progressFor(index)` ile okur; scroll'da yalnızca [RevealText] rebuild olur.
class TextChapter extends StatelessWidget {
  const TextChapter({
    required this.chapter,
    required this.index,
    required this.scrollProgress,
    super.key,
  });

  final Chapter chapter;
  final int index;
  final ScrollProgress scrollProgress;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.paper,
    child: Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppSpacing.statementMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabelText('— ${chapter.title}'),
              SizedBox(height: AppSpacing.lg),
              // Flexible: çok uzun gövde ekrana sığmazsa taşma hatası yerine alttan kırpılır.
              Flexible(
                child: ListenableBuilder(
                  listenable: scrollProgress,
                  builder: (context, _) => RevealText(
                    body: chapter.body ?? '',
                    progress: scrollProgress.value.progressFor(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
