# Realtime Database yoki Firestore?

Bu hujjat tanlovni asoslaydi va **qaysi sharoitda qayta ko'rib chiqish
kerakligini** ham aytadi.

Xulosa oldindan: **Realtime Database** (RTDB). Lekin uning ikkita
zaifligi bor va ular uchun aniq yechim kerak — pastda.

---

## 1. Ikkalasi qanday ishlaydi

| | Realtime Database | Firestore |
|---|---|---|
| Ma'lumot shakli | Bitta katta JSON daraxti | Hujjatlar va to'plamlar |
| Jonli yangilanish | Doimiy ochiq ulanish, faqat **o'zgargan qism** keladi | Hujjat darajasida |
| So'rov | **Bitta** `orderByChild` | Bir nechta shart, murakkab indekslar |
| Narx | Saqlangan **GB** + yuklangan **GB** | **Hujjat o'qish/yozish** soni |
| Oflayn | Kesh + navbat | Kesh + so'rovlar oflayn ham ishlaydi |

Asosiy farq: RTDB **trafik** bo'yicha, Firestore **amal soni** bo'yicha
pul oladi. Bu ikkisi butunlay boshqa hisob-kitob beradi.

---

## 2. Nega RTDB tanlandi

### Kechikish

Sexda bir vaqtda 3-5 qurilma bir buyurtmani ko'rib turadi. Xodim
"Qadoqlandi" tugmasini bosganda, boshqa qurilmada bu **darhol**
ko'rinishi kerak.

RTDB doimiy ochiq ulanish orqali faqat o'zgargan qismni yuboradi —
kechikish odatda 100 ms atrofida. Firestore biroz sekinroq. Bu ilova
uchun aynan shu narsa muhim.

### Ish to'plami kichik

Ilova bir vaqtda faqat **faol** buyurtmalarni ko'rsatadi — bu odatda
o'nlab yozuv. Tarix esa faqat hisobot ochilganda, sana oralig'i bo'yicha
so'raladi. Ya'ni "issiq" ma'lumot kichik va o'zgaruvchan — RTDB aynan
shunga mo'ljallangan.

### Oflayn va delta

`setPersistenceEnabled(true)` yoqilgan. Ilova qayta ochilganda butun
ma'lumot emas, faqat **oxirgi sinxronizatsiyadan keyingi o'zgarishlar**
yuklanadi. Shu sabab trafik ma'lumot hajmiga emas, **o'zgarishlar soniga**
bog'liq bo'ladi.

Bu muhim: baza 10 barobar o'ssa ham kundalik trafik deyarli o'zgarmaydi.

### Tranzaksiyalar

Pul bilan bog'liq amallar (`totalPrice`, qarz to'lovi) tranzaksiya orqali
ishlaydi. RTDB tranzaksiyasi **oflayn ham** ishlaydi — mahalliy qo'llanadi,
aloqa tiklanganda serverda qayta hisoblanadi. Sex sharoitida bu qulay.

---

## 3. RTDB ning ikkita haqiqiy zaifligi

Bularni yashirmaslik kerak.

### Zaiflik 1 — bitta so'rovda bitta shart

RTDB `where active == true AND createdAt BETWEEN x AND y` qila olmaydi.

Shu sabab `streamOrdersForPeriod()` **uchta alohida so'rovni** birlashtiradi.
Bu ishlaydi, lekin Firestore'da bitta so'rov bo'lardi.

**Ta'siri:** kod biroz murakkab, lekin tezlikka ta'sir qilmaydi.

### Zaiflik 2 — so'rov BUTUN tugunni qaytaradi ⚠️

Bu jiddiyroq.

RTDB'da `orders` bo'yicha so'rov har bir buyurtmaning **butun daraxtini**
qaytaradi — shu jumladan `history`, `items`, `comments`. Ro'yxatda tarix
ko'rsatilmasa ham, u yuklanadi.

Buyurtma umri davomida tarix o'sib boradi:

