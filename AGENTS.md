# AGENTS.md — Proje Anayasası

Bu dosya, bu repoda çalışan **tüm** yapay zeka ajanlarının (Claude Code, Antigravity, diğerleri)
ve insanların uyması gereken kuralları içerir. `CLAUDE.md` bu dosyayı import eder; iki ajan tek
anayasa okur. Bir karar burada yazılıysa tartışmasız uygulanır; değiştirmek istiyorsan önce bu
dosyayı güncelle, sonra kodu.

İş paketleri (hazır görevler: Faz 4 otomatik yayın, Faz 5 klavye) için: `docs/roadmap.md`
Tarayıcıda elle doğrulanacak maddeler için: `docs/tarayici-kontrol.md`
Claude Code oturum düzeni (yönetici oturum + alt ajanlar) için: `CLAUDE.md`
Kurulum rehberi için: `README.md`

---

## 1. Proje nedir?

Tek sayfalık (SPA), **scrollytelling** tarzı kişisel portfolyo web sitesi. Ziyaretçi aşağı kaydırdıkça
hikâye ilerler; video bölümlerinde video, kaydırma pozisyonuna bağlı olarak ileri/geri oynar.
Sağ altta, site sahibi hakkındaki soruları cevaplayan bir Gemini sohbet paneli vardır.

Bu repo bir **workshop şablonudur**: klonlayıp `assets/story.json`, `assets/about_me.md` ve
`web/video/` içeriğini değiştirerek siteyi kendinin yaparsın. Bitmiş bir örnek canlıda:
https://mustafakara.website. Repo public olabileceği için kodda **hiçbir yerde anahtar, proje
kimliği veya kişiye özel sır bulunmaz.**

### Teknoloji yığını (değiştirilmez)

| Katman | Teknoloji | Not |
|---|---|---|
| UI | Flutter Web | `flutter build web --wasm` (skwasm renderer) |
| Video | HTML `<video>` + `package:web` | `HtmlElementView` içinde, scroll ile `currentTime` sürülür |
| AI | Firebase AI Logic (`firebase_ai`) | Gemini Flash, client-side, API key yok |
| Güvenlik | Firebase App Check (`firebase_app_check`) | Web'de reCAPTCHA Enterprise provider |
| Hosting | Firebase Hosting | Elle `firebase deploy`; GitHub Actions ile otomatik deploy Faz 4'te (`docs/roadmap.md` P4.1) |
| Responsive | `flutter_screenutil` | İki tasarım boyutu (1440×900 / 390×844), tek breakpoint 720; yalnızca `lib/theme/` ve `app.dart` import eder (§11.3) |
| Video üretimi | Google Flow (Veo) | Repo dışı; çıktı `tools/encode.sh` ile işlenir |

---

## 2. Kesin kararlar

1. **Tek sayfa.** Router yok (`go_router`, `Navigator.pushNamed` vb. yok). URL asla değişmez.
   Bölümler arası geçiş `ScrollProgress.animateToChapter` ile yapılır (içeride tek
   `ScrollController.animateTo`; hareket azaltılmışsa `jumpTo`, bkz. §4). Sohbet paneli bir
   overlay'dir, sayfa değildir.
2. **Renderer: skwasm.** Build komutu daima `flutter build web --wasm`. Debug'da
   `flutter run -d chrome --wasm`. CanvasKit'e dönüş yalnızca tarayıcı WasmGC desteklemiyorsa
   ve otomatiktir; kodda renderer'a özel dallanma yazılmaz.
3. **Video, Flutter widget'ı değildir.** `video_player` paketi KULLANILMAZ. Her video bölümü,
   `dart:ui_web` `platformViewRegistry` ile kaydedilen ham bir `HTMLVideoElement`'tir ve
   `HtmlElementView` ile gömülür. Scroll → `video.currentTime` doğrudan `package:web` ile set edilir.
4. **Video dosyaları `web/video/` altında durur**, `assets/` altında değil. Böylece Flutter asset
   manager'ın `assets/assets/...` yol karmaşasına girilmez; dosyalar `/video/<ad>.mp4` olarak
   doğrudan servis edilir. `firebase.json` `/video/**` URL yolu için immutable cache header'ı
   verir (`max-age=1 yıl`): **değişen bir video aynı adla değil yeni dosya adıyla konur**, yoksa
   tarayıcı eski kopyayı gösterir. `firebase.json` ayrıca her yola dört güvenlik başlığı verir:
   `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`.
   CSP yoktur: tarayıcıda denenmeden eklenmez (Flutter web wasm ve inline betikler kolayca kırılır).
