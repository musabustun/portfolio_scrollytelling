import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Video bölümünün alt %40'ında `bg`'den şeffafa dikey gradyan (AGENTS.md §10.4); statik, blur yok.
///
/// `Stack` içinde tam ekran katman olarak kullanılır; tıklamaları geçirir.
class GradientScrim extends StatelessWidget {
  const GradientScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: AppSizes.scrimFraction,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [bg, bg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
