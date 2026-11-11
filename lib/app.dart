import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'ai/chat_controller.dart';
import 'ai/chat_panel.dart';
import 'ai/persona_service.dart';
import 'stage/chapter_indicator.dart';
import 'stage/stage.dart';
import 'stage/track.dart';
import 'story/scroll_progress.dart';
import 'story/story.dart';
import 'story/story_loader.dart';
import 'theme/theme.dart';
import 'widgets/story_error_box.dart';

/// Kök kompozisyon: story yüklendiyse site, yoksa hata kutusu; ikisi de `_Scaled` içinde
/// (LayoutBuilder → ScreenUtilInit → MaterialApp). İş mantığı yok (AGENTS.md §11.1); story ve
/// persona `main.dart`'ta hazırlanıp buraya verilir.
class App extends StatelessWidget {
  const App({required this.story, this.persona, super.key});

  final StoryLoadResult story;

  /// Firebase bağlı değilse `null`; sohbet paneli o zaman "bağlı değil" kartını gösterir.
  final PersonaService? persona;

  @override
  Widget build(BuildContext context) => switch (story) {
    StoryLoaded(:final story) => _Site(story: story, persona: persona),
    StoryLoadFailed(:final message) => _Scaled(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: StoryErrorBox(message: message),
      ),
    ),
  };
}

/// Ölçek katmanı (AGENTS.md §11.3): genişliğe göre tasarım boyutu seçen `ScreenUtilInit`.
///
/// 720 eşiği geçilince `key` değişir ve [builder]'ın kurduğu ağaç baştan kurulur; korunacak durum
/// bu widget'ın üstünde yaşar.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return ScreenUtilInit(
        key: ValueKey<bool>(AppBreakpoints.isMobileWidth(width)),
        designSize: AppBreakpoints.designSizeFor(width),
        minTextAdapt: true,
        splitScreenMode: false,
        // .sp de .r gibi min(genişlik, yükseklik) ölçeğini kullansın; geniş-kısa pencerede
        // yazı pill'den taşmasın.
        fontSizeResolver: FontSizeResolvers.radius,
        builder: (context, _) => builder(context),
      );
    },
  );
}

/// Site katmanları (AGENTS.md §4): Sahne altta, Ray ortada şeffaf, üstte pill nav ve sohbet paneli.
///
/// Yalnızca [ScrollProgress], sohbet açık/kapalı notifier'ı ve [ChatController]'ın ömrünü tutar.
/// `_Scaled`'in üstünde durur: ekran 720 eşiğini geçip altındaki ağaç yeniden kurulunca bölüm
/// konumu, sohbetin açık/kapalı durumu ve mesajlar kaybolmaz.
class _Site extends StatefulWidget {
  const _Site({required this.story, required this.persona});

  final Story story;
  final PersonaService? persona;

  @override
  State<_Site> createState() => _SiteState();
}

class _SiteState extends State<_Site> {
  late final ScrollProgress _scrollProgress = ScrollProgress(
    scrollLengths: widget.story.scrollLengths,
  );
  final ValueNotifier<bool> _chatOpen = ValueNotifier(false);
  late final ChatController _chat = ChatController(ask: widget.persona?.ask);

  @override
  void dispose() {
    _scrollProgress.dispose();
    _chatOpen.dispose();
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Scaled(
    builder: (context) => MaterialApp(
      title: widget.story.meta.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        accent: widget.story.meta.accentColor,
        background: widget.story.meta.backgroundColor,
      ),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Stage(
              story: widget.story,
              scrollProgress: _scrollProgress,
              onOpenChat: () => _chatOpen.value = true,
            ),
            Track(scrollProgress: _scrollProgress),
            ChapterIndicator(
              story: widget.story,
              scrollProgress: _scrollProgress,
            ),
            ChatPanel(
              isOpen: _chatOpen,
              controller: _chat,
              owner: widget.story.meta.owner,
            ),
          ],
        ),
      ),
    ),
  );
}
