/**
 * Obuna/litsenziya domeni.
 *
 * Muhim qoida: MUDDAT SERVERDA hisoblanadi. Qurilma soatini o'zgartirib
 * bloklashni chetlab o'tib bo'lmasligi uchun ilova hech qachon o'z
 * `DateTime.now()` iga tayanib qaror qabul qilmaydi - u serverdan
 * imzolangan javob oladi.
 */

export type PlanKind = 'trial' | 'subscription' | 'lifetime';

export interface Plan {
  id: string;
  name: string;
  months: number | null;
  days?: number;
  price: number;
  kind: PlanKind;
  description: string;
  highlight: boolean;
  lifetimeAnnualFeeUsd?: number;
}

/** Litsenziyaning joriy holati - ilova shu qiymatga qarab ekran ko'rsatadi. */
export type LicenseState =
  /** Faol - hech qanday cheklov yo'q. */
  | 'active'
  /** Faol, lekin muddat tugashiga oz qoldi - eslatma chiqadi. */
  | 'expiring'
  /** Muddat tugagan, lekin grace davri davom etmoqda - ishlaydi + ogohlantirish. */
  | 'grace'
  /** Muddat tugagan - ilova bloklanadi, to'lov ekrani ochiladi. */
  | 'expired'
  /** Bir umrlik, lekin yillik baza to'lovi kechikkan. */
  | 'lifetime_fee_due'
  /** Tenant to'xtatilgan (qo'lda bloklangan). */
  | 'suspended';

export interface License {
  tenantId: string;
  planId: string;
  kind: PlanKind;
  /** Obuna boshlangan vaqt (ms, server). */
  startedAt: number;
  /** Muddat tugash vaqti (ms, server). Bir umrlik uchun `null`. */
  expiresAt: number | null;
  /** Bir umrlik uchun keyingi yillik baza to'lovi sanasi (ms). */
  nextAnnualFeeAt?: number | null;
  suspended?: boolean;
  suspendedReason?: string | null;
}

/**
 * Ilovaga qaytariladigan, imzolangan javob.
 *
 * `signature` - `payload` ning HMAC-SHA256 imzosi. Ilova uni tekshiradi,
 * shuning uchun javobni yo'lda o'zgartirib "muddat cheksiz" deb aytib
 * bo'lmaydi. `checkedAt` + `ttlSeconds` esa oflayn ishlash oynasini
 * belgilaydi: shu muddat ichida ilova internetsiz ham ishlayveradi.
 */
export interface SignedLicenseStatus {
  payload: LicenseStatusPayload;
  signature: string;
}

export interface LicenseStatusPayload {
  tenantId: string;
  state: LicenseState;
  planId: string;
  kind: PlanKind;
  expiresAt: number | null;
  /** Muddat tugashiga necha kun qolgani (manfiy - necha kun o'tgani). */
  daysLeft: number | null;
  /** Server vaqti (ms) - ilova qurilma soatiga emas, shunga tayanadi. */
  checkedAt: number;
  /** Shu javob qancha vaqt yaroqli (soniya) - oflayn ishlash oynasi. */
  ttlSeconds: number;
  /** Foydalanuvchiga ko'rsatiladigan tayyor xabar (o'zbekcha). */
  message: string;
  /** `true` bo'lsa ilova ish ekranlarini bloklaydi. */
  blocked: boolean;
}
