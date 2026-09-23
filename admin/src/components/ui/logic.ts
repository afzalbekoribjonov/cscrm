/**
 * Dizayn tizimi komponentlarining SOF mantiqi.
 *
 * Bu yerda React ham, DOM ham yo'q — faqat kirish va chiqish. Shu
 * sababli har bir funksiya sinov bilan qoplangan (`logic.test.ts`):
 * sahifalash yoki saralashdagi xato jadvalda "yo'qolgan qator" bo'lib
 * ko'rinadi va uni ko'z bilan payqash qiyin.
 */

import { formatNumber } from '@/lib/format';

/** CSS klass nomlarini birlashtiradi — `false`/`undefined` tashlab ketiladi. */
export function cx(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join(' ');
}

/* ------------------------------------------------------------------ */
/* Sahifalash                                                          */
/* ------------------------------------------------------------------ */

export type PageItem = number | 'gap';

/**
 * Ko'rsatiladigan sahifa raqamlari.
 *
 * Birinchi va oxirgi sahifa doim ko'rinadi, joriy sahifa atrofida
 * `siblings` tadan qo'shni. Orada tushib qolganlar `'gap'` (…) bilan.
 * Bitta raqamni yashirish uchun "…" qo'yilmaydi — raqamning o'zi
 * ko'rsatiladi: "1 … 3" dan "1 2 3" tushunarliroq.
 *
 *   pageRange(6, 12) → [1, 'gap', 5, 6, 7, 'gap', 12]
 */
export function pageRange(current: number, total: number, siblings = 1): PageItem[] {
  if (total <= 0) return [];
  const page = clamp(current, 1, total);

  // Hammasi sig'adigan bo'lsa — hammasi.
  if (total <= 5 + siblings * 2) {
    return Array.from({ length: total }, (_, i) => i + 1);
  }

  const start = Math.max(2, page - siblings);
  const end = Math.min(total - 1, page + siblings);
  const items: PageItem[] = [1];

  if (start === 3) items.push(2);
  else if (start > 3) items.push('gap');

  for (let p = start; p <= end; p++) items.push(p);

  if (end === total - 2) items.push(total - 1);
  else if (end < total - 2) items.push('gap');

  items.push(total);
  return items;
}

export interface PageSlice<T> {
  rows: T[];
  /** Chegaraga keltirilgan joriy sahifa (1 dan). */
  page: number;
  pageCount: number;
  /** Ko'rsatilayotgan birinchi qator tartib raqami (1 dan); bo'sh bo'lsa 0. */
  from: number;
  to: number;
  total: number;
}

/**
 * Ro'yxatning bitta sahifasi.
 *
 * Sahifa raqami chegaradan chiqsa (filtr qo'llangach 5-sahifa endi
 * yo'q) — oxirgi mavjud sahifa qaytadi, bo'sh jadval emas.
 */
export function paginate<T>(items: readonly T[], page: number, pageSize: number): PageSlice<T> {
  const size = Math.max(1, Math.floor(pageSize));
  const total = items.length;
  const pageCount = Math.max(1, Math.ceil(total / size));
  const current = clamp(Math.floor(page) || 1, 1, pageCount);
  const start = (current - 1) * size;
  const rows = items.slice(start, start + size);

  return {
    rows,
    page: current,
    pageCount,
    from: total === 0 ? 0 : start + 1,
    to: start + rows.length,
    total,
  };
}

/* ------------------------------------------------------------------ */
/* Raqamlar                                                            */
/* ------------------------------------------------------------------ */

const NBSP = ' ';
const MINUS = '−';

/** Bir xonali kasr, keraksiz ",0" siz: 12.0 → "12", 12.94 → "12,9". */
function oneDecimal(n: number): string {
  const rounded = Math.round(n * 10) / 10;
  return (Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)).replace('.', ',');
}

/**
 * Katta sonni qisqa ko'rinishga keltiradi — kartalar va chart o'qlari uchun.
 *
 *   9 800 → "9 800"   12 900 → "12,9 ming"   1 790 000 → "1,8 mln"
 *
 * 10 000 gacha to'liq yoziladi: "9,8 ming" dan "9 800" aniqroq va
 * joy ham deyarli bir xil.
 */
