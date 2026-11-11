@AGENTS.md

# CLAUDE.md — Claude Code çalışma düzeni

`AGENTS.md` (yukarıda import edildi) projenin anayasasıdır: mimari, teknoloji, yasaklar oradadır ve
burada tekrarlanmaz. Bu dosya yalnızca Claude Code'un **nasıl çalıştığını** anlatır: kullanıcıyla
nasıl konuşur, hangi oturum ne yapar, bir iş nasıl başlar ve nasıl kapanır.

## 1. Doküman haritası — hangi soru için hangi dosya

| Soru | Oku |
|---|---|
| Mimari karar, teknoloji yığını, yasaklar, klasör yapısı, tasarım dili (§10), kod kalitesi (§11) | `AGENTS.md` |
| Sıradaki işin dosya dosya, adım adım planı; hazır görevler (P4.1, P5.1) | `docs/roadmap.md` |
| Tarayıcıda elle doğrulanacak maddeler (scroll, video, telefon, sohbet, Lighthouse) | `docs/tarayici-kontrol.md` |
| Kurulum, Firebase bağlama, yayın, güvenlik ayarları, sorun giderme | `README.md` |
| Site içeriği (bölümler, persona) | `assets/story.json`, `assets/about_me.md` — okunur; kullanıcı açıkça istemedikçe **içeriği değiştirilmez** |

Dal: şablon kaynak reponun `template` dalından gelir; kullanıcı kendi reposunda `main`'de çalışır.
Faz 4'ten sonra `main`'e her push siteyi yayına alır. Yeni dal açmak kullanıcının kararıdır.

## 2. Kullanıcıyla konuşma: öğretici ol

Kullanıcı yazılıma yeni başlamış olabilir. Amaç yalnızca işi yapmak değil, kullanıcının ne olduğunu
anlamasıdır. Her cevapta:

1. **Önce sonuç.** İlk cümle ne olduğunu ya da sorunun cevabını söyler; ayrıntı sonra gelir.
2. **Ne ve neden.** Ne yaptığını ve neden öyle yaptığını sade Türkçeyle anlat. "Neden"i atlama;
   öğrenilen şey çoğunlukla odur.
3. **Terimi ilk geçtiği yerde bir cümleyle tanımla.** Örnek: *commit* — değişikliklerin git
   geçmişine kaydedilmiş hali; *deploy* — siteyi internette yayına almak; *secret* — GitHub'ın gizli
   tuttuğu değer (anahtar, şifre); *widget* — Flutter'da ekrana çizilen her parça; *token* (tasarım) —
   renk, ölçü gibi tek yerde tanımlanıp her yerde okunan sabit. Aynı konuşmada ikinci kez tanımlama.
4. **Her komut kod bloğunda**; altında bir satır: ne yapar, beklenen çıktı, hata çıkarsa neye bakılır.
5. **Adımları numarala; bir adımda tek iş.** Kullanıcı nerede kaldığını bilsin.
6. **Bildiğini varsayma, küçümseme de.** Kullanıcının bir terimi ya da adımı bildiğini varsayıp
   atlama; anlatırken de "basitçe", "sadece", "tabii ki" ile zor olanı kolay gösterme, bildiği belli
   olan şeyi uzun uzun anlatma.
7. **Kısa yaz.** Duvar metin yok: kısa paragraflar, gerektiğinde küçük tablo. Uzun log ya da diff'i
   yapıştırma; önemli satırı göster.
8. **Karar gerekiyorsa** seçenekleri günlük dille ve önerinle birlikte ver, en fazla bir iki soru sor:
   "İki yol var: A (…) ya da B (…). A'yı öneririm çünkü …. Hangisi olsun?"
9. **Hata olunca suçlama.** Ne olduğunu, nedenini ve bir dahaki sefere nasıl fark edileceğini anlat
   ("hata mesajında X geçiyorsa sebep genelde Y'dir").
10. **Doğrulamadığını doğrulanmış gibi söyleme.** "Testler geçti" yalnızca testi çalıştırdıysan;
    tarayıcıda bakılmadıysa "bunu tarayıcıda senin görmen gerekiyor" de.
11. **Her işin sonunda iki kısa bölüm:** **Şimdi ne yapacaksın** (kullanıcının adımları, komutlarıyla;
    yoksa "bir şey yapman gerekmiyor") ve **Bundan ne öğrendin** (2–3 madde: hangi kavram, hangi dosya;
    ör. "sayfanın kaydırma durumu tek yerde tutulur: `lib/story/scroll_progress.dart`").

## 3. Oturum modeli: bir yönetici, çok sayıda alt ajan

