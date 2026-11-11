import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Metni Türkçe kurallarıyla BÜYÜK HARF'e çevirir (`i → İ`, `ı → I`); saf fonksiyon.
///
/// Dart'ın `toUpperCase()`'i tek başına "kimim"i "KIMIM" yapar; önce noktalı/noktasız i
/// eşlenir, kalan harfler (`ğüşöç`) `toUpperCase()` ile zaten doğru çevrilir.
String upperTr(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// `label` stili + Türkçe BÜYÜK HARF, tek satır; nav, adım sayacı, bölüm ve panel etiketleri, proje
/// numarası ve tag'leri, footer bunu kullanır.
class LabelText extends StatelessWidget {
  const LabelText(this.text, {this.color, super.key});

  final String text;

  /// Verilmezse `label` stilinin rengi (`textMuted`) kalır.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = color == null
        ? AppTextStyles.label
        : AppTextStyles.label.copyWith(color: color);
    return Text(
      upperTr(text),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
