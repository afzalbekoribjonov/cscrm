/**
 * To'lov kartalari.
 *
 * Karta turi RAQAMDAN aniqlanadi, sozlamada qo'lda yozilmaydi. Sabab:
 * O'zbekistonda BIN'lar chalkashtirilishi juda oson (9860 — Humo, 8600
 * va 5614 — Uzcard), qo'lda yozilsa esa noto'g'ri yorliq mijozni
 * adashtiradi. Raqamning o'zi yolg'on gapirmaydi.
 */

export interface PaymentCard {
  /** Ko'rsatish uchun bo'sh joylar bilan: "9860 1234 5678 9012". */
  number: string;
  /** "Humo" · "Uzcard" · aniqlanmasa bo'sh satr. */
  type: string;
}

const BINS: ReadonlyArray<readonly [string, string]> = [
  ['9860', 'Humo'],
  ['8600', 'Uzcard'],
  ['5614', 'Uzcard'],
];

/** Faqat raqamlarni qoldiradi. */
export function digitsOnly(input: string): string {
  return input.replace(/\D/g, '');
}

/** Karta turini BIN (dastlabki 4 raqam) bo'yicha aniqlaydi. */
export function cardType(number: string): string {
  const digits = digitsOnly(number);
  for (const [bin, name] of BINS) {
    if (digits.startsWith(bin)) return name;
  }
  return '';
}

/** "9860123456789012" -> "9860 1234 5678 9012". */
export function formatCardNumber(number: string): string {
  const digits = digitsOnly(number);
  return digits.replace(/(.{4})(?=.)/g, '$1 ');
}

/**
 * Sozlamadagi vergul bilan ajratilgan ro'yxatni kartalarga aylantiradi.
 *
 * Yaroqsiz (16 raqam emas) yozuvlar TASHLAB YUBORILADI — yarim yozilgan
 * raqamni mijozga ko'rsatgandan ko'ra ko'rsatmagan yaxshi, chunki u
 * pulni boshqa hisobga o'tkazib yuborishi mumkin.
 */
export function parseCards(raw: string): PaymentCard[] {
  return raw
    .split(',')
    .map((part) => digitsOnly(part))
    .filter((digits) => digits.length === 16)
    .map((digits) => ({
      number: formatCardNumber(digits),
      type: cardType(digits),
    }));
}
