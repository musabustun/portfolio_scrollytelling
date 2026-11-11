import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../story/scroll_progress.dart';
import '../story/story.dart';
import '../theme/theme.dart';
import '../widgets/index_label.dart';
import '../widgets/label_text.dart';
import '../widgets/pill_button.dart';
import '../widgets/step_counter.dart';
import '../widgets/tap_target.dart';

/// Aktif proje indeksi (AGENTS.md §10.5): `min(floor(progress · count), count − 1)`.
///
/// `count ≤ 0`, negatif ya da NaN `progress` → 0.
int activeProjectIndex({required double progress, required int count}) {
  if (count <= 0 || !(progress > 0)) return 0;
  return math.min((progress * count).floor(), count - 1);
}

/// Geçiş payı: panelin diliminin son çeyreğinde panel kapanırken sıradaki açılır.
const double _blend = 0.25;

/// Panel [index]'in açıklığı, 0 (kapalı) .. 1 (tam açık); her [progress]'te bütün panellerin
/// toplamı 1'dir.
///
/// `p = progress · count`; panel `i`'nin dilimi `[i, i+1)`. Dilimin son [_blend] payında `i` 1→0,
/// `i+1` 0→1 doğrusal geçer, onun dışında aktif panel 1, diğerleri 0. Son panel `progress = 1`'de
/// açık kalır. `count ≤ 0`, negatif ya da NaN `progress` → ilk panel 1, diğerleri 0.
double panelOpenness({
  required double progress,
  required int index,
  required int count,
}) {
  if (count <= 0 || !(progress > 0)) return index == 0 ? 1 : 0;
  final p = math.min(progress, 1.0) * count;
  final active = math.min(p.floor(), count - 1);
  final next = active < count - 1
      ? ((p - active - (1 - _blend)) / _blend).clamp(0.0, 1.0)
      : 0.0;
  if (index == active) return 1 - next;
  if (index == active + 1) return next;
  return 0;
}

/// Masaüstünde panel genişliği oranı: kapalı panel 1, tam açık panel 7 pay (`Expanded.flex`).
const double _collapsedWeight = 1.0;
const double _expandedWeight = 7.0;

/// `Expanded.flex` tam sayı ister; kesirli pay bu ölçekle tam sayıya çevrilir.
const double _flexScale = 1000;

/// Açık yüz bu açıklığın altında tıklanmaz: yarı saydam, kırpılmış link tıklanmasın.
const double _interactiveOpenness = 0.5;

/// Bu sayıdan fazla `links` öğesi olan projede linkler 44 px pill olmaz: masaüstünde iki sütunlu
/// link satırları ([_LinkRow]), mobilde tag boyutunda (28 px) mini pill'ler ([_LinkTag]).
const int _compactLinkThreshold = 3;

/// Projeler bölümü (AGENTS.md §10.5): bütün projeler `paper` üstünde yan yana (mobilde alt alta)
/// `surface` paneller.
///
/// Kaydırdıkça sıradaki panel genişleyip (mobilde uzayıp) içeriğini açar, diğerleri dar kalır
/// ([panelOpenness]). Animasyon ve zamanlayıcı yok: her şey bölüm `progress`'inden doğrudan çizilir.
/// Kapalı panel numara ve adı gösterir. Açık panel masaüstünde yüksekliğin tamamını kullanır
/// ([_DesktopOpenFace]): üstte kimlik, ortada öne çıkanlar ya da link satırları, altta tag'ler ve
/// eylem pill'leri; mobilde ([_MobileOpenFace]) "01 · PROJE", ad, açıklama, tag'ler ve link pill'leri
/// alt alta. Proje bağlantıları tarayıcıya dokunmaz, [openUrl] ile dışarı verilir. Altta adım sayacı.
class ProjectsChapter extends StatelessWidget {
  const ProjectsChapter({
    required this.chapter,
    required this.index,
    required this.scrollProgress,
    required this.openUrl,
    super.key,
  });

  final Chapter chapter;
  final int index;
  final ScrollProgress scrollProgress;

