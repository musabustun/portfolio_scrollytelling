# roadmap.md — İş paketleri

Bu dosya, yapılacak işin **tam olarak nasıl** yapılacağını tutar. Yazan: ana oturum (yönetici).
Okuyan: kodlama ajanları. "Ne yapılacak" kullanıcının isteğinden ya da bir issue'dan gelir; oturum
düzeni `CLAUDE.md`'de, mimari kurallar `AGENTS.md`'de, tarayıcıda elle doğrulanacak maddeler
`docs/tarayici-kontrol.md`'de.

Kurallar:
- Burada yalnızca yapılacak işlerin paketleri durur: şablonla gelen iki hazır görev (P4.1, P5.1) ve
  kullanıcının verdiği aktif iş. İş bitince paketleri silinir; dosya günlük tutmaz, bayatlamaz.
  Sonradan bilinmesi gereken şey `AGENTS.md`'ye ya da kod yorumuna yazılır.
- Kodlama ajanı bu dosyadan yalnızca **kendi paketini** okur. Paket, `AGENTS.md` ile birlikte tek
  başına yetmelidir; paket içinde "README'de yazıyor" denmez, gereken bilgi pakete kopyalanır.
  Paketin "Doküman turu" bölümü kodlama ajanı için değildir; onu doküman ajanı ya da ana oturum yapar.
- Planı yalnızca ana oturum değiştirir. Kodlama ajanı plandan sapmak isterse durur ve raporlar.
- Doğrulama: `flutter analyze`, `dart format --output=none --set-exit-if-changed .`, `flutter test`,
  `AGENTS.md` §7 taramaları ve `flutter build web --wasm`. Tarayıcı gerektiren kabul maddeleri
  `docs/tarayici-kontrol.md`'ye yazılır; kullanıcı izin vermeden ajanlar `flutter run` yapmaz.
- Sır taraması: ajan `git add` yapmaz; `git diff --cached` yalnızca `git add` edilmiş değişikliği
  gördüğü için ajanın tarafında boş döner ve bir şey kanıtlamaz. Ajan `AGENTS.md` §7'deki
  `git grep --untracked` satırını koşar (yeni dosyaları da tarar); `git diff --cached` satırını
  kullanıcı `git add -A`'dan sonra koşar.
- Lokal ön koşul: `tools/setup.sh` bir kez çalıştırılmış olmalı (`lib/firebase_options.dart` var,
  `flutter pub get` yapılmış); yoksa analyze ve build `firebase_options.dart` bulamaz.

## İş paketi formatı

Her paket şu başlıklarla yazılır. Başlık atlanmaz; boşsa "yok" yazılır.

```
### P<iş>.<sıra> — <kısa ad>
**Bağımlılık:** yok | P1.2 (hangi paket bitmeden başlanamaz; sıra önemli değilse "yok")
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
**Kodlama ajanının doküman işi:** Yalnızca kod yorumları; yoksa "yok". Kodlama ajanı `.md`
  dosyalarına dokunmaz.
**Doküman turu (doküman ajanı ya da ana oturum yapar):** Kod kabul edildikten sonraki `.md`
  değişiklikleri, hedef metinleriyle. Kodlama ajanı bu bölümü uygulamaz. Claude Code dışında tek
  ajanla çalışılıyorsa kod kabulünden sonra aynı ajan yapar.
```

Paket boyutu: bir ajanın tek oturumda, context'e takılmadan bitirebileceği kadar. Büyükse bölünür.
Aynı dosyaya dokunmayan ve birbirinin çıktısını beklemeyen paketler **bağımsızdır**, paralel çalışır.

---

## Aktif faz

**Aktif faz: yok.** Sıradaki hazır görevler: Faz 4 (P4.1), Faz 5 (P5.1). "Faz 4'ü uygula" de.
İkisi bağımsızdır (ortak kod dosyaları yok); istenen sırayla ya da paralel uygulanabilir.

---

### P4.1 — GitHub Actions: build + Firebase Hosting deploy

**Bağımlılık:** yok.

**Dosyalar:** `.github/workflows/deploy.yml` (oluştur; `.github/workflows/` klasörü yoksa o da).
Başka dosya yok.

**Amaç:** `main`'e her push'ta (ya da GitHub'da elle **Run workflow**) kod denetlenir
(`flutter analyze` + `flutter test`), wasm build alınır ve deploy secret'ları tanımlıysa site Firebase
Hosting'in canlı (`live`) kanalına yayınlanır; pull request tetiklemez, preview kanalı yoktur, dosyada
hiçbir literal proje kimliği, anahtar ya da domain yoktur.

**Bağlam:** AGENTS.md §2 karar 2 (`--wasm`) ve karar 7 (sıfır sır), §6 (App Check fail-closed:
`RECAPTCHA_SITE_KEY` boşsa sohbet kapalı yayınlanır), §7 (komutlar, sır taraması), §11.4 (kalite
kapısı; bu pakette Dart dosyası yok). Oku: `firebase.json` (hosting `public: build/web`; değişmez),
`lib/firebase_options.dart.example` (placeholder, `apiKey: 'PLACEHOLDER'`), `lib/main.dart`
(`String.fromEnvironment('RECAPTCHA_SITE_KEY')`), `tools/setup.sh`.

Secret'lar dört tane; adlar **birebir** (kullanıcı bunları GitHub'da bu adlarla girer):

| Secret | İçerik | Kullanıldığı yer |
|---|---|---|
| `FIREBASE_PROJECT_ID` | Firebase proje ID'si | `HAS_DEPLOY_SECRETS`, Deploy `projectId` |
| `FIREBASE_SERVICE_ACCOUNT` | service account JSON'unun tamamı | `HAS_DEPLOY_SECRETS`, Deploy `firebaseServiceAccount` |
| `FIREBASE_OPTIONS_DART` | `lib/firebase_options.dart`'ın tam içeriği | "Firebase ayarı", "App Check anahtarı" |
| `RECAPTCHA_SITE_KEY` | reCAPTCHA Enterprise site key | "App Check anahtarı", "Build (wasm)" |

