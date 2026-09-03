import bcrypt from 'bcryptjs';

/**
 * PIN-kod hash'lash va tekshirish.
 *
 * NEGA bcrypt (eski SHA-256 emas): PIN 4 xonali bo'lsa atigi 10 000 ta
 * variant bor. Tuzsiz SHA-256 bilan bularning hammasi bir soniyada
 * hisoblab chiqiladi — ya'ni hash sizib chiqsa, PIN darhol ochiladi.
 * bcrypt har bir tekshiruvni ataylab sekinlashtiradi va har bir hash'ga
 * tasodifiy tuz (salt) qo'shadi.
 *
 * Lekin asosiy himoya baribir shu: **hash hech qachon qurilmaga
 * yuborilmaydi**. Tekshiruv faqat shu yerda, serverda bajariladi.
 */

/**
 * bcrypt "cost" — 10 taxminan 60-100 ms beradi. Buni oshirish xavfsizlikni
 * kuchaytiradi, lekin kirishni sekinlashtiradi; 10 shu vazifa uchun
 * muvozanatli tanlov.
 */
const COST = 10;

export const PIN_MIN_LENGTH = 4;
export const PIN_MAX_LENGTH = 8;

/** Ketma-ket necha marta xato qilinsa hisob bloklanadi. */
export const MAX_FAILED_ATTEMPTS = 5;

/** Blok muddati (ms). */
export const LOCKOUT_MS = 15 * 60 * 1000;

export function isValidPin(pin: string): boolean {
  return (
    pin.length >= PIN_MIN_LENGTH &&
    pin.length <= PIN_MAX_LENGTH &&
    /^\d+$/.test(pin)
  );
}

export function hashPin(pin: string): Promise<string> {
  return bcrypt.hash(pin, COST);
}

/**
 * PIN'ni tekshiradi.
 *
 * `hash` bo'sh yoki buzilgan bo'lsa ham bcrypt'ni CHAQIRAMIZ (soxta hash
 * bilan) — shunda "xodim yo'q" va "PIN xato" holatlari bir xil vaqt
 * oladi. Aks holda javob tezligiga qarab qaysi telefon ro'yxatda borligini
 * aniqlab olish mumkin bo'lardi (timing attack).
 */
const DUMMY_HASH = '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy';

export async function verifyPin(pin: string, hash: string | undefined): Promise<boolean> {
  if (!hash) {
    await bcrypt.compare(pin, DUMMY_HASH);
    return false;
  }
  return bcrypt.compare(pin, hash);
}
