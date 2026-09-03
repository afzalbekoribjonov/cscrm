# CSCRM — ish rejasi

Bu fayl bizning umumiy navbatimiz. Har bir bosqichni birgalikda muhokama
qilib, keyin bajaramiz.

---

## ✅ 0-bosqich — poydevor (bajarildi)

- `gilam_yuvish_furqat` dan nusxa olindi, build chiqindilarisiz
- Eski Firebase kalitlari **butunlay olib tashlandi** (`google-services.json`
  ko'chirilmadi, `firebase_options.dart` qayta yozildi)
- Android paket: `com.gilamyuvishfurqat.appname` → **`uz.cscrm.uzafo`**
- Versiya `0.8.1+13` → **`1.0.0+1`**
- Brend: nom, rang palitrasi, logotip (vektor + PNG ikonkalar), native splash
- Sozlamalar `--dart-define-from-file` ga ko'chirildi — repoda kalit yo'q
- Monorepo: `app/` + `backend/` + `admin/` + `firebase/` + `shared/`
- Backend karkasi: Express + TS, litsenziya xizmati, imzolangan javob
- Websayt karkasi: React + Vite, marketing sahifalari, narxlar
- Ko'p ijarachili DB qoidalari yozildi
- Render blueprint (`render.yaml`)

**Holat:** `flutter analyze` toza · backend `tsc` toza · `admin` build toza ·
0 ta zaiflik · debug APK yig'ildi.

---

## Qabul qilingan qarorlar

| # | Savol | Qaror |
|---|---|---|
| 1 | Android paket nomi | **`uz.cscrm.uzafo`** — tasdiqlandi |
| 2 | To'lov usuli | **Qo'lda (karta o'tkazma)** — super-admin panelda tasdiqlanadi |
| 3 | Boshlash tartibi | **Avval mavjud kamchiliklarni ko'rib chiqamiz** |

## Hali ochiq savollar

| # | Savol | Hozirgi holat |
|---|---|---|
| 1 | Rejalar narxi qancha? | **TAKLIF yozildi** — tayanch 199 000 so'm/oy, tasdiqlash kerak |
| 2 | $50 qachondan hisoblanadi? | belgilanmagan — hozir sotib olingan kundan +1 yil |
| 3 | Sinov muddati 14 kun to'g'rimi? | `plans.json` da 14 |

### Taklif etilgan narxlar

| Reja | Narx | Oyiga | Chegirma |
|---|---|---|---|
| 1 oylik | 199 000 | 199 000 | — |
| 3 oylik | 537 000 | 179 000 | 10% |
| 5 oylik | 845 000 | 169 000 | 15% |
| 1 yillik | 1 790 000 | 149 167 | 25% |
| Bir umrlik | 4 500 000 | — | + $50/yil |

Bir umrlik qoplanishi: 4 500 000 / (1 790 000 − ~640 000) ≈ **3,9 yil**.
Narx `shared/plans.json` da, bitta joyda — o'zgartirilsa websayt ham,
ilova ham darhol yangi narxni ko'rsatadi (ilovani qayta yig'ish shart
emas, u rejalarni serverdan oladi).

---

## ✅ 1-bosqich — ko'p ijarachilik va PIN xavfsizligi (bajarildi)

Batafsil: [ARXITEKTURA.md](ARXITEKTURA.md) · [KAMCHILIKLAR.md](KAMCHILIKLAR.md)

- Ma'lumot `/tenants/{tenantId}/...` ga ko'chirildi
- Xodim kirishi: anonim → backend bergan custom token
- PIN tekshiruvi serverga o'tdi (bcrypt + blok + cheklov)
- Cheklangan so'rovlar (T1) — butun tarix endi yuklanmaydi
- Backend: 25 ta test, `tsc` toza
- Ilova: `flutter analyze` toza, APK yig'iladi

### Eski reja (bajarilgan)

<details>
<summary>Batafsil</summary>

## 1-bosqich — ko'p ijarachilik (eng muhim)

Hozirgi ilova **bitta biznes** uchun yozilgan: ma'lumot `/orders`,
`/employees` ildizida turadi. SaaS uchun har bir biznes ajratilishi shart.

**Nima qilinadi:**
- Ma'lumot `/tenants/{tenantId}/...` ga ko'chiriladi
- Xodim kirishi: anonim → **backend bergan custom token**
  (`tenantId`, `role`, `employeeId` claim'lari bilan)
- PIN tekshiruvi serverga o'tadi (hozir PIN hash mijozga o'qiladi)

**Nega birinchi:** hozirgi qoidalarda `auth != null` yozilgan — bu bir
biznes boshqasining ma'lumotini ko'ra olishini anglatadi. Bu tuzatilmaguncha
boshqa hech narsani ustiga qurish xavfli.

</details>

## ✅ Oraliq bosqich — pul va ma'lumot to'g'riligi (bajarildi)

- **P1** Umumiy narx va qarz endi tranzaksiya orqali o'zgaradi; narx
  xizmatlardan qayta hisoblanadi (o'zi tuzaladi)
- **P2** Rad etilgan yozuv jim yo'qolmaydi — qizil SnackBar bilan aytiladi
- **P3** Hisoblagich buzuq qiymatga chidamli
- Sof mantiq `utils/order_totals.dart` va `utils/offline_write.dart` ga
  ajratildi, **21 ta Flutter testi** bilan qoplandi

## ✅ Kamchiliklarni tuzatish (bajarildi)

`docs/KAMCHILIKLAR.md` dagi **o'nta band ham** yopildi: xavfsizlik (X1, X2),
tezlik (T1, T2), pul to'g'riligi (P1, P2, P3), ovozli signal (I1) va kod
tuzilishi (K1, K2).

- `order_detail_screen.dart` 1934 → 759 qator, qolgani 7 ta modulga ajraldi
- Sof mantiq utils'ga chiqarildi va test bilan qoplandi
- **40 ta Flutter testi** + **25 ta backend testi**

## ✅ 2-bosqich — obuna va bloklash (bajarildi)

- Litsenziya holati imzo bilan tekshiriladi (HMAC-SHA256); Dart va Node
  bir xil imzo hosil qilishi **test bilan tasdiqlangan**
- Muddat tugaganda to'lov ekrani — biznes egasiga ham, XODIMGA ham
- "Tekshirish" tugmasi ikkala rolga ham ochiq
- Oflayn oyna 6 soat; qurilma soatini orqaga surib cho'zib bo'lmaydi
- Muddat tugashiga oz qolganda tepada eslatma chizig'i
- To'lov rekvizitlari serverdan keladi (kodda qattiq yozilmagan)
- Ilova old planga qaytganda va har 15 daqiqada holat yangilanadi

### Eski reja

<details>
<summary>Batafsil</summary>

## 2-bosqich — obuna va bloklash

- Ilovada litsenziya holatini tekshirish (imzo tekshiruvi bilan)
- Muddat tugaganda **to'lov ekrani** — biznes egasiga ham, xodimlarga ham
- "Tekshirish" tugmasi — to'lovdan keyin darhol qayta so'rov
- Oflayn oyna: internetsiz 6 soat ishlash
- Muddat tugashiga 7 / 3 / 1 kun qolganda eslatma

</details>

## ✅ 3-bosqich — bildirishnomalar (bajarildi)

- App bar'ning o'ng yuqori burchagida qo'ng'iroq + o'qilmaganlar soni
- Ro'yxat: yangi buyurtma · qabul qilindi · yetgazishga tayyor ·
  yetgazildi · qayta yuvish · qarz to'landi
- **O'z harakati qaytmaydi** — xodim o'zining ishidan bildirishnoma olmaydi
- Shovqin filtrlangan: o'lchash, narx tuzatish, oddiy bosqich siljishlari
  ro'yxatga tushmaydi

**Arxitektura qarori:** bildirishnomalar bazaga YOZILMAYDI, buyurtma
tarixidan hisoblanadi. Shu sabab qo'shimcha yozuv, qo'shimcha so'rov va
cheksiz o'sadigan tugun yo'q — hamda oflayn ham ishlaydi.

### Eski reja

<details>
<summary>Batafsil</summary>

## 3-bosqich — bildirishnomalar

- App bar'ning **o'ng yuqori burchagida** qo'ng'iroq ikonkasi + hisoblagich
- Bildirishnomalar ro'yxati (o'qilgan/o'qilmagan)
- Turlari: yangi buyurtma, holat o'zgardi, to'lov, obuna eslatmasi

</details>

## ✅ 4-bosqich — super-admin platformasi (bajarildi)

Websaytda `/admin` bo'limi:

- Firebase Auth bilan kirish + **server tomonidan super-admin tasdig'i**
- Umumiy holat: bizneslar soni, faol/bloklangan, 30 kunlik tushum
- Bizneslar ro'yxati (qidiruv bilan) — diqqat talab qiladiganlar tepada
- Biznes kartasi: obuna, xodimlar/buyurtmalar soni, to'lovlar tarixi
- **To'lovni tasdiqlash** — reja tanlanadi, obuna darhol uzayadi
- Hisobni to'xtatish / qayta yoqish

Muddat uzaytirishda oldindan to'lagan mijoz kunini yo'qotmaydi: muddat
tugamagan bo'lsa yangisi mavjudining ustiga qo'shiladi (test bilan
qoplangan).

### Eski reja

<details>
<summary>Batafsil</summary>

## 4-bosqich — super-admin platformasi

- Firebase Auth bilan kirish
- Tenant'lar ro'yxati, obuna holati, muddatni uzaytirish
- To'lovlar tarixi, daromad statistikasi
- Tenant'ni to'xtatish / qayta yoqish

</details>

## 5-bosqich — biznes egasi kabineti (websaytda)

- O'z obunasini ko'rish va to'lash
- Xodimlarni boshqarish
- Hisobotlar

## ✅ 6-bosqich — to'lovni rasmiylashtirish (bajarildi)

Tanlangan usul: **qo'lda karta o'tkazma** (webhook kerak emas).

- Ilovada to'lov ekrani: karta raqami, reja, summa — hammasi serverdan
- **"To'lov haqida xabar berish"** — ega reja, summa va o'tkazma raqamini
  yuboradi. Bu obunani UZAYTIRMAYDI, faqat navbatga tushadi
- Bir vaqtda bitta so'rov — navbat takroriy xabarlar bilan to'lmaydi
- So'rov holati EGAGA ham, XODIMGA ham ko'rinadi (kutilmoqda / rad etilgan
  + sabab), shuning uchun xodim nima bo'layotganini biladi
- Panelda **To'lov so'rovlari** bo'limi: tasdiqlash (reja va summa
  so'rovdan olinadi, qo'lda kiritilmaydi) yoki sababi bilan rad etish
- Tasdiqlangach obuna darhol uzayadi; ilovada "Tekshirish" tugmasi
  yangilaydi

Qolgan: chek RASMINI yuklash (hozir o'tkazma raqami matn sifatida
kiritiladi) va Payme/Click — ikkalasi ham shu oqim ustiga qo'shiladi.

## ✅ 7-bosqich — mavjud kamchiliklarni tuzatish (bajarildi)

`docs/KAMCHILIKLAR.md` dagi barcha bandlar yopildi (T3 — admin panel
butun bazani yuklashi — shu jumladan).

## 8-bosqich — websaytni to'ldirish

- Blog / yordam markazi
- Skrinshotlar, demo video
- SEO, sitemap, Open Graph
