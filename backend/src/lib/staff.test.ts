import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { staffUid } from './staff.js';

describe('staffUid', () => {
  it('kirish va o\'chirish bir xil UID ishlatadi — format o\'zgarmasligi kerak', () => {
    // Format o'zgarsa, ilgari kirgan xodimlarning sessiyasi o'chirishda
    // topilmay qoladi. Bu sinov o'zgarishni ongli qilishga majbur qiladi.
    assert.equal(staffUid('t_abc', 'e_1'), 'staff_t_abc_e_1');
  });
});