  /// "Projeyi aç →" tıklanınca projenin `url`'i ile, bir `links` pill'i tıklanınca o linkin `url`'i
  /// ile çağrılır.
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.paper,
    child: ListenableBuilder(
      listenable: scrollProgress,
      builder: (context, _) {
        final projects = chapter.projects;
        if (projects.isEmpty) return const SizedBox.shrink();
        final progress = scrollProgress.value.progressFor(index);
        final count = projects.length;
        final openness = [
          for (var i = 0; i < count; i++)
            panelOpenness(progress: progress, index: i, count: count),
        ];
        final mobile = AppBreakpoints.isMobile;
        final gutter = AppSpacing.gutter;
        // Masaüstünde paneller nav'ın altında başlar. Mobilde nav yok; sağ üstteki sohbet pill'i
        // (gutter + buton yüksekliği) ilk panele binmesin diye paneller onun altında başlar.
        final top = mobile
            ? AppSpacing.gutter + AppSizes.buttonHeight + AppSpacing.md
            : AppSizes.navHeight + 2 * AppSpacing.md;
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, top, gutter, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: mobile
                    ? _PanelColumn(
                        projects: projects,
                        openness: openness,
                        openUrl: openUrl,
                      )
                    : _PanelRow(
                        projects: projects,
                        openness: openness,
                        openUrl: openUrl,
                      ),
              ),
              SizedBox(height: AppSpacing.md),
              StepCounter(
                current:
                    activeProjectIndex(progress: progress, count: count) + 1,
                total: count,
                progress: progress,
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Masaüstü: paneller yan yana; genişlik `Expanded.flex` ile açıklıktan, kapalı 1 pay, açık 7 pay.
class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.projects,
    required this.openness,
    required this.openUrl,
  });

  final List<Project> projects;

  /// Panel sırasıyla [panelOpenness] değerleri.
  final List<double> openness;
  final void Function(String url) openUrl;

