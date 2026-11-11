import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../story/scroll_progress.dart';
import '../story/story.dart';
import '../theme/theme.dart';
import '../widgets/label_text.dart';
import '../widgets/progress_ring.dart';
import '../widgets/tap_target.dart';

/// Üstte ortada yüzen pill nav: bölüm başlıkları ve `globalProgress` halkası; mobilde gizli
/// (AGENTS.md §10.4).
///
/// Yalnızca [scrollProgress]'i dinler; tıklanan bölüme `animateToChapter` ile gider (AGENTS.md §4).
class ChapterIndicator extends StatelessWidget {
  const ChapterIndicator({
    required this.story,
    required this.scrollProgress,
    super.key,
  });

  final Story story;
  final ScrollProgress scrollProgress;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile) return const SizedBox.shrink();
    final chapters = story.chapters;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: ListenableBuilder(
          listenable: scrollProgress,
          builder: (context, _) {
            final state = scrollProgress.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassPill(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < chapters.length; i++)
                        _NavItem(
                          index: i,
                          title: chapters[i].title,
                          active: i == state.chapterIndex,
                          onTap: () => scrollProgress.animateToChapter(i),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                _GlassPill(
                  child: ProgressRing(
                    progress: state.globalProgress,
                    size: _ringSize,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Halka çapı: pill yüksekliğinden iç boşluk ve kenarlık düşülür (Container kenarlığı içeri ekler).
double get _ringSize =>
    AppSizes.navHeight - 2 * (AppSizes.navPadding + AppSizes.borderWidth);

/// Nav yüzeyi: blur arkası yarı saydam `surface`, `border` kenarlık, pill köşe, 44 yükseklik.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.pill,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSizes.navBlurSigma,
          sigmaY: AppSizes.navBlurSigma,
        ),
        child: Container(
          height: AppSizes.navHeight,
          padding: EdgeInsets.all(AppSizes.navPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: AppRadii.pill,
            border: Border.all(
              color: AppColors.border,
              width: AppSizes.borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Tek bölüm başlığı; aktifse `surfaceRaised` pill zemin ve `text` renk, değilse `textMuted`.
///
/// Ekran okuyucu "Bölüm N: başlık" düğmesi okur, aktif bölüm seçili (`selected`) işaretlenir.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.title,
    required this.active,
    required this.onTap,
  });

  /// Bölümün 0 tabanlı sırası; etikette `index + 1` okunur.
  final int index;
  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      label: AppStrings.chapterNavLabel(index + 1, title),
      selected: active,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.hoverOf(context),
        curve: AppDurations.hoverCurve,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceRaised : AppColors.transparent,
          borderRadius: AppRadii.pill,
        ),
        child: LabelText(
          title,
          color: active ? AppColors.text : AppColors.textMuted,
        ),
      ),
    );
  }
}