| Buyurtma holati | Tarix yozuvlari | Taxminiy hajm |
|---|---|---|
| Yangi qabul qilingan | 1-2 | ~1 KB |
| Sexda, o'lchangan | 10-15 | ~3 KB |
| Yetgazishga tayyor | 20-30 | ~6 KB |

50 ta faol buyurtma = **~300 KB**, uning ~60% i ro'yxatda umuman
ishlatilmaydigan tarix.

Firestore'da tarix **subcollection** bo'lardi va ro'yxat so'rovida
umuman yuklanmasdi.

**✅ BAJARILDI.** Tarix `/tenants/{id}/order_history/` tuguniga
chiqarildi. Tuzilma **tekis** — ikki xil so'rov kerak bo'lgani uchun:

* buyurtma kartasi — `orderByChild('orderId').equalTo(id)`
* hisobotlar — `orderByChild('at').startAt(x).endAt(y)`

Buyurtma tugunida faqat **qat'iy sondagi** belgi maydonlari qoldi:
`pickedUp*`, `ready*`, `delivered*`, `lastRewash*`, `lastDebtPayment*`,
`lastAction*`. Ular o'smaydi.

Kim nima ishlatadi:

| Kim | Ilgari | Endi |
|---|---|---|
| Ro'yxat ekranlari | butun tarix yuklanardi | **umuman yuklamaydi** |
| Bildirishnomalar | tarixni aylanardi | belgi maydonlari |
| Yetgazma statistikasi | tarixdan qidirardi | `pickedUp` / `delivered` |
| Ovozli signal | `history.last` | `lastActionBy` |
| Buyurtma kartasi | buyurtma bilan birga | alohida oqim, faqat ochilganda |
| Yuvish / xodim hisoboti | buyurtma bilan birga | davr bo'yicha alohida so'rov |

---

## 4. Narx: hisob-kitob

Taxminiy o'lchov — bitta biznes kuniga **30 ta buyurtma** qiladi deb
olamiz. Har bir buyurtma o'rtacha 6 KB, umri davomida ~20 marta yoziladi.

### Bitta biznes uchun bir yilda

