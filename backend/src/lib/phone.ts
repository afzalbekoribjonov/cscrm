/**
 * Telefon raqamini kanonik "998XXXXXXXXX" ko'rinishiga keltiradi.
 *
 * Flutter tomonidagi `app/lib/utils/phone.dart` bilan AYNAN bir xil
 * ishlashi shart — aks holda ilova bir ko'rinishda saqlab, backend
 * boshqasini qidiradi va xodim kira olmaydi.
 */
export function digitsOnly(input: string): string {
  return input.replace(/[^0-9]/g, '');
}

export function lastDigits(input: string, n: number): string {
  const d = digitsOnly(input);
  return d.length <= n ? d : d.slice(d.length - n);
}

export function normalizePhone(input: string): string {
  const d = digitsOnly(input);
  if (d.length === 0) return '';
  return `998${lastDigits(d, 9)}`;
}

export function isCompletePhone(input: string): boolean {
  return normalizePhone(input).length === 12;
}