  static int _flexFor(double openness) =>
      ((_collapsedWeight + openness * (_expandedWeight - _collapsedWeight)) *
              _flexScale)
          .round();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = AppSpacing.xs;
      final count = projects.length;
      final panelsWidth = math.max(
        0.0,
        constraints.maxWidth - gap * (count - 1),
      );
      final openWidth =
          panelsWidth *
          _expandedWeight /
          ((count - 1) * _collapsedWeight + _expandedWeight);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, project) in projects.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              flex: _flexFor(openness[i]),
              child: _ProjectPanel(
                project: project,
                number: i + 1,
                openness: openness[i],
                openUrl: openUrl,
                openWidth: openWidth,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Mobil: paneller alt alta, sohbet pill'inin altından başlar; kapalı panel
/// `projectPanelCollapsedHeight`, tam açık panel kalan yüksekliğin tamamı, arası açıklıkla doğrusal.
class _PanelColumn extends StatelessWidget {
  const _PanelColumn({
    required this.projects,
    required this.openness,
    required this.openUrl,
  });

  final List<Project> projects;

  /// Panel sırasıyla [panelOpenness] değerleri.
  final List<double> openness;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final gap = AppSpacing.xs;
      final count = projects.length;
      final collapsed = AppSizes.projectPanelCollapsedHeight;
      final openHeight = math.max(
        collapsed,
        constraints.maxHeight - (gap + collapsed) * (count - 1),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, project) in projects.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            SizedBox(
              height: collapsed + openness[i] * (openHeight - collapsed),
              child: _ProjectPanel(
                project: project,
                number: i + 1,
                openness: openness[i],
                openUrl: openUrl,
                openHeight: openHeight,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Tek proje paneli: `surface` kutu, `border` kenarlık, köşe `panel`; içeriği kırpar.
///
/// Kapalı yüz (`1 − openness` opaklık) ile açık yüz (`openness` opaklık) üst üste durur; opaklığı 0
/// olan yüz kurulmaz. Açık yüz yarıdan az açıkken tıklanmaz.
class _ProjectPanel extends StatelessWidget {
  const _ProjectPanel({
    required this.project,
    required this.number,
    required this.openness,
    required this.openUrl,
    this.openWidth,
    this.openHeight,
  });

  final Project project;

  /// 1 tabanlı proje sırası.
  final int number;
  final double openness;
  final void Function(String url) openUrl;

  /// Tam açık panelin dış genişliği (masaüstü) ya da yüksekliği (mobil); açık yüz bu ölçüde dizilir.
  /// `null` olan eksen panelin o anki ölçüsünü kullanır.
  final double? openWidth;
  final double? openHeight;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.panel,
      border: Border.all(color: AppColors.border, width: AppSizes.borderWidth),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (openness < 1)
          Opacity(
            opacity: 1 - openness,
            child: _ClosedFace(name: project.name, number: number),
          ),
        if (openness > 0)
          IgnorePointer(
            ignoring: openness < _interactiveOpenness,
            child: Opacity(
              opacity: openness,
              child: _OpenFace(
                project: project,
                number: number,
                openUrl: openUrl,
                openWidth: openWidth,
                openHeight: openHeight,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Kapalı panel yüzü. Masaüstü: üstte `accent` numara, altta dikey (aşağıdan yukarı) ad, `statement`
/// stilinde `textMuted`. Mobil: kapalı yükseklikte tek satır, numara + `body` ad, dikey ortalı.
/// İkisinde de ad tek satırdır, sığmazsa solar.
class _ClosedFace extends StatelessWidget {
  const _ClosedFace({required this.name, required this.number});

  final String name;

  /// 1 tabanlı proje sırası.
  final int number;

  @override
  Widget build(BuildContext context) {
    final numberLabel = LabelText(twoDigits(number), color: context.accent);
    if (AppBreakpoints.isMobile) {
      return Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height:
              AppSizes.projectPanelCollapsedHeight - 2 * AppSizes.borderWidth,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                numberLabel,
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.body,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          numberLabel,
          SizedBox(height: AppSpacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  name,
                  style: AppTextStyles.statement.copyWith(
                    color: AppColors.textMuted,
                  ),
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Açık panel yüzü: masaüstünde [_DesktopOpenFace], mobilde [_MobileOpenFace]; her zaman tam açık
/// panelin iç ölçüsünde dizilir. Panel genişlerken (mobilde uzarken) metin yeniden sarılmaz, iç
/// boşluğun dışı kırpılır.
///
/// İç boşluk masaüstünde `lg`, mobilde `sm`: dar ekranda metne ve link satırlarına yer kalır.
class _OpenFace extends StatelessWidget {
  const _OpenFace({
    required this.project,
    required this.number,
    required this.openUrl,
    this.openWidth,
    this.openHeight,
  });

  final Project project;
  final int number;
  final void Function(String url) openUrl;

  /// [_ProjectPanel.openWidth] / [_ProjectPanel.openHeight]: tam açık panelin dış ölçüsü.
  final double? openWidth;
  final double? openHeight;

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.isMobile ? AppSpacing.sm : AppSpacing.lg;
    final inset = 2 * (AppSizes.borderWidth + padding);
    final width = openWidth;
    final height = openHeight;
    final innerWidth = width == null ? null : math.max(0.0, width - inset);
    final innerHeight = height == null ? null : math.max(0.0, height - inset);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: innerWidth,
          maxWidth: innerWidth,
          minHeight: innerHeight,
          maxHeight: innerHeight,
          child: AppBreakpoints.isMobile
              ? _MobileOpenFace(
                  project: project,
                  number: number,
                  openUrl: openUrl,
                )
              : _DesktopOpenFace(
                  project: project,
                  number: number,
                  openUrl: openUrl,
                ),
        ),
      ),
    );
  }
}

/// Masaüstü açık yüz: üç bölge panelin iç yüksekliğine yayılır, aralarında en az `lg` boşluk.
///
/// Üstte "01 · PROJE", ad ve `lead` açıklama ([_DesktopHeader]). Ortada, alta yaslı: `links`
/// [_compactLinkThreshold]'tan uzunsa [_LinkGrid], değilse varsa `highlights` ([_HighlightRow]);
/// ikisi de yoksa orta boş. Altta [_ActionStrip]: tag'ler ve eylem pill'leri ("Projeyi aç →", link
/// satırı çizilmediyse her `links` öğesi).
class _DesktopOpenFace extends StatelessWidget {
  const _DesktopOpenFace({
    required this.project,
    required this.number,
    required this.openUrl,
  });

  final Project project;
  final int number;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) {
    final url = project.url;
    final linkRows = project.links.length > _compactLinkThreshold;
    final actions = [
      if (url != null && url.trim().isNotEmpty)
        ContactLink(label: AppStrings.openProject, url: url),
      if (!linkRows) ...project.links,
    ];
    final highlights = project.highlights;
    final Widget? middle = linkRows
        ? _LinkGrid(links: project.links, openUrl: openUrl)
        : highlights.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, text) in highlights.indexed)
                _HighlightRow(number: i + 1, text: text),
            ],
          );
    final gap = EdgeInsets.only(top: AppSpacing.lg);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DesktopHeader(project: project, number: number),
        if (middle != null)
          // Flexible + Align: orta bölge kalan yüksekliği alır, içeriği alt şeridin hemen üstünde.
          Flexible(
            child: Padding(
              padding: gap,
              child: Align(alignment: Alignment.bottomLeft, child: middle),
            ),
          ),
        if (project.tags.isNotEmpty || actions.isNotEmpty)
          Padding(
            padding: gap,
            child: _ActionStrip(
              tags: project.tags,
              actions: actions,
              openUrl: openUrl,
            ),
          ),
      ],
    );
  }
}

/// Masaüstü açık yüzün üst bölgesi: "01 · PROJE", `h1` ad, `lead` açıklama (`textMuted`, en fazla
/// `overlayStatementMaxWidth` genişlikte, sola yaslı).
class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.project, required this.number});

  final Project project;
  final int number;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IndexLabel(index: number, text: AppStrings.projectLabel),
      SizedBox(height: AppSpacing.md),
      Text(project.name, style: AppTextStyles.h1),
      SizedBox(height: AppSpacing.sm),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSizes.overlayStatementMaxWidth,
        ),
        child: Text(
          project.description,
          style: AppTextStyles.lead.copyWith(color: AppColors.textMuted),
        ),
      ),
    ],
  );
}