| | RTDB | Firestore |
|---|---|---|
| Yillik yozuv | 10 950 buyurtma × 6 KB = **66 MB** | shu hajm |
| Saqlash narxi | ~$5/GB/oy → **~$4/yil** | ~$0.18/GB/oy → **~$0.15/yil** |
| Yozish | trafikka kiradi | 219 000 yozuv → **~$0.40/yil** |
| O'qish | delta, kichik | ~500 000 o'qish → **~$0.30/yil** |
| **Jami (1-yil)** | **~$5** | **~$1** |
| **Jami (3-yil ma'lumot bilan)** | **~$13** | **~$1.5** |

Firestore arzonroq — lekin **ikkalasi ham** siz belgilagan yillik $50
baza to'lovidan ancha kam.

### 500 ta biznes bo'lganda

| | RTDB | Firestore |
|---|---|---|
| 3 yillik saqlash | ~100 GB → **~$6 000/yil** | ~$220/yil |
| Trafik / amallar | ~$700/yil | ~$350/yil |
| **Jami** | **~$6 700/yil** | **~$570/yil** |

**Farq sezilarli.** Lekin uni deyarli butunlay yopadigan yechim bor —
pastga qarang.

> Narxlar taxminiy va Firebase tariflari o'zgarishi mumkin. Aniq raqam
> uchun Firebase narx kalkulyatorini tekshiring.

---

## 5. Ko'p ma'lumot bo'lganda tezlik yo'qoladimi?

**Yo'q — quyidagi uch shart bajarilsa.**

### Shart 1: indekslar joylashtirilgan ✅

`.indexOn` bo'lmasa RTDB butun tugunni yuklab, keyin filtrlaydi — bu
butun optimizatsiyani yo'qqa chiqaradi.

Indekslar `firebase/database.rules.json` da yozilgan va qoidalar bilan
birga joylashtiriladi:

```
orders        : active · status · createdAt · deliveredAt · createdBy · debtAmount
order_history : orderId · at
employees     : phone · active
expenses      : spentAt
```

Indeks bor bo'lsa, so'rov vaqti **natija hajmiga** bog'liq, umumiy
ma'lumot hajmiga emas. 100 ta buyurtma ham, 100 000 ta buyurtma ham
bir xil tezlikda 50 ta faol buyurtmani qaytaradi.

### Shart 2: so'rovlar cheklangan ✅

Hech qayerda "hammasini yukla" yo'q. Har bir ekran o'ziga keragini
so'raydi (T1 bosqichida tuzatilgan).

### Shart 3: eski ma'lumot arxivlanadi ⬜ *(hali qilinmagan)*

Bu **yagona ochiq xavf**. Tezlikka emas, **narxga** ta'sir qiladi.

Yetgazilgan va to'langan buyurtma 6 oydan keyin kundalik ishda kerak
emas. Uni arxivga ko'chirish kerak:

* eng sodda: Cloud Storage'ga JSON qilib eksport qilib, RTDB'dan o'chirish
* yoki: alohida "sovuq" RTDB nusxasiga ko'chirish

Buni backend'da oyiga bir marta ishlaydigan vazifa qiladi. Shunda issiq
baza **doim kichik qoladi** va yuqoridagi $6 000 raqami ~$800 ga tushadi.

---

## 6. Qachon Firestore'ga o'tishni qayta ko'rib chiqish kerak

Quyidagilardan **birortasi** yuz bersa:

| Chegara | Nega muhim |
|---|---|
| **1 000 dan ortiq biznes** | RTDB bitta baza ~1 000 yozuv/sekund ko'taradi; barcha ijarachilar shuni bo'lishadi |
| **Bitta biznesda 100 000 dan ortiq faol buyurtma** | Bitta tugunda juda ko'p bola — server xotirasiga bosim |
| **Murakkab hisobotlar kerak bo'lsa** | Bir nechta shartli so'rov RTDB'da yo'q |
| **Arxivlash amalga oshmasa** | Saqlash narxi yildan yilga o'sib boradi |

Hozircha bularning birortasiga ham yaqin emasmiz.

---

## 7. Xulosa va qilinadigan ishlar

**RTDB bilan davom etamiz.** Sabab: kechikish pastroq, oflayn ishlash
soddaroq, ish to'plami kichik, tranzaksiyalar oflayn ishlaydi — va u
allaqachon qurilgan hamda tekshirilgan.

Ochiq qolgan ikkita ish (ikkalasi ham **narx** bilan bog'liq, tezlik
bilan emas):

| # | Ish | Ta'siri | Holat |
|---|---|---|---|
| 1 | Tarixni alohida tugunga chiqarish | Ro'yxat yuklamasi ~60% kamayadi | ✅ bajarildi |
| 2 | Eski buyurtmalarni arxivlash | Saqlash narxi barqaror qoladi | ⬜ birinchi yil oxirigacha |

Arxivlash hozir shoshilinch emas — bir necha o'nlab mijozgacha muammo
tug'dirmaydi.

---

## 8. Region tanlash

RTDB uchta regionda ishlaydi. O'zbekistondan kechikish:

| Region | Joylashuv | Taxminiy kechikish |
|---|---|---|
| **`europe-west1`** | Belgiya | **~70-110 ms** ← tavsiya |
| `asia-southeast1` | Singapur | ~150-200 ms |
| `us-central1` | AQSh | ~180-250 ms |

**Tanlangan region: `asia-southeast1` (Singapur).**

Tavsiya `europe-west1` edi, lekin farq amalda o'lchanmagan — mening
baholashim marshrutlash odatlariga asoslangan edi, aniq o'lchovga emas.
Haqiqiy tezlik ko'rilgach qayta ko'rib chiqish mumkin: ma'lumot kam
bo'lgan paytda ko'chirish oson (yangi baza + qoidalarni joylash).
