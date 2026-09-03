import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { cardType, formatCardNumber, parseCards } from './card.js';

describe('karta turi BIN bo\'yicha aniqlanadi', () => {
  it('9860 — Humo', () => {
    assert.equal(cardType('9860 1234 5678 9012'), 'Humo');
  });

  it('8600 va 5614 — Uzcard', () => {
    assert.equal(cardType('8600 1234 5678 9012'), 'Uzcard');
    assert.equal(cardType('5614 1234 5678 9012'), 'Uzcard');
  });

  it('notanish BIN bo\'sh qaytaradi', () => {
    assert.equal(cardType('4111 1111 1111 1111'), '');
  });

  it('bo\'sh joylarsiz ham ishlaydi', () => {
    assert.equal(cardType('9860123456789012'), 'Humo');
  });
});

describe('raqamni ko\'rsatish', () => {
  it('to\'rttalab ajratadi', () => {
    assert.equal(formatCardNumber('9860123456789012'), '9860 1234 5678 9012');
  });

  it('allaqachon ajratilgan raqamni buzmaydi', () => {
    assert.equal(
      formatCardNumber('9860 1234 5678 9012'),
      '9860 1234 5678 9012',
    );
  });
});

describe('sozlamadagi ro\'yxatni o\'qish', () => {
  it('bir nechta kartani turi bilan qaytaradi', () => {
    const cards = parseCards('9860 1234 5678 9012, 5614 1234 5678 9012');

    assert.equal(cards.length, 2);
    assert.deepEqual(cards[0], {
      number: '9860 1234 5678 9012',
      type: 'Humo',
    });
    assert.deepEqual(cards[1], {
      number: '5614 1234 5678 9012',
      type: 'Uzcard',
    });
  });

  it('yarim yozilgan raqamni KO\'RSATMAYDI', () => {
    // Noto'g'ri raqamni ko'rsatish - mijoz pulni begonaga yuborishi
    // demak. Shubhali yozuv butunlay tashlanadi.
    const cards = parseCards('9860 1234 5678 9012, 5614 1234');

    assert.equal(cards.length, 1);
    assert.equal(cards[0]?.type, 'Humo');
  });

  it('bo\'sh sozlamada bo\'sh ro\'yxat', () => {
    assert.deepEqual(parseCards(''), []);
    assert.deepEqual(parseCards('   '), []);
  });
});
