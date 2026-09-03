# `firebase/` — ma'lumotlar bazasi infratuzilmasi

## Fayllar

| Fayl | Vazifasi |
|---|---|
| `database.rules.json` | Realtime Database xavfsizlik qoidalari |
| `firebase.json` | Firebase CLI sozlamasi |

## Qoidalarni joylash

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only database --project <PROJECT_ID> --config firebase/firebase.json
```

## Ma'lumotlar tuzilishi

```
/super_admins/{uid}            → true            CSCRM egalari
/user_tenants/{uid}            → tenantId        teskari qidiruv
/admin_logins/{login}          → {uid, tenantId} login → hisob
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
