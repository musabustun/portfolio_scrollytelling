import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Ray'ın anlık durumu: aktif bölüm, bölüm içi ilerleme ve tüm sayfa ilerlemesi (AGENTS.md §4).
@immutable
class ScrollState {
  const ScrollState({
    required this.chapterIndex,
    required this.progress,
    required this.globalProgress,
  });

  /// Sayfanın en üstü; Ray henüz bağlanmamışken de bu değer yayınlanır.
  static const ScrollState initial = ScrollState(
    chapterIndex: 0,
    progress: 0,
    globalProgress: 0,
  );

  /// Aktif bölümün indeksi.
  final int chapterIndex;

  /// Aktif bölüm içindeki ilerleme, 0..1.
  final double progress;

  /// Tüm hikâye boyunca ilerleme, 0..1.
  final double globalProgress;

  /// Bölüm [index]'in ilerlemesi: geçilmiş bölüm 1, gelecek bölüm 0, aktif bölüm [progress].
  double progressFor(int index) {
    if (index < chapterIndex) return 1;
    if (index > chapterIndex) return 0;
    return progress;
  }

  @override
  bool operator ==(Object other) =>
      other is ScrollState &&
      other.chapterIndex == chapterIndex &&
      other.progress == progress &&
      other.globalProgress == globalProgress;

  @override
  int get hashCode => Object.hash(chapterIndex, progress, globalProgress);

  @override
  String toString() =>
      'ScrollState(chapterIndex: $chapterIndex, progress: $progress, '
      'globalProgress: $globalProgress)';
}

/// Scroll offset'ini [ScrollState]'e çevirir; saf fonksiyon, Ray'ın sondaki boşluğunu bilmez.
///
/// [scrollLengths] her bölümün viewport cinsinden uzunluğudur. Offset 0..toplam aralığına kırpılır;
/// tam toplamda son bölüm `progress = 1` olur.
ScrollState computeScrollState({
  required double offset,
  required double viewportHeight,
  required List<double> scrollLengths,
}) {
  if (scrollLengths.isEmpty || viewportHeight <= 0) return ScrollState.initial;
  final total = _sum(scrollLengths);
  if (total <= 0) return ScrollState.initial;

  final raw = offset / viewportHeight;
  final pos = raw.isNaN ? 0.0 : raw.clamp(0.0, total);
  final last = scrollLengths.length - 1;
  if (pos >= total) {
    return ScrollState(chapterIndex: last, progress: 1, globalProgress: 1);
  }

  var start = 0.0;
  for (var i = 0; i < last; i++) {
    final end = start + scrollLengths[i];
    if (pos < end) return _stateIn(i, pos, start, scrollLengths[i], total);
    start = end;
  }
  return _stateIn(last, pos, start, scrollLengths[last], total);
}

/// Bölüm [index]'in Ray üzerindeki başlangıç offset'i (piksel); [index] 0..n-1'e kırpılır.
double chapterStartOffset({
  required int index,
  required double viewportHeight,
  required List<double> scrollLengths,
}) {
  if (scrollLengths.isEmpty) return 0;
  final clamped = index.clamp(0, scrollLengths.length - 1);
  return viewportHeight * _sum(scrollLengths.take(clamped));
}

/// [computeScrollState]'in tersi: bölüm [chapterIndex] içinde [progress] ilerlemesinin Ray üzerindeki
/// offset'i (piksel). İndeks 0..n-1'e, ilerleme 0..1'e kırpılır.
///
/// Ekran dönünce viewport yüksekliği değişir; aynı bölüm ve ilerleme yeni yükseklikte bu offset'tir.
double offsetFor({
  required int chapterIndex,
  required double progress,
  required double viewportHeight,
  required List<double> scrollLengths,
}) {
  if (scrollLengths.isEmpty || viewportHeight <= 0) return 0;
  final index = chapterIndex.clamp(0, scrollLengths.length - 1);
  final within = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
  final start = chapterStartOffset(
    index: index,
    viewportHeight: viewportHeight,
    scrollLengths: scrollLengths,
  );
  return start + viewportHeight * scrollLengths[index] * within;
}

double _sum(Iterable<double> values) =>
    values.fold<double>(0, (sum, value) => sum + value);

ScrollState _stateIn(
  int index,
  double pos,
  double start,
  double length,
  double total,
) => ScrollState(
  chapterIndex: index,
  progress: length > 0 ? ((pos - start) / length).clamp(0.0, 1.0) : 1,
  globalProgress: pos / total,
);

/// Scroll durumunun tek kaynağı: Ray'ın controller'ını dinler, [ScrollState] yayınlar
/// (AGENTS.md §4).
///
/// Controller'ın sahibi `Track`'tir; bu sınıf onu yalnızca dinler ve [animateToChapter] ile sürer,
/// asla oluşturmaz ya da dispose etmez.
///
/// Ray'dan uzun yaşar: ekran 720 eşiğini geçince `ScreenUtilInit` altındaki ağaç (Ray dahil)
/// yeniden kurulur; yeni Ray bağlanınca [restorePosition] aynı bölüme ve ilerlemeye döner. Ray
/// yeniden kurulmadan yalnızca yükseklik değişirse Track [holdPosition] ile aynı yolu kullanır.
class ScrollProgress extends ValueNotifier<ScrollState> {
  ScrollProgress({required List<double> scrollLengths})
    : scrollLengths = List.unmodifiable(scrollLengths),
      super(ScrollState.initial);

