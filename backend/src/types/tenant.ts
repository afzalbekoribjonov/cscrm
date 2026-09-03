/** Bitta biznes (ijarachi). Barcha ma'lumot `/tenants/{id}/` ostida turadi. */
export interface TenantProfile {
  name: string;
  phone?: string;
  address?: string;
  ownerUid: string;
  createdAt: number;
}

/** Foydalanuvchi roli — Firebase custom claim sifatida tokenga yoziladi. */
export type Role = 'owner' | 'staff';

/**
 * Token ichidagi da'volar (claims).
 *
 * Bularni FAQAT Admin SDK qo'ya oladi, shuning uchun ilova tomondan
 * o'zgartirib bo'lmaydi. Database qoidalari aynan shularni tekshiradi.
 */
export interface AppClaims {
  tenantId: string;
  role: Role;
  /** Xodim uchun — uning `/employees/{id}` kaliti. Egada bo'lmaydi. */
  employeeId?: string;
}

/** Xodim yozuvi (backend ko'rinishi — `pinHash` mijozga hech qachon ketmaydi). */
export interface EmployeeRecord {
  firstName: string;
  lastName: string;
  phone: string;
  pinHash: string;
  active: boolean;
  createdAt: number;
  createdBy: string;
  sections?: Record<string, boolean>;
  permissions?: Record<string, boolean>;

  /** Ketma-ket noto'g'ri PIN urinishlari soni. */
  failedAttempts?: number;
  /** Shu vaqtgacha kirish bloklangan (ms). */
  lockedUntil?: number;
}

/**
 * Telefon → tenant indeksi.
 *
 * Xodim faqat telefon + PIN kiritadi (biznes kodini eslab qolishi shart
 * emas). Backend shu indeks orqali qaysi bizneslarga tegishli ekanini
 * topadi. Indeks mijozga BERK — uni faqat Admin SDK o'qiydi, aks holda
 * raqamlar ro'yxatini yig'ib olish mumkin bo'lardi.
 */
export interface PhoneIndexEntry {
  tenantId: string;
  employeeId: string;
  tenantName: string;
}