5. **Her video "scrub-ready" encode edilmiş olmalı:** her kare keyframe (`-g 1`), sessiz (`-an`),
   H.264 yuv420p, `+faststart`. Komut: `tools/encode.sh`. Encode edilmemiş video repoya girmez
   (neden: normal videoda tarayıcı her seek'te önceki anahtar kareden itibaren çözer, scroll takılır).
   Flow çıktısına gömülü üst/alt siyah bant varsa kesilir (varsayılan kırpma yok; bantlar
   `object-fit: cover` ile sitede siyah şerit olarak görünür). `CROP=auto` bantları bulur ama koyu
   görüntüyü bant sanabilir; o zaman bantlar elle `CROP=W:H:X:Y` ile kesilir (örnekler §7).
6. **Gemini'ye yalnızca Firebase AI Logic üzerinden erişilir.** `google_generative_ai` paketi,
   `http` ile elle Gemini çağrısı, `.env` içinde API key — hepsi YASAK. Model adı tek yerde:
   `lib/ai/ai_config.dart`.
7. **Sıfır sır politikası.** Aşağıdaki dosyalar `.gitignore`'dadır ve asla commit edilmez:
   `lib/firebase_options.dart`, `.firebaserc`, `.firebase/`, `*.env`, `*.local`, service account JSON'ları
   (`*service-account*.json`, `*-firebase-adminsdk-*.json`). Repo, `lib/firebase_options.dart` olmadan **derlenmeli ve çalışmalıdır** (bkz. §6 "Firebase
   yoksa"; `firebase_options.dart.example` yalnızca `apiKey: 'PLACEHOLDER'` taşır).
   `flutterfire configure` `firebase.json`'a proje ID'li bir `flutter` bloğu ekler; bu dosya proje
   ID içermez, configure sonrası `git checkout -- firebase.json`.
8. **İçerik koddan ayrıdır.** Bölümler, metinler, video yolları `assets/story.json`'da;
   AI persona `assets/about_me.md`'de. Kod bu iki dosyayı okur, içlerinde ne yazdığını bilmez.
   Ajan, kullanıcı açıkça istemedikçe bu iki dosyanın **içeriğini** değiştirmez (şemayı değiştirebilir,
   ama şemayı değiştirirse bu dosyayı ve `README.md` §3 tablosunu günceller). Link `url` alanları
   (iletişim ve proje linkleri) yalnızca `https:`, `http:` ya da `mailto:` olabilir; başka şema
   (`javascript:` vb.) `StoryFormatException` fırlatır ve hata kutusu görünür.
9. **Hedef tarayıcı: Chrome (masaüstü).** Safari/Firefox/mobil "çalışsın" seviyesinde, "mükemmel"
   değil. Telefon için ayarlar hazır: dikey video, kırpma odağı, iOS kilidi, ekran dönünce konumun
   korunması (§4, §5).
10. **Dil:** UI metinleri `story.json`'dan gelir (Türkçe örnek içerik). Kod, yorumlar ve commit
    mesajları Türkçe ya da İngilizce olabilir; karışık olabilir; tutarlılık için tek dosya içinde
    tek dil.

---

## 3. Klasör yapısı

```
.
├── AGENTS.md                  # bu dosya
├── CLAUDE.md                  # AGENTS.md import'u + Claude Code oturum düzeni
├── README.md                  # katılımcı rehberi
├── LICENSE                    # repo lisansı
├── docs/
│   ├── roadmap.md             # iş paketleri — "tam olarak nasıl"; hazır: P4.1 (otomatik yayın), P5.1 (klavye);
│   │                          #   biten paket silinir, günlük tutmaz
│   └── tarayici-kontrol.md    # tarayıcıda elle doğrulanacak maddeler (masaüstü, telefon, sohbet, Lighthouse)
├── .gitignore
├── raw/                       # GITIGNORE — ham Flow indirmeleri; repoya yalnızca encode.sh çıktısı girer
├── pubspec.yaml
├── analysis_options.yaml      # flutter_lints + §11.4 ek kuralları
├── firebase.json              # hosting ayarı; proje ID İÇERMEZ
├── lib/
│   ├── main.dart              # bootstrap: ensureSemantics, Firebase init (varsa), App Check, story yüklemesi, PersonaService.create, runApp
│   ├── app.dart               # App → _Site (ScrollProgress, sohbet açık notifier'ı, ChatController) → _Scaled (LayoutBuilder → ScreenUtilInit) → MaterialApp (§11.1)
│   ├── theme/                 # tasarım dili sabitleri (§10) ve token kuralı (§11.2); widget'larda literal yok
│   │   ├── theme.dart             # barrel; widget'lar yalnızca bunu import eder
│   │   ├── app_colors.dart        # §10.2 palet, const Color
│   │   ├── app_fonts.dart         # font ailesi adı ve ağırlıklar, tek yer
│   │   ├── app_text_styles.dart   # §10.3 hiyerarşi: display / h1 / statement / overlayStatement / body / input / lead / eyebrow / label / button
│   │   ├── app_spacing.dart       # gutter, 8 px ritim, içerik maks genişlik
│   │   ├── app_radii.dart         # BorderRadius nesneleri: pill, panel
│   │   ├── app_durations.dart     # crossfade, hover, nav süreleri + eğriler; reduceMotionOf/crossfadeOf/hoverOf(context) (§10.6)
│   │   ├── app_sizes.dart         # bileşen ölçüleri: nav, buton, overlay (+ overlayStatementMaxWidth), panel, tag, projectPanelCollapsedHeight; video kırpma odağı (videoObjectPositionFor)
│   │   ├── app_strings.dart       # story.json dışı sabit UI metinleri (§11.2)
│   │   ├── app_breakpoints.dart   # mobil < 720, tasarım boyutları, isMobile
│   │   └── app_theme.dart         # ThemeData üretimi (meta.accent/background ezer), context.accent/bg
│   ├── widgets/               # tekrar eden UI parçaları; dosya başına tek public widget (§11.1)
│   │   ├── pill_button.dart       # dolu / çizgili pill (§10.4)
│   │   ├── tap_target.dart        # TapTarget: görünümü çocukta olan tıklanabilir alan; button semantics + onTap + el imleci (§10.4)
│   │   ├── index_label.dart       # "01 · PROJE" etiketi + twoDigits(int) yardımcısı
│   │   ├── progress_ring.dart     # nav'daki ilerleme halkası
│   │   ├── label_text.dart        # LabelText + upperTr: Türkçe kurallı BÜYÜK HARF etiket
│   │   ├── story_error_box.dart   # story.json okunamadı hata kutusu (§10.4)
│   │   ├── gradient_scrim.dart    # video altı gradyan
│   │   ├── reveal_text.dart       # kelime kelime dolan RichText (§10.5)
│   │   ├── step_counter.dart      # "01 / 03" + ilerleme çizgisi
│   │   └── typing_dots.dart       # sohbette "yazıyor" göstergesi: üç nokta, opaklık dalgası (§10.4, §10.6)
│   ├── firebase_options.dart  # GITIGNORE — flutterfire configure üretir
│   ├── firebase_options.dart.example  # placeholder; kopyalanarak kullanılır
│   ├── story/
│   │   ├── story.dart             # Story, Meta, Chapter (videoMobile/posterMobile, videoFor/posterFor), ChapterType, TextOverlay, Project (`name`, `description`, `tags`, `url`, isteğe bağlı `links` ve `highlights`; `image` yok, JSON'da kalırsa yok sayılır), ContactLink (contact ve proje linki), StoryFormatException, parseHexColor
│   │   ├── story_loader.dart      # assets/story.json okur; load() asla fırlatmaz, StoryLoaded | StoryLoadFailed döner
│   │   └── scroll_progress.dart   # ScrollProgress notifier: offset ↔ ScrollState (computeScrollState, offsetFor); animateToChapter, reduceMotion, restorePosition/holdPosition (§4)
│   ├── stage/
│   │   ├── stage.dart             # Sabit "Sahne" katmanı (Stack), aktif bölümü çizer; yalnızca bölüm değişince rebuild
│   │   ├── track.dart             # Kaydırılabilir "Ray" katmanı (CustomScrollView) (§4)
│   │   └── chapter_indicator.dart # üstteki pill nav + scroll ilerleme halkası (§10.4)
│   ├── chapters/
│   │   ├── video_chapter.dart     # scrub video + metin overlay'leri
│   │   ├── text_chapter.dart      # statement: kelime kelime beliren cümle (§10.5)
│   │   ├── projects_chapter.dart  # yan yana (mobilde alt alta) paneller, scroll ile genişleyen; saf `panelOpenness`, `activeProjectIndex` (§10.5)
│   │   └── contact_chapter.dart   # kapanış: dev başlık, büyük e-posta, link pill'leri, tek satır footer; saf `splitContactBody` (§10.5)
│   ├── web/                   # package:web yalnızca bu klasörde import edilir
│   │   ├── scrub_video_element.dart  # ScrubVideoHandle: HTMLVideoElement, blob kaynak, scrub (seek) mantığı, iOS kilidi
│   │   ├── scrub_seek_policy.dart    # saf seek kararı: SeekDecision {skip, defer, seek}, decideSeek, scrubSeekThreshold; package:web yok
│   │   └── browser.dart           # küçük tarayıcı yardımcıları: openExternal(url)
│   └── ai/
│       ├── ai_config.dart         # model adı (Flash-Lite), maxOutputTokens, maxHistory, maxQuestionChars, safetySettings
│       ├── persona_service.dart   # Firebase AI Logic; PersonaService, PersonaException; system prompt, hata eşlemesi, isEmptyContentError, clipQuestion, historyForNextTurn, withTurn (saf fonksiyonlar)
│       ├── chat_controller.dart   # ChatController (mesajlar, isStreaming, isConnected, send) + AskFn typedef; ömrü app.dart'ta
│       ├── chat_panel.dart        # sağ alt overlay UI; ChatPanel(isOpen, controller, owner); bağlı değilse "Firebase bağlı değil" kartı
│       └── chat_message.dart      # mesaj modeli
├── assets/
│   ├── story.json             # SENARYO — katılımcı burayı düzenler
│   ├── about_me.md            # PERSONA — katılımcı burayı düzenler
│   └── fonts/                 # Inter TTF'leri + OFL lisansı; pubspec `fonts:` ile kayıtlı
├── web/
│   ├── index.html             # başlık "Portfolyo", meta, og:* + twitter:* (og:image satırları yorumlu örnek), yükleme ekranı, App Check debug anahtarı (yorumlu), viewport'ta yakınlaştırma kapalı (iOS odak yakınlaştırması)
│   ├── manifest.json          # PWA adı (`name`, `short_name`) ve ikon listesi; renkler bg
│   ├── favicon.png, icons/    # Flutter varsayılan ikonları (16 px favicon, 192/512 + maskable); kendininkini aynı ad ve boyutla koy
│   ├── og.jpg                 # isteğe bağlı, sen eklersin: paylaşım görseli 1200×630; `index.html`'deki og:image satırlarını açıp mutlak adres ver
│   └── video/                 # scrub-ready mp4 + jpg poster'lar; `story.json` bunlara bakar
│       ├── sample_intro.mp4, .jpg         # örnek açılış videosu (8 sn, story.json bölüm 0); kendi videonla değiştir
│       └── sample_work.mp4, .jpg          # örnek ikinci video bölümü (8 sn); dikey (`_mobile`) sürüm yok (§5)
├── test/
│   ├── scroll_progress_test.dart  # scroll_progress.dart'ın zorunlu unit testi (computeScrollState, offsetFor, restorePosition/holdPosition)
│   ├── scrub_seek_policy_test.dart # decideSeek: skip / defer / seek kararları (saf, VM)
│   ├── story_test.dart            # Story modeli: sabit fixture ile değer/şema testleri (link şeması dahil) + gerçek story.json yapısal duman testi
│   ├── label_text_test.dart       # upperTr Türkçe büyük harf testi
│   ├── track_test.dart            # Ray: tekerlek, sürükleme, tıklama geçişi (TestPointer), reduced-motion, yükseklik değişiminde konum
│   ├── reveal_text_test.dart      # wordRevealAt / wordColorAt / parseRevealWords saf fonksiyon testi
│   ├── pill_button_test.dart      # PillButton: dolu/çizgili, hover (reduced-motion dahil), tıklama, semantics etiketi ve onTap
│   ├── typing_dots_test.dart      # TypingDots: dalga, hareketi azalt'ta sabit ve ticker yok, semantics etiketi
│   ├── tap_target_test.dart       # TapTarget: tek tıklama tek tetik, semantics etiketi/onTap/selected, imleç
│   ├── chapters_test.dart         # text/projects bölüm widget'ları (video hariç saf kısımlar), `panelOpenness`, panel genişlemesi, proje link pill'leri, kompakt link sığma testleri; gerçek Inter ile ölçer
│   ├── contact_chapter_test.dart  # ContactChapter: `splitContactBody`, büyük e-posta (mailto), link pill'leri, tek satır footer, 1440×900 ve 390×844 taşma; gerçek Inter
│   ├── chat_panel_test.dart       # sohbet kabuğu: aç/kapa, mesaj akışı, "bağlı değil" kartı, soru sınırı, yapay zekâ notu, tekerlek yutma, "Sohbeti aç" etiketi, panel yeniden kurulunca mesajlar, giriş kutusu yazı boyutu (telefonda ≥ 16, masaüstünde `body`)
│   ├── persona_service_test.dart  # system prompt, hata eşlemesi, akış (boş içerik toleransı dahil), clipQuestion, historyForNextTurn, withTurn, koruma kuralları (saf fonksiyonlar)
│   ├── stage_wiring_test.dart     # Stage/app bağlama sözleşmeleri (web import'suz); nav semantics, 720 eşiğinde durumun korunması
│   └── helpers/               # yalnızca test: ortak yardımcılar (§11.4)
│       ├── fake_ask.dart          # fakeAsk (sahte cevap akışı), fakeReply, fakeReplyDelay, fakeWordInterval
│       ├── inter_font.dart        # gerçek Inter'i yükler (yerleşim ölçen testler için)
│       ├── pump_chapter.dart      # bölüm widget'ını ScreenUtil + tema ile kuran pump yardımcısı
│       └── wheel.dart             # TestPointer ile tekerlek olayı gönderir
├── tools/
│   ├── setup.sh               # firebase_options.dart.example'ı kopyalar, pub get çalıştırır
│   └── encode.sh              # Flow mp4 → scrub-ready mp4 + poster
└── .github/workflows/
    └── deploy.yml             # Faz 4'te eklenir (docs/roadmap.md P4.1)
```

Yeni dosya eklerken bu yapıya uy. Yapıyı değiştirmek gerekiyorsa önce bu bölümü güncelle.

---

## 4. Scroll mimarisi: Ray ve Sahne

Klasik scrollytelling deseni. Bir `Stack` içinde alttan üste: Sahne, Ray, üst katman (pill nav ve
sohbet paneli). Neden iki katman: içerik ekranda sabit durur ve yalnızca kaydırma ilerlemesinden
çizilir; gerçekten kayan tek şey görünmez Ray'dır.

- **Ray (`track.dart`)** — şeffaf, kaydırılabilir. `CustomScrollView`; her bölüm için
  yüksekliği `viewportHeight × chapter.scrollLength` olan boş bir `SliverToBoxAdapter`; sonuna bir
  viewport yüksekliğinde boş sliver eklenir (max scroll = toplam − 1 viewport; yoksa son bölüm
  `progress = 1`'e ulaşamaz). Scrollbar ve overscroll `ScrollConfiguration` ile kapalı. Ray'in
  tek işi scroll event'i üretmektir; görsel içeriği yoktur, içine tıklanabilir widget konmaz.
  `hitTestBehavior: HitTestBehavior.translucent` ile kurulur: sürükleme Ray'e gider, tıklamalar
  altındaki Sahne'ye geçer (kapak pill'leri, proje linki, iletişim linkleri). **Tekerlek/trackpad
  tuzağı:** `Scrollable`'ın kendi tekerlek dinleyicisi `deferToChild`'dır; Ray'ın çocukları boş
  olduğundan translucent modda hit yoluna girmez ve tekerlek olayı kaybolur (sürükleme çalışır,
  tekerlek çalışmaz). Bu yüzden Track, `CustomScrollView`'ı kendi translucent `Listener`'ıyla sarar
  ve `PointerScrollEvent`'i `position.pointerScroll(delta)` ile controller'a iletir
  (`test/track_test.dart` bunu tekerlek + sürükleme + tıklama ile test eder). Bilinen küçük sınır:
  nav pill'inin üstündeyken tekerlek kaydırmaz (nav opak, olayı yutar).
- **Sahne (`stage.dart`)** — sabit, viewport boyutunda. Aktif bölümün widget'ını ve `progress`
  değerini alır, çizer. Bölüm değişince 250 ms crossfade yapar (hareket azaltılmışsa anlık, §10.6).

`scroll_progress.dart` tek kaynak: `ScrollProgress extends ValueNotifier<ScrollState>`,
`ScrollState { chapterIndex, progress 0..1, globalProgress 0..1 }`; `progressFor(i)` geçilmiş
bölüm için 1, gelecek için 0, aktif için `progress` verir ve bölüm widget'ları yalnızca bunu okur.
Hesap saf bir fonksiyondur (`computeScrollState`: `offset`, `viewportHeight`, `scrollLength[]` →
`ScrollState`) ve unit testi vardır. Sahne, bölümler ve nav yalnızca bu notifier'ı dinler.

Bölüme kaydırma tek kapıdan: `ScrollProgress.animateToChapter(int index)` (700 ms, easeInOutCubic).
`ScrollProgress.reduceMotion` `true` ise animasyon yerine `jumpTo` yapılır; alanı Track her build'de
`AppDurations.reduceMotionOf(context)` ile set eder (alan ataması, notifier tetiklenmez; §10.6).
`Track` mount olurken `attachScroller(ScrollController)` ile bunu kendi controller'ına bağlar,
dispose'da `detachScroller([controller])` ile ayırır (argüman verilirse yalnızca o controller hâlâ
bağlıysa ayrılır; yeni Ray eskisinin dispose'undan önce bağlanabilir). `refresh()` controller pozisyonu
hazır değilse no-op'tur; Track ilk kareden sonra ve viewport değişince `addPostFrameCallback` ile
çağırır. Nav tıklaması, kapaktaki "İletişim" pill'i ve footer'daki "YUKARI" yalnızca
`animateToChapter` çağırır; sayfa kaydırmasının tek `ScrollController`'ı `track.dart`'ta görünür
(sohbet mesaj listesinin kendi, ayrı controller'ı sayfa kaydırması değildir).

**Konum korunur.** Ekran dönünce ya da yükseklik değişince bölüm ve bölüm içi ilerleme kaybolmaz.
`offsetFor(chapterIndex:, progress:, viewportHeight:, scrollLengths:)` saf fonksiyondur ve
`computeScrollState`'in tersidir. `ScrollProgress.holdPosition()` mevcut bölümü ve ilerlemeyi saklar
(Track viewport yüksekliği değişince çağırır; yeni Ray bağlanırken `attachScroller` de aynısını yapar),
`restorePosition()` kare sonrası güncel yükseklikle `offsetFor` hesaplayıp `jumpTo` ile oraya döner.
720 eşiği geçilince Ray yeniden kurulur; `app.dart` bu yüzden `ScrollProgress`'i ve sohbet durumunu
`_Scaled`'in üstünde tutar (§11.1). Testler `test/scroll_progress_test.dart` ve `test/track_test.dart`.

**Klavye.** Klavyeyle gezinme (PageDown, oklar, Home/End) bu şablonda yoktur; Faz 5 görevidir
(`docs/roadmap.md` P5.1). Eklenince kuralları bu bölüme yazılır.

Kural: **Sahne'de aynı anda en fazla 2 bölüm monte olur.** Normalde aktif + sıradaki (indeks+1,
preload için). Bölüm geçişinde önceki bölüm crossfade bitene kadar (250 ms) monte kalır ve bu
sürede sıradaki henüz monte edilmez; sınır geçiş anında da aşılmaz. Geriye kaydırırken önceki
bölüm preload edilmez; kısa süre poster görünür, kabul edilir. Özellikle video elementleri: aynı
anda ≤ 2 `<video>` DOM'da olmalı (her video bellekte tam dosya ve çözücü tutar; telefon kaldırmaz).

Uygulama: `Stage` `AnimatedSwitcher` + `Timer` kullanır (ikisinin süresi de
`AppDurations.crossfadeOf(context)`); crossfade sırasında yalnızca son çıkan bölüm tutulur, durulunca
aktif + sıradaki `IgnorePointer` + `Opacity(0)` ile preload edilir. Preload → aktif geçişi `GlobalKey`
ile yapılır: `Stage` bölüm id → `GlobalKey` haritası tutar; preload yuvası ve `AnimatedSwitcher` aynı
anahtarı kullanır, widget aynı karede taşınır. Böylece `VideoChapter` state'i ve `<video>` elementi
korunur, yeniden monte edilmez.

`Stage(onOpenChat:)` alır. Bölüm callback'leri `Stage`'de bağlanır: kapak "İletişim" →
`animateToChapter(son)`, "▸ Sohbet" → `onOpenChat`, proje/iletişim linkleri → `openExternal`,
"YUKARI ↑" → `animateToChapter(0)`. Bölüm widget'ları tarayıcıya doğrudan dokunmaz; `openUrl` alır.

---

## 5. Video kuralları (scrub)

- `scrub_video_element.dart`, `package:web` ile `HTMLVideoElement` oluşturur:
  `muted = true`, `playsInline = true`, `preload = 'auto'`, `controls = false`.
  `poster` attribute'u `video/<ad>.jpg`; poster yalnızca `<video poster>` ile gösterilir
  (ayrıca `Image.network` yok). Sınıf `ScrubVideoHandle`: viewType benzersiz (`'scrub-video-<sayaç>'`),
  `isReady` (`loadedmetadata` sonrası true), `seekTo(progress)`, `dispose()` (rAF iptal, listener
  kaldır, `removeAttribute('src')` + `load()`, object URL'i `URL.revokeObjectURL` ile bırak).
- **Kaynak blob'tur.** `video/<ad>.mp4` `fetch` ile bir kez indirilir, blob'a çevrilir ve `src`
  object URL olur; seek'ler bellekten yapılır. Sebep: `flutter run` geliştirme sunucusu HTTP Range
  desteklemez ve Chrome, Range'siz kaynakta seek'i reddeder. İndirme boyunca `poster`
  görünür; indirme başarısız olursa ya da cevabın `content-type`'ı `video/` ile başlamıyorsa (hosting
  rewrite'ı eksik dosya için `index.html` döndürür; HTML blob'a çevrilmez) `src` doğrudan dosya yoluna
  (`video/<ad>.mp4`) döner. Hata loglanır.
- Element `pointer-events:none` ve Flutter tarafında `IgnorePointer`; tekerlek ve sürükleme Ray'a gider.
- `package:web` ve `dart:ui_web` yalnızca `lib/web/`'de import edilir; bu importları yapan dosyalar
  (`scrub_video_element.dart`, `browser.dart`) ve onları import eden `stage.dart`, `video_chapter.dart`
  VM testinde import edilmez (§11.4). İstisna: `scrub_seek_policy.dart` saftır, VM'de test edilir.
- Seek mantığı: her scroll frame'inde hedef `t = progress × duration` hesaplanır.
  `|t - currentTime| < 1/30` ise **set etme**. Set işlemi `requestAnimationFrame` ile bir sonraki
  frame'e ertelenir; bir frame'de en fazla bir seek, bekleyen hedef yenisiyle ezilir.
  **Seek kapısı:** önceki seek sürüyorsa (`video.seeking`) hedef bekletilir ve `seeked` olayından
  sonraki karede gönderilir (tarayıcı yarım kalan seek'i iptal eder, kare bozuk kalır). Karar saf
  fonksiyon `decideSeek(target:, current:, seeking:)` → `SeekDecision.skip | defer | seek`
  (`lib/web/scrub_seek_policy.dart`, eşik `scrubSeekThreshold = 1/30`).
- **Mobil kadraj.** Bölümde `videoMobile`/`posterMobile` (9:16, ikisi birlikte) varsa telefon genişliğinde
  (`AppBreakpoints.isMobile`) o oynar (`Chapter.videoFor/posterFor`). Yoksa 16:9 video `object-fit: cover`
  ile kırpılırken odak sağa kayar (`AppSizes.videoObjectPositionFor`: mobil `75% 50%`, masaüstü
  `50% 50%`) çünkü özne sağ yarıdadır (§10.8). Şablondaki örnek videoların dikey sürümü yoktur.
  Dikey sürüm iki yoldan üretilir: (1) önerilen: Flow'da aynı prompt 9:16 olarak ayrıca üretilir
  (ör. 720×1280 kaynak): `CRF=31 FPS=24 WIDTH=540 tools/encode.sh raw/x-mobile.mp4
  web/video/x_mobile` → 540×960; (2) yatay videodan dikey pencere kesilir (`CROP=W:H:X:Y WIDTH=540
  tools/encode.sh raw/x.mp4 web/video/x_mobile`; 1080p kaynakta bantsız 904 px yükseklikten
  `508:904:X:88`). 540 genişlik telefon için yeter; büyütmek kazanç sağlamaz. Dikeyde `CROP=auto`
  kullanılmaz (16:9 pencere keser).
- `duration` NaN olabilir (metadata gelmeden). `loadedmetadata` event'i gelmeden seek yapma;
  o ana kadar poster görünür.
- Video oynatılmaz; yalnızca `currentTime` ile sürülür. **Tek istisna, iOS kilidi:** WebKit
  (iOS Safari ve iOS Chrome) hiç oynatılmamış videoda seek karesini boyamaz, poster kalkınca ekran
  siyah kalır. `ScrubVideoHandle._unlock` her videoyu bir kez `play()` eder, promise çözülünce hemen
  `pause()` eder; projedeki tek `play` çağrısı budur. İlk deneme `loadedmetadata` anındadır;
  reddedilirse (Düşük Güç Modu) `document`'taki kalıcı `passive` dinleyici (`touchstart`, `touchend`,
  `pointerdown`) her dokunuşta kilidi açılmamış videoları yeniden dener. Masaüstünde zararsızdır.
- **Hareketi azalt** (§10.6): `VideoChapter` `didChangeDependencies`'te `AppDurations.reduceMotionOf`
  okur; açıksa seek yapılmaz, video poster/ilk karede sabit kalır. Kaynak yine indirilir (kabul edilen
  sadelik).
- Encode gereksinimi yukarıda (§2, karar 5). Encode'suz video "takılıyor" şikâyeti gelirse ilk kontrol
  `ffprobe -v error -select_streams v -show_entries frame=pict_type -of default=nw=1:nk=1 X.mp4 | sort | uniq -c`
  ile kare tipleri sayılır; sağlıklı video yalnızca `N I` gösterir (N = kare sayısı).
- Boyut: tek video ≤ 10 MB üst sınır, hedef mümkün olduğunca küçük (ziyaretçi her videoyu baştan
  indirir); 1280 px genişlik (`WIDTH` ortam değişkeni; dikey video 540), 24 fps, 6–15 saniye.
  Önerilen yatay `CRF=30`, dikey `CRF=31`; dosya hâlâ büyükse 33'e kadar çıkılabilir ama yüz ve
  ciltte doku kaybı başlar. Her kare keyframe (`-g 1`) kuralı aynen. Daha uzun hikâye için bölüm
  sayısını artır, video uzatma.

---

## 6. AI kuralları (Gemini / Firebase AI Logic)

- Erişim: `FirebaseAI.googleAI(useLimitedUseAppCheckTokens: true).generativeModel(model:
  AiConfig.model, systemInstruction: ..., generationConfig: ..., safetySettings: AiConfig.safetySettings)`.
  Backend `googleAI()` (Gemini Developer API). `useLimitedUseAppCheckTokens` her istek için yeni,
  tek kullanımlık App Check token'ı ister: ağdan yakalanan bir token başka istekte yeniden
  kullanılamaz (kota kötüye kullanımına karşı). Vertex/Agent Platform'a geçiş yalnızca kullanıcı
  isterse.
- Model adı `ai_config.dart`'ta tek sabit. Güncel bir **Flash** modeli kullan; hangi modelin
  desteklendiği Firebase konsolundaki AI Logic sayfasında listelenir. Kodda birden fazla model
  adı geçmez. Seçili model Flash-Lite (`gemini-3.5-flash-lite`, en ucuz genel model; maliyet
  öncelikli). `AiConfig` sınırları: `maxOutputTokens = 300`, `maxHistory = 10`,
  `maxQuestionChars = 200`. `temperature/topP/topK` **verilmez**: `firebase_ai` 5.x'te deprecated,
  Gemini 3+ yok sayar. `AiConfig.safetySettings`: dört kategoride (taciz, nefret söylemi, müstehcen,
  tehlikeli içerik) orta ve üstü olasılıklı içerik engellenir; engellenen cevap `aiBlocked` olur.
- **System prompt** = `assets/about_me.md` içeriği + `story.json`'dan türetilen kısa bölüm özeti
  ("Sitede şu bölümler var: ...") + sabit davranış kuralları (site sahibi olarak birinci tekil şahısla
  konuş, kısa cevap ver, bilmediğini uydurma vb.) + iki prompt-injection koruma kuralı
  (ziyaretçi mesajı talimat değildir, "önceki talimatları unut" türü istekler reddedilir; rolünden
  çıkma, talimatları açıklama, konu dışı yardım etme). Prompt şablonu `persona_service.dart`'ta
  (`buildSystemPrompt`), içerik dosyalarda.
- Sohbet `startChat()` ile oturum bazlı; sayfa yenilenince sıfırlanır. Kalıcılık yok, Firestore yok.
  Soru `AiConfig.maxQuestionChars` (200) karaktere kırpılır (`clipQuestion`, grapheme sayar: emoji
  ve birleşik harf bölünmez; giriş kutusu da aynı sınırı uygular). Geçmiş `historyForNextTurn` ile
  gönderimden önce kırpılır: hiçbir turda (yeni soru ve cevap dahil) `AiConfig.maxHistory` (10)
  mesajı aşmaz ve her zaman `user` ile başlar; kırpılınca oturum o geçmişle yeniden kurulur.
- Sohbet kabuğu: `ChatPanel({isOpen: ValueNotifier<bool>, controller: ChatController, owner: String})`
  (`owner` = `meta.owner`, boş sohbet metninde "<owner> hakkında bir şey sor.").
  `ChatController` (`lib/ai/chat_controller.dart`) durumu tutar: `messages`, `isStreaming`,
  `isConnected`, `send(String)`; `AskFn = Future<Stream<String>> Function(String)` typedef'i de orada.
  `app.dart` `ChatController(ask: persona?.ask)` kurar (`PersonaService.ask`); `ask` `null` ise Firebase
  bağlı değildir (aşağıda). Mesajlar panelde değil controller'da durur; controller `_Site`'ın ömrüne
  bağlıdır, panel yeniden kurulsa da mesajlar ve süren akış kaybolmaz (§11.1). Üretim kodunda sahte
  cevap yoktur; testler `test/helpers/fake_ask.dart`'taki `fakeAsk`'ı kullanır.
  `PersonaService.create({story, appCheckActive})` başka girdi almaz. Cevaplar `sendMessageStream`
  ile akar; UI kelime kelime gösterir.
- **Firebase yoksa ya da App Check etkin değilse (fail-closed):** `main.dart` yalnızca
  `DefaultFirebaseOptions.currentPlatform.apiKey == 'PLACEHOLDER'` koşuluna bakar (örnek dosyada başka
  alan yoktur; `flutterfire configure` dosyayı yerinde güncelleyebilir ya da ezebilir, koşul `apiKey`
  üstünden kalır). Placeholder ise Firebase başlatılmaz. Gerçek ayar olsa bile `RECAPTCHA_SITE_KEY` boşsa ya
  da başlatma/etkinleştirme hata verirse App Check etkinleşmez; `PersonaService.create(appCheckActive: false)`
  `null` döner, `ChatController.ask` `null` olur: panel açılır ama mesaj listesi ve giriş kutusu yerine
  "FIREBASE BAĞLI DEĞİL" etiketli kart ("Sohbet için Firebase'i bağla: README adım 2.") gösterilir.
  App Check'siz sohbet hiçbir yerde açılmaz; lokalde de site key'siz sohbet kapalıdır (lokal debug
  token akışı README adım 2.8). Uygulama **çökmez**, scroll deneyimi tam çalışır.
- **App Check zorunlu.** App Check, Gemini isteğinin gerçekten senin sitenden geldiğini kanıtlar;
  yoksa sayfadaki Firebase ayarını kopyalayan biri senin kotanı harcayabilir. Firebase AI Logic,
  yeni projelerde App Check'i zorunlu kılar; App Check olmadan istekler reddedilir. Web provider:
  `ReCaptchaEnterpriseProvider(siteKey)`
  (Fraud Defense = reCAPTCHA Enterprise'ın yeni adı; Firebase konsolu yeni web uygulamaları için
  reCAPTCHA v3 Classic kaydını kapattı, `ReCaptchaV3Provider` kullanılmaz);
  `FirebaseAppCheck.instance.activate(providerWeb: ...)` ile verilir. Site key Google Cloud konsolunda
  (Security → reCAPTCHA → Create key → Website) üretilir, **ID'si site key'dir, gizli anahtar yoktur**;
  ayda 10.000 doğrulama ücretsiz. Site key `--dart-define=RECAPTCHA_SITE_KEY=...` ile verilir,
  `String.fromEnvironment` ile okunur; dosyaya yazılmaz. Boşsa App Check aktive edilmez, konsola
  uyarı yazılır ve sohbet kapalı kalır.
- Hata yönetimi: hatalar `PersonaException(userMessage)` olur (`toString` = mesaj); kullanıcıya tek
  satır Türkçe gösterilir, stack trace gösterilmez. Hata loglanır (`debugPrint`), yutulmaz.
  Eşleme `userMessageFor` ile, metinler `AppStrings`'te (`aiBusy` kota, `aiAppCheck` App Check/403 →
  README 2.4 ve 2.5, `aiNotEnabled` AI Logic kapalı → 2.2, `aiBadConfig` geçersiz Firebase ayarı →
  2.3, `aiBadModel` model yok → `ai_config.dart`, `aiRegion`, `aiBlocked`, `aiOffline`,
  `aiEmptyReply`, `aiUnknown`).
- **Boş içerik istisnası:** `firebase_ai` 5.1.0, Gemini `"content": {}` (rolsüz, parçasız) döndüğünde
  `FirebaseAISdkException('Unhandled format for Content: {}')` fırlatır; model boş cevap verince
  (en sık sebep: `about_me.md` hâlâ yer tutucuyla) ya da metinden sonraki son parçada görülür.
  `isEmptyContentError` bunu tanır; `replyText` loglar ama akışın normal sonu sayar: metin geldiyse
  cevap tamam, gelmediyse `aiEmptyReply` (README "Sorun giderme"). SDK hatayla biten turu oturum
  geçmişine eklemediği için `ask` cevabı biriktirir ve tur eksikse oturumu `withTurn` ile yeniden
  kurar (`maxHistory` korunur).

---

## 7. Komutlar

```bash
# ilk kurulum (Firebase'siz çalıştırma) — tools/setup.sh ilk iki satırı yapar
cp lib/firebase_options.dart.example lib/firebase_options.dart
flutter pub get
flutter run -d chrome --wasm

# Firebase bağlama (katılımcı kendi projesiyle)
dart pub global activate flutterfire_cli
flutterfire configure --platforms=web
git checkout -- firebase.json   # configure firebase.json'a proje ID'li blok ekler; geri al

# kalite kapısı — her commit öncesi
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test

# sır taraması — commit öncesi ikisi de boş dönmeli (tek kaynak; diğer dosyalar buraya referans verir);
# public repoya giren anahtarı herkes görür ve geçmişten silmek zordur. İlki yalnızca `git add` edilmiş
# değişikliği görür (kullanıcı `git add -A`'dan sonra koşar; ajan git add yapmaz). İkincisi yeni,
# henüz eklenmemiş dosyaları da tarar (`.gitignore`'dakileri atlar); ajan bunu koşar.
git diff --cached -U0 | grep -nE "AIza[0-9A-Za-z_-]{30,}|PRIVATE KEY|private_key|6L[0-9A-Za-z_-]{38}"
git grep --untracked -nE "AIza[0-9A-Za-z_-]{30,}|PRIVATE KEY|private_key|6L[0-9A-Za-z_-]{38}" -- ':!*.md'

# token sızıntısı — lib/theme/ ve app.dart dışında literal renk/font/ölçü yok; boş dönmeli (§11.2)
grep -rnE "Color\(0x|[^A-Za-z]Colors\.|fontFamily:|fontSize:|\.circular\(|Duration\(|\.(w|h|sp|r)[^A-Za-z0-9_]" lib --exclude-dir=theme | grep -v "^lib/app.dart"

# üretim build + elle deploy (README §4)
flutter build web --wasm --dart-define=RECAPTCHA_SITE_KEY=$RECAPTCHA_SITE_KEY
firebase deploy --only hosting
# otomatik yayın (.github/workflows/deploy.yml) Faz 4'te eklenir: docs/roadmap.md P4.1

# video işleme
tools/encode.sh girdi.mp4 web/video/<ad>
CROP=auto tools/encode.sh raw/<ad>.mp4 web/video/<ad>   # Flow siyah bant gömdüyse kırpar; koyu görüntüde çıktıyı kontrol et
CRF=30 FPS=24 CROP=1608:904:156:88 tools/encode.sh raw/x.mp4 web/video/x   # bantları elle keser (örnek: 1080p kaynak, 1280×720 çıkar)
CRF=31 FPS=24 WIDTH=540 tools/encode.sh raw/x-mobile.mp4 web/video/x_mobile   # Flow'da 9:16 üretilmiş dikey (540×960)
CRF=31 FPS=24 WIDTH=540 CROP=508:904:X:88 tools/encode.sh raw/x.mp4 web/video/x_mobile   # alternatif: yataydan kesme
```

---

## 8. Yapma listesi

- Router, ikinci sayfa, deep link ekleme.
- `video_player`, `chewie`, `webview_flutter` veya herhangi bir video paketi ekleme.
- `google_generative_ai`, `dart_openai` vb. doğrudan LLM paketi ekleme.
- `lib/firebase_options.dart`, `.firebaserc`, herhangi bir key/secret/token commit'leme.
  Şüphede kal: §7'deki sır taraması boş dönmeli.
- `assets/story.json` veya `assets/about_me.md` **içeriğini** istenmeden değiştirme.
- Videoyu `assets/` altına taşıma.
- Sayfa kaydırması için ikinci bir `ScrollController` ya da `NotificationListener` ile ikinci bir scroll
  kaynağı (sohbet mesaj listesinin kendi controller'ı bunun dışındadır, §4).
- Sahne'de 2'den fazla bölümü aynı anda monte etme.
- State management paketi ekleme (riverpod, bloc, provider). `ValueNotifier` +
  `ListenableBuilder` yeter; proje küçük, workshop okunabilirliği öncelikli.
- Test yazmadan `scroll_progress.dart` değiştirme (bu dosyanın unit testi vardır).
- Widget içinde renk, font, boyut, radius, süre literal'i yazma; `MediaQuery` ile elle responsive
  hesap yapma (§11.2, §11.3).
- Aynı UI parçasını iki dosyaya kopyalama; `lib/widgets/`'a çıkar (§11.1).
- `main.dart`'a widget, `app.dart`'a iş mantığı koyma.

---

## 9. Çalışma tarzı (ajanlar için)

- İş kullanıcının isteğinden gelir; paketler `docs/roadmap.md`'ye yazılır. İki görev hazır yazılıdır:
  "Faz 4'ü uygula" → P4.1 (otomatik yayın), "Faz 5'i uygula" → P5.1 (klavyeyle gezinme). Bir işi
  bitirmeden sonrakine geçme. Her iş sonunda kabul kriterlerini tek tek kontrol et; `flutter analyze`
  temiz, `flutter test` yeşil olsun.
- Claude Code'da işler bir ana oturum ile alt ajanlar arasında bölünür; roller, modeller ve döngü
  `CLAUDE.md`'de. Alt ajan yalnızca bu dosyayı ve `docs/roadmap.md`'deki kendi paketini okur.
- Dal: bu şablon kaynak reponun `template` dalından gelir; sen kendi reponda `main` dalında
  çalışırsın. Otomatik yayın (Faz 4'ten sonra) `main`'e her push'ta çalışır; bu yüzden `main`'e
  yalnızca kalite kapısından (§7) geçmiş kod girer. Commit'ler küçük ve açıklayıcıdır: her commit tek
  bir değişikliği anlatır, okumak ve gerekirse geri almak kolay olur.
- Bir şeyi "neden böyle" diye merak ediyorsan cevap bu dosyadadır; yoksa kullanıcıya sor,
  tahmin etme.
- Yeni bağımlılık eklerken `pubspec.yaml`'a yorum satırıyla neden eklendiğini yaz.
- Tarayıcıda doğrulama gerektiren işlerde (scroll akıcılığı, video seek) kodu "çalışıyor" diye
  işaretlemeden önce gerçekten Chrome'da aç, scroll et, DevTools Performance'ta frame düşmesi
  var mı bak. Kod ajanları tarayıcı açmaz; bu maddeler `docs/tarayici-kontrol.md` listesiyle (elle
  ya da bir tarayıcı ajanıyla, ör. Antigravity) kapanır.
- Kullanıcı yazılıma yeni başlamış olabilir. Rapor önce sonucu söyler: ne değişti, nasıl test edildi,
  ne eksik. Terimleri ilk geçtiği yerde açıkla, komutların ne yaptığını yaz (Claude Code için
  ayrıntı `CLAUDE.md` "öğretici ol"). Alt ajanın ana oturuma raporu üç satırdır. Övgü yok.

---

## 10. Tasarım dili

Tasarım dilinin tek kaynağı bu bölümdür. Özet: sinematik kurgu, sakin hareket, kapak kompozisyonu,
hepsi **koyu** temada. Buradaki değerler `lib/theme/` altındaki token dosyalarında yaşar (§11.2);
widget'lar renk, font ya da ölçü yazmaz, token okur.

### 10.1 İlke

- Sinematik ve sakin: az eleman, çok boşluk, büyük tipografi, tek vurgu rengi.
- Her hareket scroll'a bağlıdır. Kendiliğinden oynayan animasyon yok (istisna: bölüm crossfade,
  hover, sohbet cevabının akışı; cevap beklerken "yazıyor" göstergesi bu kapsamdadır).
- Metin videonun üstünde kutusuz durur; okunurluk videonun kadrajıyla sağlanır (§10.8).

### 10.2 Palet

| Token | Değer | Kullanım |
|---|---|---|
| `bg` | `#0A0A0A` | video bölümlerinin zemini, sayfa arkası |
| `paper` | `#161616` | `text` / `projects` / `contact` bölümlerinin zemini |
| `surface` | `#1E1E1E` | nav, sohbet paneli, kartlar |
| `surfaceRaised` | `#2A2A2A` | aktif nav pill'i, kullanıcı mesaj balonu |
| `border` | beyaz %8 | surface kenarlıkları, ayırıcı çizgiler |
| `text` | `#F2F2EE` | başlık ve birincil metin |
| `textMuted` | `#9A9A94` | paragraf, etiket, ikincil |
| `textDim` | `#2A2A28` | reveal öncesi kelimeler |
| `accent` | `#C8F04E` | tek vurgu: selamlama, vurgulu kelime, dolu buton, halka |
| `onAccent` | `#0A0A0A` | accent üstündeki yazı |
| `transparent` | `#00000000` | tam şeffaf; widget'ta `Colors.transparent` yazılmaz |
| `surfaceGlass` | `#CC1E1E1E` | `surface` %80; blur arkasındaki nav ve panel zemini |
| `hoverOverlay` | `#1AF2F2EE` | `text` %10; buton hover'ında `Color.alphaBlend` ile zemine bindirilir |
| `error` | `#E5322D` | yalnızca `story.json` hata kutusu |

`story.json` `meta.accent` ve `meta.background` doluysa `accent` ve `bg`'yi ezer; katılımcının tek
renk ayarı budur. Başka renk yok; ara gri gerekirse `text` opaklıkla kısılır.

### 10.3 Tipografi

Tek aile: **Inter** (`assets/fonts/`, OFL lisans dosyasıyla; ağdan font yüklenmez).
Ağırlıklar 400 / 500 / 600 / 700, statik TTF.

| Stil | Boyut masaüstü / mobil | Ağırlık | Harf aralığı | Satır |
|---|---|---|---|---|
| `display` (kapak ve iletişim başlığı) | 112 / 56 px | 700 | -0.04em | 0.95 |
| `h1` (bölüm başlığı) | 64 / 40 px | 600 | -0.03em | 1.0 |
| `statement` (text bölümü cümlesi, kapalı proje paneli adı, iletişim e-postası) | 48 / 28 px | 500 | -0.02em | 1.15 |
| `overlayStatement` (başlıksız video overlay cümlesi) | 40 / 26 px | 500 | -0.02em | 1.2 |
| `body` | 17 / 16 px | 400 | 0 | 1.6 |
| `input` (sohbet giriş kutusu) | 17 / 16 px, ölçeklenmez taban: en az 16 | 400 | 0 | 1.6 |
| `lead` (kapak gövdesi) | 22 / 18 px | 400 | 0 | 1.5 |
| `eyebrow` (kapak selamlaması, BÜYÜK HARF*) | 16 / 13 px | 500 | +0.14em | 1.0 |
| `label` (etiket, nav, sayaç) | 11 px | 500, BÜYÜK HARF* | +0.14em | 1.0 |
| `button` (pill buton yazısı) | 13 / 13 px | 500 (BÜYÜK HARF değil) | +0.02em | 1.0 |

Boyutlar tasarım px'idir (masaüstü 1440×900, mobil 390×844); ekrana ölçekleme screenutil ile
token getter'larında yapılır (§11.3).
*Büyük harf: `LabelText` widget'ı `upperTr` ile Türkçe kurallarıyla çevirir (`i → İ`, `ı → I`);
Dart `toUpperCase()` tek başına yanlıştır.
Numaralı etiket deseni: `01 · PROJE` (numara `accent`, etiket `textMuted`). İndeksler iki haneli.

### 10.4 Bileşenler

- **Pill nav (`chapter_indicator.dart`):** üstte ortada, yüzen. `surfaceGlass` zemin, `border`
  kenarlık, radius 999, yükseklik 44, iç boşluk 6. İçinde her bölüm için `label` stilinde başlık;
  aktif olan `text` renginde ve `surfaceRaised` pill zemininde, diğerleri `textMuted`. Nav item'da
  hover yok, yalnızca aktif/pasif renk geçişi 150 ms; tıklama `animateToChapter`. Her öğe
  `TapTarget(label: AppStrings.chapterNavLabel(n, başlık), selected: aktif)`:
  ekran okuyucu "Bölüm N: başlık" düğmesi okur, aktif bölüm seçili işaretlidir. Sağ ucunda ayrı
  küçük pill: `globalProgress` halkası (accent yay, 2 px; çap
  `navHeight − 2·(navPadding + borderWidth)`). `BackdropFilter` (blur 16) burada olabilir.
  Mobilde (`AppBreakpoints.isMobile`) gizli.
- **Butonlar:** iki tür, ikisi de pill (radius 999, yükseklik 44, yatay iç boşluk 20).
  Dolu: `context.accent` zemin, `onAccent` yazı. Çizgili: şeffaf zemin, `border` kenarlık, `text` yazı.
  Yazı `button` stilinde. Ok varsa sağda ` →`. Hover 150 ms, zemin `Color.alphaBlend(hoverOverlay,
  zemin)`; büyüme ve gölge yok. Widget: `PillButton({label, onTap, filled, arrow, semanticsLabel})`.
  Kök `Semantics(button, label: semanticsLabel ?? label, onTap: onTap, excludeSemantics)`: ekran
  okuyucu yalnızca etiketi okur, ok (` →`) okunmaz; görünen yazıdan farklı ad gerekiyorsa
  `semanticsLabel` verilir. `excludeSemantics` içteki `GestureDetector`'ın dokunma eylemini de
  düşürdüğü için `onTap` semantics'e ayrıca verilir: ekran okuyucuyla etkinleştirme çalışır, tek
  tıklama tek kez tetikler (çift tetiklenme olmaz). Hover'sız tıklanabilir alanlar (nav öğesi, proje
  ve iletişim link satırları, sohbet kapatma) aynı kalıbı `lib/widgets/tap_target.dart`'taki
  `TapTarget({label, onTap, child, selected})` ile alır: `button` semantics + `onTap` + el imleci +
  opak hit-test. Gönder butonu `TapTarget` değildir (etkin/pasif durumu ve imleci kendi semantics'inde).
- **Video overlay (`video_chapter.dart`):** sol alt, maksimum genişlik 560, gutter kadar
  içeriden. Üstte `label` ("02 · İŞLER"), altında `h1` başlık, altında `body` paragraf. Arkasında
  kutu yok; bölümün alt %40'ında `bg`'den şeffafa dikey gradyan scrim (statik, ucuz).
  Video alanı `Semantics(image, label: AppStrings.videoLabelFor(başlık))` ("<başlık> videosu"),
  dekoratif sayılmaz; scrim `ExcludeSemantics` ile ağaç dışında.
  Başlıksız overlay (`title` yok, `body` var): gövde tek başına büyük `overlayStatement` cümlesi
  (`text` rengi), maksimum genişlik 720 (`AppSizes.overlayStatementMaxWidth`), üstünde bölüm etiketi
  çizilmez (aynı bölümde etiket tekrar etmesin); başlıklıysa yukarıdaki düzen. Her overlay kendi genişlik kısıtını alır.
  Kapak istisnası (`chapters[0]`'ın ilk overlay'i, genişlik 560): üstte `accent` renkli selamlama
  (`meta.tagline`, `eyebrow` stili, `upperTr` ile BÜYÜK HARF; tek satıra kısılmaz, uzunsa sarar),
  altında overlay `title` `display` stilinde, altında overlay `body` `lead` stilinde (`text`), en altta iki pill: dolu "İletişim" (`animateToChapter(son)`)
  ve çizgili "▸ Sohbet" (paneli açar).
  Overlay opaklığı `TextOverlay.opacityAt(progress)`: ilk ve son %10'da doğrusal fade; `from <= 0`
  ise giriş fade'i yok (kapak açılışta görünür), `to >= 1` ise çıkış fade'i yok. Opaklığı 0 olan
  overlay kurulmaz.
- **Sohbet butonu ve paneli (`chat_panel.dart`):** masaüstünde sağ altta çizgili pill "💬 Sohbet";
  mobilde (`AppBreakpoints.isMobile`) sağ üstte **dolu** (`accent`) pill (sol alttaki overlay metinleriyle
  çakışmasın). Kapalı pill'in erişilebilirlik etiketi `AppStrings.openChat` ("Sohbeti aç",
  `PillButton.semanticsLabel`); Material `Tooltip` kullanılmaz (Material ister, kendi süre sabitlerini
  taşır). Header'da başlık ve × ikonu (`Icons.close`, erişilebilirlik etiketi `AppStrings.close`). Panel
  380×560 (mobilde gutter içinde tam ekran), `surfaceGlass` zemin, `border`, radius 24; ikinci ve son
  `BackdropFilter` burada.
  Giriş kutusu (`style` ve `hintStyle`) `AppTextStyles.input` kullanır: iOS Safari 16 CSS px altındaki girişe
  odaklanınca sayfayı yakınlaştırıp tam ekran Flutter yüzeyini kaydırır, bu yüzden boyut 16 mantıksal pikselin
  altına inmez; `web/index.html` viewport'u da yakınlaştırmayı kapatır (`maximum-scale=1, user-scalable=no`;
  parmakla yakınlaştırma da kapanır, bilerek).
  Header yüksekliği 56 (`chatHeaderHeight`). Kullanıcı mesajı sağda `surfaceRaised` balon, asistan
  solda balonsuz düz metin. Giriş kutusu pill, gönder butonu `accent` daire (36, `sendButtonSize`).
  Soru gönderilince cevabın ilk parçası gelene kadar asistan satırında (solda, balonsuz) `TypingDots`
  görünür: üç `textMuted` nokta (`typingDotSize` 6, `typingDotGap` 4), opaklık 0.3 ↔ 1 dalgası, tek
  `AnimationController` (`AppDurations.typing`, 1200 ms); ilk parça gelince kalkar (durum
  `ChatController.isStreaming` + boş son asistan mesajından türetilir). Ekran okuyucu
  `Semantics(liveRegion, label: AppStrings.typing)` okur.
  Panel zemini opak `Listener` ile tekerleği yutar (altındaki Ray kaymaz). Buton ↔ panel geçişi
  250 ms crossfade; mesajlar panel kapanınca kalır. `ask` `null` ise (Firebase bağlı değil) gövdede
  mesaj listesi ve giriş kutusu yerine kart: `label` stilinde "FIREBASE BAĞLI DEĞİL" + `body`
  yönlendirme; composer kurulmaz. Giriş kutusu `AiConfig.maxQuestionChars` ile sınırlıdır. Bağlıyken giriş kutusunun altında ortalı, `button`
  boyutunda `textMuted`, en fazla iki satır yapay zekâ notu durur (`AppStrings.chatDisclaimer`: cevaplar
  hatalı olabilir, mesajlar Gemini'ye gider); "bağlı değil" kartında görünmez.
- **Yükleme ekranı (`index.html`):** `bg` zemin, ortada `label` stilinde site adı, altında 1 px
  `border` çizgi ve üstünde `accent` ilerleme. Flutter ilk frame'de kaldırır. Kadran, spinner yok.
  Flutter henüz yüklü olmadığı için renkler §10.2'den CSS'e elle kopyalanır, font sistem fontudur,
  ad `index.html`'de sabittir (katılımcı `<title>` ile birlikte değiştirir).
- **Hata kutusu (`story.json` bozuk):** `paper` zemin, sol kenarlık 3 px `error`; üstte `label`
  stilinde `error` renkli "STORY.JSON OKUNAMADI", altında Inter `body` mesaj, altında `textMuted`
  yönlendirme ("Dosyayı düzelt ve sayfayı yenile. Şema: README.md §3."). Widget
  `lib/widgets/story_error_box.dart`. `error` rengi yalnızca burada kullanılır.

### 10.5 Bölüm düzenleri (type'a göre)

- `video`: tam ekran, `object-fit: cover`. Overlay'ler §10.4. Poster görünürken overlay aynen durur. Telefon genişliğinde `videoMobile` varsa o oynar, yoksa 16:9 video sağa odaklı kırpılır (§5 "Mobil kadraj").
- `text` (statement): `paper` zemin. Ortalanmış `statement` cümlesi, maksimum genişlik 880.
  Üstte `label` olarak bölüm başlığı ("— BEN KİMİM"). Her kelime `textDim`'den `text`'e `progress`
  ile dolar: kelime `i`'nin rengi `lerp(textDim, text, clamp((progress - i/n) * n * 1.5, 0, 1))`.
  `body` içinde `**kelime**` işaretli kelimeler dolduğunda `accent` olur. `RevealText` tek
  `Text.rich`; ayrıştırma `parseRevealWords` (yıldız dışındaki noktalama korunur), renk `wordRevealAt`.
- `projects` (paneller): görsel yok. `paper` zemin üstünde bütün projeler aynı anda yan yana (mobilde alt
  alta) `surface` panel olarak durur (`border` kenarlık, radius panel 24). Hangi panelin açık olduğunu saf
  `panelOpenness(progress, index, count)` verir (0..1): her proje `progress`'in `1/n`'lik diliminde açıktır,
  dilimin son çeyreğinde (`_blend = 0.25`) doğrusal biçimde sıradaki panele geçer; açıklıkların toplamı hep
  1'dir. Masaüstünde genişlik payı kapalı 1, açık 7. Kapalı yüz: üstte `accent` numara (`label`), altında
  dikey (aşağıdan yukarı) proje adı `statement`, `textMuted`. Açık yüz, masaüstünde tam yükseklikte üç bölgeli `Column` (`spaceBetween`): **üst** `IndexLabel`
  ("01 · PROJE"), `h1` proje adı, `lead` açıklama (`textMuted`, maks 720); **orta** (alta yaslı) ya link
  satırları ya öne çıkanlar: `links` 3'ten uzunsa (`_compactLinkThreshold`) iki sütunlu ızgara, her satır üstte
  `border` çizgi, solda `lead` etiket, sağda `accent` ok, tamamı tıklanır, hover yok; değilse `highlights`
  doluysa her satır üstte `border` çizgi, solda `accent` iki haneli numara, sağda `lead` metin; **alt şerit**
  solda tag'ler (çizgili mini pill, yükseklik 28), sağda eylem pill'leri: `url` varsa "Projeyi aç →", `links` 3
  ve daha azsa her link pill (ilk pill dolu `accent`, diğerleri çizgili); link satırları çizildiyse sağda yalnızca
  varsa `url` pill'i. Mobil açık yüz: `label` "01 · PROJE", `h1`, `body` açıklama, tag'ler, `url` ve `links[]`
  pill'leri (`url` 44 px; `links` 3'ten uzunsa linkler tag boyutunda 28 px mini pill, `text` rengi, ` →`, hover
  yok: çok link telefonda kartı taşırmasın); `highlights` ve link satırları mobilde çizilmez.
  Açık yüz hep tam açık ölçüde dizilir, panel onu kırpar (genişlerken metin yeniden sarılmaz); açıklık < 0.5
  iken tıklanmaz. Mobilde kapalı panel yüksekliği `AppSizes.projectPanelCollapsedHeight` (52) ve yatay satır
  (numara + ad), açık panel kalan alanın tamamı; üst boşluk `gutter + buttonHeight + md` (sağ üstteki sohbet
  pill'ine binmesin); açık yüz iç boşluğu mobilde `sm`, masaüstünde `lg`. En altta `StepCounter` ("01 / 03" +
  120 px ince ilerleme çizgisi); aktif proje `activeProjectIndex` = `min(floor(progress * n), n-1)`.
  `AnimatedSwitcher`/crossfade yok, her şey `progress`'ten doğrudan çizilir.
