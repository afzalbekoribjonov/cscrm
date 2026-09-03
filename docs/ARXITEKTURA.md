# CSCRM arxitekturasi

## Ko'p ijarachilik (multi-tenancy)

Har bir biznes = bitta **tenant**. Ma'lumot to'liq ajratilgan:

```
/tenants/{tenantId}/
    profile/        biznes nomi, telefon, manzil
    license/        obuna holati   (FAQAT backend yozadi)
    members/{uid}   egalar
    employees/{id}  xodimlar       (pinHash mijozga ko'rinmaydi)
    products/{id}   xizmat turlari
    orders/{id}     buyurtmalar  (tarixsiz - pastga qarang)
    order_history/  o'zgarishlar jurnali (TEKIS, indeks: orderId + at)
    expenses/{id}   chiqimlar
    payments/{id}   to'lovlar tarixi  (FAQAT backend yozadi)
    payment_requests/{id}  "men to'ladim" so'rovlari (FAQAT backend yozadi)
    counters/       buyurtma raqami hisoblagichi

/admin_logins/{login}       → {uid, tenantId}   (mijozga berk)
/user_tenants/{uid}         → tenantId
/employee_phone_index/{tel} → {tenantId, employeeId, tenantName}  (berk)
/super_admins/{uid}         → true
/tenant_directory/{id}      → createdAt   (bizneslar ro'yxati, berk)
/pending_payments/{id}      → ko'rib chiqilmagan to'lov so'rovi (berk)
/payments_log/{id}          → tasdiqlangan to'lov, indeks: at (berk)
```

### Nega uchta ildiz tugun qo'shildi

RTDB'da tugunni o'qish uning **butun daraxtini** yuklab olish demak.
Super-admin paneli avval `ref('tenants').get()` qilardi — ya'ni har bir
biznesning har bir buyurtmasi va tarixini ham tortib olardi.

* `tenant_directory` — faqat ID'lar. Admin SDK'da "faqat kalitlarni ber"
  (shallow) so'rovi yo'q, shuning uchun ro'yxat alohida turishi kerak.
  Panel shu ID'lar bo'yicha har bir biznesdan faqat `profile` va
  `license` ni o'qiydi.
* `pending_payments` — ko'rib chiqilmagan so'rovlar. Hal bo'lishi bilan
  yozuv o'chiriladi, shuning uchun tugun hech qachon kattalashmaydi.
* `payments_log` — daromad statistikasi. `at` indeksi tufayli "oxirgi 30
  kun" so'rovi butun to'lovlar tarixini emas, faqat kerakli qismini
  o'qiydi.

Ajratish **token da'volari** (custom claims) orqali amalga oshadi:
qoidalar `auth.token.tenantId === $tenantId` shartini tekshiradi. Da'voni
faqat Admin SDK yoza oladi, shuning uchun ilova uni soxtalashtira olmaydi.

Ilova tomonida barcha yo'llar [`TenantScope`](../app/lib/services/tenant_scope.dart)
orqali o'tadi — servislar bazaga to'g'ridan-to'g'ri murojaat qilmaydi.

---

## Kirish oqimlari

### Biznes egasi — ro'yxatdan o'tish

```
Ilova ──POST /api/v1/auth/register──▶ Backend
                                       │ Auth foydalanuvchi yaratadi
                                       │ tenant + sinov litsenziyasi
                                       │ setCustomUserClaims{tenantId, role:owner}
                                       ▼
Ilova ◀────── customToken ─────────────┘
  │
  └─▶ signInWithCustomToken()
```

### Biznes egasi — kirish

```
Ilova ──signInWithEmailAndPassword──▶ Firebase Auth
  │                                     (parolni faqat Auth tekshira oladi)
  ├─ tokendagi da'volar bormi?
  │    yo'q ──▶ POST /api/v1/auth/claims/sync ──▶ tokenni majburiy yangilash
  ▼
TenantScope faollashadi
```

### Xodim — kirish

```
Ilova ──POST /api/v1/auth/employee/login {phone, pin}──▶ Backend
                                                          │ telefon indeksi
                                                          │ bcrypt.compare
                                                          │ urinishlar hisobi
                                                          │ createCustomToken
                                                          ▼
Ilova ◀──── customToken + vakolatlar ─────────────────────┘
```

**PIN hech qachon qurilmada tekshirilmaydi va hash qurilmaga
yuborilmaydi.** Eski versiyada aksincha edi — batafsil:
[KAMCHILIKLAR.md](KAMCHILIKLAR.md) X1 bandi.

Himoya qatlamlari:

| Qatlam | Nima beradi |
|---|---|
| bcrypt (cost 10) | Har bir tekshiruv ~100 ms, har hash o'z tuzi bilan |
| 5 xato → 15 daq blok | Hisob darajasida |
| 10 urinish / 10 daq | IP darajasida (`loginLimiter`) |
| `pinHash` `.read: false` | Hash umuman o'qilmaydi |

---

## Cheklangan so'rovlar

