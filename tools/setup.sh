#!/usr/bin/env bash
# İlk kurulum: placeholder Firebase ayarını oluşturur ve bağımlılıkları indirir (Firebase'siz çalıştırma)
#
# Kullanım:  tools/setup.sh        (her dizinden çağrılabilir)
# Sonuç:     lib/firebase_options.dart (yoksa .example'dan kopyalanır) + flutter pub get
#
# lib/firebase_options.dart .gitignore'dadır (AGENTS.md §2 karar 7). Varsa dokunulmaz; böylece
# `flutterfire configure` ile üretilmiş gerçek ayar ezilmez. Firebase bağlamak için README adım 2.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v flutter >/dev/null || { echo "flutter bulunamadı. Kurulum: https://docs.flutter.dev/get-started/install" >&2; exit 1; }

OPTIONS="lib/firebase_options.dart"
EXAMPLE="lib/firebase_options.dart.example"

if [[ -f "$OPTIONS" ]]; then
  echo "• $OPTIONS zaten var, dokunulmadı"
else
  cp "$EXAMPLE" "$OPTIONS"
  echo "• $OPTIONS placeholder oluşturuldu (Firebase bağlamak için README adım 2)"
fi

flutter pub get

echo "✓ Hazır: flutter run -d chrome --wasm"