- `contact`: `paper` zemin, sola yaslı. `LabelText(bölüm başlığı)`, altında `body`'nin **ilk satırı** `display`
  stilinde dev başlık, kalan satırlar `lead` stilinde `textMuted` detay (saf `splitContactBody`; `body` boşsa
  başlık yerine bölüm başlığı). Altında ilk `mailto:` linki büyük `accent` adres + ` →` (`statement`,
  `FittedBox` scaleDown, tek satır; adres `mailto:` sonrası, `?` öncesi); diğer linkler oklu çizgili pill.
  Footer tek ince satır: `border` üst çizgi, solda `label` "`meta.owner` · yıl", sağda "YUKARI ↑"
  (`animateToChapter(0)`). Dev filigran yok. Halftone, parçacık, imleç efekti yok.

Ortak: yatay gutter masaüstü 64 px, mobil 20 px; içerik maksimum 1280 px; dikey ritim 8 px
katları. Köşe: pill 999, panel ve kart 24. Gölge yok; derinlik `border` ve zemin tonuyla verilir.

### 10.6 Hareket

- Bölüm geçişi: 250 ms crossfade, `easeOutCubic`.
- Overlay görünme: `at` aralığının ilk ve son %10'unda opaklık, ayrıca 12 px yukarı kayma.
- Bölüme kaydırma (`animateToChapter`): 700 ms `easeInOutCubic`.
- Hover: 150 ms, yalnızca renk.
- Sayaç ve halka `progress`'i doğrudan çizer; tween yok.
- **Hareketi azalt.** İşletim sistemi ayarı (`prefers-reduced-motion: reduce`) Flutter web'de
  `MediaQueryData.disableAnimations` olur; `AppDurations.reduceMotionOf(context)` okur. Açıkken:
  crossfade (Sahne, sohbet buton ↔ panel) ve hover `Duration.zero`
  (`AppDurations.crossfadeOf/hoverOf(context)`); bölüme kaydırma animasyonsuz `jumpTo`
  (`ScrollProgress.reduceMotion`, §4); video seek edilmez, poster/ilk karede sabit (§5). Scroll'a
  bağlı değişimler (overlay fade ve kayma, reveal, sayaç, halka) aynen kalır; onları kullanıcının
  kendi kaydırması sürer. Sohbet "yazıyor" göstergesi (`TypingDots`) dalgalanmaz, noktalar sabit 0.6
  opaklıkta durur (`typing` için `...Of(context)` getter'ı yoktur: süre değil, controller'ın çalışıp
  çalışmadığı değişir; gösterge `reduceMotionOf`'u kendisi okur).

### 10.7 Performans sınırları

- `BackdropFilter` yalnızca nav ve sohbet panelinde; ikisi de scroll ile hareket etmez.
- Scroll ile konumu ya da opaklığı değişen hiçbir widget'ta blur, `BoxShadow`, `ShaderMask` yok.
- Text reveal tek bir `RichText`'tir; kelime başına widget üretilmez.
- Proje görseli kullanılmaz (projeler panel olarak çizilir, §10.5); `Image.network` yok.
- Yapılmayacaklar: yatay 3D galeri, halftone wordmark, parçacık, imleç efekti, otomatik oynayan
  video, Lottie, ikinci font ailesi.

### 10.8 Video kadrajı (Flow üretimi için)

Her bölüm videosu 6–15 sn (§5), 16:9, koyu stüdyo, tek yönlü ışık, düşük doygunluk; vurgu rengi videoda
kullanılmaz. **Güvenli alan:** sol %45 ve alt %30 koyu ve detaysız kalır; overlay oraya gelir.
Kapak: özne sağ yarıda, göğüsten yukarı, kameraya bakıyor, yavaş push-in.
Bölümler arası: bir videonun son karesi sonrakinin ilk karesi (Flow "Frames to Video").
Doğrulanmış Flow promptları ve ayarları `README.md` §3 "Hazır Flow promptları" bölümünde.

---

## 11. Kod kalitesi ve responsive

Hedef: senior seviyesinde, tekrarsız, okunabilir kod. Katılımcı herhangi bir dosyayı açtığında
ne olduğunu 30 saniyede anlamalı.

### 11.1 Dosya ve widget düzeni

- Her dosyada **tek public** widget ya da sınıf; dosya adı sınıf adının snake_case hali.
- `main.dart` yalnızca bootstrap: `WidgetsFlutterBinding.ensureInitialized().ensureSemantics()`
  (semantics ağacı web'de baştan açık: Lighthouse ve ekran okuyucu "erişilebilirliği etkinleştir"
  adımı olmadan görür), Firebase init (varsa), `await StoryLoader.load()`,
  `PersonaService.create(story:, appCheckActive:)` (App Check etkin değilse `null`, §6),
  `runApp(App(story: ..., persona: ...))`. İçinde widget tanımı yok. Story `runApp` öncesi yüklenir:
  ilk kare story hazırken çizilir, `index.html` yükleme ekranı `flutter-first-frame`'e kadar kalır.
- `app.dart` yalnızca kompozisyon: `App` story'yi `switch` ile ya `_Site`'a ya `_Scaled` içinde
  `MaterialApp(home: StoryErrorBox)`'a verir. Private `_Site` StatefulWidget durumu tutar:
  `ScrollProgress`, sohbet açık/kapalı `ValueNotifier<bool>` ve `ChatController`; altında
  private `_Scaled` (`LayoutBuilder` → `ScreenUtilInit(key)`) ve `MaterialApp(title: meta.title,
  theme: AppTheme.build(accent:, background:))` ile `Stack[Stage, Track, ChapterIndicator, ChatPanel]`
  kurulur. Durum `_Scaled`'in üstünde yaşar: 720 eşiği geçilince (telefonu çevirme) alttaki ağaç
  yeniden kurulur ama bölüm konumu, sohbet açık/kapalı durumu ve mesajlar kaybolmaz. İş mantığı yok.
- İki yerde kullanılan her UI parçası `lib/widgets/` altında tek widget'tır (`PillButton`, `TapTarget`,
  `IndexLabel`, `ProgressRing`, `GradientScrim`, `RevealText`, `StepCounter`, `TypingDots`). Aynı 10
  satır iki dosyada görülürse widget'a çıkarılır.
