/// story.json dışındaki sabit UI metinleri; tek yer. Widget'ta string literal yalnızca biçimlendirme için.
abstract final class AppStrings {
  /// Kapaktaki dolu pill; son bölüme kaydırır.
  static const String contact = 'İletişim';

  /// Kapaktaki çizgili pill; sohbet panelini açar.
  static const String chat = '▸ Sohbet';

  /// Sohbet butonu: masaüstünde sağ alt çizgili, mobilde sağ üst dolu.
  static const String chatButton = '💬 Sohbet';

  /// Sohbet paneli başlığı.
  static const String chatTitle = 'Sohbet';

  /// Sohbet giriş kutusu ipucu.
  static const String chatHint = 'Bir şey sor…';

  /// Giriş kutusunun altındaki yapay zekâ notu; yalnızca sohbet bağlıyken görünür.
  static const String chatDisclaimer =
      "Yapay zekâ asistanı; cevaplar hatalı olabilir. Mesajların Gemini'ye gider, kişisel bilgi "
      'yazma.';

  /// Cevabın ilk parçası beklenirken çıkan "yazıyor" göstergesi (erişilebilirlik etiketi;
  /// ekranda yalnızca üç nokta görünür).
  static const String typing = 'Yazıyor…';

  /// Gönder butonu (erişilebilirlik etiketi).
  static const String send = 'Gönder';

  /// Paneli kapatma × ikonu (erişilebilirlik etiketi).
  static const String close = 'Kapat';

  /// Kapalı sohbet pill'i (erişilebilirlik etiketi; görünen yazı [chatButton]).
  static const String openChat = 'Sohbeti aç';

  /// Pill nav öğesi (erişilebilirlik etiketi); [number] 1 tabanlı bölüm sırası.
  static String chapterNavLabel(int number, String title) =>
      'Bölüm $number: $title';

  /// Video bölümünün `<video>` alanı (erişilebilirlik etiketi); [title] bölüm başlığı.
  static String videoLabelFor(String title) => '$title videosu';

  /// Proje bağlantısı pill'i; sonuna ok `PillButton` tarafından eklenir.
  static const String openProject = 'Projeyi aç';

  /// Footer'da başa dönüş.
  static const String backToTop = 'YUKARI ↑';

  /// Projects bölümündeki indeks etiketi ("01 · PROJE").
  static const String projectLabel = 'Proje';

  /// Sohbet boşken gösterilen davet; [owner] story.json `meta.owner`.
  static String chatEmptyFor(String owner) => '$owner hakkında bir şey sor.';

  /// Firebase yokken panelde giriş kutusu yerine çıkan kartın başlığı.
  static const String notConnectedTitle = 'Firebase bağlı değil';

  /// "Bağlı değil" kartının yönlendirme metni.
  static const String notConnectedBody =
      "Sohbet için Firebase'i bağla: README adım 2.";

  /// AI hatası: kota aşıldı.
  static const String aiBusy = 'Şu an çok yoğunum, biraz sonra dene.';

  /// AI hatası: App Check isteği reddetti (403 / PERMISSION_DENIED).
  static const String aiAppCheck =
      'Doğrulama başarısız (App Check). README adım 2.4 ve 2.5.';

  /// AI hatası: ağ bağlantısı yok.
  static const String aiOffline = 'Bağlantı yok. İnterneti kontrol et.';

  /// AI hatası: projede Firebase AI Logic açılmamış.
  static const String aiNotEnabled =
      'Firebase AI Logic etkin değil. README adım 2.2.';

  /// AI hatası: API anahtarı ya da Firebase ayarı geçersiz.
  static const String aiBadConfig =
      'Firebase ayarı geçersiz (firebase_options.dart). README adım 2.3.';

  /// AI hatası: model adı bulunamadı.
  static const String aiBadModel =
      'Model bulunamadı; lib/ai/ai_config.dart içindeki model adını kontrol et.';

  /// AI hatası: kullanıcının bölgesi desteklenmiyor.
  static const String aiRegion = 'Bu bölgede kullanılamıyor.';

  /// AI hatası: soru ya da cevap güvenlik filtresine takıldı.
  static const String aiBlocked = 'Bu soruya cevap veremiyorum.';

  /// AI hatası: akış bitti ama hiç metin gelmedi.
  static const String aiEmptyReply = 'Cevap boş geldi, tekrar dene.';

  /// AI hatası: tanınmayan hata.
  static const String aiUnknown = 'Bir şeyler ters gitti, tekrar dene.';

  /// story.json hata kutusunun başlığı (`LabelText` BÜYÜK HARF'e çevirir).
  static const String storyErrorTitle = 'story.json okunamadı';

  /// story.json hata kutusunun yönlendirmesi.
  static const String storyErrorHint =
      'Dosyayı düzelt ve sayfayı yenile. Şema: README.md §3.';
}
