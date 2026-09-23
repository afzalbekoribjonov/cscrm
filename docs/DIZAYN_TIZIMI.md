# CSCRM dizayn tizimi

Websayt va boshqaruv paneli uchun yagona komponentlar va qoidalar.
Maqsad — bir xil vazifadagi element sahifadan sahifaga turlicha
ko'rinmasligi.

* Komponentlar: `admin/src/components/ui/` — `import { … } from '@/components/ui'`
* Tokenlar: `admin/src/styles/global.css` (`:root`)
* Komponent uslublari: `admin/src/styles/ui.css` (hammasi `ui-` bilan)
* **Jonli vitrina:** `cd admin && npm run dev` → <http://localhost:5173/ui-kit.html>
  (faqat ishlab chiqishda; prod yig'ilishiga kirmaydi)
* Sinovlar: `cd admin && npm test`

---

## Tokenlar

Sahifalarda piksel va rang **qo'lda yozilmaydi** — tokendan olinadi.

| Guruh | Tokenlar | Izoh |
|---|---|---|
| Oraliq | `--space-1…16` (4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64) | 4px qadam |
| Matn | `--fs-12…36`, `--lh-tight/snug/normal`, `--fw-regular/semibold/bold/heavy` | Marketing sarlavhalari o'z `clamp()` ida |
| Holat matni | `--success-ink`, `--warning-ink`, `--danger-ink`, `--info-ink`, `--neutral-ink` | Oq fonda, sahifa fonida va o'z `-soft` fonida **≥ 4.5:1** — hisoblab tanlangan |
| Holat foni | `--*-soft` | Nishon, ogohlantirish fonlari |
| Boshqaruv | `--control-h-sm/…/lg` (32 · 40 · 48) | Barmoqli ekranda 40 · 44 |
| Qatlam | `--z-sticky` · `--z-header` · `--z-dropdown` · `--z-overlay` · `--z-toast` | 9999 yozilmaydi |
| Harakat | `--dur-fast` (120ms) · `--dur` (180ms) · `--ease` | `prefers-reduced-motion` hurmat qilinadi |
| Fokus | `--focus-ring` | Barcha boshqaruv elementlarida bir xil |

`--success`, `--warning`, `--danger` — **belgi va to'ldirish** uchun. Ular
matn sifatida oq fonda 2–3:1 beradi, shuning uchun matnga `-ink` ishlatiladi.

## Komponentlar

| Komponent | Qachon |
|---|---|
| `Button`, `ButtonLink` | Har bir amal. Variant: `primary` (sahifada bitta asosiy), `secondary`, `outline`, `plain` (bekor qilish), `danger`, `danger-outline`. `loading` — takroriy bosishdan himoya |
| `IconButton` | Faqat ikonkali tugma. `label` MAJBURIY (ekran o'quvchi + maslahat) |
| `Field` + `Input` / `Textarea` / `Select` / `SearchInput` / `MoneyInput` | Har bir forma maydoni. Yorliq doim ko'rinadi; xato va maslahat `aria` orqali o'zi bog'lanadi |
| `Badge` | Holat. Ma'no matnda, rang — qo'shimcha |
| `Card`, `DescriptionList` | Sahifa bo'limi; kalit–qiymat ro'yxati |
| `StatCard` | Bitta ko'rsatkich. O'zgarish doim **davr** bilan ("o'tgan 30 kunga nisbatan"); rang — o'sish YAXSHIMI (`goodWhen`), strelka yo'nalishi emas |
| `PageHeader` | Har sahifaning boshi va yagona `h1` |
| `Tabs` | Bir sahifada bir necha bo'lim (biznes kartasi) |
| `DataTable` + `useTable` + `Pagination` | Ro'yxatlar. Telefonda kartalar, saralash alohida tanlovda |
| `DropdownMenu` | Qator amallari ("…"). Xavfli amallar oxirida, ajratilgan |
| `Dialog` | Oyna. Fokus ichida, orqa fon `inert`, Esc, fokus qaytadi; telefonda pastdan |
| `ConfirmDialog` | Muhim / qaytarib bo'lmaydigan amal |
| `PromptDialog` | Sabab so'rash (rad etish, to'xtatish) |
| `useToast` | Amal natijasi ("Saqlandi") |
| `Alert` | Sahifadagi doimiy ogohlantirish |
| `EmptyState` | Ma'lumot yo'q — doim NIMA UCHUN bo'shligini aytadi |
| `Skeleton` | Birinchi yuklanish |
| `ChartCard` + `BarChart` | Chart — yuklanish/xato/bo'sh holatlari va **jadval ko'rinishi** bilan |
| `Stack`, `Cluster` | Oraliqni `style={{ marginTop }}` o'rniga shkaladan |

`window.confirm`, `window.prompt`, `alert` — **ishlatilmaydi**.

## Qoidalar

### Tasdiqlash — qachon va qanday

| Amal | Qanday |
|---|---|
| Oddiy saqlash, filtr, qidiruv | Tasdiqlashsiz — natija toast bilan |
| To'lovni tasdiqlash, reja yoki muddatni o'zgartirish, hisobni to'xtatish | `ConfirmDialog` — nima bo'lishi `consequences` da aniq yoziladi |
| Arxivlash, butunlay o'chirish | `ConfirmDialog tone="danger" requireText={nomi}` — nom qo'lda yoziladi |

Xavfli oynada fokus "Bekor qilish" da (yoki nom maydonida) — tasodifiy
Enter hech narsani o'chirmaydi. `onConfirm` xato tashlasa oyna yopilmaydi,
xato ichida ko'rinadi.

### Holatlar

Har bir ma'lumot bloki to'rt holatni ko'rsatadi: **yuklanish** (skelet),
**xato** (nima qilish kerakligi bilan, qayta urinish tugmasi), **bo'sh**
(sababi bilan), **ma'lumot**. Qayta yuklashda eski ma'lumot xira turadi —
skeletga sakramaydi.

### Matn

Foydalanuvchiga "server", "API", "token", holat kodi (500, 404), inglizcha
xato matni **ko'rsatilmaydi**. Xato — nima bo'lganini va nima qilishni
aytadi: "Aloqa o'rnatilmadi. Internetni tekshirib, qayta urinib ko'ring."

### Chartlar

* Qism va butun — to'plangan bar (`StatusBar`), donut emas.
* Ustun ≤ 24px, uchi 4px yumaloq, asosi to'g'ri; to'r chiziqlari ingichka.
* Bitta qatorga legend yo'q (sarlavha aytadi); ≥ 2 qatorda — doim.
* Matn hech qachon qator rangida emas — `--text` / `--text-muted`.
* Chart ranglari (`--chart-1…4`) validatordan o'tgan: rang ko'rmaslik
  holatlarida ham ajraladi. Kunduzgi rejimda 3–4-ranglar oq fonga 3:1
  dan past — shuning uchun jadval ko'rinishi **majburiy**.

### Kirish imkoniyati

* Klaviatura: har bir element Tab bilan yetiladi, fokus ko'rinadi
  (`--focus-ring`); menyu, yorliqlar va chart strelkalar bilan boshqariladi.
* Rang yagona belgi emas — yonida matn yoki ikonka.
* Telefonda bosiladigan element ≥ 44px; matn maydoni 16px (iOS kattalashtirmaydi).
