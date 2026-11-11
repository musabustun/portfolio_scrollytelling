import 'dart:async';

import 'package:flutter/widgets.dart';

import '../chapters/contact_chapter.dart';
import '../chapters/projects_chapter.dart';
import '../chapters/text_chapter.dart';
import '../chapters/video_chapter.dart';
import '../story/scroll_progress.dart';
import '../story/story.dart';
import '../theme/theme.dart';
import '../web/browser.dart';

/// Sahne: viewport boyutunda sabit katman; aktif bölümü ve preload için sıradakini çizer (AGENTS.md §4).
///
/// Yalnızca bölüm değişince rebuild olur, progress değişince olmaz. Aynı anda en fazla 2 bölüm
/// monte edilir: durulmuşken aktif + sıradaki, crossfade sırasında çıkan + giren. Her bölüm kendi
/// `GlobalKey`'i ile sarılır; preload edilen bölüm aktif olunca aynı karede taşınır, yeniden monte
/// edilmez (`<video>` elementi ve `VideoChapter` state'i korunur).
class Stage extends StatefulWidget {
  const Stage({
    required this.story,
    required this.scrollProgress,
    required this.onOpenChat,
    super.key,
  });

  final Story story;
  final ScrollProgress scrollProgress;

  /// Kapaktaki "▸ Sohbet" pill'i; sohbet panelini açar.
  final VoidCallback onOpenChat;

  @override
  State<Stage> createState() => _StageState();
}

class _StageState extends State<Stage> {
  int _active = 0;

  /// Crossfade bitti mi; bitene kadar sıradaki bölüm preload edilmez.
  bool _settled = true;
  Timer? _timer;

  /// Bölüm id → anahtar; preload yuvası ve `AnimatedSwitcher` aynı anahtarı kullanır.
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'chapter-$id'));

  @override
  void initState() {
    super.initState();
    _active = widget.scrollProgress.value.chapterIndex;
    widget.scrollProgress.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollProgress != widget.scrollProgress) {
      oldWidget.scrollProgress.removeListener(_onScroll);
      widget.scrollProgress.addListener(_onScroll);
      _active = widget.scrollProgress.value.chapterIndex;
    }
  }

  @override
  void dispose() {
    widget.scrollProgress.removeListener(_onScroll);
    _timer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final index = widget.scrollProgress.value.chapterIndex;
    if (index == _active) return;
    setState(() {
      _active = index;
      _settled = false;
    });
    _timer?.cancel();
    _timer = Timer(AppDurations.crossfadeOf(context), _settle);
  }

  void _settle() {
    if (mounted) setState(() => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = widget.story.chapters;
    final next = _active + 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Durulmuşken var; bölüm değiştiği karede kalkar, böylece anahtar iki yerde birden olmaz.
        if (_settled && next < chapters.length)
          IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: KeyedSubtree(
                key: _keyFor(chapters[next].id),
                child: _chapterWidget(next),
              ),
            ),
          ),
        AnimatedSwitcher(
          duration: AppDurations.crossfadeOf(context),
          switchInCurve: AppDurations.crossfadeCurve,
          switchOutCurve: AppDurations.crossfadeCurve,
          layoutBuilder: _layoutSwitcher,
          child: KeyedSubtree(
            key: _keyFor(chapters[_active].id),
            child: _chapterWidget(_active),
          ),
        ),
      ],
    );
  }

  /// Hızlı kaydırmada `AnimatedSwitcher` birden çok çıkan bölüm biriktirir; yalnızca en sonuncusu
  /// tutulur. Durulunca (timer, animasyonun son karesinden önce bitebilir) o da bırakılır; giren
  /// bölüm o anda opak olduğu için görünmez. Böylece preload ile birlikte sınır 2 bölüm aşılmaz;
  /// dışarıda kalan çıkış kayıtları ağaçta olmadığı için `GlobalKey` çakışması da olmaz.
  Widget _layoutSwitcher(Widget? current, List<Widget> previous) => Stack(
    fit: StackFit.expand,
    children: [if (!_settled && previous.isNotEmpty) previous.last, ?current],
  );

  /// Bölüm türüne göre gerçek widget; tarayıcı ve sohbet eylemleri callback olarak verilir.
  Widget _chapterWidget(int index) {
    final story = widget.story;
    final chapter = story.chapters[index];
    final scrollProgress = widget.scrollProgress;
    return switch (chapter.type) {
      ChapterType.video => VideoChapter(
        chapter: chapter,
        index: index,
        scrollProgress: scrollProgress,
        meta: story.meta,
        isCover: index == 0,
        onContactTap: () =>
            scrollProgress.animateToChapter(story.chapters.length - 1),
        onChatTap: widget.onOpenChat,
      ),
      ChapterType.text => TextChapter(
        chapter: chapter,
        index: index,
        scrollProgress: scrollProgress,
      ),
      ChapterType.projects => ProjectsChapter(
        chapter: chapter,
        index: index,
        scrollProgress: scrollProgress,
        openUrl: openExternal,
      ),
      ChapterType.contact => ContactChapter(
        chapter: chapter,
        meta: story.meta,
        openUrl: openExternal,
        onBackToTop: () => scrollProgress.animateToChapter(0),
      ),
    };
  }
}