export function compactNumber(value: number): string {
  if (!Number.isFinite(value)) return '—';
  const sign = value < 0 ? MINUS : '';
  const abs = Math.abs(value);

  if (abs < 10_000) return sign + formatNumber(Math.round(abs));
  if (abs < 1_000_000) return `${sign}${oneDecimal(abs / 1_000)}${NBSP}ming`;
  if (abs < 1_000_000_000) return `${sign}${oneDecimal(abs / 1_000_000)}${NBSP}mln`;
  return `${sign}${oneDecimal(abs / 1_000_000_000)}${NBSP}mlrd`;
}

export type Direction = 'up' | 'down' | 'flat';

/**
 * Oldingi davrga nisbatan o'zgarish.
 *
 * Oldingi qiymat 0 bo'lsa foizni hisoblab BO'LMAYDI (nolga bo'lish) —
 * "+∞%" ko'rsatish o'rniga `pct: null` qaytadi va karta faqat
 * yo'nalishni ko'rsatadi.
 */
export function deltaOf(current: number, previous: number): { pct: number | null; direction: Direction } {
  const diff = current - previous;
  const direction: Direction = diff > 0 ? 'up' : diff < 0 ? 'down' : 'flat';
  if (previous === 0) return { pct: null, direction };
  return { pct: (diff / Math.abs(previous)) * 100, direction };
}

/** "+12%", "−8,5%", "0%" — haqiqiy minus belgisi bilan. */
export function formatDelta(pct: number): string {
  const abs = Math.abs(pct);
  const body = abs < 10 ? oneDecimal(abs) : String(Math.round(abs));
  if (body === '0') return '0%';
  return `${pct > 0 ? '+' : MINUS}${body}%`;
}

/* ------------------------------------------------------------------ */
/* Matn                                                                */
/* ------------------------------------------------------------------ */

/** Ism yoki nomdan ikki bosh harf: "Gilam Yuvish Markazi" → "GY". */
export function initials(name: string): string {
  const letters = name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => Array.from(word)[0] ?? '')
    .join('');
  return letters ? letters.toLocaleUpperCase('uz') : '?';
}

/** Matndan barqaror indeks — bir xil nom doim bir xil rang oladi. */
export function toneIndex(key: string, count: number): number {
  if (count <= 0) return 0;
  let hash = 5381;
  for (const ch of key) hash = ((hash * 33) ^ ch.codePointAt(0)!) >>> 0;
  return hash % count;
}

/**
 * O'zbekcha tutuq belgisining barcha ko'rinishlari.
 *
 * "G'olib" nomini foydalanuvchi telefonda ʻ, ’ yoki ` bilan yozishi
 * mumkin — ko'zga bir xil, lekin belgi boshqa. Solishtirishda ularni
 * bittaga keltirmasak, to'g'ri yozilgan nom "mos emas" deb rad etilardi.
 */
