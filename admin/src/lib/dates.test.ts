import { describe, expect, it } from 'vitest';

import { dayOfMonth, formatDay, formatMonth, formatRelative, formatTime, monthShort } from './dates';

const HOUR = 3_600_000;
/** Toshkent vaqti bo'yicha sana → UTC ms. */
const tash = (y: number, m: number, d: number, h = 0, min = 0) => Date.UTC(y, m - 1, d, h, min) - 5 * HOUR;

const NOW = tash(2026, 9, 23, 14, 0);

describe('Toshkent vaqti', () => {
  it('UTC 19:30 — Toshkentda ertangi kun, 00:30', () => {
    const t = Date.UTC(2026, 8, 22, 19, 30);
    expect(dayOfMonth(t)).toBe(23);
    expect(formatTime(t)).toBe('00:30');
  });
});

describe('formatDay / formatMonth', () => {
  it('joriy yilda yilsiz', () => {
    expect(formatDay(tash(2026, 9, 23), NOW)).toBe('23-sentabr');
  });

  it('boshqa yilda yil bilan', () => {
    expect(formatDay(tash(2025, 12, 31), NOW)).toBe('31-dekabr 2025');
  });

  it('oy', () => {
    expect(formatMonth(tash(2026, 1, 1))).toBe('Yanvar 2026');
    expect(monthShort(tash(2026, 7, 1))).toBe('iyl');
  });
});

describe('formatRelative', () => {
  it('yaqin vaqtlar', () => {
    expect(formatRelative(NOW - 20_000, NOW)).toBe('hozirgina');
    expect(formatRelative(NOW - 15 * 60_000, NOW)).toBe('15 daqiqa oldin');
  });

  it('bugun va kecha — Toshkent kuni bo\'yicha', () => {
    expect(formatRelative(tash(2026, 9, 23, 9, 5), NOW)).toBe('bugun 09:05');
    expect(formatRelative(tash(2026, 9, 22, 23, 50), NOW)).toBe('kecha 23:50');
  });

  it('bir hafta ichida — kun, undan keyin — sana', () => {
    expect(formatRelative(tash(2026, 9, 20, 10), NOW)).toBe('3 kun oldin');
    expect(formatRelative(tash(2026, 9, 1, 10), NOW)).toBe('1-sentabr');
  });
});
