import { useSyncExternalStore } from 'react';

/**
 * Kun/tun rejimi.
 *
 * STANDART — KUN REJIMI, operatsion tizimdan QAT'IY NAZAR.
 *
 * Ilgari sayt faqat `prefers-color-scheme` ga ergashardi: kompyuteri tun
 * rejimida turgan odam saytni hech qachon kunduzgi ko'rinishda ko'rmasdi
 * va uni o'zgartira ham olmasdi. Endi tanlov foydalanuvchida: u
 * `localStorage` da saqlanadi va keyingi tashrifda tiklanadi.
 *
 * Boshlang'ich qiymatni `index.html` dagi kichik skript qo'yadi —
 * React yuklanguncha. Aks holda sahifa avval oq, keyin qora bo'lib
 * "chaqnardi".
 */
export type Theme = 'light' | 'dark';

const KEY = 'cscrm-theme';

/** Tinglovchilar — bir nechta tugma bir vaqtda sinxron turishi uchun. */
const listeners = new Set<() => void>();

function current(): Theme {
  if (typeof document === 'undefined') return 'light';
  return document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
}

function subscribe(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function setTheme(theme: Theme): void {
  document.documentElement.dataset.theme = theme;
  try {
    localStorage.setItem(KEY, theme);
  } catch {
    // Maxfiy oynada localStorage taqiqlangan bo'lishi mumkin — tanlov
    // shu sessiyada baribir ishlaydi, faqat eslab qolinmaydi.
  }
  listeners.forEach((fn) => fn());
}

/**
 * Joriy rejim va uni almashtirish.
 *
 * `useSyncExternalStore` — chunki haqiqiy manba React holati emas,
 * `<html data-theme>` atributi: uni `index.html` dagi skript ham
 * qo'yadi. Shu tufayli server/klient mos kelmasligi ham bo'lmaydi.
 */
export function useTheme(): { theme: Theme; toggle: () => void } {
  const theme = useSyncExternalStore<Theme>(subscribe, current, () => 'light');
  return {
    theme,
    toggle: () => setTheme(theme === 'dark' ? 'light' : 'dark'),
  };
}
