# roadmap.md — Aktif işin detaylı planı

Bu dosya, kullanıcının istediği işin **tam olarak nasıl** yapılacağını tutar. Yazan: ana oturum
(yönetici). Okuyan: kodlama ajanları. "Ne yapılacak" kullanıcının isteğinden ya da bir issue'dan gelir;
oturum düzeni `CLAUDE.md`'de, mimari kurallar `AGENTS.md`'de, tarayıcıda elle doğrulanacak maddeler
`docs/tarayici-kontrol.md`'de.

Kurallar:
- Burada aynı anda yalnızca **bir işin** paketleri durur. İş bitince paketler silinir; dosya büyümez,
  bayatlamaz.
- Kodlama ajanı bu dosyadan yalnızca **kendi paketini** okur. Paket, `AGENTS.md` ile birlikte tek
  başına yetmelidir; paket içinde "README'de yazıyor" denmez, gereken bilgi pakete kopyalanır.
- Planı yalnızca ana oturum değiştirir. Kodlama ajanı plandan sapmak isterse durur ve raporlar.
- Doğrulama: `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test`,
  `AGENTS.md` §7 taramaları ve `flutter build web --wasm`. Tarayıcı gerektiren kabul maddeleri
  `docs/tarayici-kontrol.md`'ye yazılır; kullanıcı izin vermeden ajanlar `flutter run` yapmaz.
- Tek şablon dal `template`'tir; başka demo dalı kesilmez. O dalın kendi `docs/roadmap.md`'sinde
  katılımcının uygulayacağı paketler (P4.1 otomatik yayın, P5.1 klavyeyle gezinme) **aktif** durur ve
  `main`'deki `.github/workflows/deploy.yml` ile klavye davranışıyla uyumlu tutulur. Buradaki (`main`) dosya ise yalnızca `main`'in aktif işini taşır.

## İş paketi formatı

Her paket şu başlıklarla yazılır. Başlık atlanmaz; boşsa "yok" yazılır.

```
### P<iş>.<sıra> — <kısa ad>
**Bağımlılık:** yok | P1.2 (hangi paket bitmeden başlanamaz)
**Dosyalar:** lib/..., test/..., web/...  (her biri için: oluştur / değiştir / sil)
**Amaç:** Tek cümle; bu paket bitince ne doğru olacak.
**Bağlam:** İşe başlamadan okunacak dosyalar ve AGENTS.md bölüm numaraları (örn. §4, §5);
  §11 her pakette zorunludur.
**Adımlar:** Numaralı, dosya bazında. Sınıf ve fonksiyon adları, imzalar, önemli sabitler,
  kullanılacak paket API'leri açık yazılır. Ajan yorum yapmak zorunda kalmamalı.
**Yapma:** Bu pakete özel yasaklar (AGENTS.md §8'e ek olanlar).
**Kabul:** Doğrulanabilir maddeler. Komutlar açık: `flutter analyze`, `flutter test`,
  tarayıcıda ne görülmeli, DevTools'ta ne ölçülmeli.
**Karar noktaları:** Ana oturuma sorulması gereken açık sorular; yoksa "yok".
```

Paket boyutu: bir ajanın tek oturumda, context'e takılmadan bitirebileceği kadar. Büyükse bölünür.
Aynı dosyaya dokunmayan ve birbirinin çıktısını beklemeyen paketler **bağımsızdır**, paralel çalışır.

---

## Aktif faz

**Aktif faz: yok.** Yeni iş kullanıcıdan gelince paketleri buraya yazılır.
