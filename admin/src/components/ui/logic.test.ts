import { describe, expect, it } from 'vitest';

import {
  compactNumber,
  cx,
  deltaOf,
  formatDelta,
  initials,
  matchesConfirmation,
  niceTicks,
  pageRange,
  paginate,
  sortRows,
  toneIndex,
  visibleLabelIndexes,
} from './logic';

const NBSP = ' ';

describe('cx', () => {
  it('bo\'sh qiymatlarni tashlab ketadi', () => {
    expect(cx('btn', false, undefined, 'btn--primary', null, '')).toBe('btn btn--primary');
  });
});

describe('pageRange', () => {
  it('kam sahifada hammasi ko\'rinadi', () => {
    expect(pageRange(2, 5)).toEqual([1, 2, 3, 4, 5]);
    expect(pageRange(1, 7)).toEqual([1, 2, 3, 4, 5, 6, 7]);
  });

  it('o\'rtada ikki tomonda … bo\'ladi', () => {
    expect(pageRange(6, 12)).toEqual([1, 'gap', 5, 6, 7, 'gap', 12]);
  });

  it('boshida faqat o\'ng tomonda …', () => {
    expect(pageRange(1, 12)).toEqual([1, 2, 'gap', 12]);
    expect(pageRange(3, 12)).toEqual([1, 2, 3, 4, 'gap', 12]);
  });

  it('bitta raqam uchun … qo\'yilmaydi — raqamning o\'zi', () => {
    // 4-sahifada chap tomonda faqat "2" tushib qoladi.
    expect(pageRange(4, 12)).toEqual([1, 2, 3, 4, 5, 'gap', 12]);
    expect(pageRange(9, 12)).toEqual([1, 'gap', 8, 9, 10, 11, 12]);
  });

  it('chegaradan chiqqan sahifa chegaraga keltiriladi', () => {
    expect(pageRange(99, 12).at(-2)).toBe(11);
    expect(pageRange(0, 3)).toEqual([1, 2, 3]);
  });

  it('sahifa yo\'q — bo\'sh', () => {
    expect(pageRange(1, 0)).toEqual([]);
  });

  it('har doim birinchi va oxirgi sahifa bor, takror yo\'q', () => {
    for (let total = 1; total <= 30; total++) {
      for (let p = 1; p <= total; p++) {
        const items = pageRange(p, total);
        const nums = items.filter((x): x is number => x !== 'gap');
        expect(nums[0]).toBe(1);
        expect(nums.at(-1)).toBe(total);
        expect(new Set(nums).size).toBe(nums.length);
        expect(nums).toContain(p);
      }
    }
  });
});

describe('paginate', () => {
  const items = Array.from({ length: 45 }, (_, i) => i + 1);

  it('birinchi sahifa', () => {
    const s = paginate(items, 1, 20);
    expect(s.rows).toHaveLength(20);
    expect([s.from, s.to, s.total, s.pageCount]).toEqual([1, 20, 45, 3]);
  });

  it('oxirgi to\'liq bo\'lmagan sahifa', () => {
    const s = paginate(items, 3, 20);
    expect(s.rows).toEqual([41, 42, 43, 44, 45]);
    expect([s.from, s.to]).toEqual([41, 45]);
  });

  it('filtrdan keyin yo\'q bo\'lib qolgan sahifa — oxirgisi beriladi, bo\'sh emas', () => {
    const s = paginate(items.slice(0, 5), 4, 20);
    expect(s.page).toBe(1);
    expect(s.rows).toHaveLength(5);
  });

  it('bo\'sh ro\'yxat', () => {
    const s = paginate([], 1, 20);
    expect([s.from, s.to, s.total, s.pageCount]).toEqual([0, 0, 0, 1]);
  });
});

