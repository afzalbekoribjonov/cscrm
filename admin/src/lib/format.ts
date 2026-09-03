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