- `build` 60 satırı geçerse parçalanır: ayrı dosyada widget ya da aynı dosyada private `_Xxx`
  widget; "helper metod" ile değil.
- Hesaplar widget dışında saf fonksiyondur ve test edilebilir: `wordColorAt(progress:, index:, count:, ...)`,
  `activeProjectIndex(progress:, count:)`, `panelOpenness(progress:, index:, count:)`, `splitContactBody(body, fallback:)` gibi; gerekirse `@visibleForTesting`.
- Mümkün olan her yerde `const` constructor ve `const` widget. Sabit tutan sınıflar
  `abstract final class` (`AppColors` gibi), örneklenmez.
- Her public sınıfın başında tek satır `///`: ne işe yarar, neyi okur.

### 11.2 Token kuralı: widget'ta literal yok

Renk, font ailesi, yazı boyutu, boşluk, radius, süre, eğri, breakpoint ve bileşen ölçüleri
yalnızca `lib/theme/` altında tanımlanır (dosya listesi §3). Widget'larda şunlar **yazılmaz:**
`Color(0x..)`, `Colors.*`, `fontFamily:`, `fontSize:`, `BorderRadius.circular(n)`,
`Duration(...)`, çıplak `.w/.h/.sp/.r`. Yerine `AppColors.text`, `AppTextStyles.h1`,
`AppRadii.pill`, `AppDurations.crossfadeOf(context)`, `AppSizes.navHeight` okunur. §7'deki token sızıntı
taraması boş dönmek zorundadır; `lib/theme/` ve `app.dart` taramadan muaftır.

