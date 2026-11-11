import 'package:flutter/widgets.dart';

/// Görünümü [child]'da olan tıklanabilir alan: ekran okuyucuya [label] adlı düğme, fareye el imleci,
/// dokunmaya opak hit-test.
///
/// Semantics çocuğu dışlar (`excludeSemantics`): ekran okuyucu yalnızca [label]'ı okur; ok, büyük
/// harf ya da ikon okunmaz. Dışlanan `GestureDetector`'ın dokunma eylemi yerine [onTap] semantics'e
/// ayrıca verilir: ekran okuyucuyla etkinleştirme çalışır. Hover rengi yok; hover isteyen düğme
/// `PillButton`'dır.
class TapTarget extends StatelessWidget {
  const TapTarget({
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    super.key,
  });

  /// Ekran okuyucunun okuduğu ad.
  final String label;

  final VoidCallback onTap;

  final Widget child;

  /// Seçili durum (ör. aktif nav öğesi). `null` ise düğmenin seçim durumu yoktur; `false` ise
  /// "seçili değil" okunur.
  final bool? selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    ),
  );
}