`GITHUB_TOKEN` kullanılmaz. GitHub Actions tuzakları (sık yapılan hatalar):
- `secrets` bağlamı adım `if:` ifadesinde kullanılamaz. Deploy kararı job `env`'indeki
  `HAS_DEPLOY_SECRETS` ile taşınır; değeri `'true'` / `'false'` metnidir.
- Secret değeri `run:` satırına `${{ }}` ile gömülmez; adımın `env`'ine alınır, shell'de `"$AD"`
  olarak okunur (değer shell komutuna dönüşmesin).
- `channelId` ifadeyle kurulmaz (`cond && '' || 'live'` kalıbında `''` yanlış sayılır, sonuç hep
  `live` olur). PR tetiği olmadığından değer sabit: `live`.

**Adımlar:** Tek dosya, 2 boşluk girinti, LF satır sonu, dosya sonunda tek satır sonu; adımlar
arasında boş satır.

1. Dosya başında Türkçe yorum bloğu (`#`), beş satır: (a) main'e push → analyze + test + wasm build +
   canlı yayın, PR tetiklemez; (b) başka daldan elle (`workflow_dispatch`) tetiklenirse analyze +
   test + build; yayın yok; (c) 4 secret repo **Settings → Secrets and variables → Actions**'ta
   tanımlanır, adları ve nereden alındıkları README.md §4'te; (d) dosyada hiçbir literal değer (proje
   ID, anahtar, domain) yok, hepsi secret'tan okunur; (e) secret yoksa (fork, ilk kurulum) analyze +
   test + build yine çalışır, yalnızca deploy adımı atlanır.
2. `name: Deploy`
3. Workflow düzeyinde (en üst seviye; `jobs:`'ın dışında, `name`/`on`/`jobs` ile aynı girintide) şu
   üç blok, bu sırayla:
   ```yaml
   on:
     push:
       branches: [main]
     workflow_dispatch:

   concurrency:
     group: deploy-${{ github.ref }}
     cancel-in-progress: true

   permissions:
     contents: read
   ```
   `pull_request` tetiği yok. `concurrency`: aynı dala gelen yeni push eski koşuyu iptal eder.
4. `jobs:` altında tek job `build-and-deploy`: `runs-on: ubuntu-latest`, `timeout-minutes: 30` ve job
   `env`'i:
   ```yaml
       env:
         # secrets bağlamı adım if:'lerinde kullanılamaz; deploy kararı job env'i üzerinden taşınır.
         HAS_DEPLOY_SECRETS: ${{ secrets.FIREBASE_SERVICE_ACCOUNT != '' && secrets.FIREBASE_PROJECT_ID != '' }}
   ```
5. `steps:` bu sırayla, bu adlarla (adı olmayanlar yalnızca `uses:` ya da `run:`):
   1. `uses: actions/checkout@v5`, `with: persist-credentials: false`; üstünde yorum: token
      `.git/config`'e yazılmaz, sonraki adımlar repo kimliğiyle git işlemi yapamaz.
   2. `uses: subosito/flutter-action@v2`, `with: channel: stable` ve `cache: true` (Flutter sürümü
      sabitlenmez).
   3. `name: Firebase ayarı`; üstünde yorum: `lib/firebase_options.dart` .gitignore'dadır (AGENTS.md §2
      karar 7), secret'tan ya da placeholder'dan üretilir. `env: FIREBASE_OPTIONS_DART: ${{ secrets.FIREBASE_OPTIONS_DART }}`;
      `run: |`
      ```bash
      if [ -n "$FIREBASE_OPTIONS_DART" ]; then
        printf '%s\n' "$FIREBASE_OPTIONS_DART" > lib/firebase_options.dart
      else
        cp lib/firebase_options.dart.example lib/firebase_options.dart
        echo "::warning::FIREBASE_OPTIONS_DART boş; placeholder ile build (sohbet kapalı)"
      fi
      ```
   4. `name: App Check anahtarı`; üstünde yorum: gerçek Firebase ayarı varken site key boşsa App Check
      kurulmaz ve sohbet kapalı yayınlanır (main.dart fail-closed, AGENTS.md §6); bunu sessizce
      yayınlamak yerine iş burada durur. `env:` iki satır,
      `FIREBASE_OPTIONS_DART: ${{ secrets.FIREBASE_OPTIONS_DART }}` ve
      `RECAPTCHA_SITE_KEY: ${{ secrets.RECAPTCHA_SITE_KEY }}`; `run: |`
      ```bash
      if [ -n "$FIREBASE_OPTIONS_DART" ] && [ -z "$RECAPTCHA_SITE_KEY" ]; then
        echo "::error::FIREBASE_OPTIONS_DART dolu ama RECAPTCHA_SITE_KEY boş: App Check olmadan sohbet kapalı yayınlanır. RECAPTCHA_SITE_KEY secret'ını ekle (README §4)."
        exit 1
      fi
      ```
      İkisi de boşsa (ilk kurulum, fork) adım geçer; placeholder ile build sürer.
   5. `run: flutter pub get`
   6. `run: flutter analyze`
   7. `run: flutter test`
   8. `name: Build (wasm)`; üstünde yorum: site key boşsa boş string geçer, main.dart App Check'i atlar,
      sohbet kapalı kalır (AGENTS.md §6). `env: RECAPTCHA_SITE_KEY: ${{ secrets.RECAPTCHA_SITE_KEY }}`;
      `run: flutter build web --wasm --dart-define=RECAPTCHA_SITE_KEY="$RECAPTCHA_SITE_KEY"`
   9. `name: Deploy`; `if: env.HAS_DEPLOY_SECRETS == 'true' && github.ref == 'refs/heads/main'`;
      `uses: FirebaseExtended/action-hosting-deploy@v0`; `with:` yalnızca üç satır:
      `firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}`,
      `projectId: ${{ secrets.FIREBASE_PROJECT_ID }}`, `channelId: live`.
   10. `name: Deploy atlandı`; `if: env.HAS_DEPLOY_SECRETS != 'true' || github.ref != 'refs/heads/main'`;
       `run: |` tek satır:
       `echo "::notice::Deploy atlandı: FIREBASE_SERVICE_ACCOUNT / FIREBASE_PROJECT_ID yok (README §4) ya da dal main değil"`
