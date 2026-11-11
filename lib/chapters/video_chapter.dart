import 'package:flutter/widgets.dart';

import '../story/scroll_progress.dart';
import '../story/story.dart';
import '../theme/theme.dart';
import '../web/scrub_video_element.dart';
import '../widgets/gradient_scrim.dart';
import '../widgets/index_label.dart';
import '../widgets/label_text.dart';
import '../widgets/pill_button.dart';

/// Video bölümü (AGENTS.md §10.4–10.5): tam ekran scrub video, alt gradyan scrim, sol altta `at`
/// aralığında beliren kutusuz overlay'ler (başlıksız overlay büyük `overlayStatement` cümlesi);
/// kapakta ([isCover]) ilk overlay `eyebrow` selamlama + `display` başlık + `lead` gövde + iki pill.
///
/// Video scroll ile sürülür, oynatılmaz (AGENTS.md §5; tek istisna [ScrubVideoHandle]'daki iOS
/// kilidi). `<video>` elementi state yaşadıkça bir kez kurulur; scroll'da yalnızca overlay katmanı
/// rebuild olur. Mobilde bölümün dikey videosu
/// (`videoMobile`/`posterMobile`) varsa o, yoksa 16:9 video sağa kaydırılmış kırpmayla oynar.
/// Kaynak ve kırpma odağı (`AppSizes.videoObjectPositionFor`) kurulumda bir kez seçilir;
/// breakpoint değişince `ScreenUtilInit` anahtarı tüm ağacı yeniden kurduğu için handle da yeni
/// kaynak ve odakla yaratılır, `didUpdateWidget`'ta ek iş gerekmez.
/// "Hareketi azalt" açıkken (AGENTS.md §10.6) seek yapılmaz, video poster/ilk karede sabit kalır;
/// kaynak yine indirilir (kabul edilen sadelik).
class VideoChapter extends StatefulWidget {
  const VideoChapter({
    required this.chapter,
    required this.index,
    required this.scrollProgress,
    required this.meta,
    required this.isCover,
    required this.onContactTap,
    required this.onChatTap,
    super.key,
  });

  final Chapter chapter;

  /// Bölümün story içindeki 0 tabanlı sırası; etikette `index + 1` yazılır.
  final int index;
  final ScrollProgress scrollProgress;

  /// Kapak selamlaması (`tagline`) ve başlık yedeği (`owner`).
  final Meta meta;

  /// `true` ise ilk overlay kapak düzeninde çizilir (`chapters[0]`).
  final bool isCover;

  /// Kapaktaki dolu "İletişim" pill'i.
  final VoidCallback onContactTap;

  /// Kapaktaki çizgili "▸ Sohbet" pill'i.
  final VoidCallback onChatTap;

  @override
  State<VideoChapter> createState() => _VideoChapterState();
}

class _VideoChapterState extends State<VideoChapter> {
  late ScrubVideoHandle _handle;

  /// "Hareketi azalt" açık mı; `MediaQuery` değişince [didChangeDependencies] günceller.
  bool _reduceMotion = false;

  double get _progress => widget.scrollProgress.value.progressFor(widget.index);

  @override
  void initState() {
    super.initState();
    _handle = _createHandle();
    widget.scrollProgress.addListener(_seek);
    _seek();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppDurations.reduceMotionOf(context);
  }

  @override
  void didUpdateWidget(VideoChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollProgress != widget.scrollProgress) {
      oldWidget.scrollProgress.removeListener(_seek);
      widget.scrollProgress.addListener(_seek);
    }
    final old = oldWidget.chapter;
    final chapter = widget.chapter;
    if (old.video != chapter.video ||
        old.poster != chapter.poster ||
        old.videoMobile != chapter.videoMobile ||
        old.posterMobile != chapter.posterMobile) {
      _disposeHandle();
      _handle = _createHandle();
    }
    _seek();
  }

  @override
  void dispose() {
    widget.scrollProgress.removeListener(_seek);
    _disposeHandle();
    super.dispose();
  }

  /// Şema `video` bölümünde `video` ve `poster`'ı zorunlu tutar; ikisi de doludur, mobil seçim de
  /// en kötü ihtimalle onlara düşer.
  ScrubVideoHandle _createHandle() {
    final chapter = widget.chapter;
    final mobile = AppBreakpoints.isMobile;
    final handle = ScrubVideoHandle(
      src: chapter.videoFor(mobile: mobile)!,
      poster: chapter.posterFor(mobile: mobile)!,
      objectPosition: AppSizes.videoObjectPositionFor(
        hasMobileVideo: chapter.videoMobile != null,
      ),
    );
    handle.isReady.addListener(_seek);
    return handle;
  }

  void _disposeHandle() {
    _handle.isReady.removeListener(_seek);
    _handle.dispose();
  }

  /// Videoyu bölümün güncel ilerlemesine konumlar; metadata gelmeden handle no-op'tur.
  /// Hareket azaltılmışsa hiç konumlamaz.
  void _seek() {
    if (_reduceMotion) return;
    _handle.seekTo(_progress);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        color: context.bg,
        // Ekran okuyucu videoyu bölüm başlığıyla görsel olarak okur; dekoratif değildir.
        child: Semantics(
          label: AppStrings.videoLabelFor(widget.chapter.title),
          image: true,
          // Tekerlek ve sürükleme Ray'a aittir; video hiçbir işaretçi olayı almaz.
          child: IgnorePointer(
            child: HtmlElementView(viewType: _handle.viewType),
          ),
        ),
      ),
      const ExcludeSemantics(child: GradientScrim()),
      ListenableBuilder(
        listenable: widget.scrollProgress,
        builder: (context, _) => _OverlayLayer(
          chapter: widget.chapter,
          index: widget.index,
          progress: _progress,
          meta: widget.meta,
          isCover: widget.isCover,
          onContactTap: widget.onContactTap,
          onChatTap: widget.onChatTap,
        ),
      ),
    ],
  );
}