const APOSTROPHES = /[‘’ʻʼ`´]/g;

function normalizeForCompare(text: string): string {
  return text
    .replace(APOSTROPHES, "'")
    .trim()
    .replace(/\s+/g, ' ')
    .toLocaleLowerCase('uz');
}

/**
 * Xavfli amalni tasdiqlash uchun yozilgan matn kutilganiga mosmi.
 *
 * Katta-kichik harf, chetdagi va takroriy bo'shliq, tutuq belgisi
 * turi hisobga olinmaydi — maqsad foydalanuvchini qiynash emas, balki
 * u AYNAN QAYSI biznesni o'chirayotganini o'qib, anglab yozishi.
 * Bo'sh kutilgan matn hech qachon mos kelmaydi.
 */
export function matchesConfirmation(input: string, expected: string): boolean {
  const target = normalizeForCompare(expected);
  if (target.length === 0) return false;
  return normalizeForCompare(input) === target;
}

/* ------------------------------------------------------------------ */
/* Saralash                                                            */
/* ------------------------------------------------------------------ */

export type SortDir = 'asc' | 'desc';
export type SortValue = string | number | null | undefined;

const collator = new Intl.Collator('uz', { numeric: true, sensitivity: 'base' });

/**
 * Qatorlarni saralaydi — asl massivga TEGMAYDI.
 *
 * Bo'sh qiymatlar (null/undefined/'') yo'nalishdan qat'i nazar OXIRIDA:
 * "muddati yo'q" biznes teskari saralashda tepaga chiqib, ro'yxatni
 * to'sib qo'ymasligi kerak. Teng qiymatlarda asl tartib saqlanadi.
 */
export function sortRows<T>(rows: readonly T[], value: (row: T) => SortValue, dir: SortDir): T[] {
  const factor = dir === 'asc' ? 1 : -1;
  const isEmpty = (v: SortValue) => v === null || v === undefined || v === '';

  return rows
    .map((row, index) => ({ row, index, v: value(row) }))
    .sort((a, b) => {
      const ae = isEmpty(a.v);
      const be = isEmpty(b.v);
      if (ae || be) return ae === be ? a.index - b.index : ae ? 1 : -1;

      const cmp =
        typeof a.v === 'number' && typeof b.v === 'number'
          ? a.v - b.v
          : collator.compare(String(a.v), String(b.v));
      return cmp !== 0 ? cmp * factor : a.index - b.index;
    })
    .map((x) => x.row);
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

/* ------------------------------------------------------------------ */
/* Chart o'qi                                                          */
/* ------------------------------------------------------------------ */

/**
 * O'q uchun "yumaloq" bo'linmalar: 0 · 500 ming · 1 mln · 1,5 mln.
 *
 * Qadam 1 / 2 / 2,5 / 5 × 10ⁿ dan tanlanadi — 0 · 437 000 · 874 000
 * kabi o'qib bo'lmaydigan bo'linmalar chiqmaydi. Tepa qiymat eng katta
 * ma'lumotdan kichik bo'lmaydi (ustun o'qdan chiqib ketmaydi).
 *
 * Hamma qiymat 0 bo'lsa: bitta "0" chizig'i, shkala esa 1 — ustunlar
 * yo'q, lekin chart buzilmaydi.
 */
export function niceTicks(
  maxValue: number,
  target = 4,
  /** Sanaladigan narsa (biznes, to'lov soni) — kasr bo'linma bo'lmaydi. */
  integer = false,
): { max: number; ticks: number[] } {
  if (!Number.isFinite(maxValue) || maxValue <= 0) return { max: 1, ticks: [0] };

  const rough = maxValue / Math.max(1, target);
  const magnitude = 10 ** Math.floor(Math.log10(rough));
  const residual = rough / magnitude;
  const factor = residual <= 1 ? 1 : residual <= 2 ? 2 : residual <= 2.5 ? 2.5 : residual <= 5 ? 5 : 10;
  let step = factor * magnitude;
  // "2,5 ta biznes" bo'lmaydi: butun qiymatda qadam butun va >= 1.
  if (integer) step = Math.max(1, Math.ceil(step));
  const max = Math.ceil(maxValue / step - 1e-9) * step;

  const ticks: number[] = [];
  for (let v = 0; v <= max + step / 2; v += step) ticks.push(Number(v.toPrecision(12)));
  return { max, ticks };
}

/**
 * X o'qida qaysi yorliqlar ko'rsatiladi — ustma-ust tushmasligi uchun.
 *
 * Har `k`-chisi ko'rsatiladi, OXIRGIDAN hisoblab: eng yangi davr
 * (masalan, bugun) doim yorliqli bo'lsin.
 */
export function visibleLabelIndexes(count: number, maxLabels: number): number[] {
  if (count <= 0) return [];
  const k = Math.max(1, Math.ceil(count / Math.max(1, maxLabels)));
  const out: number[] = [];
  for (let i = count - 1; i >= 0; i -= k) out.unshift(i);
  return out;
}
