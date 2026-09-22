#!/usr/bin/env bash
#
# CSCRM ilovasini yig'adi — kalitlar bilan.
#
# Ishga tushirish (`app/` papkasidan):
#     bash tool/build_apk.sh            # prod
#     bash tool/build_apk.sh dev        # dev
#
# NEGA SKRIPT KERAK. Firebase kalitlari kodda emas, `env/*.json` da va
# ular build vaqtida `--dart-define-from-file` orqali uzatiladi. Bayroq
# UNUTILSA, `flutter build apk` baribir muvaffaqiyatli tugaydi — faqat
# natijadagi ilova kalitsiz bo'ladi va qurilmada "Serverga ulanib
# bo'lmadi" deb ochiladi. Ya'ni xato yig'ish paytida emas, foydalanuvchi
# qo'lida ko'rinadi.
#
# Shu sabab bu yerda yig'ishdan KEYIN tekshiruv ham bor: tayyor APK
# ichida loyiha identifikatori bormi. Bo'lmasa skript yiqiladi va
# kalitsiz APK tarqatilmaydi.

set -euo pipefail

ENV_NAME="${1:-prod}"
ENV_FILE="env/${ENV_NAME}.json"
APK="build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$ENV_FILE" ]; then
  echo "XATO: $ENV_FILE topilmadi." >&2
  echo "Namuna: env/example.json — undan nusxa olib to'ldiring." >&2
  exit 1
fi

PROJECT_ID="$(node -e "process.stdout.write(require('./$ENV_FILE').FIREBASE_PROJECT_ID || '')")"
if [ -z "$PROJECT_ID" ]; then
  echo "XATO: $ENV_FILE ichida FIREBASE_PROJECT_ID yo'q." >&2
  exit 1
fi

echo "Yig'ilmoqda: $ENV_NAME ($PROJECT_ID)"
flutter build apk --release --dart-define-from-file="$ENV_FILE"

# --- Tekshiruv ---
#
# Kalitlar AOT snapshot ichiga matn sifatida tushadi. Loyiha
# identifikatori topilmasa, demak bayroq ishlamagan.
if ! grep -aq "$PROJECT_ID" "$APK"; then
  echo >&2
  echo "XATO: tayyor APK ichida '$PROJECT_ID' topilmadi." >&2
  echo "Ilova kalitsiz yig'ilgan — bunday APK'ni tarqatmang." >&2
  exit 1
fi

SIZE="$(du -m "$APK" | cut -f1)"
echo "Tayyor: $APK (${SIZE} MB) — kalitlar joyida."
