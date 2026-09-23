import { describe, expect, it } from 'vitest';

import type { LicenseStatus } from '@/lib/admin-types';

import { cleanLogin } from './dialogs';
import { purgeText, tenantState, termText } from './status';

const DAY = 86_400_000;
const NOW = Date.UTC(2026, 8, 23, 9);

function status(patch: Partial<LicenseStatus>): LicenseStatus {
  return {
    tenantId: 't1',
    state: 'active',
    planId: 'm1',
    kind: 'subscription',
    expiresAt: NOW + 10 * DAY,
    daysLeft: 10,
    checkedAt: NOW,
    message: '',
    blocked: false,
    ...patch,
  };
}

describe('tenantState', () => {
  it('arxiv har qanday holatdan ustun', () => {
    const archive = { archivedAt: NOW, purgeAfter: NOW + 30 * DAY, reason: 'x' };
    expect(tenantState({ status: status({ state: 'expired', blocked: true }), archive }).label).toBe('Arxivda');
  });

  it('faol sinov — "Sinovda", pullik faol — "Faol"', () => {
    expect(tenantState({ status: status({ kind: 'trial' }), archive: null })).toEqual({ label: 'Sinovda', tone: 'info' });
    expect(tenantState({ status: status({}), archive: null }).label).toBe('Faol');
  });

  it('muddati tugagan sinov — bloklangan', () => {
    expect(tenantState({ status: status({ kind: 'trial', state: 'expired', blocked: true }), archive: null }).label).toBe(
      'Bloklangan',
    );
  });
});

describe('termText', () => {
  it('qolgan va o\'tgan kunlar', () => {
    expect(termText(status({ daysLeft: 10 })).sub).toBe('10 kun qoldi');
    expect(termText(status({ daysLeft: -3 })).sub).toBe('3 kun o\'tdi');
  });

  it('bir umrlik — cheksiz', () => {
    expect(termText(status({ kind: 'lifetime', expiresAt: null, daysLeft: 120 }))).toEqual({
      main: 'Cheksiz',
      sub: 'yillik to\'lovgacha 120 kun',
    });
  });

  it('muddat yo\'q', () => {
    expect(termText(status({ expiresAt: null, daysLeft: null }))).toEqual({ main: '—' });
  });
});

describe('purgeText', () => {
  it('necha kundan keyin o\'chiriladi', () => {
    expect(purgeText({ archivedAt: NOW, purgeAfter: NOW + 12 * DAY, reason: '' }, NOW)).toBe(
      '12 kundan keyin butunlay o\'chiriladi',
    );
    expect(purgeText({ archivedAt: NOW, purgeAfter: NOW - DAY, reason: '' }, NOW)).toBe('bugun butunlay o\'chiriladi');
  });
});

describe('cleanLogin — server qoidasi bilan bir xil', () => {
  it('kichik harf, ruxsat etilmagan belgilar olib tashlanadi', () => {
    expect(cleanLogin('  Oybek.Market ')).toBe('oybekmarket');
    expect(cleanLogin('shop_01-uz')).toBe('shop_01-uz');
    expect(cleanLogin('Дўкон')).toBe('');
  });
});
