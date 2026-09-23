# CSCRM dizayn tizimi

Websayt va boshqaruv paneli uchun yagona komponentlar va qoidalar.
Maqsad — bir xil vazifadagi element sahifadan sahifaga turlicha
ko'rinmasligi.

* Komponentlar: `admin/src/components/ui/` — `import { … } from '@/components/ui'`
* Tokenlar: `admin/src/styles/global.css` (`:root`)
* Komponent uslublari: `admin/src/styles/ui.css` (hammasi `ui-` bilan)
* **Jonli vitrina:** `cd admin && npm run dev` → <http://localhost:5173/ui-kit.html>
  (faqat ishlab chiqishda; prod yig'ilishiga kirmaydi)
* **Panelni ko'rib chiqish:** <http://localhost:5173/admin-preview.html> —
  haqiqiy sahifalar NAMUNAVIY javoblar bilan, serverga va bazaga ulanmasdan.
  Holatlar: `?holat=bosh`, `xato`, `sekin`, `faolliksiz`. Sahifa:
  `?yol=/admin/tenants/t2`. Amallar (to'lov, arxiv, o'chirish) xotiradagi
  namunaviy ro'yxatni o'zgartiradi — sahifa yangilansa asliga qaytadi.
  Cheklangan rol: `?rol=operator`.
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
| `List`, `ListItem`, `ListSkeleton` | Karta ichidagi qisqa ro'yxatlar ("E'tibor talab qiladi", "Oxirgi to'lovlar") |
| `Drawer` | Telefondagi menyu paneli — Dialog bilan bir xil fokus va `inert` qoidalari |
| `Dialog` | Oyna. Fokus ichida, orqa fon `inert`, Esc, fokus qaytadi; telefonda pastdan |
| `ConfirmDialog` | Muhim / qaytarib bo'lmaydigan amal |
| `PromptDialog` | Sabab so'rash (rad etish, to'xtatish) |
| `Checkbox` | Belgilash (rol vakolatlari). Haqiqiy katakcha — klaviatura va ekran o'quvchi o'z-o'zidan ishlaydi |
| `FormDialog` | Maydonli oyna (tahrirlash, to'lov qabul qilish). Enter bilan yuboriladi, `validate` maydon xatolarini ko'rsatadi, server xatosida oyna ochiq qoladi va kiritilgan ma'lumot saqlanadi |
| `useToast` | Amal natijasi ("Saqlandi") |
| `Alert` | Sahifadagi doimiy ogohlantirish |
| `EmptyState` | Ma'lumot yo'q — doim NIMA UCHUN bo'shligini aytadi |
| `Skeleton` | Birinchi yuklanish |
| `ChartCard` + `BarChart` | Chart — yuklanish/xato/bo'sh holatlari va **jadval ko'rinishi** bilan |
| `Stack`, `Cluster` | Oraliqni `style={{ marginTop }}` o'rniga shkaladan |

`window.confirm`, `window.prompt`, `alert` — **ishlatilmaydi**.

Ma'lumot yuklash — `useApi(path, pick)` (`lib/use-api.ts`): yo'l o'zgarsa
eski so'rov bekor qilinadi, qayta yuklashda eski ma'lumot ekranda qoladi,
oynaga qaytilganda eskirgan ma'lumot o'zi yangilanadi.

Sahifa joylashuvi: `.ui-stat-grid` — ko'rsatkichlar qatori (1 → 2 → 4
ustun, hech qachon 3 + 1), `.ui-grid` — kartalar to'ri (har ustun ≥ 360px;
`.ui-grid--fill` — bitta karta qolsa ham cho'zilmaydi), `.ui-split` —
asosiy ustun + yon panel (≥ 1100px), `.ui-toolbar` — qidiruv + filtrlar,
`.ui-timeline` — amallar jurnali. Matn: `.ui-note` (izoh), `.ui-code`
(login, ID — teng enli shrift), `.ui-muted`.

Ro'yxat holati (qidiruv, filtr, saralash, sahifa) va karta bo'limi
URL'da saqlanadi (`?q=&holat=&tartib=&sahifa=`, `?bolim=`) — orqaga
qaytilganda yoki havola yuborilganda o'sha ko'rinish ochiladi.

## Qoidalar

### Tasdiqlash — qachon va qanday

| Amal | Qanday |
|---|---|
| Oddiy saqlash, filtr, qidiruv | Tasdiqlashsiz — natija toast bilan |
| Tahrirlash, to'lov qabul qilish, obunani o'zgartirish | `FormDialog` — oqibati oyna ichida yoziladi ("tushumga yozilmaydi" va h.k.) |
| To'xtatish, so'rovni rad etish | `PromptDialog tone="danger"` — sabab majburiy, mijozga ko'rinadi |
| Qayta ochish, arxivdan qaytarish | `ConfirmDialog` — nima bo'lishi `consequences` da aniq yoziladi |
| Arxivlash | `FormDialog tone="danger"` — sabab + nomni qo'lda yozish |
| Butunlay o'chirish | `ConfirmDialog tone="danger" requireText={nomi}` — nom qo'lda yoziladi, server ham tekshiradi |

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