/// Masaüstü alt şeridi: solda tag'ler, sağda eylem pill'leri ([actions] sırasıyla, ilki dolu);
/// aralarında en az `lg`. Tag yoksa pill'ler yine sağda durur.
class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.tags,
    required this.actions,
    required this.openUrl,
  });

  final List<String> tags;

  /// Eylem pill'lerinin etiketi ve hedefi; boşsa sağ taraf kurulmaz.
  final List<ContactLink> actions;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Flexible(
        child: tags.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: EdgeInsetsDirectional.only(end: AppSpacing.lg),
                child: _TagWrap(tags),
              ),
      ),
      if (actions.isNotEmpty)
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (i, action) in actions.indexed)
              PillButton(
                label: action.label,
                arrow: true,
                filled: i == 0,
                onTap: () => openUrl(action.url),
              ),
          ],
        ),
    ],
  );
}

/// İki sütunlu link satırları: linkler sırayla sol, sağ, sol… dağıtılır; sütunlar arası `lg`.
class _LinkGrid extends StatelessWidget {
  const _LinkGrid({required this.links, required this.openUrl});

  final List<ContactLink> links;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final column in [0, 1]) ...[
        if (column > 0) SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, link) in links.indexed)
                if (i % 2 == column)
                  _LinkRow(label: link.label, onTap: () => openUrl(link.url)),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Öne çıkan madde satırı: solda `accent` iki haneli sıra numarası (sabit `xl` genişlik), sağda
/// `lead` metin.
class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.number, required this.text});

  /// 1 tabanlı madde sırası.
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => _RuledRow(
    children: [
      SizedBox(
        width: AppSpacing.xl,
        child: LabelText(twoDigits(number), color: context.accent),
      ),
      Expanded(child: Text(text, style: AppTextStyles.lead)),
    ],
  );
}