describe('compactNumber', () => {
  it('10 000 gacha to\'liq', () => {
    expect(compactNumber(0)).toBe('0');
    expect(compactNumber(9800)).toBe(`9${NBSP}800`);
  });

  it('minglar, millionlar, milliardlar', () => {
    expect(compactNumber(12_900)).toBe(`12,9${NBSP}ming`);
    expect(compactNumber(199_000)).toBe(`199${NBSP}ming`);
    expect(compactNumber(1_790_000)).toBe(`1,8${NBSP}mln`);
    expect(compactNumber(2_500_000_000)).toBe(`2,5${NBSP}mlrd`);
  });

  it('manfiy son haqiqiy minus bilan', () => {
    expect(compactNumber(-15_000)).toBe(`−15${NBSP}ming`);
  });

  it('noto\'g\'ri qiymat', () => {
    expect(compactNumber(Number.NaN)).toBe('—');
  });
});

describe('deltaOf / formatDelta', () => {
  it('o\'sish va pasayish', () => {
    expect(deltaOf(120, 100)).toEqual({ pct: 20, direction: 'up' });
    expect(deltaOf(80, 100)).toEqual({ pct: -20, direction: 'down' });
    expect(deltaOf(100, 100)).toEqual({ pct: 0, direction: 'flat' });
  });

  it('oldingi davr 0 — foiz yo\'q, lekin yo\'nalish bor', () => {
    expect(deltaOf(5, 0)).toEqual({ pct: null, direction: 'up' });
    expect(deltaOf(0, 0)).toEqual({ pct: null, direction: 'flat' });
  });

  it('manfiy asosda yo\'nalish to\'g\'ri', () => {
    // -100 dan -50 ga — yaxshilanish, ya'ni o'sish.
    expect(deltaOf(-50, -100)).toEqual({ pct: 50, direction: 'up' });
  });

  it('formatlash', () => {
    expect(formatDelta(20)).toBe('+20%');
    expect(formatDelta(-8.46)).toBe('−8,5%');
    expect(formatDelta(0.04)).toBe('0%');
    expect(formatDelta(125.6)).toBe('+126%');
  });
});

describe('initials', () => {
  it('ikki so\'zdan ikki harf', () => {
    expect(initials('Gilam Yuvish Markazi')).toBe('GY');
    expect(initials('  ali  ')).toBe('A');
  });

  it('o\'zbekcha harflar', () => {
    expect(initials("o'lmas shoh")).toBe('OS');
  });

  it('bo\'sh nom', () => {
    expect(initials('   ')).toBe('?');
  });
});

describe('toneIndex', () => {
  it('bir xil kalit — bir xil natija, chegarada', () => {
    const a = toneIndex('t_abc', 6);
    expect(a).toBe(toneIndex('t_abc', 6));
    expect(a).toBeGreaterThanOrEqual(0);
    expect(a).toBeLessThan(6);
  });
});

describe('matchesConfirmation — xavfli amalni tasdiqlash', () => {
  it('aniq mos', () => {
    expect(matchesConfirmation('Toza Gilam', 'Toza Gilam')).toBe(true);
  });

  it('katta-kichik harf va bo\'shliqlar hisobga olinmaydi', () => {
    expect(matchesConfirmation('  toza   gilam ', 'Toza Gilam')).toBe(true);
  });

  it('tutuq belgisining boshqa ko\'rinishi ham mos', () => {
    for (const ap of ['‘', '’', 'ʻ', 'ʼ', '`']) {
      expect(matchesConfirmation(`G${ap}olib`, "G'olib")).toBe(true);
    }
  });

  it('boshqa nom mos emas', () => {
    expect(matchesConfirmation('Toza Gila', 'Toza Gilam')).toBe(false);
    expect(matchesConfirmation('Toza Gilam 2', 'Toza Gilam')).toBe(false);
  });

  it('bo\'sh kutilgan matn hech qachon mos emas', () => {
    expect(matchesConfirmation('', '')).toBe(false);
    expect(matchesConfirmation('   ', '  ')).toBe(false);
  });
});