Ilgari `ref('orders')` butun tarixni o'qirdi va `keepSynced(true)` uni
qurilmada saqlardi. Endi har bir ekran o'ziga kerakli qismni so'raydi:

| So'rov | Indeks | Kim ishlatadi |
|---|---|---|
| `streamActiveOrders()` | `active` | Yangi / Yuvish / Qadoqlash / Yetgazma |
| `streamOrdersForPeriod(from, to)` | `createdAt` + `deliveredAt` + `active` | hisobotlar |
| `streamDebtors()` | `debtAmount` | Qarzdorlar |
| `streamRecentOrders(limit)` | `createdAt` | boshqaruv ro'yxati |

Natijada kundalik yuklama biznesning **umumiy tarixiga** emas, **joriy ish
hajmiga** bog'liq bo'ladi.

---

## API

Barcha yo'llar `/api/v1` ostida. Avtorizatsiya: `Authorization: Bearer <ID token>`.

| Metod | Yo'l | Kim | Vazifasi |
|---|---|---|---|
| GET | `/health` | ochiq | Render sog'liq tekshiruvi |
| POST | `/auth/register` | ochiq | biznes + ega yaratish |
| POST | `/auth/employee/login` | ochiq | telefon + PIN → token |
| POST | `/auth/claims/sync` | kirgan | da'volarni tiklash |
| POST | `/auth/credentials/login` | ega | loginni almashtirish |
| GET | `/license/plans` | ochiq | rejalar ro'yxati |
| GET | `/license/status` | kirgan | obuna holati (imzolangan) |
| POST | `/license/payment-request` | ega | "men to'ladim" xabari |
| GET | `/license/payment-request` | kirgan | so'rov holati (xodimga ham) |
| POST | `/employees` | ega | xodim qo'shish |
| POST | `/employees/:id/pin` | ega | PIN almashtirish |
| DELETE | `/employees/:id` | ega | xodimni o'chirish |
| GET | `/admin/me` | super-admin | ruxsatni tasdiqlash |
| GET | `/admin/stats` | super-admin | umumiy ko'rsatkichlar |
| GET | `/admin/tenants` | super-admin | bizneslar ro'yxati |
| GET | `/admin/tenants/:id` | super-admin | biznes kartasi |
| POST | `/admin/tenants/:id/confirm-payment` | super-admin | to'lovni tasdiqlash |
| POST | `/admin/tenants/:id/suspend` | super-admin | to'xtatish / yoqish |
| GET | `/admin/payment-requests` | super-admin | to'lov so'rovlari navbati |
| POST | `/admin/tenants/:id/payment-requests/:reqId/reject` | super-admin | so'rovni rad etish |

`/license/status` **tenantId'ni so'rovdan olmaydi** — faqat tokendagi
da'vodan. Aks holda istalgan foydalanuvchi boshqa biznesning obuna
holatini ko'ra olardi.

---

## Litsenziya imzosi

Server javobi HMAC-SHA256 bilan imzolanadi:

```
tenantId|state|planId|kind|expiresAt|daysLeft|checkedAt|ttlSeconds|blocked
```

Maydonlar aniq tartibda birlashtiriladi (`JSON.stringify` emas) — kalitlar
tartibi o'zgarib, ilova va server turli natija olmasligi uchun.

Muddat **doim serverda** hisoblanadi: ilova hech qachon o'z
`DateTime.now()` iga tayanib qaror qabul qilmaydi, shuning uchun qurilma
soatini orqaga surib bloklashni chetlab o'tib bo'lmaydi.

---

## Obuna va bloklash

### Oqim

```
Ilova ochiladi
   │
   ├─ LicenseGate ──▶ GET /api/v1/license/status
   │                    (tenantId TOKENDAN, so'rovdan emas)
   │                          │
   │                    imzo tekshiriladi (HMAC-SHA256)
   │                          │
   │                    keshga yoziladi (6 soat)
   ▼
 blocked?
   ├─ ha  ──▶ SubscriptionBlockedScreen  (ega ham, xodim ham ko'radi)
   └─ yo'q ─▶ HomeShell
                 └─ SubscriptionBanner (muddat yaqin bo'lsa)
```

Holat yangilanadi: ilova ochilganda · old planga qaytganda · har 15
daqiqada · "Tekshirish" tugmasi bosilganda.

### Nega xodim ham to'lov ekranini ko'radi

Xodim to'lovni o'zi qilmaydi, lekin nima bo'layotganini bilishi kerak —
aks holda u "ilova buzildi" deb o'ylaydi va rahbarga aytmaydi. Shu sabab
unga ham ekran ko'rsatiladi, lekin rekvizitlar o'rniga "boshqaruvchiga
xabar bering" deb yoziladi. **"Tekshirish" tugmasi ikkalasiga ham ochiq** —
to'lov o'tganini xodim ham tekshira olsin.

### Oflayn ishlash

Javob 6 soat yaroqli. Bu vaqt ichida internet bo'lmasa ham ilova
ishlayveradi — sexda aloqa uzilib turishi odatiy hol.