6. Kabul'deki komutları sırayla çalıştır, çıktılarını raporla.

**Yapma:** `firebase init hosting:github` çalıştırma (kendi workflow'unu ve `.firebaserc`'yi yazar);
`firebase.json`, `.gitignore`, `pubspec.yaml`, `lib/`, `test/` ve `.md` dosyalarını düzenleme; ikinci
job, matrix, ek cache adımı; Flutter sürümü sabitleme; `pull_request` tetiği, preview kanalı,
`repoToken`, `expires`; secret adlarını farklı yazma; git yazma komutu (`add`, `commit`, `push`);
`flutter run`.

**Kabul:**
- YAML ayrıştırılır: `ruby -ryaml -e 'YAML.load_file(".github/workflows/deploy.yml"); puts "ok"'` → `ok`.
- Adım sırası:
  `ruby -ryaml -e 'y=YAML.load_file(".github/workflows/deploy.yml"); puts y["jobs"]["build-and-deploy"]["steps"].map{|s| s["name"] || s["uses"] || s["run"]}'`
  → sırayla `actions/checkout@v5`, `subosito/flutter-action@v2`, `Firebase ayarı`, `App Check anahtarı`,
  `flutter pub get`, `flutter analyze`, `flutter test`, `Build (wasm)`, `Deploy`, `Deploy atlandı`.
- `ruby` yoksa iki YAML kontrolünü atla ve raporda belirt: GitHub Actions ilk koşuda dosyayı
  ayrıştırır, hata Actions sekmesinde görünür. `actionlint` kuruluysa temiz; yoksa atlanır.
- Secret adları: `grep -oE "secrets\.[A-Z_]+" .github/workflows/deploy.yml | sort -u` → tam dört satır:
  `secrets.FIREBASE_OPTIONS_DART`, `secrets.FIREBASE_PROJECT_ID`, `secrets.FIREBASE_SERVICE_ACCOUNT`,
  `secrets.RECAPTCHA_SITE_KEY`.
- Yasak kalıp yok: `grep -nE "if:.*secrets|pull_request|repoToken|GITHUB_TOKEN|expires|preview" .github/workflows/deploy.yml` boş.
- Literal yok: `grep -nE "AIza|6L[0-9A-Za-z_-]{38}|\.web\.app|\.firebaseapp\.com|https?://" .github/workflows/deploy.yml` boş.
- `grep -c "persist-credentials: false" .github/workflows/deploy.yml` → `1`;
  `grep -c "exit 1" .github/workflows/deploy.yml` → `1`.
- `flutter analyze` sıfır uyarı; `dart format --output=none --set-exit-if-changed .` temiz;
  `flutter test` yeşil; `flutter build web --wasm` lokalde başarılı.
- Sır taraması: `AGENTS.md` §7'deki `git grep --untracked` satırı boş (yeni `deploy.yml`'yi de tarar).
  `git diff --cached` satırını ajan değil, kullanıcı `git add -A`'dan sonra koşar.
- Gerçek yayın kullanıcıda (ajan değil): dört secret GitHub'a girilir, `main`'e push edilir (ya da
  GitHub → Actions → Deploy → Run workflow). Actions sekmesinde iş yeşil; secret'sız koşuda
  "Deploy atlandı" notu beklenir. Yayından sonra
  `curl -sI https://<proje-id>.web.app/video/<ad>.mp4 | grep -i cache-control` →
  `public, max-age=31536000, immutable`; `https://<proje-id>.web.app/olmayan-yol` siteyi açar
  (SPA rewrite).

**Karar noktaları:** yok.

**Kodlama ajanının doküman işi:** yalnızca `deploy.yml` içindeki yorumlar (adım 1 ve adımların üstündeki
yorumlar). `.md` dosyalarına dokunmaz.

**Doküman turu (doküman ajanı ya da ana oturum yapar):** Her maddede "P5.1 duruyorsa" = P5.1 paketi hâlâ
bu dosyada; "P5.1 bittiyse" = paketi silinmiş. Metin bu arada başka biçimde düzenlenmişse aynı anlamdaki
satırı bul. Sonda `grep -n "Faz 4\|P4.1" AGENTS.md CLAUDE.md README.md docs/tarayici-kontrol.md` boş
dönmeli; `docs/roadmap.md`'de yalnızca (duruyorsa) P5.1 paketinin kendi "P4.1 duruyorsa / bittiyse"
satırları kalır.

