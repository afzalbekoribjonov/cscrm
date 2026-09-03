import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { normalizePhone } from '../lib/phone.js';
import { hashPin, isValidPin, verifyPin } from './pin.js';

describe('isValidPin', () => {
  it('4-8 xonali raqamni qabul qiladi', () => {
    assert.equal(isValidPin('1234'), true);
    assert.equal(isValidPin('12345678'), true);
  });

  it('qisqa, uzun yoki raqam bo\'lmagan PIN\'ni rad etadi', () => {
    assert.equal(isValidPin('123'), false);
    assert.equal(isValidPin('123456789'), false);
    assert.equal(isValidPin('12a4'), false);
    assert.equal(isValidPin(''), false);
  });
});

describe('hashPin / verifyPin', () => {
  it('to\'g\'ri PIN tasdiqlanadi', async () => {
    const hash = await hashPin('4821');
    assert.equal(await verifyPin('4821', hash), true);
  });

  it('noto\'g\'ri PIN rad etiladi', async () => {
    const hash = await hashPin('4821');
    assert.equal(await verifyPin('4822', hash), false);
  });

  it('bir xil PIN har safar BOSHQA hash beradi (tuz ishlaydi)', async () => {
    const a = await hashPin('1111');
    const b = await hashPin('1111');
    assert.notEqual(a, b, 'tuzsiz hash lug\'at hujumiga ochiq bo\'lardi');
    // Ikkalasi ham baribir to'g'ri tekshiriladi.
    assert.equal(await verifyPin('1111', a), true);
    assert.equal(await verifyPin('1111', b), true);
  });

  it('hash yo\'q bo\'lsa yiqilmaydi, false qaytaradi', async () => {
    assert.equal(await verifyPin('1234', undefined), false);
  });
});

describe('normalizePhone — Dart tomoni bilan bir xil bo\'lishi shart', () => {
  it('har xil formatni bir xil natijaga keltiradi', () => {
    const expected = '998901234567';
    assert.equal(normalizePhone('+998 90 123 45 67'), expected);
    assert.equal(normalizePhone('998901234567'), expected);
    assert.equal(normalizePhone('901234567'), expected);
    assert.equal(normalizePhone('+998901234567'), expected);
    assert.equal(normalizePhone('90-123-45-67'), expected);
  });

  it('bo\'sh kiritmada bo\'sh qaytaradi', () => {
    assert.equal(normalizePhone(''), '');
    assert.equal(normalizePhone('   '), '');
  });
});