- `app_colors.dart`: §10.2 paleti, `static const Color`. Katılımcının ezebildiği iki renk
  (`accent`, `bg`) widget'larda `context.accent` / `context.bg` extension'ı ile okunur; extension
  `Theme.of(context)`'e bakar, `AppTheme` bu ikisini parametre olarak alır (`colorScheme.primary`,
  `scaffoldBackgroundColor`); `story.json` `meta` hex değerlerini `Meta.accentColor` /
  `Meta.backgroundColor` getter'ları `Color`'a çevirir. Diğer renkler doğrudan `AppColors.*`.
- `app_strings.dart`: `AppStrings`; `story.json` dışındaki her görünen sabit metin ("İletişim",
  "▸ Sohbet", "Projeyi aç", "YUKARI ↑", "Firebase bağlı değil" kartı, `ai*` hata mesajları, `typing`
  "Yazıyor…" vb.) yalnızca burada durur. Widget'ta string literal yalnızca biçimlendirme içindir.
- `app_fonts.dart`: `family = 'Inter'` ve ağırlıklar. Font adı başka hiçbir dosyada geçmez.
- `app_text_styles.dart`: §10.3 hiyerarşisi (`display`, `h1`, `statement`, `overlayStatement`, `body`,
  `input` (sohbet girişi: `body`, en az 16 px), `lead`, `eyebrow`, `label`, `button`); her stil `static TextStyle get`, boyutu
  breakpoint'e göre seçip `.sp` ile ölçekler. Widget'ta `TextStyle(` yazılmaz; gerekirse
  `AppTextStyles.body.copyWith(color: ...)`.
