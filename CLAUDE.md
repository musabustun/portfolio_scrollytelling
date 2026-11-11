@AGENTS.md

# CLAUDE.md — Claude Code çalışma düzeni

`AGENTS.md` (yukarıda import edildi) projenin anayasasıdır: mimari, teknoloji, yasaklar oradadır ve
burada tekrarlanmaz. Bu dosya yalnızca Claude Code'un **nasıl çalıştığını** anlatır: hangi oturum
ne yapar, hangi dokümanı ne zaman okur, bir iş nasıl başlar ve nasıl kapanır.

## 1. Doküman haritası — hangi soru için hangi dosya

| Soru | Oku |
|---|---|
| Mimari karar, teknoloji yığını, yasaklar, klasör yapısı, tasarım dili (§10), kod kalitesi (§11) | `AGENTS.md` |
| Şu an yapılan işin dosya dosya, adım adım planı | `docs/roadmap.md` |
| Tarayıcıda elle doğrulanacak maddeler (scroll, video, telefon, sohbet, Lighthouse) | `docs/tarayici-kontrol.md` |
| Katılımcı kurulumu, Firebase bağlama, deploy, sorun giderme | `README.md` |
| Site içeriği (bölümler, persona) | `assets/story.json`, `assets/about_me.md` — okunur; kullanıcı açıkça istemedikçe **içeriği değiştirilmez** |