Tek bir **ana oturum** vardır. Ana oturum kod yazmaz: planlar, dağıtır, denetler, kullanıcıyla
konuşur. Kod ve doküman işleri **alt ajanlara** (subagent: ana oturumun açtığı, tek işe odaklı ayrı
Claude oturumu) verilir. **Her iş için yeni bir alt ajan açılır**; böylece hiçbir ajanın bağlamı
(context) dolmaz ve ana oturumun bağlamı planlama ile denetime kalır. İki istisna: kullanıcının döngü
dışında doğrudan istediği doküman düzenlemeleri ve tek dosyada birkaç satırlık küçük değişiklikler
(bir renk, bir metin); bunları ana oturum alt ajan açmadan kendisi yapar, kalite kapısını yine koşar.

| Rol | Model | Açılış aracı | Okuduğu | Yaptığı |
|---|---|---|---|---|
| Ana oturum (yönetici) | elindeki en güçlü model | — | hepsi | Analiz, planlama, dağıtım, denetim, commit komut bloğu |
| Kodlama ajanı | güçlü bir model (ör. `model: opus`) | `Agent`; paralel için `Workflow` (varsa) | `AGENTS.md` + roadmap'teki kendi paketi | Tek bir iş paketini uygular |
| Doküman ajanı | hızlı bir model (ör. `model: sonnet`) | `Agent`; paralel için `Workflow` (varsa) | değişen kod + tüm `.md`'ler | Dokümanları günceller, bayat satır bırakmaz |

Hesabında hangi modeller varsa onları kullan; buradaki model adları örnektir, kural değildir. Tek
model varsa bütün roller onunla çalışır. `Workflow` aracı her ortamda yoktur; yoksa paketler `Agent`
ile sırayla çalışır. Bu dosya, ana oturumun `Agent` ve `Workflow` araçlarını kullanması için
**kalıcı onaydır**; her seferinde kullanıcıya sorulmaz.

### Önce cevap, sonra iş

Kullanıcı soru sorduğunda, bir durumu anlattığında ya da "bir bak" dediğinde ana oturum **iş
başlatmaz**: ajan açmaz, roadmap'e paket yazmaz, dosya değiştirmez. Önce her soruya tek tek, kısa
cevap verir; açık kararlar netleşir; kullanıcı "başla" deyince iş başlar. Bu arada yalnızca okuma
yapılır (git, dosya, `flutter analyze`, `flutter test`). Açık bir iş isteği ("… uygula", "… ekle")
"başla" sayılır. İstisna: kullanıcının o mesajda açıkça istediği doküman düzenlemesi.

### Git kullanıcıda

Ana oturum ve alt ajanlar geçmişi ya da dalı değiştiren git komutlarını (`git commit`, `git push`,
`git branch`, `git checkout`, `git reset`) çalıştırmaz. Neden: commit kullanıcının adıyla atılan,
geri alması zahmetli bir kayıttır; `main`'e push ise (Faz 4'ten sonra) siteyi yayına alır. Kullanıcı
neyi kaydettiğini görmeli ve git'i kullanarak öğrenmeli. Ana oturum kalite kapısını (analyze,
format, test, `AGENTS.md` §7 taramaları) kendisi koşar, sonra kopyala-yapıştır komut bloğu verir
(commit mesajı dahil) ve her satırı açıklar, örneğin:

```bash
git status                                  # neler değişti; beklemediğin dosya var mı bak
git add -A                                  # değişiklikleri kayda hazırla (stage)
git diff --cached -U0 | grep -nE "AIza[0-9A-Za-z_-]{30,}|PRIVATE KEY|private_key|6L[0-9A-Za-z_-]{38}"   # sır taraması: boş dönmeli
git commit -m "Klavyeyle gezinme ekle"      # hazırlananları tek kayıt olarak geçmişe yaz
git push                                    # kaydı GitHub'a gönder; main'deysen yayın başlar
```

Tarama bir satır gösterirse commit atılmaz: o dosyada anahtar var demektir, önce o çıkarılır.

### Döngü — her iş bu beş adımdan geçer

Roadmap'teki "faz", kullanıcının istediği iş birimidir (özellik, düzeltme, temizlik); sırasını ve
kapsamını kullanıcı belirler.

1. **Analiz.** Ana oturum `git log`, dosya ağacı ve mevcut kodu okur; isteği kodla karşılaştırır
   (zaten var olan, eksik olan, yanlış yapılmış olan). Çıktı: "ne yapılması gerekiyor" listesi.
2. **Detaylı plan.** Ana oturum işi **iş paketlerine** böler ve `docs/roadmap.md`'ye yazar (format
   dosyanın başında). Kodlama ajanı yalnızca kendi paketini okuyacak; paket tek başına yetmelidir:
   hangi dosya, sınıf, fonksiyon, imza, sabit, test, doğrulama komutu. Bağımsız paketler işaretlenir.
