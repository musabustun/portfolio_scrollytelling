import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Pill buton (AGENTS.md §10.4): dolu (`accent` zemin) ya da çizgili (`border` kenarlık); hover'da
/// zemin %10 açılır.
///
/// Genişlik yazıya göre; ebeveyn germedikçe yatayda yayılmaz. Büyüme ve gölge yok, yalnızca renk.
class PillButton extends StatefulWidget {
  const PillButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.arrow = false,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  /// Ekran okuyucunun okuduğu ad; `null` ise [label]. Görünen yazı ve ok semantics'e girmez.
  final String? semanticsLabel;

  /// `true`: `accent` zemin + `onAccent` yazı; `false`: şeffaf zemin + `border` kenarlık + `text` yazı.
  final bool filled;

  /// `true` ise yazının sağına ` →` eklenir.
  final bool arrow;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.filled;
    final base = filled ? context.accent : AppColors.transparent;
    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
      // Çocuk dışlandığı için `GestureDetector`'ın dokunma eylemi semantics'e girmez; ekran
      // okuyucuyla etkinleştirme için ayrıca verilir.
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDurations.hoverOf(context),
            curve: AppDurations.hoverCurve,
            height: AppSizes.buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.buttonPaddingX),
            decoration: BoxDecoration(
              color: _hovered
                  ? Color.alphaBlend(AppColors.hoverOverlay, base)
                  : base,
              borderRadius: AppRadii.pill,
              border: filled
                  ? null
                  : Border.all(
                      color: AppColors.border,
                      width: AppSizes.borderWidth,
                    ),
            ),
            // `alignment` yerine `Center(widthFactor: 1)`: dikeyde ortalar ama sınırlı
            // genişlikte (ör. Column içinde) butonu tam genişliğe yaymaz.
            child: Center(
              widthFactor: 1,
              child: Text(
                widget.arrow ? '${widget.label} →' : widget.label,
                style: AppTextStyles.button.copyWith(
                  color: filled ? AppColors.onAccent : AppColors.text,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