describe('sortRows', () => {
  type Row = { name: string; days: number | null };
  const rows: Row[] = [
    { name: 'Beta', days: 5 },
    { name: 'alfa', days: null },
    { name: "G'olib", days: -2 },
    { name: 'Alfa 10', days: 5 },
    { name: 'Alfa 2', days: 30 },
  ];

  it('raqam bo\'yicha, bo\'shlari oxirida', () => {
    expect(sortRows(rows, (r) => r.days, 'asc').map((r) => r.days)).toEqual([-2, 5, 5, 30, null]);
  });

  it('teskari yo\'nalishda ham bo\'shlari OXIRIDA', () => {
    expect(sortRows(rows, (r) => r.days, 'desc').map((r) => r.days)).toEqual([30, 5, 5, -2, null]);
  });

  it('teng qiymatlarda asl tartib saqlanadi', () => {
    const fives = sortRows(rows, (r) => r.days, 'asc').filter((r) => r.days === 5);
    expect(fives.map((r) => r.name)).toEqual(['Beta', 'Alfa 10']);
  });

  it('matn: katta-kichik harfsiz va raqamlarni son sifatida', () => {
    expect(sortRows(rows, (r) => r.name, 'asc').map((r) => r.name)).toEqual([
      'alfa',
      'Alfa 2',
      'Alfa 10',
      'Beta',
      "G'olib",
    ]);
  });

  it('asl massiv o\'zgarmaydi', () => {
    const copy = [...rows];
    sortRows(rows, (r) => r.name, 'desc');
    expect(rows).toEqual(copy);
  });
});

describe('niceTicks', () => {
  it('pul miqdorlari', () => {
    expect(niceTicks(1_790_000)).toEqual({
      max: 2_000_000,
      ticks: [0, 500_000, 1_000_000, 1_500_000, 2_000_000],
    });
  });

  it('kichik sonlar', () => {
    expect(niceTicks(7)).toEqual({ max: 8, ticks: [0, 2, 4, 6, 8] });
    expect(niceTicks(1)).toEqual({ max: 1, ticks: [0, 0.25, 0.5, 0.75, 1] });
  });

  it('tepa qiymat hech qachon ma\'lumotdan kichik emas', () => {
    for (const v of [3, 10, 99, 101, 2_345, 999_999, 1_000_001, 73_450_000]) {
      const { max, ticks } = niceTicks(v);
      expect(max).toBeGreaterThanOrEqual(v);
      expect(ticks[0]).toBe(0);
      expect(ticks.at(-1)).toBe(max);
      expect(ticks.length).toBeLessThanOrEqual(7);
    }
  });

  it('hamma qiymat 0 — chart buzilmaydi', () => {
    expect(niceTicks(0)).toEqual({ max: 1, ticks: [0] });
    expect(niceTicks(Number.NaN)).toEqual({ max: 1, ticks: [0] });
  });
});

describe('visibleLabelIndexes', () => {
  it('sig\'sa — hammasi', () => {
    expect(visibleLabelIndexes(5, 10)).toEqual([0, 1, 2, 3, 4]);
  });

  it('sig\'masa — har k-chisi, oxirgisi doim bor', () => {
    const idx = visibleLabelIndexes(30, 7);
    expect(idx.at(-1)).toBe(29);
    expect(idx.length).toBeLessThanOrEqual(7);
  });

  it('bo\'sh', () => {
    expect(visibleLabelIndexes(0, 5)).toEqual([]);
  });
});

describe('niceTicks — butun sonlar', () => {
  it('sanaladigan narsada kasr bo\'linma yo\'q', () => {
    expect(niceTicks(1, 4, true)).toEqual({ max: 1, ticks: [0, 1] });
    expect(niceTicks(3, 4, true)).toEqual({ max: 3, ticks: [0, 1, 2, 3] });
    const { ticks } = niceTicks(7, 4, true);
    expect(ticks.every(Number.isInteger)).toBe(true);
  });

  it('katta sonlarda oddiy rejim bilan bir xil', () => {
    expect(niceTicks(1_790_000, 4, true)).toEqual(niceTicks(1_790_000));
  });
});
