# CSCRM arxitekturasi

## Ko'p ijarachilik (multi-tenancy)

Har bir biznes = bitta **tenant**. Ma'lumot to'liq ajratilgan:

```
/tenants/{tenantId}/
    profile/        biznes nomi, telefon, manzil
    license/        obuna holati   (FAQAT backend yozadi)
    members/{uid}   egalar
    employees/{id}  xodimlar       (PIN hashi bu yerda EMAS — pastga qarang)
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
/employee_secrets/{t}/{e}   → {pinHash}   (berk — faqat backend)
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
| 10 XATO urinish / 10 daq | IP darajasida (`loginLimiter`); muvaffaqiyatli kirish sanalmaydi |
| `employee_secrets` (berk tugun) | Hash mijozga umuman yuborilmaydi |

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
| GET | `/admin/overview?range=7d\|30d\|90d\|12m` | super-admin | "Umumiy" sahifasi bitta so'rovda: ko'rsatkichlar, chartlar, e'tibor ro'yxati (Toshkent vaqti bo'yicha) |
| GET | `/admin/badges` | super-admin | menyu hisoblagichlari (kutilayotgan to'lovlar) |
| GET | `/admin/tenants` | `tenants.read` | bizneslar ro'yxati (arxiv holati va oxirgi faollik bilan) |
| GET | `/admin/tenants/:id` | `tenants.read` | biznes kartasi |
| PATCH | `/admin/tenants/:id/profile` | `tenants.edit` | nom, telefon, manzilni tahrirlash |
| PUT | `/admin/tenants/:id/license` | `subscriptions.manage` | reja / muddatni TO'LOVSIZ o'zgartirish (sabab majburiy, tushumga yozilmaydi) |
| POST | `/admin/tenants/:id/confirm-payment` | `payments.manage` | to'lovni tasdiqlash (`idempotencyKey` — takroriy bosishdan himoya) |
| POST | `/admin/tenants/:id/suspend` | `tenants.suspend` | to'xtatish (sabab majburiy) / qayta ochish |
| POST | `/admin/tenants/:id/archive` | `tenants.archive` | arxivlash (sabab majburiy) |
| POST | `/admin/tenants/:id/restore` | `tenants.archive` | arxivdan qaytarish |
| DELETE | `/admin/tenants/:id` | `tenants.delete` | butunlay o'chirish — faqat arxivdagi, tanada `confirmName` |
| GET/POST | `/admin/tenants/:id/credentials` | `credentials.manage` | egasining logini / yangi parol |
| GET | `/admin/tenants/:id/audit` | `audit.read` | shu biznes bo'yicha amallar jurnali |
| GET | `/admin/audit` | `audit.read` | umumiy amallar jurnali |
| GET | `/admin/payment-requests` | `payments.manage` | to'lov so'rovlari navbati |
| POST | `/admin/tenants/:id/payment-requests/:reqId/reject` | `payments.manage` | so'rovni rad etish |
| GET | `/cabinet/me` | ega | kabinet: biznes, login, obuna holati |
| GET | `/cabinet/summary?range=today\|7d\|30d\|month` | ega | hisobot (ilova qoidasi bilan, Toshkent kuni) |
| GET | `/cabinet/employees` | ega | xodimlar (PINsiz) va oxirgi faollik |
| GET | `/cabinet/payments` | ega | tasdiqlangan to'lovlar (admin UID'isiz) |
| GET | `/admin/users` | `users.read` | egalar va xodimlar (hali kirmaganlari ham) |
| POST | `/admin/users/:uid/signout` | `users.manage` | barcha qurilmalardan chiqarish |
| GET | `/admin/access` | `admins.manage` | rollar, panel xodimlari, bosh administratorlar |
| POST/PATCH/DELETE | `/admin/access/roles[/:id]` | `admins.manage` | rol yaratish / tahrirlash / o'chirish |
| POST/PATCH/DELETE | `/admin/access/members[/:uid]` | `admins.manage` | xodim qo'shish / rolini almashtirish / chiqarish |

Panel yo'llarida "Kim" ustunidagi nom — vakolat (`backend/src/lib/permissions.ts`).
`/admin/me` hamma panel xodimiga ochiq — u kimligini va vakolatlarini
qaytaradi, panel menyu va tugmalarni shunga qarab ko'rsatadi.

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

Websaytda `/admin`. Uch qatlamli himoya:

1. **Ko'rinish** — `RequireAdmin` marshrutni yopadi, menyu va tugmalar
   vakolatga qarab ko'rsatiladi
2. **Kirish** — har bir `/api/v1/admin/*` so'rovi `requireAdmin` dan
   o'tadi: bosh administrator yoki rolga ega panel xodimi
3. **Vakolat** — har yo'l o'z `requirePermission` ini tekshiradi

Firebase'ga kirish o'zi yetarli emas: har qanday hisob kira oladi, lekin
panelga faqat bosh administrator (`SUPER_ADMIN_UIDS` — bazada emas,
**serverda**) va `admin_members` dagi xodimlar.

### Rollar

| | Bosh administrator | Panel xodimi |
|---|---|---|
| Qayerda | server sozlamasi `SUPER_ADMIN_UIDS` | `admin_members/{uid}` → `admin_roles/{roleId}` |
| Vakolat | hammasi | roli bergan vakolatlar |
| Panel xodimlari va rollar (`admins.manage`) | bor | **hech qachon** — rolga berib bo'lmaydi |
| Panel orqali olib tashlash | mumkin emas | mumkin (seanslari yopiladi) |

* Vakolatlar bazada **ro'yxat** sifatida saqlanadi — nuqtali nom
  (`tenants.read`) bazada kalit bo'la olmaydi.
* Huquq 30 soniya keshlanadi; shu server jarayonidagi o'zgarish darhol
  kuchga kiradi.
* Biznesga bog'langan hisob (ilova egasi/xodimi) panelga qo'shilmaydi,
  panel xodimining hisobi esa biznes egasi sifatida tiklanmaydi — bir
  admin boshqasining hisobini egallab olmasligi uchun.
* Yangi xodimga hisob yaratilsa, vaqtinchalik parol faqat javobda bir
  marta qaytadi (jurnalga ham, logga ham tushmaydi); xodim uni panelda
  o'zi almashtiradi.

### Qoidalar joylanmagan paytda

Ba'zi so'rovlar `.indexOn` ga tayanadi (`admin_audit.tenantId`,
`admin_logins.tenantId`, `push_tokens.tenantId`). Indeks jonli bazada
hali yo'q bo'lsa, `whereEquals` tugunni to'liq o'qib saralaydi (logda
ogohlantirish). Umumiy jurnal push-kalit tartibida o'qiladi — indeks
kerak emas. Emulatorda jonli qoidalar nusxasi va yangi qoidalar bilan
ikkala holat ham sinalgan.

Ruxsati yo'q hisob bilan kirilsa, panel oddiy "ruxsat yo'q" deydi — UID
va sozlama nomi ko'rsatilmaydi (ular hujumchiga ma'lumot beradi).

### To'lov oqimi (qo'lda karta o'tkazma)

```
Mijoz kartaga o'tkazadi
   │
   └─▶ ilovada "To'lov qildim" (so'rov → pending_payments)
          │
          ▼
    Panel: "To'lov so'rovlari" (menyuda hisoblagich)
          │
          ├─ "Tasdiqlash" — reja va summa so'rovdan olinadi
          │     ├─▶ litsenziya uzayadi
          │     ├─▶ payments_log ga yoziladi (tushum)
          │     └─▶ so'rov yopiladi, jurnalga yoziladi
          │
          └─ "Rad etish" — sabab majburiy, mijoz ilovada ko'radi
                       │
                       ▼
             Ilova 15 daqiqada o'zi ochiladi
             (yoki mijoz "Tekshirish" ni bosadi)
```

So'rovsiz kelgan to'lov (masalan, naqd) — biznes kartasidagi "To'lov
qabul qilish" bilan. Bir xil kalit (`idempotencyKey`) bilan qayta kelgan
so'rov ikkinchi to'lov yozmaydi.

### To'lov va "obunani o'zgartirish" — ikki xil amal

| | To'lov qabul qilish | Obunani o'zgartirish |
|---|---|---|
| Qachon | Mijoz pul to'ladi | Xato tuzatish, sovg'a kunlar, kompensatsiya |
| Tushumga | yoziladi (`payments_log`) | **yozilmaydi** |
| Muddat | reja bo'yicha avtomatik | sana qo'lda tanlanadi |
| Sabab | ixtiyoriy izoh | **majburiy** |
| Jurnal | `payment.confirm` | `license.update` (oldingi → yangi qiymat) |

Aralashtirilsa "Umumiy" sahifasidagi tushum yolg'on bo'lib qoladi.

### Biznesning hayot yo'li: arxiv va o'chirish

```
Faol / Sinovda / Bloklangan
   │  "Arxivlash" (sabab + nomni qo'lda yozish)
   ▼
Arxivda — ilova yopiq, ma'lumot 30 kun saqlanadi
   │                              │
   │ "Arxivdan qaytarish"         │ 30 kun o'tdi (avtomatik)
   ▼                              │ yoki "Hozir o'chirish" (nomni yozish)
oldingi holatiga qaytadi          ▼
                          Butunlay o'chiriladi
```

* Butunlay o'chirishda biznes tuguni, xodimlarning PIN yozuvlari,
  login, telefon indekslari, push tokenlar va egasi + xodimlarning
  kirish hisoblari o'chadi. **`payments_log` saqlanadi** — o'tgan
  davrlar tushumi o'zgarmasligi kerak.
* Faqat arxivdagi biznes o'chiriladi (server tekshiradi) — faol biznes
  bitta bosishda yo'qolmaydi.
* Arxivdagi biznesga to'lov, obuna o'zgarishi va to'xtatish qo'llanmaydi
  (409): aks holda to'lagan mijoz 30 kundan keyin o'chib ketardi.
* Avtomatik tozalash faqat prod serverda ishlaydi (ishga tushgach 1
  daqiqa, keyin har 6 soatda); mahalliy ishga tushirish hech narsani
  o'chirmaydi.

### Amallar jurnali (`admin_audit`)

Panel orqali qilingan har bir o'zgarish (to'lov, rad etish, tahrirlash,
obuna, to'xtatish, arxiv, o'chirish, login/parol, tarif narxi, xabar,
sayt sozlamalari) kim, qachon va nima o'zgargani bilan yoziladi.
Asosiy o'zgarish bilan BITTA atomar yozuvda — jurnalsiz o'zgarish
bo'lmaydi. Parol, PIN, kalit kabi qiymatlar jurnalga tushmaydi
(`[yashirilgan]`). Tugun faqat serverga ochiq.

### Muddat uzaytirish qoidasi

Muddat **hali tugamagan** bo'lsa yangisi mavjudining ustiga qo'shiladi —
oldindan to'lagan mijoz qolgan kunlarini yo'qotmaydi. Tugagan bo'lsa
bugundan boshlanadi. Bir umrlikka o'tganda muddat bekor bo'ladi va
yillik baza to'lovi sanasi qo'yiladi.

### "Umumiy" sahifasi qayerdan oladi

| Ko'rsatkich | Manba | Izoh |
|---|---|---|
| Tushum, chart | `payments_log` (`at` indeksi) | faqat davr + oldingi davr o'qiladi |
| Yangi bizneslar | `tenant_directory` + `profile.createdAt` | |
| Obuna holatlari, e'tibor ro'yxati | har biznesning `license` i → `evaluate()` | ilova ko'radigan holat bilan aynan bir xil |
| To'lov so'rovlari | `pending_payments` | faqat hal qilinmaganlar |
| Ilovadan foydalanish | Firebase **Auth** `lastRefreshTime` | bazaga yozilmaydi; olinmasa sahifa "aniqlab bo'lmadi" deydi |

Vaqt Toshkent bo'yicha (UTC+5): server Singapurda, lekin "bugun" va
"bu oy" mijozlar uchun hisoblanadi.

## Websayt: yuklash hajmi

Sayt va panel bitta React ilovasi, lekin **alohida bo'laklarda**:

| Bo'lak | Qachon yuklanadi | Tarkibi |
|---|---|---|
| asosiy (~234 KB, gzip ~76 KB) | har qanday sahifa | React, marshrutlar, bosh sahifa, soha sahifalari, sayt uslublari |
| sahifa bo'laklari (1–10 KB) | shu sahifaga o'tganda | Narxlar, Imkoniyatlar, Yordam va h.k. |
| `AdminArea` + `auth` + `AdminRoutes` | faqat `/kirish` va `/admin` | Firebase Auth SDK, panel komponentlari va uslublari (`ui.css`) |

Ya'ni saytga reklamadan kelgan mijoz Firebase SDK'ni ham, panel kodini ham
umuman yuklamaydi (ilgari hammasi bitta 558 KB faylda edi).

## Biznes egasining kabineti

`/kabinet/*` — alohida bo'lak, o'z `OwnerAuthProvider` i bilan. Kirish
ilovadagi login (`login@cscrm.local`) va parol bilan; server tokendagi
`role: owner` da'vosini tekshiradi (`GET /cabinet/me`), biznes ID esa
so'rovdan emas, tokendan olinadi.

* Hamma raqam serverda hisoblanadi (`services/cabinet.ts`) — ilovadagi
  `income_stats.dart` ning aynan nusxasi: pul qaysi kuni olingan bo'lsa,
  o'sha kunga. Buyurtmadan faqat hisob maydonlari o'qiladi — mijoz ismi
  va telefoni javobga tushmaydi.
* Kerakli indekslar (`orders.createdAt/deliveredAt/active/debtAmount`,
  `order_history.at`, `expenses.spentAt`) jonli qoidalarda allaqachon
  bor — emulatorda jonli qoidalar nusxasi bilan tekshirilgan.
* Kabinet faqat O'QIYDI; yagona yozuv — mavjud "Men to'ladim" so'rovi.
* Egaga qaytariladigan to'lov so'rovi va to'lovlarda admin UID yo'q
  (`toOwnerPaymentRequest`).
