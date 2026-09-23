# `firebase/` — ma'lumotlar bazasi infratuzilmasi

## Fayllar

| Fayl | Vazifasi |
|---|---|
| `rules.mjs` | Qoidalar **MANBASI** — o'zgarish faqat shu yerda |
| `database.rules.json` | Izohli nusxa — o'qish va ko'rib chiqish uchun (yig'iladi) |
| `database.rules.deploy.json` | Izohsiz nusxa — Firebase aynan shuni qabul qiladi (yig'iladi) |
| `test/rules.test.mjs` | Qoidalarning emulatordagi sinovi |
| `firebase.json` | Firebase CLI va emulator sozlamasi |

Ikkala JSON ham `rules.mjs` dan yig'iladi — ularni qo'lda tahrirlamang.
Firebase qoidalar faylidagi `"//"` izoh kalitini qabul qilmaydi, shuning
uchun joylanadigan nusxa alohida.

## Qoidani o'zgartirish tartibi

```bash
cd firebase
npm install                  # bir marta
node rules.mjs               # JSON'larni qayta yig'ish
npm test                     # emulatorda sinov — JONLI BAZAGA TEGMAYDI
```

Sinov uchun Java 11+ kerak (emulator Java'da ishlaydi). Sinovdagi
"ilova:" holatlari ilovaning haqiqiy yozuv yo'llari: ular o'tmasa, yangi
qoida mijozlar qo'lidagi ilovani buzadi — joylamang.

## Qoidalarni joylash

Faqat sinovlar o'tgandan keyin. Yo'llardan biri:

```bash
# 1) Firebase CLI (Google hisobi bilan)
firebase deploy --only database --project <PROJECT_ID> --config firebase/firebase.json

# 2) Servis kaliti bilan (backend/.env dagi FIREBASE_SERVICE_ACCOUNT)
node tools/deploy_rules.mjs
```

Yoki qo'lda: Firebase Console → Realtime Database → Rules — va
`database.rules.deploy.json` mazmunini qo'yish.

## Ma'lumotlar tuzilishi

```
/super_admins/{uid}            → true            CSCRM egalari
/user_tenants/{uid}            → tenantId        teskari qidiruv
/admin_logins/{login}          → {uid, tenantId} login → hisob
/employee_secrets/{t}/{e}      → {pinHash}       PIN hashlari (mijozga berk)
/tenants/{tenantId}/
    profile/                   biznes ma'lumoti
    license/                   obuna holati  (FAQAT backend yozadi)
    members/{uid}              → true
    employees/{id}/
    products/{id}/
    orders/{id}/
    expenses/{id}/
    counters/
    notifications/{id}/
```

## Xavfsizlik: nega custom token kerak

Eski loyihada xodimlar `signInAnonymously()` bilan kirardi va qoidalar
`auth != null` deb tekshirardi. Bu degani: o'sha Firebase loyihasiga anonim
kira olgan **har qanday** odam butun bazani o'qiy olardi.

Ko'p ijarachili tizimda bu qabul qilib bo'lmaydi — bir biznes boshqasining
buyurtmalarini ko'rib qolishi mumkin edi. Shuning uchun:

1. Ilova telefon + PIN ni **backend**ga yuboradi
2. Backend PIN'ni tekshiradi va Firebase **custom token** yaratadi:
   `{ tenantId, role: 'owner' | 'staff', employeeId }`
3. Ilova shu token bilan kiradi
4. Qoidalar `auth.token.tenantId` ni tekshiradi — uni ilova tomondan
   o'zgartirib bo'lmaydi

`license` tuguni mijoz uchun **faqat o'qish** — obunani foydalanuvchi o'zi
uzaytira olmaydi. Uni faqat Admin SDK (backend) yozadi.
