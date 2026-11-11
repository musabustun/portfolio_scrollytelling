import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Reveal metninin tek kelimesi; `**kelime**` ile işaretlendiyse [emphasized].
///
/// [RevealText]'in iç modeli; testler [parseRevealWords] çıktısını okumak için görür.
@visibleForTesting
class RevealWord {
  const RevealWord(this.text, {this.emphasized = false});

  /// Yıldızları atılmış kelime (bitişik noktalama dahil).
  final String text;

  /// Dolunca `text` yerine `accent` olur.
  final bool emphasized;
}

/// `**x**` deseni; yıldızların dışındaki noktalama kelimeye geri eklenir ("**Flutter**," → "Flutter,").
final _emphasis = RegExp(r'^([^*]*)\*\*([^*]+)\*\*([^*]*)$');

/// Gövdeyi boşluklardan kelimelere böler; `**kelime**` vurgulu olur, yıldızlar atılır.
///
/// Vurgu tek kelimeliktir: `**iki kelime**` desteklenmez, yıldızlar olduğu gibi kalır.
List<RevealWord> parseRevealWords(String body) => [
  for (final token in body.trim().split(RegExp(r'\s+')))
    if (token.isNotEmpty) _parseToken(token),
];

RevealWord _parseToken(String token) {
  final match = _emphasis.firstMatch(token);
  if (match == null) return RevealWord(token);
  return RevealWord('${match[1]}${match[2]}${match[3]}', emphasized: true);
}

/// Kelimenin dolma hızı: her kelime kendi `1/n` diliminin 2/3'ünde tamamen dolar (AGENTS.md §10.5).
const double _revealSpeed = 1.5;

/// Kelime [index]'in dolma oranı 0..1: `clamp((progress − i/n) · n · 1.5, 0, 1)`.
double wordRevealAt({
  required double progress,
  required int index,
  required int count,
}) {
  if (count <= 0) return 0;
  final t = (progress - index / count) * count * _revealSpeed;
  return t.clamp(0.0, 1.0);
}

/// Kelime rengi: `textDim`'den `text`'e (vurguluysa [accent]'e) [wordRevealAt] oranında.
Color wordColorAt({
  required double progress,
  required int index,
  required int count,
  required bool emphasized,
  required Color accent,
}) {
  final t = wordRevealAt(progress: progress, index: index, count: count);
  return Color.lerp(
    AppColors.textDim,
    emphasized ? accent : AppColors.text,
    t,
  )!;
}

/// Text bölümü cümlesi: kelimeler `progress` ile soluktan dolar (AGENTS.md §10.5); tek `RichText`,
/// ortalı.
class RevealText extends StatelessWidget {
  const RevealText({required this.body, required this.progress, super.key});

  /// `**kelime**` işaretli olabilen düz metin (story.json `body`).
  final String body;

  /// Bölüm içi ilerleme 0..1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final words = parseRevealWords(body);
    final n = words.length;
    final accent = context.accent;
    final style = AppTextStyles.statement;
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < n; i++)
            TextSpan(
              text: i < n - 1 ? '${words[i].text} ' : words[i].text,
              style: style.copyWith(
                color: wordColorAt(
                  progress: progress,
                  index: i,
                  count: n,
                  emphasized: words[i].emphasized,
                  accent: accent,
                ),
              ),
            ),
        ],
      ),
      style: style,
      textAlign: TextAlign.center,
    );
  }
}
