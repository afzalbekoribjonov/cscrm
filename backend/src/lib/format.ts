/**
 * Summani uchtalab ajratadi: 1250000 → "1 250 000".
 *
 * `toLocaleString` ATAYLAB ishlatilmaydi: natija serverdagi ICU
 * ma'lumotiga bog'liq (ba'zida vergul, ba'zida bo'linmas bo'shliq).
 * Jurnal matni sayt bilan bir xil ko'rinishi kerak.
 */
export function groupDigits(n: number): string {
  const sign = n < 0 ? '-' : '';
  const [int = '0', frac] = Math.abs(n).toString().split('.');
  const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${sign}${grouped}${frac ? `.${frac}` : ''}`;
}