/// Sol alttaki overlay yığını; opaklık ve yükselme `progress`'ten doğrudan çizilir (tween yok).
///
/// Her overlay kendi maksimum genişliğini alır ([_overlayMaxWidth]): başlıksız cümle
/// `overlayStatementMaxWidth`, kapak ve başlıklı overlay `overlayMaxWidth`.
/// Opaklığı 0 olan overlay hiç kurulmaz; görünmez bir pill tıklanabilir kalmaz.
class _OverlayLayer extends StatelessWidget {
  const _OverlayLayer({
    required this.chapter,
    required this.index,
    required this.progress,
    required this.meta,
    required this.isCover,
    required this.onContactTap,
    required this.onChatTap,
  });

  final Chapter chapter;
  final int index;
  final double progress;
  final Meta meta;
  final bool isCover;
  final VoidCallback onContactTap;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) {
    final overlays = chapter.overlays;
    return Positioned(
      left: AppSpacing.gutter,
      right: AppSpacing.gutter,
      bottom: AppSpacing.gutter,
      // Align ve Stack gevşek kısıt verir; böylece her overlay'in maxWidth'i Positioned'ın sıkı
      // genişliğini daraltabilir.
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Stack(
          alignment: AlignmentDirectional.bottomStart,
          children: [
            for (var i = 0; i < overlays.length; i++)
              if (overlays[i].opacityAt(progress) case final opacity
                  when opacity > 0)
                ConstrainedBox(
                  key: ValueKey<int>(i),
                  constraints: BoxConstraints(
                    maxWidth: _overlayMaxWidth(
                      overlays[i],
                      cover: isCover && i == 0,
                    ),
                  ),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, AppSizes.overlayRise * (1 - opacity)),
                      child: isCover && i == 0
                          ? _CoverOverlay(
                              overlay: overlays[i],
                              meta: meta,
                              onContactTap: onContactTap,
                              onChatTap: onChatTap,
                            )
                          : _TextOverlayView(
                              overlay: overlays[i],
                              index: index,
                              chapterTitle: chapter.title,
                            ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Başlıksız, gövdeli overlay: büyük `overlayStatement` cümlesi olarak çizilir.
bool _isStatement(TextOverlay overlay) =>
    overlay.title == null && overlay.body != null;

/// Overlay'in maksimum genişliği; kapak overlay'i ([cover]) her durumda `overlayMaxWidth`'te kalır.
double _overlayMaxWidth(TextOverlay overlay, {required bool cover}) =>
    !cover && _isStatement(overlay)
    ? AppSizes.overlayStatementMaxWidth
    : AppSizes.overlayMaxWidth;

/// Standart overlay, kutusuz (AGENTS.md §10.4): başlık varsa "02 · İŞLER" etiketi + `h1` başlık +
/// `textMuted` `body` gövde; başlıksızsa etiketsiz, gövde tek başına büyük `overlayStatement`
/// cümlesi (`text`). Etiket bölümde yalnızca başlıklı overlay'de görünür, her cümlede tekrarlanmaz.
class _TextOverlayView extends StatelessWidget {
  const _TextOverlayView({
    required this.overlay,
    required this.index,
    required this.chapterTitle,
  });

  final TextOverlay overlay;
  final int index;
  final String chapterTitle;

  @override
  Widget build(BuildContext context) {
    final statement = _isStatement(overlay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!statement) IndexLabel(index: index + 1, text: chapterTitle),
        if (overlay.title case final title?) ...[
          SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.h1),
        ],
        if (overlay.body case final body?) ...[
          if (!statement) SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: statement
                ? AppTextStyles.overlayStatement
                : AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Kapak overlay'i (AGENTS.md §10.4 kapak istisnası): `accent` renkli BÜYÜK HARF `eyebrow`
/// selamlama, `display` başlık, `lead` gövde (`text`) ve iki pill.
class _CoverOverlay extends StatelessWidget {
  const _CoverOverlay({
    required this.overlay,
    required this.meta,
    required this.onContactTap,
    required this.onChatTap,
  });

  final TextOverlay overlay;
  final Meta meta;
  final VoidCallback onContactTap;
  final VoidCallback onChatTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        upperTr(meta.tagline),
        style: AppTextStyles.eyebrow.copyWith(color: context.accent),
      ),
      SizedBox(height: AppSpacing.sm),
      Text(overlay.title ?? meta.owner, style: AppTextStyles.display),
      if (overlay.body case final body?) ...[
        SizedBox(height: AppSpacing.sm),
        Text(body, style: AppTextStyles.lead),
      ],
      SizedBox(height: AppSpacing.md),
      // Pill'ler Ray'ın altındadır; Ray translucent olduğu için tıklama buraya geçer
      // (AGENTS.md §4).
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            label: AppStrings.contact,
            filled: true,
            onTap: onContactTap,
          ),
          SizedBox(width: AppSpacing.xs),
          PillButton(label: AppStrings.chat, onTap: onChatTap),
        ],
      ),
    ],
  );
}
