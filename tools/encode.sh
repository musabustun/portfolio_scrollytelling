#!/usr/bin/env bash
# Google Flow (ya da herhangi bir kaynak) mp4 -> scroll ile sürülebilir ("scrub-ready") mp4 + poster
#
# Kullanım:  tools/encode.sh girdi.mp4 web/video/<ad>                       (varsayılan: kırpma yok)
#            CROP=auto tools/encode.sh girdi.mp4 web/video/<ad>             (Flow üst/alt siyah bant gömdüyse)
#            CROP=1016:572:132:74 tools/encode.sh girdi.mp4 web/video/<ad>  (elle kırpma: genişlik:yükseklik:x:y)
# Dikey (9:16) mobil video: WIDTH=540 CRF=31 FPS=24 tools/encode.sh raw/x_mobile.mp4 web/video/x_mobile  → 540×960
# Ayar:      CRF (kalite, varsayılan 23), WIDTH (genişlik px, varsayılan 1280), FPS (varsayılan 30) ortam değişkenidir.
#            Önerilen: CRF=30 (dikey video 31) ve FPS=24; varsayılanlar daha büyük dosya üretir.
#            örn. CRF=30 FPS=24 tools/encode.sh girdi.mp4 web/video/<ad>
# Çıktı:     web/video/<ad>.mp4  ve  web/video/<ad>.jpg
#
# Neden gerekli? Normal videolarda yalnızca her 5-10 saniyede bir "tam kare" (keyframe) vardır;
# tarayıcı currentTime=3.7 dediğinde önceki keyframe'e gidip oraya kadar decode eder. Scroll'da
# saniyede onlarca kez bunu yapmak takılma yaratır. -g 1 ile HER kare keyframe olur: dosya büyür,
# scroll ipek gibi akar. Ses atılır (scroll'da ses oynatılmaz), WIDTH genişliğine (varsayılan 1280 px)
# ölçeklenir, faststart ile metadata başa alınır (ilk seek beklemez).
#
# Siyah bantlar (CROP): Flow videoların üstüne ve altına siyah bant gömer; site videoyu
# object-fit: cover ile tüm ekrana yaydığı için bu bantlar ekranda siyah şerit olarak görünür.
# Kırpma yalnızca istenirse yapılır: CROP=auto bantları bulur ve bantsız resmin ortasından 16:9
# bir pencere keser. Çok karanlık videolarda auto gerçek görüntüyü bant sanıp kesebilir; çıktıyı kontrol et.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Kullanım: $0 girdi.mp4 web/video/<ad>   (uzantısız hedef)" >&2
  exit 1
fi

IN="$1"
OUT_BASE="$2"
OUT_MP4="${OUT_BASE}.mp4"
OUT_JPG="${OUT_BASE}.jpg"

# Önerilen CRF=30 (dikey 31); dosya hâlâ büyükse 33'e kadar artır. Daha kaliteli istiyorsan düşür.
CRF="${CRF:-23}"
WIDTH="${WIDTH:-1280}"
FPS="${FPS:-30}"
# none = hiç dokunma (varsayılan), auto = bantları bul ve kes, W:H:X:Y = ffmpeg crop değerini elle ver
CROP="${CROP:-none}"

command -v ffmpeg >/dev/null || { echo "ffmpeg bulunamadı. brew install ffmpeg / sudo apt install ffmpeg" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe bulunamadı (ffmpeg ile birlikte gelir)." >&2; exit 1; }
[[ -f "$IN" ]] || { echo "Girdi yok: $IN" >&2; exit 1; }
mkdir -p "$(dirname "$OUT_BASE")"

# Kırpma filtresi; boş kalırsa video kırpılmaz. Doluysa scale'den önce çalışır.
CROP_FILTER=""
case "$CROP" in
  none)
    echo "→ Kırpma yok (CROP=none varsayılan; bant varsa CROP=auto)"
    ;;
  auto)
    echo "→ Letterbox taranıyor: $IN"
    # ffmpeg videonun tamamını tarar ve "crop=W:H:X:Y" önerileri yazar; sonuncusu tüm videoyu kapsar.
    # Sonuç çıkmazsa (|| true) betik durmaz, aşağıda uyarı verilir.
    DETECT=$(ffmpeg -hide_banner -nostats -i "$IN" -vf cropdetect=limit=24:round=2:reset=0 -f null - 2>&1 \
      | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' | tail -n 1 || true)
    if [[ -z "$DETECT" ]]; then
      echo "⚠ Letterbox tespiti sonuç vermedi, kırpma yapılmadı" >&2
    else
      SRC_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$IN")
      SRC_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=nw=1:nk=1 "$IN")
      # Yalnızca yükseklik (PIC_H) ve üst bant (PIC_Y) kullanılır. Genişlik tahminine güvenilmez:
      # Flow sol tarafı bilerek karanlık bırakır, ffmpeg orayı da bant sanabilir.
      IFS=: read -r _ PIC_H _ PIC_Y <<< "${DETECT#crop=}"
      if (( PIC_H >= SRC_H - 2 )); then
        echo "→ Letterbox yok, kırpma yapılmadı"
      else
        # Bantsız resmin ortasından 16:9 pencere. Ölçüler çift sayı olmalı (yuv420p şartı).
        WIN_H=$PIC_H
        WIN_W=$(( PIC_H * 16 / 9 / 2 * 2 ))
        if (( WIN_W > SRC_W )); then
          WIN_W=$SRC_W
        fi
        WIN_X=$(( (SRC_W - WIN_W) / 2 / 2 * 2 ))
        CROP_FILTER="crop=${WIN_W}:${WIN_H}:${WIN_X}:${PIC_Y},"
        echo "→ Letterbox: üst/alt ${PIC_Y} px bar bulundu, 16:9 pencere ${WIN_W}x${WIN_H} (x=${WIN_X}) kırpılıyor"
      fi
    fi
    ;;
  *)
    CROP_FILTER="crop=${CROP},"
    echo "→ Elle kırpma: crop=${CROP}"
    ;;
esac

echo "→ Encode: $IN → $OUT_MP4 (crf=$CRF, width=$WIDTH, fps=$FPS, her kare keyframe)"
# setsar=1: kırpılan pencere tam 16:9 olmayabilir; pikseller kare kalsın, tarayıcı resmi germesin.
ffmpeg -y -hide_banner -loglevel error -stats \
  -i "$IN" \
  -an \
  -vf "${CROP_FILTER}scale=${WIDTH}:-2:flags=lanczos,setsar=1,fps=${FPS}" \
  -c:v libx264 -preset slow -crf "$CRF" \
  -g 1 -keyint_min 1 -sc_threshold 0 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$OUT_MP4"

echo "→ Poster: $OUT_JPG (ilk kare)"
ffmpeg -y -hide_banner -loglevel error \
  -i "$OUT_MP4" -frames:v 1 -q:v 3 "$OUT_JPG"

SIZE_MB=$(du -m "$OUT_MP4" | cut -f1)
echo "✓ Bitti. ${OUT_MP4} = ${SIZE_MB} MB"
if (( SIZE_MB > 10 )); then
  echo "⚠ 10 MB üstü. CRF'i artırıp (30-33, örn. CRF=32) aynı komutla tekrar çalıştır (CROP/WIDTH/FPS verdiysen onları da yaz) ya da videoyu kısalt." >&2
fi

# Doğrulama ipucu: tüm kareler I-frame mi?
#   ffprobe -v error -select_streams v -show_entries frame=pict_type -of default=nw=1:nk=1 "$OUT_MP4" | sort | uniq -c
#   (sağlıklı çıktı tek satır: "<kare sayısı> I")
