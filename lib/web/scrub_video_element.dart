import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'scrub_seek_policy.dart';

/// Scroll ile sürülen ham `<video>` elementi; platform view olarak kaydedilir (AGENTS.md §5).
///
/// Kurallar: element sessiz, satır içi, kontrolsüz ve `pointer-events:none`'dır; tekerlek ve
/// sürükleme Flutter'a (Ray'a) gider. Video oynatılmaz, yalnızca `currentTime` set edilir (tek istisna
/// aşağıdaki iOS kilidi).
/// Kaynak: video `fetch` ile bir kez indirilir, blob'a çevrilir ve `src` object URL olur; seek'ler
/// bellekten yapılır, ağ isteği ve HTTP Range gerekmez. İndirme boyunca `poster` görünür; indirme
/// başarısız olursa ya da cevap video değilse (`content-type` `video/` değil) `src` doğrudan dosya
/// yoluna döner. `loadedmetadata` gelmeden seek yapılmaz.
/// Seek kapısı: hedef mevcut zamandan [scrubSeekThreshold]'dan az farklıysa set edilmez; set işlemi
/// `requestAnimationFrame` ile sonraki kareye ertelenir, karede en fazla bir seek olur, bekleyen
/// hedef yenisiyle ezilir. Önceki seek sürüyorsa ([decideSeek] → `defer`) hedef bekletilir ve
/// `seeked` olayından sonraki karede gönderilir; böylece tarayıcı süren seek'i iptal etmez, kare
/// yarım kalmaz.
/// Kadraj: `object-fit:cover` kırparken odak `objectPosition` (CSS `object-position`) ile seçilir.
/// iOS kilidi: WebKit (iOS Safari ve iOS Chrome) hiç oynatılmamış videoda seek karesini boyamaz;
/// poster kalkınca ekran siyah kalır. Bu yüzden her video bir kez `play` edilip promise çözülünce
/// hemen `pause` edilir ([_unlock]; AGENTS.md §5'teki tek oynatma istisnası). İlk deneme
/// `loadedmetadata` anındadır (sessiz + satır içi videoda iOS hareket istemez). Düşük Güç Modu bunu
/// reddeder; bu yüzden `document`'ta kalıcı bir `passive` dinleyici (`touchstart`, `touchend`,
/// `pointerdown`; iOS kullanıcı hareketini `touchend`/`pointerup`'ta sayar) her dokunuşta kilidi
/// açılmamış canlı handle'ları yeniden dener; sonradan kurulan handle'lar da bir sonraki dokunuşta
/// açılır. Hepsi açıksa dinleyici iş yapmaz. Kilit açılınca bekleyen seek hedefi sonraki karede
/// gönderilir; masaüstünde zararsızdır.
class ScrubVideoHandle {
  ScrubVideoHandle({
    required String src,
    required String poster,
    required String objectPosition,
  }) : viewType = 'scrub-video-${_counter++}' {
    _element
      ..muted = true
      ..playsInline = true
      ..preload = 'auto'
      ..controls = false
      ..poster = poster
      ..style.cssText =
          'width:100%;height:100%;object-fit:cover;'
          'object-position:$objectPosition;display:block;pointer-events:none';
    _element
      ..addEventListener('loadedmetadata', _onLoadedMetadata)
      ..addEventListener('seeked', _onSeeked);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => _element,
    );
    _live.add(this);
    _hookGestures();
    unawaited(_loadAsBlob(src));
  }

  /// Her handle'a benzersiz viewType verir; aynı viewType iki kez kaydedilmez.
  static int _counter = 0;

  /// Dispose edilmemiş handle'lar; her kullanıcı hareketinde kilidi kapalı olanlar yeniden denenir.
  static final Set<ScrubVideoHandle> _live = {};

  /// Sayfa düzeyindeki kalıcı hareket dinleyicisi eklendi mi; yalnızca bir kez eklenir, kaldırılmaz.
  static bool _gestureHooked = false;
  static final JSFunction _onGesture = _unlockLive.toJS;

  /// `HtmlElementView(viewType: ...)` ile gömülecek benzersiz kimlik: `scrub-video-<sayaç>`.
  final String viewType;

  final web.HTMLVideoElement _element =
      web.document.createElement('video') as web.HTMLVideoElement;
  final ValueNotifier<bool> _isReady = ValueNotifier<bool>(false);
  late final JSFunction _onLoadedMetadata = _handleLoadedMetadata.toJS;
  late final JSFunction _onSeeked = _handleSeeked.toJS;
  late final JSFunction _onFrame = _flush.toJS;

  int? _rafId;
  double? _pendingTime;
  String? _objectUrl;
  bool _disposed = false;
  bool _unlocked = false;
  bool _unlocking = false;

  /// `loadedmetadata` sonrası `true`; yalnızca seek'i kapılar, poster bundan bağımsız görünür.
  ValueListenable<bool> get isReady => _isReady;

  /// Videoyu bölüm ilerlemesine ([progress] 0..1) göre konumlar; hazır değilse hiçbir şey yapmaz.
  void seekTo(double progress) {
    if (_disposed || !_isReady.value) return;
    final duration = _element.duration;
    if (!duration.isFinite || duration <= 0) return;

    final target = progress.clamp(0.0, 1.0) * duration;
    if ((target - _element.currentTime).abs() < scrubSeekThreshold) {
      // Video zaten hedefte; aynı karede kalmış eski bir hedef varsa o da geçersizdir.
      _pendingTime = null;
      return;
    }
    _pendingTime = target;
    _rafId ??= web.window.requestAnimationFrame(_onFrame);
  }

  /// Bekleyen kareyi iptal eder, listener'ları kaldırır, indirmeyi durdurur ve blob'u bırakır.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _live.remove(this);
    final rafId = _rafId;
    if (rafId != null) web.window.cancelAnimationFrame(rafId);
    _rafId = null;
    _pendingTime = null;
    _element
      ..removeEventListener('loadedmetadata', _onLoadedMetadata)
      ..removeEventListener('seeked', _onSeeked)
      ..removeAttribute('src')
      ..load();
    final objectUrl = _objectUrl;
    if (objectUrl != null) web.URL.revokeObjectURL(objectUrl);
    _objectUrl = null;
    _isReady.dispose();
  }

  /// Videoyu tek istekte indirip blob object URL'i olarak `src`'ye verir; hata olursa ya da cevap
  /// video değilse [src]'ye döner.
  ///
  /// Hosting her yolu `index.html`'e çevirir (`firebase.json` rewrite): eksik video `200` + HTML
  /// döner. `content-type` `video/` ile başlamıyorsa HTML blob'a çevrilmez, hata loglanır.
  Future<void> _loadAsBlob(String src) async {
    try {
      final response = await web.window.fetch(src.toJS).toDart;
      if (!response.ok) throw StateError('HTTP ${response.status}');
      final type = response.headers.get('content-type') ?? '';
      if (!type.toLowerCase().startsWith('video/')) {
        throw StateError('video değil (content-type: "$type")');
      }
      final blob = await response.blob().toDart;
      // dispose fetch sürerken geldiyse blob'a URL açılmaz; bırakılacak bir şey kalmaz.
      if (_disposed) return;
      final objectUrl = web.URL.createObjectURL(blob);
      _objectUrl = objectUrl;
      _element.src = objectUrl;
    } catch (e) {
      if (_disposed) return;
      debugPrint('scrub video blob yüklenemedi ($src): $e');
      _element.src = src;
    }
  }

  void _handleLoadedMetadata(web.Event _) {
    if (_disposed) return;
    _isReady.value = true;
    _unlock();
  }

  /// Seek bitti: bekletilen hedef varsa sonraki karede gönderilir.
  void _handleSeeked(web.Event _) => _requestFrameIfPending();

  /// Bekleyen seek hedefi varsa sonraki kareyi ister; kare zaten istenmişse yenisi açılmaz.
  void _requestFrameIfPending() {
    if (_disposed || _pendingTime == null) return;
    _rafId ??= web.window.requestAnimationFrame(_onFrame);
  }

  /// iOS kilidi: videoyu bir kez başlatıp promise çözülünce hemen durdurur; sonraki çağrılar no-op.
  ///
  /// Projedeki tek `play` çağrısı buradadır. Reddedilirse (ör. Düşük Güç Modu) bayrak sıfırlanır,
  /// sonraki kullanıcı hareketinde [_unlockLive] yeniden dener. Dispose sonrası gelen sonuç yok sayılır.
  void _unlock() {
    if (_disposed || _unlocked || _unlocking) return;
    _unlocking = true;
    unawaited(
      _element
          .play()
          .toDart
          .then((_) {
            if (_disposed) return;
            _element.pause();
            _unlocked = true;
            _unlocking = false;
            _requestFrameIfPending();
          })
          .catchError((Object e) {
            _unlocking = false;
            if (!_disposed) debugPrint('scrub video unlock reddedildi: $e');
          }),
    );
  }

  /// Sayfaya kalıcı `touchstart`, `touchend` ve `pointerdown` dinleyicisi ekler (`passive`).
  ///
  /// Bir kez eklenir, hiç kaldırılmaz; `touchend` iOS'un kullanıcı hareketi saydığı olaydır.
  static void _hookGestures() {
    if (_gestureHooked) return;
    _gestureHooked = true;
    final options = web.AddEventListenerOptions(passive: true);
    web.document
      ..addEventListener('touchstart', _onGesture, options)
      ..addEventListener('touchend', _onGesture, options)
      ..addEventListener('pointerdown', _onGesture, options);
  }

  /// Kullanıcı hareketi: kilidi açık olmayan ve denemesi sürmeyen canlı handle'larda [_unlock] dener.
  ///
  /// `_live` boşsa ya da hepsi açıksa hiçbir şey yapmaz (en fazla 2 handle; maliyet yok).
  static void _unlockLive(web.Event _) {
    for (final handle in _live) {
      if (!handle._unlocked && !handle._unlocking) handle._unlock();
    }
  }

  /// rAF geri çağrısı: karede tek seek, en son istenen hedefe; seek sürüyorsa hedef bekler.
  void _flush(double _) {
    _rafId = null;
    final target = _pendingTime;
    if (_disposed || target == null) return;
    switch (decideSeek(
      target: target,
      current: _element.currentTime,
      seeking: _element.seeking,
    )) {
      case SeekDecision.skip:
        _pendingTime = null;
      case SeekDecision.defer:
        // `_pendingTime` kalır; `seeked` gelince [_handleSeeked] yeni kare ister.
        break;
      case SeekDecision.seek:
        _pendingTime = null;
        _element.currentTime = target;
    }
  }
}