/// Tıklanabilir link satırı: solda `lead` etiket (tek satır), sağda `accent` ok; hover rengi yok.
///
/// Ekran okuyucu yalnızca [label]'ı okur (ok semantics'e girmez).
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.lead;
    return TapTarget(
      label: label,
      onTap: onTap,
      child: _RuledRow(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('→', style: style.copyWith(color: context.accent)),
        ],
      ),
    );
  }
}

/// Üstte `border` çizgili, dikeyde `sm` iç boşluklu satır; çocuklar taban çizgisinde hizalı.
/// [_HighlightRow] ve [_LinkRow]'un ortak çerçevesi.
class _RuledRow extends StatelessWidget {
  const _RuledRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: children,
      ),
    ),
  );
}

/// Mobil açık yüz: "01 · PROJE", ad, açıklama, tag'ler ve varsa link pill'leri alt alta: önce `url`
/// için "Projeyi aç →", sonra her `links` öğesi için etiketli pill; ikisi de yoksa ne pill ne boşluk.
/// `links` [_compactLinkThreshold]'tan uzunsa linkler [_LinkTag] (28 px) olur, "Projeyi aç →" yine
/// 44 px pill kalır; link satırları az yer kaplar, açıklamaya yer kalır. `highlights` çizilmez.
class _MobileOpenFace extends StatelessWidget {
  const _MobileOpenFace({
    required this.project,
    required this.number,
    required this.openUrl,
  });

  final Project project;
  final int number;
  final void Function(String url) openUrl;

  @override
  Widget build(BuildContext context) {
    final url = project.url;
    final compact = project.links.length > _compactLinkThreshold;
    final linkButtons = [
      if (url != null && url.trim().isNotEmpty)
        PillButton(
          label: AppStrings.openProject,
          arrow: true,
          onTap: () => openUrl(url),
        ),
      for (final link in project.links)
        compact
            ? _LinkTag(label: link.label, onTap: () => openUrl(link.url))
            : PillButton(
                label: link.label,
                arrow: true,
                onTap: () => openUrl(link.url),
              ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IndexLabel(index: number, text: AppStrings.projectLabel),
        SizedBox(height: AppSpacing.md),
        Text(project.name, style: AppTextStyles.h1),
        SizedBox(height: AppSpacing.sm),
        // Flexible: dar ekranda uzun açıklama taşma hatası yerine kırpılır.
        Flexible(
          child: Text(
            project.description,
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ),
        if (project.tags.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md),
          _TagWrap(project.tags),
        ],
        if (linkButtons.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            // Kompakt modda 44 px "Projeyi aç" ile 28 px linkler aynı satırda ortalanır.
            crossAxisAlignment: WrapCrossAlignment.center,
            children: linkButtons,
          ),
        ],
      ],
    );
  }
}

/// Projenin tag'leri: [_Tag]'ler `xs` aralıkla yan yana, sığmazsa alt satıra.
class _TagWrap extends StatelessWidget {
  const _TagWrap(this.tags);

  final List<String> tags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [for (final tag in tags) _Tag(tag)],
  );
}

/// Çizgili mini pill (yükseklik 28) içinde `label` stilinde tag; [_LinkTag]'in de görünümü.
class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color});

  final String text;

  /// Verilmezse `label` stilinin rengi (`textMuted`); link için `text`.
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.tagHeight,
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      borderRadius: AppRadii.pill,
      border: Border.all(color: AppColors.border, width: AppSizes.borderWidth),
    ),
    // `alignment` yerine `Center(widthFactor: 1)`: Wrap içinde tag tam satıra yayılmaz.
    child: Center(widthFactor: 1, child: LabelText(text, color: color)),
  );
}

/// Tıklanabilir kompakt link: [_Tag] görünümünde, `text` renginde "ETİKET →"; hover rengi yok.
///
/// Ekran okuyucu yalnızca [label]'ı okur (ok ve büyük harf semantics'e girmez).
class _LinkTag extends StatelessWidget {
  const _LinkTag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TapTarget(
    label: label,
    onTap: onTap,
    child: _Tag('$label →', color: AppColors.text),
  );
}