1. `AGENTS.md`
   - §3 ağacında `deploy.yml` satırının yorumu:
     ```
     # Firebase Hosting deploy: yalnızca `main`'e push (+ elle workflow_dispatch) tetikler, PR/preview yok; analyze + test + wasm build, 4 secret varsa deploy (README §4)
     ```
   - §1 tablosunda Hosting satırı:
     ```
     | Hosting | Firebase Hosting | Elle `firebase deploy` ya da GitHub Actions ile otomatik deploy (`main`'e push) |
     ```
   - §7'de `# otomatik yayın (.github/workflows/deploy.yml) Faz 4'te eklenir: docs/roadmap.md P4.1`
     satırı şu iki satır olur:
     ```
     # GitHub Actions (.github/workflows/deploy.yml): FIREBASE_OPTIONS_DART secret'ı dolu ama
     # RECAPTCHA_SITE_KEY boşsa iş durur (sohbet kapalı yayınlanmasın); ikisi de boşsa placeholder ile build edilir.
     ```
   - §9 dal maddesinde "Otomatik yayın (Faz 4'ten sonra) `main`'e her push'ta çalışır" →
     "Otomatik yayın (`.github/workflows/deploy.yml`) `main`'e her push'ta çalışır".
   - Dosya başındaki `docs/roadmap.md` satırı: P5.1 duruyorsa ilk, P5.1 bittiyse ikinci metin:
     ```
     İş paketleri (hazır görev: Faz 5 klavye) için: `docs/roadmap.md`
     Aktif işin ayrıntılı iş paketleri için: `docs/roadmap.md`
     ```
   - §3 `roadmap.md` satırı: P5.1 duruyorsa
     ```
     │   ├── roadmap.md             # iş paketleri — "tam olarak nasıl"; hazır: P5.1 (klavye);
     │   │                          #   biten paket silinir, günlük tutmaz
     ```
     P5.1 bittiyse (tek satır, ikinci satır silinir)
     ```
     │   ├── roadmap.md             # aktif işin paketleri — "tam olarak nasıl"; iş bitince silinir, günlük tutmaz
     ```
   - §9 ilk maddede "İki görev hazır yazılıdır: "Faz 4'ü uygula" → P4.1 (otomatik yayın), "Faz 5'i
     uygula" → P5.1 (klavyeyle gezinme)." cümlesi: P5.1 duruyorsa `Hazır yazılı görev: "Faz 5'i uygula"
     → P5.1 (klavyeyle gezinme).`; P5.1 bittiyse cümle silinir.
2. `CLAUDE.md`
   - Doküman haritasının `docs/roadmap.md` satırı: P5.1 duruyorsa ilk, P5.1 bittiyse ikinci metin:
     ```
     | Sıradaki işin dosya dosya, adım adım planı; hazır görev (P5.1) | `docs/roadmap.md` |
     | Sıradaki işin dosya dosya, adım adım planı | `docs/roadmap.md` |
     ```
   - "Dal:" paragrafında "Faz 4'ten sonra `main`'e her push siteyi yayına alır." →
     "`main`'e her push siteyi yayına alır (`.github/workflows/deploy.yml`)."
   - "Git kullanıcıda"da "`main`'e push ise (Faz 4'ten sonra) siteyi yayına alır" → "`main`'e push ise
     siteyi yayına alır".
   - "### Hazır görevler: Faz 4 ve Faz 5" bölümü: P5.1 bittiyse bölümün tamamı (başlık dahil) silinir.
     P5.1 duruyorsa bölüm şu olur:
     ```
     ### Hazır görev: Faz 5

     Şablonun `docs/roadmap.md`'sinde bir paket hazır yazılıdır: **P5.1** (klavyeyle gezinme). Kullanıcı
     "Faz 5'i uygula" deyince paket hazır olduğu için analiz ve plan kısa geçer: ana oturum paketi okur,
     kodun paketin varsaydığı durumda olduğunu kontrol eder, kullanıcıya ne yapılacağını ve neden işe
     yaradığını iki üç cümleyle anlatır, sonra kodlama ajanını açar. Döngünün 3–5. adımları aynen uygulanır.
     ```
3. `README.md`
   - Bölüm 4 "GitHub Actions ile otomatik deploy": "Şablonda `.github/workflows/deploy.yml` yoktur: bu
     dosyayı ajana yazdırırsın. Bu ilk "ajan görevin" olur." →
     "`.github/workflows/deploy.yml` hazır: `main`'e her push'ta analyze, test ve build çalışır; dört
     secret girilince site yayınlanır."
   - Bölüm 4 adım 1 ("**1. Ajana yazdır.**", `Faz 4'ü uygula.` kod bloğu ve "Ajan `docs/roadmap.md`'deki
     P4.1 paketini okur … secret'tan okunmalı." paragrafı) tek paragraf olur; adım numaraları değişmez:
     ```
     **1. Dosyaya bak.** `.github/workflows/deploy.yml`'de sırayla `flutter analyze`, `flutter test`, wasm
     build ve deploy adımları var; içinde hiçbir anahtar yazmaz, hepsi secret'tan okunur.
     ```
   - Bölüm 6 "Hazır iki görev" tablosu: `Faz 4'ü uygula.` satırı silinir. P5.1 duruyorsa başlık
     "### Hazır görev" olur; P5.1 bittiyse alt bölümün tamamı (başlık + tablo) silinir.
   - Bölüm 6 "Claude Code'da nasıl denir": metin `Faz 4'ü uygula.` örneğini veriyorsa ve P5.1 bittiyse
     "Açılınca görevi yaz: … Kendi fikrin için de aynısı geçerli: ne istediğini düz Türkçe anlat." →
     "Açılınca ne istediğini düz Türkçe yaz. Ajan önce `AGENTS.md`'yi okur, işi `docs/roadmap.md`'de
     paketlere böler, sonra çalışır." (Metin `Faz 5'i uygula.` diyorsa ve P5.1 duruyorsa dokunma.)
   - Giriş tablosu adım 6 ("İstersen ajana iki ek özellik yazdır: otomatik yayın, klavyeyle gezinme
     (bölüm 6)"): P5.1 duruyorsa "İstersen ajana klavyeyle gezinmeyi yazdır (bölüm 6)"; P5.1 bittiyse
     "Ajanla kendi özelliğini ekle (bölüm 6)".
   - "Gerekenler" tablosunda Claude Code satırı ("Bölüm 6 ve Faz 4/5 için gerekir"): P5.1 duruyorsa
     "Bölüm 6 ve Faz 5 için gerekir"; P5.1 bittiyse "Bölüm 6 için gerekir".
   - "Sorun giderme" tablosunda "`.github/workflows/deploy.yml` yok" satırı silinir.
4. `docs/tarayici-kontrol.md`: "## Faz 4'ü uyguladıktan sonra (otomatik yayın)" başlığı
   "## Otomatik yayın (GitHub Actions)" olur; maddeler aynen kalır (yayın sonrası kontroller).
5. `docs/roadmap.md`
   - Bu paket (başlığından bir sonraki `---`'e kadar) silinir.
   - Kurallar'ın ilk maddesi: P5.1 duruyorsa "şablonla gelen iki hazır görev (P4.1, P5.1)" →
     "şablonla gelen hazır görev (P5.1)"; P5.1 bittiyse madde şu olur:
     ```
     - Burada yalnızca aktif işin paketleri durur. İş bitince paketleri silinir; dosya günlük tutmaz,
       bayatlamaz. Sonradan bilinmesi gereken şey `AGENTS.md`'ye ya da kod yorumuna yazılır.
     ```
   - "Aktif faz" notu: P5.1 duruyorsa `**Aktif faz: yok.** Sıradaki hazır görev: Faz 5 (P5.1). "Faz 5'i
     uygula" de.`; P5.1 bittiyse `**Aktif faz: yok.** Yeni iş kullanıcıdan gelince paketleri buraya yazılır.`

---

### P5.1 — Klavyeyle gezinme

**Bağımlılık:** yok.

**Dosyalar:** `lib/stage/track.dart` (değiştir), `test/track_test.dart` (değiştir),
`test/stage_wiring_test.dart` (değiştir).

**Amaç:** Masaüstünde `PageDown` / `↓` / `Space` sonraki, `PageUp` / `↑` önceki, `Home` ilk, `End` son
bölüme gider; sohbet kutusuna yazarken bu tuşlar sayfayı kaydırmaz; davranış gerçek tuş olayı gönderen
testlerle kapatılır.

**Bağlam:** AGENTS.md §4 (Ray; bölüme kaydırmanın tek kapısı `ScrollProgress.animateToChapter`,
hareket azaltılmışsa `jumpTo`), §8 (ikinci scroll kaynağı yok), §10.6 (hareketi azalt), §11.1, §11.4
(klavye `tester.sendKeyDownEvent` ile test edilir). Oku: `lib/stage/track.dart`,
`lib/story/scroll_progress.dart` (`chapterCount`, `value.chapterIndex`, `animateToChapter`,
`reduceMotion`), `lib/ai/chat_panel.dart` (sohbet `TextField`'ı), `test/track_test.dart`,
`test/stage_wiring_test.dart`.

Neden global handler: `Focus` / `Shortcuts` / `Actions` ağacı kullanılmaz; sohbet paneli kapanınca odak
kaybolur ve odak tabanlı kısayollar düşer. `HardwareKeyboard.instance` handler'ı odaktan bağımsızdır.
Neden `animateToChapter`: klavye ikinci bir scroll kaynağı değildir (§8); hareketi azalt açıkken
`animateToChapter` zaten `jumpTo` yapar, ek kod gerekmez.

Bilinen sınırlar (kabul edilir, düzeltilmez): Shift+Space de ileri gider (geri değil); PageUp önceki
bölümün başına gider, içinde bulunulan bölümün başına değil; adım 2'deki 8. test, `_onKey`'deki
`mounted` koruması yüzünden `removeHandler` satırını tek başına kanıtlamaz (kod incelemesinde
`dispose`'a bakılır).

**Adımlar:**
1. `lib/stage/track.dart`:
   1. Import ekle (zorunlu): `dart:async` (`unawaited`) ve `package:flutter/services.dart`
      (`HardwareKeyboard`, `KeyEvent`, `KeyDownEvent`, `LogicalKeyboardKey`). `EditableTextState` ve
      `FocusManager` `package:flutter/widgets.dart`'tan gelir (zaten import edili).
   2. `_TrackState.initState`: `widget.scrollProgress.attachScroller(_controller);` satırından sonra
      `HardwareKeyboard.instance.addHandler(_onKey);`.
   3. `_TrackState.dispose`: ilk satır `HardwareKeyboard.instance.removeHandler(_onKey);` (sonra mevcut
      `detachScroller` / `_controller.dispose()` aynen).
   4. Yeni metot `bool _onKey(KeyEvent event)`: `_onPointerSignal`'dan ve onun yardımcısı
      `static bool _wouldScroll`'dan SONRA, `build`'den önce. `///` yorumu: "Global klavye handler'ı;
      odaktan bağımsızdır (sohbet kapanınca odak kaybolsa da çalışır). Eşlenen tuşta hedef değişmese
      de `true` döner: tarayıcının varsayılan kaydırması olmasın." Gövde, sırayla:
      - `if (!mounted || event is! KeyDownEvent) return false;` (tuş tekrarı `KeyRepeatEvent` ve bırakma
        `KeyUpEvent` yok sayılır; dağıtım sırasında sökülen Ray tuşu işlemez).
      - Metin alanı odaklıysa `false`:
        `FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null`.
      - `final progress = widget.scrollProgress; final last = progress.chapterCount - 1;`
        `if (last < 0) return false;` `final current = progress.value.chapterIndex;`
      - Hedef:
        ```dart
        final target = switch (event.logicalKey) {
          LogicalKeyboardKey.pageDown ||
          LogicalKeyboardKey.arrowDown ||
          LogicalKeyboardKey.space => current + 1,
          LogicalKeyboardKey.pageUp || LogicalKeyboardKey.arrowUp => current - 1,
          LogicalKeyboardKey.home => 0,
          LogicalKeyboardKey.end => last,
          _ => null,
        };
        ```
      - `if (target == null) return false;`
        `unawaited(progress.animateToChapter(target.clamp(0, last)));` `return true;`
   5. `Track` sınıfının `///` yorumuna, tekerlek paragrafından sonra yeni paragraf: "Klavye:
      PageDown/↓/Space sonraki, PageUp/↑ önceki, Home ilk, End son bölüme
      [ScrollProgress.animateToChapter] ile gider; metin alanı odaklıyken devre dışıdır."
2. `test/track_test.dart` (mevcut `pumpTrack(tester, {reduceMotion})`, `lengths = [4.0, 1.5, 4.0, 2.0,
   1.5, 1.0]` ve `scrollProgress` kullanılır; dosya başındaki `///` yorumuna "klavye bölüm bölüm gezer"
   eklenir; `package:flutter/services.dart` import'u zorunlu: `LogicalKeyboardKey`, `HardwareKeyboard`,
   `KeyEvent`, `KeyDownEvent`).
   Yazım kuralı: her `sendKeyDownEvent`'in ardından aynı tuş için `sendKeyUpEvent` gönderilir (test
   içinde arada `pump` olabilir); yoksa sonraki testte "tuş zaten basılı" hatası çıkar.
   - Yardımcı `Future<bool> press(WidgetTester tester, LogicalKeyboardKey key)`: `sendKeyDownEvent` →
     `sendKeyUpEvent` → `pumpAndSettle`; `sendKeyDownEvent`'in dönüşünü (olay işlendi mi) döner.
   - Dosya sonunda yardımcı sınıf `_RecordingScrollProgress extends ScrollProgress`
     (`required super.scrollLengths`): `final List<int> targets = [];`, `animateToChapter(int index)`'i
     override edip `targets.add(index)` sonra `super.animateToChapter(index)` döner.
   - Testler (ad → beklenti):
     1. `klavye: PageDown sonraki, PageUp önceki bölüm` → PageDown `true` döner, bölüm 1, `progress` 0;
        PageUp `true` döner, bölüm 0.
     2. `klavye: ArrowDown ve Space sonraki, ArrowUp önceki bölüm` → ↓ 1, ↓ 2, Space 3, ↑ 2.
     3. `klavye: End son, Home ilk bölüm` → End `lengths.length - 1`; Home 0 ve `globalProgress` 0.
     4. `klavye: PageDown, ArrowDown, End, Home, ArrowUp, Space, PageUp sırası` → kayıt listesi
        `(tuş, beklenen bölüm)`: 1, 2, son, 0, 0, 1, 0; her adımda `reason: '$key'`.
     5. `klavye: uçlarda kalır, tuş yine de işlenir` → başta ↑ `true` döner, bölüm 0 ve
        `globalProgress` 0; End sonrası PageDown `true` döner, bölüm hâlâ son.
     6. `klavye: eşlenmeyen tuş ve tuş tekrarı kaydırmaz` → `keyA` `false` döner, bölüm 0; PageDown down
        + `pumpAndSettle` → 1; `sendKeyRepeatEvent(pageDown)` `false` döner; up + `pumpAndSettle`
        sonrası bölüm hâlâ 1.
     7. `reduced-motion: klavye tek karede bölüm değiştirir` → `pumpTrack(reduceMotion: true)`; PageDown
        down + tek `pump()` → bölüm 1; sonra PageDown up.
     8. `klavye: Ray değişince eski handler kaldırılır, Ray kalkınca tuş işlenmez` → iki
        `_RecordingScrollProgress` (`first`, `second`; `addTearDown(...dispose)`), `Directionality`
        içinde. `Track(key: ValueKey('ilk'), scrollProgress: first)`: PageDown `true`, `first.targets`
        `[1]`. `ValueKey('ikinci')` + `second` ile yeniden pump (yeni State, eskisi dispose): PageDown
        `true`, `first.targets` hâlâ `[1]`, `second.targets` `[1]`, `second.value.chapterIndex` 1.
        Ağaç `SizedBox.expand()` olunca PageDown `false`, iki liste değişmez, `tester.takeException()` null.
     9. `klavye: tuş dağıtılırken sökülen Ray hata vermez, tuşu işlemez` → `HardwareKeyboard`
        handler'ları eklenme sırasıyla çağırır ve dağıtım sırasında kaldırılan handler'ı o turda yine
        çağırır. Test, Ray kurulmadan ÖNCE `HardwareKeyboard.instance.addHandler(unmountTrack)` ekler
        (`addTearDown` ile kaldırır). `unmountTrack(KeyEvent event)`: `KeyDownEvent` ve Ray görünürken
        `StatefulBuilder`'ın `setState`'iyle Ray'ı `SizedBox.expand()` ile değiştirir, ağacı eşzamanlı
        söker (`final owner = tester.binding.buildOwner!; owner.buildScope(tester.binding.rootElement!);
        owner.finalizeTree();`) ve `false` döner. Ağaç: `Directionality` → `StatefulBuilder` →
        `showTrack ? Track(scrollProgress: progress) : SizedBox.expand()` (`progress` bir
        `_RecordingScrollProgress`). Beklenti: PageDown `false`, `find.byType(Track)` yok,
        `progress.targets` boş, `takeException()` null. Bu test `_onKey`'deki `!mounted` kontrolünü kanıtlar.
3. `test/stage_wiring_test.dart` (mevcut `pumpSite`, `chatOpen`, `scrollProgress`;
   `package:flutter/services.dart` import'u zorunlu: `LogicalKeyboardKey`): test
   `klavye: sohbet kutusu odaklıyken PageDown kaydırmaz` → yerel `pageDown()` (down + up +
   `pumpAndSettle`). `pumpSite`; `chatOpen.value = true` + `pump`; `find.byType(TextField)`'a tap +
   `pump`; `pageDown()` → bölüm 0, `progress` 0. `chatOpen.value = false` + `pumpAndSettle`;
   `TextField` yok; `pageDown()` → bölüm 1 (panel kapanınca odak gitse de handler çalışır).
4. Kabul'deki komutları çalıştır, çıktılarını raporla.

**Yapma:** `Focus`, `FocusScope`, `Shortcuts`, `Actions`, `KeyboardListener`, `RawKeyboard`
(deprecated) kullanma; `ScrollController`'ı klavyeden doğrudan sürme (`animateTo`/`jumpTo`) ya da
ikinci scroll kaynağı ekleme (§8); `lib/story/scroll_progress.dart`'ı değiştirme (gerekmez); tuş
tekrarıyla sürekli kaydırma; bilinen sınırları "düzeltme"; yeni bağımlılık; `.md` dosyaları;
`flutter run`; git yazma komutu.

**Kabul:**
- `flutter analyze` sıfır uyarı; `dart format --output=none --set-exit-if-changed .` temiz;
  `flutter test` yeşil (yeni 9 + 1 test dahil; önce `flutter test test/track_test.dart test/stage_wiring_test.dart`).
- `grep -n "addHandler\|removeHandler" lib/stage/track.dart` → iki satır (`initState`, `dispose`).
- `grep -rnE "Shortcuts\(|Actions\(|FocusScope|KeyboardListener|RawKeyboard" lib` boş.
- AGENTS.md §7 token sızıntı taraması ve `git grep --untracked` sır taraması boş.
- Tarayıcı maddesi kullanıcıda (`docs/tarayici-kontrol.md`): Chrome'da tuşlar bölüm bölüm gezer;
  sohbet kutusuna yazarken sayfa kaymaz; panel kapanınca tuşlar yine çalışır.

**Karar noktaları:** yok.

**Kodlama ajanının doküman işi:** yalnızca kod yorumları (adım 1.4 ve 1.5'teki `///` yorumları, adım
2'deki test dosyası başlık yorumu). `.md` dosyalarına dokunmaz.

**Doküman turu (doküman ajanı ya da ana oturum yapar):** Her maddede "P4.1 duruyorsa" = P4.1 paketi hâlâ
bu dosyada; "P4.1 bittiyse" = paketi silinmiş. Metin bu arada başka biçimde düzenlenmişse aynı anlamdaki
satırı bul. Sonda `grep -n "Faz 5\|P5.1" AGENTS.md CLAUDE.md README.md docs/tarayici-kontrol.md` boş
dönmeli; `docs/roadmap.md`'de yalnızca (duruyorsa) P4.1 paketinin kendi "P5.1 duruyorsa / bittiyse"
satırları kalır.

1. `AGENTS.md`
   - §4'teki iki satırlık **Klavye** notu (`**Klavye.** Klavyeyle gezinme ... bu bölüme yazılır.`) şu
     paragraf olur, birebir:
     ```
     **Klavye.** `Track` global bir `HardwareKeyboard.instance` handler'ı kurar (`initState`'te
     `addHandler`, `dispose`'da `removeHandler`): `PageDown` / `↓` / `Space` sonraki, `PageUp` / `↑` önceki,
     `Home` ilk, `End` son bölüm. Hedef `0..chapterCount-1`'e kırpılır ve yalnızca `animateToChapter`'a
     verilir; klavye ikinci bir scroll kaynağı değildir (§8). Yalnızca `KeyDownEvent` işlenir (tuş tekrarı
     yok sayılır); eşlenen tuşta hedef değişmese de olay tüketilir, tarayıcının varsayılan kaydırması
     olmaz. Metin alanı odaklıyken (`FocusManager.instance.primaryFocus` bir `EditableTextState` altında)
     handler `false` döner: sohbet kutusuna yazılan boşluk ve oklar sayfayı kaydırmaz. `Focus` /
     `Shortcuts` / `Actions` ağacı kullanılmaz: sohbet paneli kapanınca odak kaybolur ve odak tabanlı
     kısayollar düşer; global handler odaktan bağımsızdır. Testler `test/track_test.dart` (tuşlar, uçlar,
     Ray sökülünce handler kalkar) ve `test/stage_wiring_test.dart` (sohbet kutusu odaklıyken kaydırmaz).
     ```
   - §4'te "Nav tıklaması, kapaktaki "İletişim" pill'i ve footer'daki "YUKARI" yalnızca
     `animateToChapter` çağırır" → "Nav tıklaması, kapaktaki "İletişim" pill'i, footer'daki "YUKARI"
     ve klavye kısayolları yalnızca `animateToChapter` çağırır".
   - §3 ağacı:
     ```
     │   │   ├── track.dart             # Kaydırılabilir "Ray" katmanı (CustomScrollView) + klavye kısayolları (§4)
     │   ├── track_test.dart            # Ray: tekerlek, sürükleme, tıklama geçişi (TestPointer), klavye kısayolları, reduced-motion, yükseklik değişiminde konum
     │   ├── stage_wiring_test.dart     # Stage/app bağlama sözleşmeleri (web import'suz); klavye/odak, nav semantics, 720 eşiğinde durumun korunması
     ```
   - §11.4: "tekerlek, sürükleme ve tıklama örneği `test/track_test.dart`" → "örnek `test/track_test.dart`".
   - Dosya başındaki `docs/roadmap.md` satırı: P4.1 duruyorsa ilk, P4.1 bittiyse ikinci metin:
     ```
     İş paketleri (hazır görev: Faz 4 otomatik yayın) için: `docs/roadmap.md`
     Aktif işin ayrıntılı iş paketleri için: `docs/roadmap.md`
     ```
   - §3 `roadmap.md` satırı: P4.1 duruyorsa
     ```
     │   ├── roadmap.md             # iş paketleri — "tam olarak nasıl"; hazır: P4.1 (otomatik yayın);
     │   │                          #   biten paket silinir, günlük tutmaz
     ```
     P4.1 bittiyse (tek satır, ikinci satır silinir)
     ```
     │   ├── roadmap.md             # aktif işin paketleri — "tam olarak nasıl"; iş bitince silinir, günlük tutmaz
     ```
   - §9 ilk maddede hazır görevler cümlesi: P4.1 duruyorsa `Hazır yazılı görev: "Faz 4'ü uygula" → P4.1
     (otomatik yayın).`; P4.1 bittiyse cümle silinir.
2. `CLAUDE.md`
   - Doküman haritasının `docs/roadmap.md` satırı: P4.1 duruyorsa ilk, P4.1 bittiyse ikinci metin:
     ```
     | Sıradaki işin dosya dosya, adım adım planı; hazır görev (P4.1) | `docs/roadmap.md` |
     | Sıradaki işin dosya dosya, adım adım planı | `docs/roadmap.md` |
     ```
   - "### Hazır görevler: Faz 4 ve Faz 5" bölümü: P4.1 bittiyse (bölüm "### Hazır görev: Faz 5" ise)
     bölümün tamamı (başlık dahil) silinir. P4.1 duruyorsa bölüm şu olur:
     ```
     ### Hazır görev: Faz 4

     Şablonun `docs/roadmap.md`'sinde bir paket hazır yazılıdır: **P4.1** (GitHub Actions ile otomatik
     yayın). Kullanıcı "Faz 4'ü uygula" deyince paket hazır olduğu için analiz ve plan kısa geçer: ana
     oturum paketi okur, kodun paketin varsaydığı durumda olduğunu kontrol eder (ör. `deploy.yml` zaten
     var mı), kullanıcıya ne yapılacağını ve neden işe yaradığını iki üç cümleyle anlatır, sonra kodlama
     ajanını açar. Döngünün 3–5. adımları aynen uygulanır. Kapanış raporunda kullanıcının GitHub'a
     gireceği dört secret ve ilk yayını nasıl kontrol edeceği adım adım yazılır (`README.md` §4).
     ```
3. `README.md`
   - Bölüm 6 "Hazır iki görev" (ya da "Hazır görev") tablosu: `Faz 5'i uygula.` satırı silinir. P4.1
     duruyorsa başlık "### Hazır görev" olur; P4.1 bittiyse alt bölümün tamamı (başlık + tablo) silinir.
   - Bölüm 6 "Claude Code'da nasıl denir": "Açılınca görevi yaz: `Faz 5'i uygula.`" → P4.1 duruyorsa
     "Açılınca görevi yaz: `Faz 4'ü uygula.`" (cümlenin geri kalanı aynen); P4.1 bittiyse
     "Açılınca görevi yaz: … ne istediğini düz Türkçe anlat." kısmı →
     "Açılınca ne istediğini düz Türkçe yaz. Ajan önce `AGENTS.md`'yi okur, işi `docs/roadmap.md`'de
     paketlere böler, sonra çalışır."
   - Giriş tablosu adım 6: P4.1 duruyorsa "İstersen ajana otomatik yayını yazdır (bölüm 6)"; P4.1
     bittiyse "Ajanla kendi özelliğini ekle (bölüm 6)".
   - "Gerekenler" tablosunda Claude Code satırı: P4.1 duruyorsa "Bölüm 6 ve Faz 4 için gerekir"; P4.1
     bittiyse "Bölüm 6 için gerekir".
   - Klavyenin "yok" ya da "Faz 5'te gelir" dendiği başka cümle varsa (`grep -n "lavye" README.md`)
     kaldırılır ya da "klavyeyle gezinme var" olarak düzeltilir.
4. `docs/tarayici-kontrol.md`
   - "## Faz 5'i uyguladıktan sonra (klavyeyle gezinme)" bölümünün klavye maddeleri "Masaüstü (Chrome)"
     bölümüne, "Nav tıklaması doğru bölüme kayıyor" maddesinin altına taşınır ve o başlık silinir;
     maddeler işaretsiz (`- [ ]`) kalır.
   - O bölümdeki "hareketi azalt" maddesi ayrı taşınmaz; Masaüstü'ndeki mevcut "hareketi azalt"
     maddesiyle tek maddede birleşir:
     ```
     - [ ] İşletim sisteminde "hareketi azalt" açıkken: crossfade ve hover anlık, nav tıklaması ve klavye
           geçişi animasyonsuz atlıyor, video poster/ilk karede sabit.
     ```
5. `docs/roadmap.md`
   - Bu paket (başlığından dosya sonuna ya da bir sonraki `---`'e kadar) silinir.
   - Kurallar'ın ilk maddesi: P4.1 duruyorsa "şablonla gelen iki hazır görev (P4.1, P5.1)" →
     "şablonla gelen hazır görev (P4.1)"; P4.1 bittiyse madde şu olur:
     ```
     - Burada yalnızca aktif işin paketleri durur. İş bitince paketleri silinir; dosya günlük tutmaz,
       bayatlamaz. Sonradan bilinmesi gereken şey `AGENTS.md`'ye ya da kod yorumuna yazılır.
     ```
   - "Aktif faz" notu: P4.1 duruyorsa `**Aktif faz: yok.** Sıradaki hazır görev: Faz 4 (P4.1). "Faz 4'ü
     uygula" de.`; P4.1 bittiyse `**Aktif faz: yok.** Yeni iş kullanıcıdan gelince paketleri buraya yazılır.`