Sıradaki iş kullanıcının isteğinden (ya da issue'dan) gelir; `docs/roadmap.md` aktif işin paketlerini
taşır, `git branch -a` dalları gösterir. Dal modeli **iki dal**: `main` kodun geliştiği ve yayınlanan
site; `template` tek şablon dal. `template` **tek commit**'tir (geçmişsiz); kişisel içerik, `deploy.yml`
ve klavye kısayolları yoktur (katılımcı ajana yazdırır). Üstüne commit eklenmez, `main`'de şablonu
etkileyen değişiklik olunca `template` yeniden üretilir ya da düzeltme amend + force push ile aynı
commit'te yapılır ve bu komutları kullanıcı koşar. Başka demo
dalı kesilmez.

## 2. Oturum modeli: bir yönetici, çok sayıda alt ajan

Tek bir **ana oturum** vardır; güçlü bir modelde çalışır (Fable). Ana oturum kod yazmaz: planlar,
dağıtır, denetler, kullanıcıyla konuşur. Kod ve doküman işleri **alt ajanlara** (subagent) verilir.
**Her iş için yeni bir alt ajan açılır**; böylece hiçbir ajan context penceresine takılmaz ve ana
oturumun penceresi planlama ile denetime kalır. İstisna: kullanıcının döngü dışında doğrudan
istediği doküman düzenlemelerini ana oturum kendisi yapar; kod için her zaman alt ajan.

| Rol | Model | Açılış aracı | Okuduğu | Yaptığı |
|---|---|---|---|---|
| Ana oturum (yönetici) | Fable | — | hepsi | Analiz, planlama, dağıtım, denetim, commit komut bloğu |
| Kodlama ajanı | Opus (`model: opus`) | `Agent`, paralelde `Workflow` | `AGENTS.md` + roadmap'teki kendi paketi | Tek bir iş paketini uygular |
| Doküman ajanı | Sonnet (`model: sonnet`) | `Agent`, paralelde `Workflow` | değişen kod + tüm `.md`'ler | Dokümanları günceller, bayat satır bırakmaz |

Bu dosya, ana oturumun `Agent` ve `Workflow` araçlarını kullanması için **kalıcı onaydır**; her
seferinde kullanıcıya sorulmaz.

### Önce cevap, sonra iş

Kullanıcı soru sorduğunda, bir durumu anlattığında ya da "bir bak" dediğinde ana oturum **iş
başlatmaz**: ajan açmaz, roadmap'e paket yazmaz, dosya değiştirmez, branch oynatmaz. Önce
soruların her birine tek tek, kısa cevap verir; model, sıra ve açık kararlar netleşir; kullanıcı
"başla" deyince iş başlar. Bu arada yalnızca okuma yapılır (git, dosya, `flutter analyze`,
`flutter test`). İstisna: kullanıcının o mesajda açıkça istediği doküman düzenlemesi.

### Git kullanıcıda

Ana oturum `git commit`, `git branch`, `git checkout --orphan`, `git push` çalıştırmaz; kalite
kapısını (analyze, format, test, §7 taramaları) kendisi koşar, sonra kullanıcıya kopyala-yapıştır
komut bloğu verir (commit mesajı dahil). `template` güncellemesi (yeniden üretme ya da amend + force push) de kullanıcı
tarafından koşulur. Aşağıdaki döngüde "commit atar" geçen yerler bu kuralla okunur.

### Döngü — her iş bu beş adımdan geçer

Roadmap'teki "faz", kullanıcının istediği iş birimidir (özellik, düzeltme, temizlik); sırasını ve kapsamını kullanıcı belirler.

1. **Analiz.** Ana oturum kullanıcının istediği işi alır. `git log`, dosya ağacı ve mevcut
   kodu okur; isteği kodla karşılaştırır: zaten var olan, eksik olan, yanlış yapılmış
   olan. Çıktı: "ne yapılması gerekiyor" listesi.

2. **Detaylı plan.** Ana oturum işi **iş paketlerine** böler ve `docs/roadmap.md`'ye yazar.
   Kodlama ajanı yalnızca roadmap'i okuyacak; o yüzden paket tek başına yetmelidir:
   hangi dosya, hangi sınıf ve fonksiyon, hangi imza, hangi sabit, hangi test, hangi komutla
   doğrulanır. Paket formatı `docs/roadmap.md`'nin başındadır. Birbirine bağlı olmayan paketler
   işaretlenir; onlar paralel çalışacaktır.

3. **Kodlama (yönetici modu).** Her iş paketi için bir kodlama ajanı açılır. Bağımsız paketler
   `Workflow` ile aynı anda, bağımlı olanlar sırayla çalışır. Kodlama ajanının kuralları:
   - Yalnızca `AGENTS.md` ve kendi roadmap paketini okur; `README.md` okumaz.
   - İş bitene kadar durmaz. Roadmap'te cevabı olmayan bir **karar** çıkarsa durur, seçenekleri
     ana oturuma raporlar ve onay bekler. Ana oturum karar verir ya da kullanıcıya sorar.
   - Commit atmaz, yeni alt ajan açmaz, `assets/story.json` ve `assets/about_me.md` içeriğine dokunmaz.
   - Bitince üç satır raporlar: ne değişti, nasıl test edildi, ne eksik.

   Ana oturum **her raporu denetler**: diff'i okur, `flutter analyze` ve `flutter test`'i kendisi
   çalıştırır, paketin kabul kriterlerini ve `AGENTS.md`'yi kontrol eder. Yanlış iş varsa **aynı
   ajana** (`SendMessage`) düzeltmeyi söyler; yeni ajan açıp sıfırdan başlatmaz. Tarayıcıda
   doğrulama gerektiren işleri (scroll, video seek, DevTools) ajanın "çalışıyor" demesiyle
   kapatmaz, kendisi bakar. Tarayıcıya bakılamıyorsa (kullanıcı yasağı) işaretçi/scroll davranışı
   `TestPointer` widget testiyle kapatılır (`AGENTS.md` §11.4); paket kabulüne bu test yazılır,
   tarayıcı maddeleri `docs/tarayici-kontrol.md`'ye eklenir.

4. **Doküman turu.** Kod bitince doküman ajanları açılır (Sonnet). Ana oturum yönetir. Görevleri:
   - Değişen koda göre `AGENTS.md`, `README.md`, `docs/tarayici-kontrol.md` ve kod yorumlarını güncellemek.
     Bayat tek bir satır, yanlış bir dosya adı, biten işten kalmış bir "TODO" notu bırakmamak.
   - `docs/roadmap.md`'deki işin paketlerini **silmek**; roadmap günlük tutmaz, sonradan bilinmesi
     gereken şey `AGENTS.md`'ye ya da kod yorumuna yazılır.
   - Dokümanlar arası tüm referansları (dosya adı, bölüm numarası, komut, satır) kontrol etmek;
     kırık ya da bayat olanı düzeltmek. Yalnızca bu tur sonunda dokümanlar "doğru" sayılır.
   - `docs/roadmap.md`'de sıradaki işin paketleri yazılı olmalı (kullanıcı bir sonraki işi verdiyse;
     yoksa "Aktif faz: yok" notu). `template`'in kendi roadmap'inde katılımcının uygulayacağı
     paketler (P4.1 otomatik yayın, P5.1 klavyeyle gezinme) durur; kodlama ajanı onları okur.

   Ana oturum doküman diff'ini de denetler, `AGENTS.md` §7'deki sır ve token taramalarını
   çalıştırır (ikisi de boş), commit atar (yukarıdaki git kuralıyla: komut bloğu verir). Yeni demo dalı kesilmez; `template`'e
   düzeltme gerekiyorsa yeniden üretme ya da amend, tek commit. Sonraki işe kullanıcı istemeden geçilmez.

5. **Kapanış raporu.** Doküman turu bitince ana oturum kullanıcıya **tek mesajda, dosya dosya**
   anlatır; alt ajan raporlarını özetlemekle yetinmez, kendi denetiminden yazar:
   - Hangi dosya **oluştu / değişti / silindi**, her biri **ne işe yarar**, neden dokunuldu
     (klasör klasör gruplanır: `lib/`, `web/`, `tools/`, `docs/`, kök dosyalar).
   - Hangi doğrulamalar çalıştırıldı ve sonuçları (analyze, test, taramalar, build).
   - Ne açık kaldı, neden; kullanıcının **kendisinin yapacağı** şey varsa komutuyla birlikte.
   - Kodlamayla ilgisi olmayan sade dille; komutlar kod bloğunda. Kullanıcı bu raporu okuyup
     "ne oldu, şimdi ne yapacağım" sorusuna başka dosya açmadan cevap verebilmeli.

### İş kapısı — hepsi birden

`flutter analyze` temiz · `dart format` temiz · `flutter test` yeşil · §7 taramaları boş · işin kabul
kriterleri tamam · tarayıcı maddeleri `docs/tarayici-kontrol.md`'de · `docs/roadmap.md` daraltılmış ·
kapanış raporu verilmiş.