Qurilma soatini **orqaga surib** bu oynani cho'zib bo'lmaydi: oxirgi
ko'rilgan server vaqti saqlanadi va undan orqaga qaytilmaydi
(`utils/license_clock.dart`). Oldinga surish esa foyda bermaydi — u keshni
tezroq eskirtiradi.

### Xavfsiz sukut: shubhada BLOKLAMAYMIZ

Holat umuman aniqlanmasa (birinchi ishga tushirish, tarmoq muammosi,
kesh muddati tugagan) ilova **ochiq qoladi**.

Bu ataylab shunday: tarmoq nosozligi tufayli ishlab turgan biznesni
to'xtatib qo'yish — xatolikdan ko'ra qimmatroq. Chetlab o'tish xavfi past,
chunki holatni faqat server hisoblaydi va `license` tuguniga mijoz yoza
olmaydi (Database qoidalari). Server javob berishi bilan haqiqiy holat
qo'llanadi.

Aksincha, serverdan TUSHUNARSIZ javob kelsa (`blocked` maydoni yo'q)
xavfsiz tomonga og'amiz va bloklaymiz.

### To'lov rekvizitlari

Kodda emas, server sozlamasida (`PAYMENT_*`). Karta almashsa ilovani
qayta yig'ish shart emas — Render'da qiymatni o'zgartirish kifoya.
Sozlanmagan bo'lsa ilova soxta karta ko'rsatmaydi, aloqaga yo'naltiradi.

---

## Bildirishnomalar

Qo'ng'iroq app bar'ning o'ng yuqori burchagida, o'qilmaganlar soni bilan.

### Nega bazaga yozilmaydi

Kerakli ma'lumot allaqachon buyurtmada bor. Alohida `notifications`
tuguni yaratilsa:

* har bir amalda qo'shimcha yozuv ketardi
* tugun yillar davomida cheksiz o'sardi (aynan T1 dagi muammo)
* amal yozilib, bildirishnomasi yozilmay qolishi mumkin edi

Tarixdan hisoblash bularning hammasidan xoli va **oflayn ham ishlaydi** —
ma'lumot allaqachon qurilmada.

`buildNotifications()` buyurtmaning O'ZIDAGI hodisa belgilaridan
(`pickedUp`, `ready`, `delivered`, `lastRewash`, `lastDebtPayment`)
quriladi — tarix endi alohida tugunda va ro'yxat so'roviga tushmaydi.
"O'qilgan" holati qurilmada saqlanadi (oxirgi ko'rilgan vaqt) — bu
"menga ko'rsatildimi" degan savol, u qurilmaga tegishli.

### Nima ro'yxatga tushadi

| Tushadi | Tushmaydi |
|---|---|
| Yangi buyurtma | O'lchash va narx tuzatish |
| Qabul qilindi (sexga kirdi) | Xizmatni qadoqlashga o'tkazish |
| Yetgazishga tayyor | Xizmatni o'chirish |
| Yetgazildi | Mijoz ma'lumotini tahrirlash |
| Qayta yuvishga qaytarildi | |
| Qarz to'landi | |

O'z harakati hech qachon qaytmaydi — tarixdagi `byEmployeeId` tekshiriladi.

---

## Super-admin paneli

Websaytda `/admin`. Ikki qatlamli himoya:

1. **Ko'rinish** — `RequireSuperAdmin` marshrutni yopadi
2. **Haqiqiy** — har bir `/api/v1/admin/*` so'rovi `requireSuperAdmin`
   dan o'tadi

Firebase'ga kirish o'zi yetarli emas: har qanday hisob kira oladi, lekin
panelga faqat `SUPER_ADMIN_UIDS` sozlamasidagi UID'lar. Ro'yxat bazada
emas, **serverda** — uni hech kim ilova orqali o'zgartira olmaydi.

Ruxsati yo'q hisob bilan kirilsa, panel o'sha hisobning UID'ini
ko'rsatadi — sozlamaga qo'shish oson bo'lsin.

### To'lov oqimi (qo'lda karta o'tkazma)

```
Mijoz kartaga o'tkazadi
   │
   └─▶ chekni Telegram orqali yuboradi
          │
          ▼
    Super-admin panelda biznesni ochadi
          │
          ├─ rejani tanlaydi
          ├─ olingan summani kiritadi
          └─ "To'lovni tasdiqlash"
                │
                ├─▶ litsenziya uzayadi (to'xtatilgan bo'lsa ochiladi)
                └─▶ to'lov tarixga yoziladi
                       │
                       ▼
             Ilova 15 daqiqada o'zi ochiladi
             (yoki mijoz "Tekshirish" ni bosadi)
```

### Muddat uzaytirish qoidasi

Muddat **hali tugamagan** bo'lsa yangisi mavjudining ustiga qo'shiladi —
oldindan to'lagan mijoz qolgan kunlarini yo'qotmaydi. Tugagan bo'lsa
bugundan boshlanadi. Bir umrlikka o'tganda muddat bekor bo'ladi va
yillik baza to'lovi sanasi qo'yiladi.
