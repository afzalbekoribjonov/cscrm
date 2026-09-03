# `env/` — build konfiguratsiyasi

Bu papkada CSCRM'ning build vaqtidagi sozlamalari turadi. **Hech qanday
kalit dastur kodiga yozilmaydi** — hammasi shu yerdan `--dart-define-from-file`
orqali uzatiladi.

## Fayllar

| Fayl | Git'da | Vazifasi |
|---|---|---|
| `example.json` | ✅ ha | Namuna/shablon. Kalitlar soxta. |
| `dev.json` | ❌ yo'q | Ishlab chiqish (test Firebase loyihasi). |
| `prod.json` | ❌ yo'q | Ishlab chiqarish (haqiqiy Firebase loyihasi). |

## Boshlash

```bash
cp env/example.json env/dev.json
# dev.json ichidagi qiymatlarni Firebase Console'dan olib to'ldiring
```

## Ishga tushirish

```bash
flutter run --dart-define-from-file=env/dev.json
flutter build apk --release --dart-define-from-file=env/prod.json
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

## Qiymatlarni qayerdan olish

Firebase Console → Project settings (⚙️):

- `FIREBASE_PROJECT_ID` — General → Project ID
- `FIREBASE_MESSAGING_SENDER_ID` — Cloud Messaging → Sender ID
- `FIREBASE_ANDROID_API_KEY` / `_APP_ID` — General → Your apps → Android
- `FIREBASE_WEB_API_KEY` / `_APP_ID` — General → Your apps → Web
- `FIREBASE_DATABASE_URL` — Realtime Database → Data (yuqoridagi URL)

## `API_BASE_URL`

CSCRM API manzili. Xodim kirishi (PIN tekshiruvi) va obuna holati shu
server orqali o'tadi.

| Muhit | Qiymat |
|---|---|
| Android emulyator | `http://10.0.2.2:8080` (sukut bo'yicha) |
| Haqiqiy qurilma, mahalliy server | `http://<kompyuter-IP>:8080` |
| Ishlab chiqarish | `https://cscrm-api.onrender.com` |

## `LICENSE_SIGNING_SECRET`

Backend'dagi bir xil nomli qiymat bilan **aynan mos** bo'lishi shart —
ilova litsenziya javobining imzosini shu kalit bilan tekshiradi.

Bu kalit APK ichida bo'ladi, ya'ni uni ajratib olish mumkin. Shuning uchun
u faqat "javob yo'lda o'zgartirilmadimi" degan savolga javob beradi.
Haqiqiy himoya serverda: litsenziya holatini faqat server hisoblaydi va
`license` tuguniga mijoz yoza olmaydi.
