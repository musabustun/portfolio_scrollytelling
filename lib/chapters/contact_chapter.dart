import 'package:flutter/widgets.dart';

import '../story/story.dart';
import '../theme/theme.dart';
import '../widgets/label_text.dart';
import '../widgets/pill_button.dart';
import '../widgets/tap_target.dart';

/// E-posta linkinin şeması; büyük harfli yazım da (`MAILTO:`) tanınır.
const String _mailto = 'mailto:';

/// İletişim `body`'sini dev başlığa ve detay satırına böler (saf fonksiyon).
///
/// `body` boş ya da `null` ise başlık [fallback] (bölüm başlığı), detay yok. Değilse ilk satır
/// (`\n`'e kadar) başlık, kalanı detay; detay kırpılır, boş kalırsa `null`.
({String headline, String? detail}) splitContactBody(
  String? body, {
  required String fallback,
}) {
  final text = body?.trim() ?? '';
  if (text.isEmpty) return (headline: fallback, detail: null);
  final newline = text.indexOf('\n');
  if (newline < 0) return (headline: text, detail: null);
  final detail = text.substring(newline + 1).trim();
  return (
    headline: text.substring(0, newline).trim(),
    detail: detail.isEmpty ? null : detail,
  );
}

/// Kapanış bölümü (AGENTS.md §10.5 `contact`): `paper` zeminde sola yaslı dev çağrı cümlesi, altında
/// tıklanabilir büyük e-posta ve diğer linkler; altta tek satır footer.
///
/// `body`'nin ilk satırı `display` başlık, kalanı `lead` detay ([splitContactBody]). `links`'teki ilk
/// `mailto:` linki `accent` renkli büyük adres olarak, diğerleri çizgili pill olarak çizilir. Footer:
/// `border` üst çizgi, solda "SAHİP · YIL", sağda "YUKARI ↑". Tarayıcıya dokunmaz:
/// linkler [openUrl], başa dönüş [onBackToTop] ile dışarı verilir.
class ContactChapter extends StatelessWidget {
  const ContactChapter({
    required this.chapter,
    required this.meta,
    required this.openUrl,
    required this.onBackToTop,
    super.key,
  });

  final Chapter chapter;
  final Meta meta;

  /// E-posta ya da link pill'i tıklanınca linkin `url`'i ile çağrılır.
  final void Function(String url) openUrl;

  /// "YUKARI ↑" tıklanınca çağrılır (Stage: `animateToChapter(0)`).
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.paper,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _ContactBody(chapter: chapter, openUrl: openUrl),
        ),
        _Footer(owner: meta.owner, onBackToTop: onBackToTop),
      ],
    ),
  );
}

/// Üst bölüm: nav'ın altından başlar, sola yaslı ve dikeyde ortalı; etiket, dev başlık, detay,
/// büyük e-posta ve link pill'leri.
class _ContactBody extends StatelessWidget {
  const _ContactBody({required this.chapter, required this.openUrl});

  final Chapter chapter;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) {
    final text = splitContactBody(chapter.body, fallback: chapter.title);
    final detail = text.detail;
    final email = _emailLinkOf(chapter.links);
    final others = [
      for (final link in chapter.links)
        if (!identical(link, email)) link,
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSizes.navHeight + 2 * AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabelText(chapter.title),
              SizedBox(height: AppSpacing.md),
              Text(text.headline, style: AppTextStyles.display),
              if (detail != null) ...[
                SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppSizes.overlayStatementMaxWidth,
                  ),
                  child: Text(
                    detail,
                    style: AppTextStyles.lead.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
              if (email != null || others.isNotEmpty)
                SizedBox(height: AppSpacing.xl),
              if (email != null) _EmailLink(link: email, openUrl: openUrl),
              if (email != null && others.isNotEmpty)
                SizedBox(height: AppSpacing.lg),
              if (others.isNotEmpty)
                _LinkPills(links: others, openUrl: openUrl),
            ],
          ),
        ),
      ),
    );
  }
}

/// `url`'i `mailto:` ile başlayan ilk link; yoksa `null`.
ContactLink? _emailLinkOf(List<ContactLink> links) {
  for (final link in links) {
    if (link.url.toLowerCase().startsWith(_mailto)) return link;
  }
  return null;
}

/// Büyük e-posta: `mailto:` sonrası adres (`?` sonrası atılır) + ok, `statement` stilinde `accent`.
///
/// Tek satır; dar ekranda `FittedBox` ile küçülür. Ekran okuyucu linkin `label`'ını okur. Hover yok.
class _EmailLink extends StatelessWidget {
  const _EmailLink({required this.link, required this.openUrl});

  final ContactLink link;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) {
    final address = link.url.substring(_mailto.length).split('?').first;
    return TapTarget(
      label: link.label,
      onTap: () => openUrl(link.url),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '$address →',
          style: AppTextStyles.statement.copyWith(color: context.accent),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}

/// E-posta dışındaki linkler: oklu çizgili pill'ler, sığmayan alt satıra geçer.
class _LinkPills extends StatelessWidget {
  const _LinkPills({required this.links, required this.openUrl});

  final List<ContactLink> links;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final link in links)
        PillButton(
          label: link.label,
          arrow: true,
          onTap: () => openUrl(link.url),
        ),
    ],
  );
}

/// Footer: `border` üst çizgi, tek satır; solda "SAHİP · YIL", sağda "YUKARI ↑".
class _Footer extends StatelessWidget {
  const _Footer({required this.owner, required this.onBackToTop});

  final String owner;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: LabelText('$owner · ${DateTime.now().year}')),
          _BackToTop(onTap: onBackToTop),
        ],
      ),
    ),
  );
}

/// "YUKARI ↑" metin butonu: `text` renkli `label`, tıklama imleci; dikey boşluk dokunma alanını büyütür.
///
/// Ekran okuyucu görünen yazıyı (Türkçe BÜYÜK HARF) okur.
class _BackToTop extends StatelessWidget {
  const _BackToTop({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TapTarget(
    label: upperTr(AppStrings.backToTop),
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: const LabelText(AppStrings.backToTop, color: AppColors.text),
    ),
  );
}
