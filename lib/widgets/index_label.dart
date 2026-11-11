import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'label_text.dart';

/// Sayıyı iki haneli yazar (`1 → '01'`); indeks etiketi, adım sayacı ve proje numaraları kullanır.
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// Numaralı etiket "01 · PROJE" (AGENTS.md §10.3): numara `accent`, ayraç ve metin `textMuted`,
/// `label` stili; video overlay'i ve açık proje paneli kullanır.
///
/// [index] 1 tabanlıdır; metin Türkçe kurallarıyla BÜYÜK HARF'e çevrilir. Tek satır, tek `Text.rich`.
class IndexLabel extends StatelessWidget {
  const IndexLabel({required this.index, required this.text, super.key});

  /// 1 tabanlı sıra numarası; iki haneli yazılır.
  final int index;

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.label;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: twoDigits(index),
            style: style.copyWith(color: context.accent),
          ),
          TextSpan(text: ' · ${upperTr(text)}'),
        ],
      ),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
