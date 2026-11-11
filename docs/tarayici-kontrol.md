# Tarayıcı kontrol listesi

Kod ajanları tarayıcı açmaz; scroll akıcılığı, video ve dokunma davranışı burada elle (ya da bir tarayıcı
ajanıyla) doğrulanır. Pointer ve klavye davranışının asıl güvencesi `flutter test`'tir (`AGENTS.md` §11.4);
bu liste testin göremediği şeyleri kapatır. Maddeler `- [ ]`; geçeni işaretle, kalanın yanına nedenini yaz.
Hazır tarayıcı ajanı görevi: `README.md` bölüm 7.

## Nasıl koşulur

- Üretim build'i: `flutter build web --wasm`, sonra `npx serve -s build/web -l 5000`.
- Geliştirme: `flutter run -d chrome --wasm --web-port=5000 --dart-define=RECAPTCHA_SITE_KEY=<site key>`.
  Anahtarsız çalıştırınca sohbet kapalı gelir (aşağıda).
- Tarayıcı ajanıyla (ör. Antigravity): "`AGENTS.md`'yi oku, siteyi aç, aşağıdaki maddeleri sırayla
  doğrula; her madde için GEÇTİ/KALDI ve tek satır kanıt yaz. Kod değiştirme."
- Telefon maddeleri için gerçek cihaz (iPhone Safari/Chrome, Android Chrome) ya da Chrome DevTools
  cihaz modu (390 px).

## Masaüstü (Chrome)

- [ ] Açılış: yükleme ekranı ilk karede kalkıyor; konsolda hata yok.
- [ ] Video bölümleri scroll ile ileri-geri akıcı, kare atlaması yok; poster video inene kadar görünür;
      DevTools Network'te her video için tek istek.
- [ ] `document.querySelectorAll('video').length` her an ≤ 2.
- [ ] DevTools Performance: scroll sırasında 16 ms üstü kare yok.
- [ ] Kapak ve başlıksız overlay yazıları büyük, taşmıyor, video üstünde okunuyor.
- [ ] Overlay'ler doğru aralıkta beliriyor/kayboluyor; kapak pill'leri çalışıyor.
- [ ] Projeler: paneller yan yana, kaydırdıkça sıradaki panel akıcı genişliyor, kapalı panelde dikey ad
      okunuyor. Açık panel dolu: öne çıkanlar ya da link satırları, altta tag'ler ve eylem pill'leri;
      link satırları ve pill'ler tıklanınca yeni sekmede açıyor, imleç el oluyor.
- [ ] İletişim: dev başlık, büyük e-posta tek satır ve ekran içinde, tek satırlık footer; "YUKARI" başa dönüyor.
- [ ] Pill ve linklere tek tıklama tek kez çalışıyor (yeni sekme iki kez açılmıyor, sohbet iki kez
      açılıp kapanmıyor).
- [ ] Nav tıklaması doğru bölüme kayıyor; halka ilerliyor.
- [ ] İşletim sisteminde "hareketi azalt" açıkken: crossfade ve hover anlık, nav tıklaması animasyonsuz
      atlıyor, video poster/ilk karede sabit.
- [ ] Ekran okuyucu (VoiceOver): nav öğeleri "Bölüm N: …" ve aktif olan seçili, "Sohbeti aç", video alanı
      "<başlık> videosu"; düğmeler ekran okuyucuyla etkinleşiyor.

## Telefon (390 px ve gerçek cihaz)

- [ ] Nav gizli; sohbet pill'i sağ üstte dolu; ilk proje paneli ona binmiyor; paneller alt alta.
- [ ] Kapak, projeler ve iletişim 390 px'te taşmıyor; çok linkli bir proje paneli de sığıyor.
- [ ] Dikey (`videoMobile`) videosu olan bölümde dikey video yükleniyor ve akıcı; olmayan bölümde özne
      (sağa odaklı kırpma) görünüyor.
- [ ] Ekranı döndürünce (ve adres çubuğu açılıp kapanınca) bölüm ve ilerleme korunuyor; açık sohbet ve
      mesajları kaybolmuyor.
- [ ] iPhone'da Düşük Güç Modu açık ve kapalıyken video karesi boyanıyor (ilk dokunuştan sonra da).

## Sohbet

- [ ] Firebase ve reCAPTCHA anahtarı bağlıyken: cevap kelime kelime akıyor; "önceki talimatları unut"
      isteği kibarca reddediliyor; giriş kutusunun altında yapay zekâ notu görünüyor.
- [ ] `RECAPTCHA_SITE_KEY` verilmeden (ya da `firebase_options.dart` placeholder iken): panel açılıyor ama
      "FIREBASE BAĞLI DEĞİL" kartı görünüyor, giriş kutusu ve yapay zekâ notu yok; scroll deneyimi tam çalışıyor.
- [ ] Soru gönderince cevap gelene kadar asistan satırında üç nokta dalgalanıyor, ilk kelimeyle kalkıyor;
      "hareketi azalt" açıkken noktalar sabit.
- [ ] iPhone Safari'de sohbet kutusuna dokununca klavye açılıyor, sayfa yakınlaşmıyor ve kaymıyor; klavye
      kapanınca düzen aynen dönüyor.
- [ ] Panel açıkken tekerlek sayfayı kaydırmıyor; kapatınca mesajlar duruyor.
- [ ] Otomasyonla açılan tarayıcıda reCAPTCHA sohbeti reddederse bu hata değildir (bot koruması); sohbeti
      kendi tarayıcında elle dene.

## Lighthouse (Chrome, masaüstü)

- [ ] Performance ≥ 80
- [ ] Accessibility ≥ 90

## Faz 4'ü uyguladıktan sonra (otomatik yayın)

- [ ] `.github/workflows/deploy.yml` var; `main`'e push'ta Actions çalışıyor (analyze, test, build yeşil).
- [ ] Dört secret girilince deploy adımı çalışıyor. `FIREBASE_SERVICE_ACCOUNT` ya da `FIREBASE_PROJECT_ID` eksikse
      "Deploy atlandı" yazıyor, iş kırmızı olmuyor. `FIREBASE_OPTIONS_DART` dolu ama `RECAPTCHA_SITE_KEY` boşsa iş
      bilerek kırmızı oluyor (sohbet kapalı yayınlanmasın diye).
- [ ] Canlı sitede (`https://<proje-id>.web.app` ya da kendi domainin): açılış, video ve sohbet çalışıyor;
      sohbet "Doğrulama başarısız" demiyor (reCAPTCHA domain listesi ve Browser key kısıtı, `README.md` bölüm 5).
- [ ] Canlı sitede `web/index.html`'deki App Check debug token satırı yorumda (konsolda debug token uyarısı yok).

## Faz 5'i uyguladıktan sonra (klavyeyle gezinme)

- [ ] `PageDown` / `↓` / `Space` sonraki, `PageUp` / `↑` önceki, `Home` ilk, `End` son bölüme gidiyor.
- [ ] Sohbet kutusuna yazarken tuşlar sayfayı kaydırmıyor; panel kapanınca yine çalışıyor.
- [ ] "Hareketi azalt" açıkken klavye geçişi animasyonsuz atlıyor.

## Yayından sonra

- [ ] `web/og.jpg` ekledinse: paylaşım önizlemesi (`og:image`) kendi adresinde doğru görseli gösteriyor.