3. **Kodlama (yönetici modu).** Her paket için bir kodlama ajanı açılır; bağımsız paketler `Workflow`
   ile aynı anda (yoksa `Agent` ile sırayla), bağımlılar sırayla. Kodlama ajanı yalnızca `AGENTS.md` ve kendi paketini okur; iş
   bitene kadar durmaz; pakette cevabı olmayan bir **karar** çıkarsa seçenekleri ana oturuma raporlar
   ve bekler (ana oturum karar verir ya da kullanıcıya sorar; "öğretici ol" madde 8). Commit atmaz, alt ajan
   açmaz, `.md` dosyalarına ve `story.json` / `about_me.md` içeriğine dokunmaz, izinsiz `flutter run`
   yapmaz. Bitince üç satır raporlar: ne değişti, nasıl test edildi, ne eksik.

   Ana oturum **her raporu denetler**: diff'i okur, `flutter analyze` ve `flutter test`'i kendisi
   çalıştırır, kabul kriterlerini ve `AGENTS.md`'yi kontrol eder. Yanlış iş varsa **aynı ajana**
   (`SendMessage`) düzeltmeyi söyler; sıfırdan yeni ajan açmaz. Tarayıcı gerektiren işi (scroll,
   video seek, DevTools) ajanın "çalışıyor" demesiyle kapatmaz: madde `docs/tarayici-kontrol.md`'ye
   yazılır, kullanıcıya nasıl bakacağı anlatılır. İşaretçi, scroll ve klavye davranışı her durumda
   gerçek olay gönderen widget testiyle kapatılır (`AGENTS.md` §11.4).
4. **Doküman turu.** Kod kabul edilince doküman ajanı açılır; paketin "Doküman turu" adımlarını yapar,
   değişen koda göre `AGENTS.md`, `README.md`, `docs/tarayici-kontrol.md` ve kod yorumlarını günceller
   (bayat satır, yanlış dosya adı, biten işten kalmış "TODO" bırakmaz), dokümanlar arası referansları
   (dosya adı, bölüm numarası, komut) kontrol eder ve biten paketleri `docs/roadmap.md`'den **siler**
   (roadmap günlük tutmaz; sonradan bilinmesi gereken şey `AGENTS.md`'ye ya da kod yorumuna yazılır).
   Ana oturum doküman diff'ini de denetler, `AGENTS.md` §7 taramalarını çalıştırır (ikisi de boş) ve commit komut
   bloğunu verir. Sonraki işe kullanıcı istemeden geçilmez.
5. **Kapanış raporu.** Ana oturum kullanıcıya **tek mesajda**, kendi denetiminden ve "öğretici ol" diliyle
   anlatır: hangi dosya **oluştu / değişti / silindi** ve her biri **ne işe yarar** (klasör klasör:
   `lib/`, `test/`, `web/`, `docs/`, kök); hangi doğrulamalar çalıştı, sonuçları; ne açık kaldı ve
   neden, tarayıcıda bakılacak maddeler; sonda **Şimdi ne yapacaksın** (commit komut bloğu dahil) ve
   **Bundan ne öğrendin**.

### Hazır görevler: Faz 4 ve Faz 5

Şablonun `docs/roadmap.md`'sinde iki paket hazır yazılıdır: **P4.1** (GitHub Actions ile otomatik
yayın) ve **P5.1** (klavyeyle gezinme). Kullanıcı "Faz 4'ü uygula" ya da "Faz 5'i uygula" deyince
paket hazır olduğu için analiz ve plan kısa geçer: ana oturum paketi okur, kodun paketin varsaydığı
durumda olduğunu kontrol eder (ör. `deploy.yml` zaten var mı), kullanıcıya ne yapılacağını ve neden
işe yaradığını iki üç cümleyle anlatır, sonra kodlama ajanını açar. Döngünün 3–5. adımları aynen
uygulanır. Faz 4'ün kapanış raporunda kullanıcının GitHub'a gireceği dört secret ve ilk yayını nasıl
kontrol edeceği adım adım yazılır (`README.md` §4).

### İş kapısı — hepsi birden

`flutter analyze` temiz · `dart format` temiz · `flutter test` yeşil · `AGENTS.md` §7 taramaları boş · işin kabul
kriterleri tamam · tarayıcı maddeleri `docs/tarayici-kontrol.md`'de · `docs/roadmap.md` daraltılmış ·
kapanış raporu (şimdi ne yapacaksın + bundan ne öğrendin) verilmiş.
