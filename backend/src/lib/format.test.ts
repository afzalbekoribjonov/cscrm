import assert from 'node:assert/strict';
import { test } from 'node:test';

import { groupDigits } from './format.js';

test('groupDigits: uchtalab ajratadi', () => {
  assert.equal(groupDigits(0), '0');
  assert.equal(groupDigits(950), '950');
  assert.equal(groupDigits(1000), '1 000');
  assert.equal(groupDigits(1250000), '1 250 000');
  assert.equal(groupDigits(-45000), '-45 000');
  assert.equal(groupDigits(1234.5), '1 234.5');
});
