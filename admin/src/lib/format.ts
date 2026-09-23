/**
 * Raqam va sana formatlari — websayt bo'ylab BITTA joyda.
 *
 * Nega o'z formatimiz: `Intl.NumberFormat('uz-UZ')` ko'p brauzerlarda
 * o'zbek lokali ma'lumotisiz qoladi va ingliz formatiga tushadi —
 * "199,000" deb chiqadi. O'zbekcha yozuvda ajratgich bo'sh joy.
 *
 * Ajratgich sifatida UZILMAYDIGAN bo'sh joy ishlatiladi, aks holda
 * "199" bilan "000" qatorning ikki chetiga bo'linib ketishi mumkin.
 */

const GROUP = ' ';

const grouped = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

export function formatNumber(n: number): string {
  return grouped.format(n).replace(/,/g, GROUP);
}

export function formatSom(n: number): string {
  return `${formatNumber(n)} so'm`;
}

/**
 * Telefon: "998901234567" → "+998 90 123 45 67".
 * Kutilmagan uzunlikdagi raqam o'zgarishsiz qaytadi — noto'g'ri
 * guruhlab, chalg'itgandan ko'ra shunday qolgani yaxshi.
 */
export function formatPhone(raw: string | null | undefined): string {
  if (!raw) return '';
  const d = raw.replace(/\D/g, '');
  if (d.length === 12 && d.startsWith('998')) {
    return `+998 ${d.slice(3, 5)} ${d.slice(5, 8)} ${d.slice(8, 10)} ${d.slice(10)}`;
  }
  return raw;
}
