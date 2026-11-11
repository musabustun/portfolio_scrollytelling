import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../story/scroll_progress.dart';
import '../theme/theme.dart';

/// Ray: şeffaf, kaydırılabilir katman; tek işi scroll üretip [ScrollProgress]'e bağlamaktır (AGENTS.md §4).
///
/// Sayfa kaydırmasının tek controller'ı burada yaşar. Görsel ya da tıklanabilir çocuk yoktur;
/// `HitTestBehavior.translucent` sayesinde tıklamalar alttaki Sahne'ye geçer.
///
/// Tekerlek/trackpad için ayrı `Listener` gerekir: `Scrollable`'ın kendi tekerlek dinleyicisi
/// `deferToChild`'dır; Ray'ın çocukları boş olduğundan hit yoluna hiç girmez ve olay kaybolur.
/// Dıştaki translucent `Listener` olayı yakalar, `Scrollable`'ın mantığını dikey eksende uygular.
///
/// Ekran 720 eşiğini geçince Ray yeniden kurulur (yeni controller, offset 0); ilk kareden sonra
/// [ScrollProgress.restorePosition] önceki bölüme ve ilerlemeye döner. Ray yeniden kurulmadan
/// yalnızca yükseklik değişirse (pencere boyu, eşiği geçmeyen dönüş) [ScrollProgress.holdPosition]
/// konumu saklar, aynı `restorePosition` kare sonrası uygular.
class Track extends StatefulWidget {
  const Track({required this.scrollProgress, super.key});

  final ScrollProgress scrollProgress;

  @override
  State<Track> createState() => _TrackState();
}

class _TrackState extends State<Track> {
  late final ScrollController _controller = ScrollController();

  /// Son build'deki viewport yüksekliği; değişince bölüm ve ilerleme korunur, durum bir sonraki
  /// karede yeniden hesaplanır.
  double? _viewportHeight;

  @override
  void initState() {
    super.initState();
    widget.scrollProgress.attachScroller(_controller);
  }

  @override
  void didUpdateWidget(Track oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollProgress != widget.scrollProgress) {
      oldWidget.scrollProgress.detachScroller(_controller);
      widget.scrollProgress.attachScroller(_controller);
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    // Yalnızca kendi controller'ını ayırır: ekran dönünce yeni Ray bu dispose'dan önce bağlanmıştır.
    widget.scrollProgress.detachScroller(_controller);
    _controller.dispose();
    super.dispose();
  }

  /// Pozisyon ilk layout'tan önce hazır değildir ve boyut değişimi scroll event'i üretmez;
  /// bu yüzden kare bittikten sonra çalışır (build sırasında notifier tetiklenmez). Önce
  /// `restorePosition` (Ray yeniden kurulduysa ya da yükseklik değiştiyse saklı bölüme döner),
  /// sonra `refresh`.
  void _scheduleRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.scrollProgress
        ..restorePosition()
        ..refresh();
    });
  }

  /// `Scrollable._receivedPointerSignal`'ın dikey kopyası: yalnızca gerçekten kaydıracaksa
  /// resolver'a kaydolur; resolver olayı tek dinleyiciye verir, çift kaydırma olmaz.
  void _onPointerSignal(PointerSignalEvent event) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (event is PointerScrollEvent) {
      if (!position.physics.shouldAcceptUserOffset(position)) return;
      if (!_wouldScroll(position, event.scrollDelta.dy)) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
        final scroll = resolved as PointerScrollEvent;
        final delta = scroll.scrollDelta.dy;
        if (!_wouldScroll(position, delta)) return;
        position.pointerScroll(delta);
        scroll.respond(allowPlatformDefault: false);
      });
    } else if (event is PointerScrollInertiaCancelEvent) {
      position.pointerScroll(0);
    }
  }

  static bool _wouldScroll(ScrollPosition position, double delta) {
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return delta != 0 && target != position.pixels;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Alan ataması; notifier tetiklenmez, build sırasında güvenli.
      widget.scrollProgress.reduceMotion = AppDurations.reduceMotionOf(context);
      final viewportHeight = constraints.maxHeight;
      if (viewportHeight != _viewportHeight) {
        // İlk build değilse: aynı piksel offset'i yeni yükseklikte başka bölüme düşer.
        if (_viewportHeight != null) widget.scrollProgress.holdPosition();
        _viewportHeight = viewportHeight;
        _scheduleRefresh();
      }
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: _onPointerSignal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context)
              .copyWith(scrollbars: false, overscroll: false),
          child: CustomScrollView(
            controller: _controller,
            hitTestBehavior: HitTestBehavior.translucent,
            slivers: [
              for (final length in widget.scrollProgress.scrollLengths)
                SliverToBoxAdapter(
                  child: SizedBox(height: viewportHeight * length),
                ),
              // Max scroll = toplam − 1 viewport; bu boşluk olmadan son bölüm progress = 1'e ulaşmaz.
              SliverToBoxAdapter(child: SizedBox(height: viewportHeight)),
            ],
          ),
        ),
      );
    },
  );
}
