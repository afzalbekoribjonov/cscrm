/**
 * Sanalar — TOSHKENT vaqti bo'yicha (UTC+5, yozgi vaqt yo'q).
 *
 * Nega o'zimiz: `Intl.DateTimeFormat('uz')` ko'p brauzerlarda o'zbekcha
 * ma'lumotsiz keladi va "September" yoki "M09" chiqaradi. Oy nomlari
 * kam va o'zgarmas — ularni shu yerda saqlash ishonchliroq.
 *
 * Vaqt zonasi ham shu yerda hal qilinadi: admin kompyuteri qaysi
 * zonada bo'lmasin, "bugun" Toshkent bo'yicha — server ham shunday
 * hisoblaydi (backend/src/services/overview.ts).
 */

const TZ_OFFSET = 5 * 3_600_000;
const DAY = 86_400_000;

const MONTHS = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];
const MONTHS_SHORT = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];

function parts(ms: number) {
  const d = new Date(ms + TZ_OFFSET);
  return {
    year: d.getUTCFullYear(),
    month: d.getUTCMonth(),
    day: d.getUTCDate(),
    hour: d.getUTCHours(),
    minute: d.getUTCMinutes(),
  };
}

const pad = (n: number) => String(n).padStart(2, '0');

/** "23-sentabr" (joriy yilda) yoki "23-sentabr 2025". */
export function formatDay(ms: number, now = Date.now()): string {
  const p = parts(ms);
  const base = `${p.day}-${MONTHS[p.month]}`;
  return p.year === parts(now).year ? base : `${base} ${p.year}`;
}

/** "Sentabr 2026". */
export function formatMonth(ms: number): string {
  const p = parts(ms);
  const name = MONTHS[p.month]!;
  return `${name[0]!.toUpperCase()}${name.slice(1)} ${p.year}`;
}

/** Oy qisqa nomi: "sen". */
export function monthShort(ms: number): string {
  return MONTHS_SHORT[parts(ms).month]!;
}

/** Kun raqami: "23". */
export function dayOfMonth(ms: number): number {
  return parts(ms).day;
}

/** "14:05". */
export function formatTime(ms: number): string {
  const p = parts(ms);
  return `${pad(p.hour)}:${pad(p.minute)}`;
}

/**
 * Nisbiy vaqt: "hozirgina", "15 daqiqa oldin", "bugun 14:05",
 * "kecha 09:12", "3 kun oldin", keyin — sana.
 */
export function formatRelative(ms: number, now = Date.now()): string {
  const diff = now - ms;
  if (diff < 60_000) return 'hozirgina';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} daqiqa oldin`;

  const dayOf = (t: number) => Math.floor((t + TZ_OFFSET) / DAY);
  const days = dayOf(now) - dayOf(ms);
  if (days === 0) return `bugun ${formatTime(ms)}`;
  if (days === 1) return `kecha ${formatTime(ms)}`;
  if (days < 7) return `${days} kun oldin`;
  return formatDay(ms, now);
}