  /// Bölüm uzunlukları (viewport cinsinden), değiştirilemez kopya.
  final List<double> scrollLengths;

  ScrollController? _controller;

  /// Yeni Ray bağlanırken ya da viewport yüksekliği değişirken saklanan durum; [restorePosition]
  /// uygular ve siler.
  ScrollState? _pendingRestore;

  /// "Hareketi azalt" açık mı; Track her build'de `MediaQuery`'den set eder (notifier tetiklenmez).
  /// `true` ise [animateToChapter] animasyonsuz `jumpTo` yapar (AGENTS.md §10.6).
  bool reduceMotion = false;

  int get chapterCount => scrollLengths.length;

  /// Ray'ın controller'ına bağlanır; öncekine bağlıysa ondan ayrılır.
  ///
  /// Durum sayfanın başı (bölüm 0, ilerleme 0) değilse saklanır: Ray yeniden kurulmuştur ve
  /// [restorePosition] oraya döner. İlk açılışta saklanacak bir şey yoktur.
  void attachScroller(ScrollController controller) {
    detachScroller();
    final previous = value;
    _pendingRestore = previous.chapterIndex == 0 && previous.progress == 0
        ? null
        : previous;
    _controller = controller;
    controller.addListener(refresh);
    refresh();
  }

  /// Mevcut bölümü ve ilerlemeyi bekleyen geri yükleme olarak saklar; [restorePosition] uygular.
  ///
  /// Track viewport yüksekliği değişince (aynı Ray) çağırır: piksel offset'i aynı kalır ama yeni
  /// yükseklikte başka bir bölüme düşer. Zaten bekleyen bir geri yükleme varsa o korunur;
  /// controller bağlı değilse no-op. Notifier tetiklenmez, build sırasında güvenlidir.
  void holdPosition() {
    final current = value;
    if (_controller == null || _pendingRestore != null) return;
    // Sayfa başı geri yüklenmez: offset zaten 0'dır ([attachScroller] ile aynı kural).
    if (current.chapterIndex == 0 && current.progress == 0) return;
    _pendingRestore = current;
  }

  /// Controller'dan ayrılır; controller'ı dispose etmez.
  ///
  /// [controller] verilirse yalnızca o bağlıysa ayrılır: ekran dönünce yeni Ray eskisi dispose
  /// edilmeden bağlanır; eski Ray'ın dispose'u yeni bağlantıyı koparmamalı.
  void detachScroller([ScrollController? controller]) {
    if (controller != null && !identical(controller, _controller)) return;
    _controller?.removeListener(refresh);
    _controller = null;
    _pendingRestore = null;
  }

  /// [attachScroller]'da ya da [holdPosition]'da saklanan bölüme ve bölüm içi ilerlemeye `jumpTo`
  /// ile döner; offset güncel viewport yüksekliğiyle hesaplanır ([offsetFor]). Track ilk kareden ve
  /// her yükseklik değişiminden sonra, [refresh]'ten önce çağırır. Saklı durum yoksa no-op; pozisyon
  /// henüz hazır değilse saklı durum sonraki çağrıya kalır.
  void restorePosition() {
    final target = _pendingRestore;
    final controller = _controller;
    final position = _readyPosition;
    if (target == null || controller == null || position == null) return;
    final viewportHeight = position.viewportDimension;
    if (viewportHeight <= 0) return;
    _pendingRestore = null;
    final offset = offsetFor(
      chapterIndex: target.chapterIndex,
      progress: target.progress,
      viewportHeight: viewportHeight,
      scrollLengths: scrollLengths,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    controller.jumpTo(offset);
  }

  /// Controller'ın güncel konumundan durumu yeniden hesaplar (ör. viewport boyutu değişince).
  void refresh() {
    final position = _readyPosition;
    if (position == null) return;
    value = computeScrollState(
      offset: position.pixels,
      viewportHeight: position.viewportDimension,
      scrollLengths: scrollLengths,
    );
  }

  /// Bölüm [index]'in başına kaydırır; bölümler arası geçişin tek kapısı (AGENTS.md §4, §10.6).
  Future<void> animateToChapter(int index) async {
    final controller = _controller;
    final position = _readyPosition;
    if (controller == null || position == null) return;
    final target = chapterStartOffset(
      index: index,
      viewportHeight: position.viewportDimension,
      scrollLengths: scrollLengths,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (reduceMotion) {
      controller.jumpTo(target);
      return;
    }
    await controller.animateTo(
      target,
      duration: AppDurations.navScroll,
      curve: AppDurations.navScrollCurve,
    );
  }

  /// Bağlı ve yerleşimi tamamlanmış tek scroll pozisyonu; yoksa `null`.
  ScrollPosition? get _readyPosition {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return null;
    final position = controller.position;
    final ready =
        position.hasPixels &&
        position.hasViewportDimension &&
        position.hasContentDimensions;
    return ready ? position : null;
  }

  @override
  void dispose() {
    detachScroller();
    super.dispose();
  }
}