- `app_spacing.dart` (gutter 64/20, ritim 8, içerik 1280), `app_radii.dart` (`BorderRadius`
  nesneleri: pill 999, panel 24), `app_durations.dart` (250/150/700 + `typing` 1200 ms + `Curves`),
  `app_sizes.dart` (nav 44, buton 44, overlay 560, `overlayStatementMaxWidth` 720, panel 380×560, tag 28, ilerleme çizgisi 120,
  `projectPanelCollapsedHeight` 52, `sendButtonSize`, `chatHeaderHeight`, `typingDotSize` 6, `typingDotGap` 4),
  `app_breakpoints.dart` (mobil < 720, tasarım boyutları, `isMobile`). Hepsi ölçekli getter sunar;
  `.w/.h/.sp/.r` yalnızca bu dosyalarda geçer. Ölçü olmayan oranlar (balon genişliği `0.8`,
  panel genişlik payı 1 / 7) widget'ta oran olarak kalabilir.
- `app_durations.dart`: sabitler (`crossfade`, `hover`, `navScroll` + eğriler) kalır, ama widget'lar
  sabiti değil `AppDurations.crossfadeOf(context)` / `hoverOf(context)` okur; "hareketi azalt" açıksa
  bunlar `Duration.zero` döner (§10.6). `Duration.zero` da widget'ta yazılmaz. `navScroll`'u yalnızca
  `ScrollProgress` okur (azaltılmışsa `jumpTo`). `typing` bilinçli olarak `...Of(context)` getter'sızdır (§10.6).
