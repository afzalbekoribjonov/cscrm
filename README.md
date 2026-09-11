# CSCRM — Cleaning Service CRM

Xizmat biznesi (gilam yuvish, kimyoviy tozalash, kir yuvish) uchun buyurtma,
xodim va moliya boshqaruv tizimi. Obuna asosida ishlaydigan ko'p ijarachili
(multi-tenant) SaaS mahsulot.

## Tuzilishi

```
cscrm/
├── app/          Flutter ilova (Android + Web) — biznes egasi va xodimlar uchun
├── backend/      Node.js API (Render) — obuna, litsenziya, super-admin
├── admin/        React websayt (Render) — marketing + super-admin panel
├── firebase/     Realtime Database qoidalari
├── shared/       Ikkala tomon uchun umumiy ma'lumot (narx rejalari)
├── tools/        Yordamchi skriptlar (ikonka generatsiyasi)
└── render.yaml   Render joylash konfiguratsiyasi
```

## Texnologiyalar

| Qism | Texnologiya | Joylashuv |
|---|---|---|
| Mobil ilova | Flutter 3.27 / Dart 3.6 | Android APK / AAB |
| Ma'lumotlar bazasi | Firebase Realtime Database | Firebase |
| Autentifikatsiya | Firebase Auth (custom token) | Firebase |
| API | Node.js 20 + Express + TypeScript | Render |
| Websayt | React 18 + Vite + TypeScript | Render (static) |

**Nega Realtime Database (Firestore emas):** buyurtma holati sexda bir necha
qurilmada bir vaqtda ko'rinishi kerak. RTDB'ning `onValue` oqimlari kechikishi
pastroq, oflayn keshi soddaroq va bu hajmdagi ma'lumot uchun arzonroq.

## Ishga tushirish

### 1. Firebase loyihasini yarating

1. [Firebase Console](https://console.firebase.google.com) → yangi loyiha
2. **Realtime Database** yoqing (region: `europe-west1` tavsiya etiladi)
3. **Authentication** → Sign-in method → **Email/Password** ni yoqing
4. Android ilova qo'shing, paket nomi: `uz.cscrm.uzafo`
5. Web ilova qo'shing (websayt uchun)
6. Qoidalarni joylang:
   ```bash
   firebase deploy --only database --config firebase/firebase.json
   ```

### 2. Mobil ilova

```bash
cd app
flutter pub get
cp env/example.json env/dev.json     # Firebase qiymatlarini to'ldiring
flutter run --dart-define-from-file=env/dev.json
```

### 3. Backend

```bash
cd backend
npm install
cp .env.example .env                 # qiymatlarni to'ldiring
npm run dev                          # http://localhost:8080
```

### 4. Websayt

```bash
cd admin
npm install
cp .env.example .env.local           # qiymatlarni to'ldiring
npm run dev                          # http://localhost:5173
```

## Maxfiy ma'lumotlar

Repoda **hech qanday kalit saqlanmaydi**. Har bir qism o'z sozlamasini
tashqaridan oladi:

| Qism | Fayl | Git'da |
|---|---|---|
| Flutter | `app/env/dev.json`, `app/env/prod.json` | ❌ |
| Backend | `backend/.env` | ❌ |
| Websayt | `admin/.env.local` | ❌ |
| Android imzo | `app/android/key.properties` | ❌ |

Namunalar (`*.example`) repoda bor va soxta qiymatlar bilan to'ldirilgan.

## Obuna rejalari

Narxlar **yagona manbada**: [`shared/plans.json`](shared/plans.json).
Backend, websayt va ilova — uchalasi ham shu fayldan oladi, shuning uchun
narx ikki joyda boshqacha ko'rinishi mumkin emas.

| Reja | Muddat |
|---|---|
| Sinov | 1 kun, bepul (qo'shimcha kunsiz) |
| 1 oylik / 3 oylik / 5 oylik / 1 yillik | obuna |
| Bir umrlik | cheksiz + yiliga $50 (baza uchun) |

Obuna muddati tugagan zahoti ilova **bloklanadi** — qo'shimcha vaqt
berilmaydi. Muddat tugashidan 7, 3 va 1 kun oldin ogohlantiriladi.

Bir umrlik rejadagi yillik baza to'lovi bundan mustasno: unga
to'lov sanasidan keyin 3 kun beriladi (`grace.lifetimeAnnualFeeDays`).

## Joylash (Render)

`render.yaml` blueprint ikkala servisni ham yaratadi. Maxfiy qiymatlar
(`sync: false`) Render panelida qo'lda kiritiladi.

## Foydali buyruqlar

```bash
python tools/generate_icons.py          # brend ikonkalarini qayta yaratish
cd app && flutter analyze               # Dart tahlili
cd backend && npm run typecheck         # TS tahlili
cd admin && npm run build               # websayt yig'ish
```
