import { describe, expect, it } from 'vitest';

import { formatPhone } from './format';

describe('formatPhone', () => {
  it('o\'zbek raqami guruhlanadi', () => {
    expect(formatPhone('998901234567')).toBe('+998 90 123 45 67');
  });

  it('kutilmagan raqam o\'zgarishsiz', () => {
    expect(formatPhone('12345')).toBe('12345');
  });

  it('bo\'sh', () => {
    expect(formatPhone(undefined)).toBe('');
  });
});
