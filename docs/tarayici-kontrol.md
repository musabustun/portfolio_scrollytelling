# Tarayıcı kontrol listesi

Kod ajanları tarayıcı açmaz; scroll akıcılığı, video seek ve dokunma davranışı burada elle (ya da bir
tarayıcı ajanıyla) doğrulanır. Pointer ve klavye davranışının asıl güvencesi `flutter test`'tir
(`AGENTS.md` §11.4); bu liste testin göremediği şeyleri kapatır. Maddeler `- [ ]`; geçeni işaretle,
kalanın yanına nedenini yaz.

## Nasıl koşulur

- Üretim build'i: `flutter build web --wasm`, sonra `npx serve -s build/web -l 5000`.
- Geliştirme: `flutter run -d chrome --wasm --dart-define=RECAPTCHA_SITE_KEY=<site key>`.
  Anahtarsız çalıştırınca sohbet kapalı gelir (aşağıda).
- Antigravity gibi bir tarayıcı ajanıyla: "`AGENTS.md`'yi oku, siteyi aç, aşağıdaki maddeleri sırayla
  doğrula; her madde için ekran görüntüsü, konsol çıktısı ve geçti/kaldı + neden yaz. Kod değiştirme."
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
- [ ] Klavye: `PageDown` / `↓` / `Space` sonraki, `PageUp` / `↑` önceki, `Home` ilk, `End` son bölüm.
      Sohbet kutusuna yazarken tuşlar sayfayı kaydırmıyor; panel kapanınca yine çalışıyor.
- [ ] İşletim sisteminde "hareketi azalt" açıkken: crossfade ve hover anlık, nav tıklaması animasyonsuz
      atlıyor, video poster/ilk karede sabit.
- [ ] Ekran okuyucu (VoiceOver): nav öğeleri "Bölüm N: …" ve aktif olan seçili, "Sohbeti aç", video alanı
      "<başlık> videosu"; düğmeler VoiceOver ile etkinleşiyor.

## Telefon (390 px ve gerçek cihaz)

- [ ] Nav gizli; sohbet pill'i sağ üstte dolu; ilk proje paneli ona binmiyor; paneller alt alta.
- [ ] Kapak, projeler ve iletişim 390 px'te taşmıyor; 8 linkli proje paneli sığıyor.
- [ ] Dikey videolar yükleniyor ve akıcı; dikey sürümü olmayan bölümde özne (sağa odaklı kırpma) görünüyor.
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

## Lighthouse (Chrome, masaüstü)

- [ ] Performance ≥ 80
- [ ] Accessibility ≥ 90