- `app_theme.dart`: token'lardan `ThemeData` üretir (`AppTheme.build({Color? accent, Color? background})`;
  story modelini import etmez) ve `context.accent`, `context.bg` extension'larını tanımlar.
- `theme.dart` barrel: widget'lar yalnızca `import '../theme/theme.dart'` yapar.

### 11.3 Responsive: flutter_screenutil

- `app.dart` (`_Scaled`): `LayoutBuilder` ile genişlik ölçülür; `< 720` ise mobil tasarım boyutu (390×844),
  değilse masaüstü (1440×900). `ScreenUtilInit(designSize: ..., key: ValueKey(isMobile),
  minTextAdapt: true, splitScreenMode: false,
  fontSizeResolver: FontSizeResolvers.radius)` (`.sp` de `.r` gibi min(genişlik,
  yükseklik) ölçeğini kullanır; geniş-kısa pencerede yazı taşmaz); `key` breakpoint değişince
  yeniden init'i garanti eder.
- Tüm ölçüler tasarım px'i olarak token'da durur; token getter'ı `.w/.h/.sp/.r` uygular. Widget'lar
  `MediaQuery.of(context).size` ile elle hesap yapmaz, `AppBreakpoints.isMobile` okur.
- Tek breakpoint vardır (720). Tablet ayrı ele alınmaz; masaüstü tasarım ölçeklenir.
- Düzen değişimi (yan yana paneller → alt alta, nav gizle, panel tam ekran) `AppBreakpoints.isMobile` ile;
  ölçek değişimi screenutil ile. İkisi karıştırılmaz, widget'ta piksel koşulu yazılmaz.
