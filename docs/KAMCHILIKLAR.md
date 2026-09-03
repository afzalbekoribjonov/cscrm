# Mavjud ilovadagi kamchiliklar

Manba: `gilam_yuvish_furqat` (nusxa olingan kod). Har bir band tekshirilgan —
taxmin emas, kodda aniq joyi ko'rsatilgan.

Tartib: **xavfsizlik → pul → ishonchlilik → tezlik → kod sifati**.

---

## ✅ X1. PIN-kodlarni har qanday odam ochib olishi mumkin — TUZATILDI

**Qayerda:** `app/lib/services/auth_service.dart:159` (`employeeSignIn`)

```dart
await _auth.signInAnonymously();          // har kim kira oladi
final snapshot = await _db.ref('employees').get();   // BARCHA xodimlar
...
if (employee.pinHash == pinHash) return employee;    // solishtiruv QURILMADA
```

Uchta muammo bir joyda:

1. **PIN hash qurilmaga yuklanadi.** Ilova barcha xodimlarning `pinHash` ini
   o'qiydi. Qoidada `employees: {".read": "auth != null"}` — ya'ni loyihaga
   anonim kira olgan **har qanday** odam buni o'qiydi.
2. **Hash tuzsiz (salt yo'q) va PIN 4 xonali.** `hashPin` = oddiy SHA-256
   (`auth_service.dart:20`), PIN uzunligi 4 (`pin_pad.dart:9`). Bu 10 000 ta
   variant — oddiy noutbukda bir soniyada hammasini hisoblab, jadval bilan
   solishtirib bo'ladi. Ya'ni **har bir xodimning PIN kodi ochiladi**.
3. **Urinishlar cheklanmagan.** Noto'g'ri PIN necha marta kiritilsa ham
   bloklanmaydi.

**Oqibati:** begona odam istalgan xodim nomidan kirib, buyurtma yarata,
o'chira, to'lov belgilay oladi.

**Bajarildi:**

* PIN tekshiruvi backendga ko'chirildi (`POST /api/v1/auth/employee/login`)
* `bcrypt` (cost 10), har hash o'z tuzi bilan — `backend/src/services/pin.ts`
* Hisob darajasida blok: 5 xatodan keyin 15 daqiqa
* IP darajasida cheklov: 10 daqiqada 10 urinish
* `pinHash` qoidada `".read": false` — hash umuman o'qilmaydi
* PIN uzunligi 4-8 xonaga kengaytirildi (avval qat'iy 4 edi)
* `Employee` modelidan `pinHash` maydoni butunlay olib tashlandi
* Vaqt hujumiga qarshi: xodim topilmaganda ham bcrypt chaqiriladi

---

## ✅ X2. Bir mijoz boshqasining ma'lumotini ko'radi — TUZATILDI

**Qayerda:** eski `database.rules.json` — barcha tugunlarda `".read": "auth != null"`

Bitta biznes uchun bu yetarli edi. SaaS'da esa — bir mijoz ikkinchisining
buyurtmalari, mijoz raqamlari va daromadini ko'radi.

**Bajarildi:**

* Ma'lumot `/tenants/{tenantId}/...` ga ko'chirildi
* Qoidalar `auth.token.tenantId` ni tekshiradi
* `signInAnonymously()` **butunlay olib tashlandi**
* Ilovada barcha yo'llar `TenantScope` orqali o'tadi
* `employee_phone_index` mijozga butunlay berk

---

## ✅ P1. Bir vaqtda ikki xodim ishlaganda pul yo'qoladi — TUZATILDI

**Qayerda:** `order_service.dart` — `updateItemMeasurement:352`,
`deleteItem:385`, `settleDebt:508`, `markDelivered:471`

Bu metodlar umumiy summani **eski nusxadan** hisoblab, natijani to'liq
yozadi:

```dart
'totalPrice': order.totalPrice - item.price + price,   // order — eski nusxa
```

Ikki xodim bir buyurtmaning ikki xil xizmatini bir vaqtda o'lchasa, keyingi
yozuv birinchisini bekor qiladi — **narx noto'g'ri qoladi**.

`settleDebt` da xuddi shunday: `paymentAmount: (order.paymentAmount ?? 0) + amount`.
Ikki joydan bir vaqtda qarz yopilsa, bittasi yo'qoladi.

`deleteItem` da `itemCount: order.items.length - 1` ham shunday.

**Diqqat:** `addItemsToOrder` da bu **to'g'ri qilingan** — tranzaksiya
ishlatilgan. Ya'ni muammo bilingan, lekin hamma joyga qo'llanmagan.

**Bajarildi:**

* `updateItemMeasurement`, `deleteItem`, `updateItemStatus` — umumiy
  `_mutateOrder` tranzaksiyasiga o'tdi
* Umumiy narx va xizmatlar soni endi SAQLANMAYDI, balki har safar
  xizmatlardan **qayta hisoblanadi** (`sumItemPrices`) — shu sabab avval
  buzilgan qiymat ham keyingi o'zgarishda o'zi tuzalib ketadi
* `settleDebt` alohida tranzaksiyada; qancha olinishi serverdagi joriy
  qarzdan kelib chiqadi (`applyDebtPayment`) — qarz manfiy bo'lmaydi va
  to'lov ikkilanmaydi
* "Hammasi tayyor" tekshiruvi ham serverdagi holatdan bajariladi
* Sof mantiq `lib/utils/order_totals.dart` ga ajratildi va **test bilan
  qoplandi** (13 ta test)

**Qo'shimcha tuzatish:** xizmat qayta yuvishga qaytarilganda buyurtma ham
"Yetgazishga tayyor" holatidan "Yuvishda" ga qaytadi. Ilgari qaytmasdi —
to'liq bo'lmagan buyurtmani yetkazib yuborish mumkin edi.

---

## ✅ P2. Ruxsat rad etilsa, foydalanuvchi "saqlandi" deb o'ylaydi — TUZATILDI

**Qayerda:** `app/lib/utils/offline_write.dart:28`

```dart
final guarded = write.catchError((Object e, StackTrace s) {
  debugPrint('Firebase yozuvi xato berdi: $e');   // xatolik YUTILADI
});
```

`awaitOrQueue` **hamma** xatolikni yutadi. Internet yo'qligi uchun bu to'g'ri
(yozuv navbatga tushadi). Lekin `permission-denied` yoki noto'g'ri ma'lumot
xatosi ham shu yerda yo'qoladi: ekran "bajarildi" deb yopiladi, o'zgarish
esa keshdan qaytib, biroz o'tib yo'qoladi.

**Bajarildi:**

* Vaqtinchalik (tarmoq) xatoliklar va haqiqiy rad etishlar ajratildi
* Rad etish `WriteFailures` oqimiga tushadi, `HomeShell` uni qizil
  SnackBar bilan ko'rsatadi — ekran yopilgandan keyin kelgan javob ham
* `permission-denied` va `expired-token` uchun tushunarli o'zbekcha xabar
* **Test bilan qoplangan** (8 ta test), shu jumladan "kech kelgan rad
  etish" holati

Bu funksiya ataylab istisno TASHLAMAYDI: chaqiruvchi ekranlarning aksari
`try { } finally { }` ishlatadi (`catch` siz), tashlangan istisno esa
ushlanmay qolardi.

---

## ✅ P3. Buyurtma raqamlarida bo'shliq qoladi — TUZATILDI

**Qayerda:** `order_service.dart:120-126` (`createOrder`)

Raqam hisoblagichdan olinadi, keyin buyurtma yoziladi. Yozuv
`awaitOrQueue` bilan — ya'ni **muvaffaqiyatsiz bo'lsa ham xatolik
chiqmaydi**. Natijada hisoblagich oshgan, buyurtma esa yo'q: #57 dan keyin
#59 keladi.

Yana: `(current as int? ?? 0)` — agar hisoblagichga biror sababdan matn
yozilib qolsa, bu **xatolik tashlaydi** va yangi buyurtma umuman
yaratilmaydi.

**Bajarildi:**

* Hisoblagich endi kutilmagan qiymatga (matn, kasr son) chidaydi —
  butun "yangi buyurtma" oqimi bitta buzuq qiymatdan to'xtab qolmaydi
* `result.committed` tekshiriladi
* Yozuv rad etilsa endi jim yo'qolmaydi (P2 tuzatishi tufayli)

Qoladigan kichik xavf ochiq qoldirildi: hisoblagich oshgandan keyin ilova
butunlay yopilib qolsa, raqamda bo'shliq paydo bo'ladi (#57 → #59). Bu
zararsiz — raqam faqat identifikator, ketma-ketligi hisobotlarda
ishlatilmaydi. Uni butunlay yo'qotish uchun buyurtma yaratish serverga
ko'chirilishi kerak bo'lardi.

---

## ✅ I1. Ovozli signal noto'g'ri ishlaydi — TUZATILDI

**Qayerda:** `home_shell.dart:88` (`_notifyIfChanged`)

Uch muammo:

1. **`build()` ichida chaqiriladi.** Yon ta'sir (ovoz) va holat o'zgarishi
   (`_lastOrdersSignature =`) build paytida bajarilmasligi kerak.
2. **O'z harakatingizga ham ovoz chiqadi.** Xodim tugma bossa — o'zining
   o'zgarishidan ovoz eshitadi.
3. **Har qanday o'zgarishga chalinadi** — izoh qo'shilsa ham, holat
   o'zgarsa ham, bir xil.

**Bajarildi:**

* Oqim endi `StreamBuilder` o'rniga `initState` da tinglanadi — ovoz va
  holat o'zgarishi `build()` dan tashqarida
* O'zgarishni KIM qilgani tarixdan tekshiriladi: xodim o'z tugmasini
  bosganda o'ziga ovoz eshittirmaydi
* Taqqoslash arzonlashdi — butun ro'yxatdan bitta ulkan matn o'rniga
  har bir buyurtma uchun qisqa iz
* Mantiq `utils/order_change_detector.dart` ga ajratildi va **12 ta test**
  bilan qoplandi

---

## ✅ T1. Barcha buyurtmalar doim qurilmaga yuklanadi — TUZATILDI

**Qayerda:** `main.dart:53` va `order_service.dart:74`

```dart
FirebaseDatabase.instance.ref('orders').keepSynced(true);   // BUTUN tarix
Stream<List<Order>> streamAllOrders() => _db.ref('orders').onValue...  // limit yo'q
```

Hech qayerda `limitToLast` yoki `orderByChild` yo'q. Kuniga 20 ta buyurtma
qiladigan biznesda 2 yildan keyin ~15 000 ta buyurtma — har biri
xizmatlari, tarixi va izohlari bilan. Bularning **hammasi** har safar
yuklanadi va qurilmada saqlanadi.

Oqibati: ilova sekin ochiladi, telefon xotirasi to'ladi, mobil internet
sarflanadi, Firebase hisobi qimmatlashadi.

Ustiga-ustak `home_shell.dart:78` (`_signatureFor`) **har bir o'zgarishda**
shu 15 000 buyurtmadan bitta ulkan matn yasaydi.

**Bajarildi:**

* `keepSynced(true)` butun `orders` daraxtidan olib tashlandi
* `active` maydoni qo'shildi; operatsion ekranlar faqat faol
  buyurtmalarni oladi (`streamActiveOrders`)
* Hisobotlar davr bo'yicha so'raydi (`streamOrdersForPeriod`)
* Qarzdorlar `debtAmount` indeksi bo'yicha (`streamDebtors`)
* Boshqaruv ro'yxati `limitToLast` bilan (`streamRecentOrders`)
* Indekslar qoidalarga qo'shildi

Natijada yuklama biznesning umumiy tarixiga emas, joriy ish hajmiga
bog'liq bo'ladi.

---

## ✅ T2. Har bir o'zgarishda 4 ta ekran qayta chiziladi — TUZATILDI

**Qayerda:** `home_shell.dart:117-145`

`StreamBuilder` ichida to'rtala ekran ham qaytadan yaratiladi va
to'liq ro'yxat har biriga uzatiladi. Bitta buyurtma holati o'zgarsa —
hammasi qayta chiziladi.

Bundan tashqari har bir ekran VA har bir nishoncha ro'yxatni alohida
filtrlardi — ya'ni bitta o'zgarishda ro'yxat yetti marta aylanib chiqilardi.

**Bajarildi:**

* `utils/order_sections.dart` — barcha bo'limlar BIR martalik o'tishda
  ajratiladi va tayyor holda uzatiladi
* Filtr shartlari bir joyga to'plandi (ilgari uchta ekran fayliga
  tarqalgan edi va ekran bilan nishoncha farq qilib ketishi mumkin edi)

---

## ✅ K1. `order_detail_screen.dart` — 1935 qator — TUZATILDI

Bitta faylda: ko'rish, tahrirlash, o'lchash, to'lov, izoh, tarix, vakolat
tekshiruvi. Bunday faylga xavfsiz o'zgartirish kiritish qiyin.

**Bajarildi** — 1934 qator 759 qatorga tushdi, qolgani 7 ta modulga
ajratildi (`lib/screens/orders/widgets/`):

| Fayl | Qator | Nima |
|---|---|---|
| `order_view_common.dart` | 110 | formatlar, ranglar, tarix matnlari |
| `comment_bubble.dart` | 62 | izoh ko'rinishi |
| `order_history_view.dart` | 116 | tarix ro'yxati |
| `edit_item_sheet.dart` | 148 | o'lchash oynasi |
| `order_action_cards.dart` | 160 | olib kelish / transport kartalari |
| `order_sheets.dart` | 286 | izoh, tarix, qayta yuvish oynalari |
| `order_item_card.dart` | 357 | xizmat kartasi |

---

## ✅ K2. Kichikroq kamchiliklar — TUZATILDI

- ✅ `payment_dialog` — `allowDiscount` endi `_submit()` da ham
  tekshiriladi (ilgari faqat ko'rinish darajasida himoyalangan edi)
- ✅ `markDelivered` — endi tranzaksiya va farq SERVERDAGI joriy narxdan
  hisoblanadi. Bu bir muhim holatni ham yopdi: dastavchik to'lov oynasini
  ochib turganda sexdagi xodim buyurtmaga xizmat qo'shsa, farq hech
  qayerda qayd etilmay yo'qolib ketardi
- ✅ `auth_service` — majburiy ochish yo'q, `null` tekshiriladi
- ✅ Vakolat endi JONLI kuzatiladi: boshqaruvchi vakolatni o'zgartirsa
  darhol kuchga kiradi, xodim bloklansa tizimdan chiqariladi

---

## Holat

| # | Kamchilik | Holat |
|---|---|---|
| X1 | PIN-kodlar ochiq | ✅ tuzatildi |
| X2 | Ijarachilar ajratilmagan | ✅ tuzatildi |
| T1 | Butun tarix yuklanadi | ✅ tuzatildi |
| P1 | Bir vaqtda tahrirlashda pul yo'qoladi | ✅ tuzatildi |
| P2 | Ruxsat xatosi yutiladi | ✅ tuzatildi |
| P3 | Buyurtma raqamlarida bo'shliq | ✅ tuzatildi |
| I1 | Ovozli signal noto'g'ri | ✅ tuzatildi |
| T2 | 4 ta ekran qayta chiziladi | ✅ tuzatildi |
| K1 | 1935 qatorli fayl | ✅ tuzatildi |
| K2 | Kichik kamchiliklar | ✅ tuzatildi |
| T3 | Admin panel butun bazani yuklardi | ✅ tuzatildi |
| X3 | Nuqtali login bilan ro'yxatdan o'tib bo'lmasdi | ✅ tuzatildi |
| K3 | Tekshirilmagan kalit 500 qaytarardi | ✅ tuzatildi |

**Barcha aniqlangan kamchiliklar tuzatildi.**

Yo'l-yo'lakay topilgan va tuzatilgan qo'shimcha muammolar:

* Xizmat qayta yuvishga qaytarilganda buyurtma "Yetgazishga tayyor"
  holatida qolib ketardi — to'liq bo'lmagan buyurtmani yetkazib yuborish
  mumkin edi
* `/license/status` `tenantId` ni so'rovdan olardi — istalgan kirgan
  foydalanuvchi boshqa biznesning obuna holatini ko'ra olardi
* **T3** — super-admin paneli `ref('tenants').get()` qilardi. RTDB'da bu
  butun daraxtni yuklab olish demak: 100 ta biznes × 10 000 buyurtma
  bo'lsa, panelni bir ochish uchun butun baza tortib olinardi. Endi
  `/tenant_directory` da faqat ID'lar turadi va har bir biznesdan aynan
  `profile` + `license` o'qiladi; biznes kartasida buyurtmalar soni
  hisoblagichdan olinadi, buyurtmalar tuguni umuman ochilmaydi
* **X3** — jonli baza bilan birinchi sinovda topildi: `ali.vali` kabi
  login bilan ro'yxatdan o'tish 500 bilan yiqilardi. Sabab: login
  `admin_logins/{login}` yo'lida BAZA KALITI bo'lib yoziladi, RTDB
  kalitida esa `.` `#` `$` `/` `[` `]` bo'lishi mumkin emas.
  `sanitizeLogin` dan nuqta olib tashlandi — ilova va server tomonida
  bir xil, ikkalasi ham test bilan qoplangan
* **K3** — bo'lim/vakolat nomlari tekshirilmay to'g'ri bazaga
  yozilardi. Taqiqlangan belgili nom 500 "kutilmagan xatolik" berardi,
  mijoz esa nima noto'g'ri ekanini bilmasdi. Endi zod tekshiradi va
  tushunarli 400 qaytadi
* T1 tuzatilgandan keyin Yetgazma bo'limidagi "Yetgazildi" ro'yxati bo'sh
  qolgan edi (yetgazilgan buyurtma `active: false` bo'ladi) — operatsion
  oqimga bugungi yetgazilganlar qo'shildi