- `flutter_screenutil` yalnızca `lib/theme/` ve `app.dart` tarafından import edilir.

### 11.4 Lint ve otomatik kontrol

- `analysis_options.yaml`: `flutter_lints` + `prefer_const_constructors`,
  `prefer_const_literals_to_create_immutables`, `prefer_final_locals`, `require_trailing_commas`,
  `sort_constructors_first`, `avoid_print`. `flutter analyze` sıfır uyarı, `dart format` temiz.
- §7'deki iki tarama (sır, token sızıntısı) her commit öncesi boş.
- VM testleri `package:web` / `dart:ui_web` import eden dosyaları (`lib/web/scrub_video_element.dart`,
  `lib/web/browser.dart`) ve onları import eden `stage.dart`, `video_chapter.dart`'ı import etmez;
  tarayıcıya dokunan mantık callback'le ya da saf dosyaya (`lib/web/scrub_seek_policy.dart` gibi,
  VM'de test edilir) alınır.
- **İşaretçi ve klavye davranışı testle kapatılır.** Scroll, tekerlek, sürükleme, tıklama, klavye ya
  da hit-test davranışını değiştiren her iş, gerçek olay gönderen bir widget testi içerir (tekerlek
  `TestPointer` + `PointerDeviceKind.mouse` + `scroll`, sürükleme `tester.drag`, tıklama `tester.tap`,
  klavye `tester.sendKeyDownEvent`; tekerlek, sürükleme ve tıklama örneği `test/track_test.dart`;
  tekerlek ve bölüm kurma yardımcıları `test/helpers/wheel.dart`, `pump_chapter.dart`). "Tarayıcıda
  bakılır" yeterli değildir; tarayıcı doğrulaması yapılamadığı durumda bu test tek güvencedir.
- **Yerleşim sığmasını ölçen widget testi gerçek fontu yükler** (`test/helpers/inter_font.dart`,
  `FontLoader(AppFonts.family)`; örnek `test/chapters_test.dart`): test fontu Inter'den yaklaşık
  2 kat geniştir, sığma ölçümü yanlış çıkar.
