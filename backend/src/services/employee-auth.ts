import { db, auth } from '../lib/firebase.js';
import { normalizePhone } from '../lib/phone.js';
import { ApiError } from '../middleware/error.js';
import type {
  AppClaims,
  EmployeeRecord,
  PhoneIndexEntry,
} from '../types/tenant.js';
import {
  LOCKOUT_MS,
  MAX_FAILED_ATTEMPTS,
  verifyPin,
} from './pin.js';

/**
 * Xodim kirishi — butun tekshiruv SHU YERDA bajariladi.
 *
 * Eski ilovada bu mijoz tomonda edi: qurilma barcha xodimlarni PIN
 * hash'lari bilan yuklab olib, o'zi solishtirardi. Endi qurilmaga faqat
 * natija (token) qaytadi, hash esa serverdan chiqmaydi.
 */

/** Telefon raqamiga bog'langan barcha bizneslar. */
export async function findTenantsForPhone(
  phone: string,
): Promise<PhoneIndexEntry[]> {
  const normalized = normalizePhone(phone);
  if (!normalized) return [];
  const snap = await db().ref(`employee_phone_index/${normalized}`).get();
  if (!snap.exists()) return [];
  const raw = snap.val() as Record<string, PhoneIndexEntry>;
  return Object.values(raw);
}

interface LoginResult {
  customToken: string;
  claims: AppClaims;
  employee: {
    id: string;
    firstName: string;
    lastName: string;
    sections: string[];
    permissions: string[];
  };
  tenantName: string;
}

/**
 * Telefon + PIN ni tekshirib, Firebase custom token qaytaradi.
 *
 * Token ichida `tenantId`, `role` va `employeeId` da'volari bo'ladi —
 * Database qoidalari aynan shularni tekshiradi. Da'volarni faqat Admin SDK
 * yoza oladi, shuning uchun ilova ularni soxtalashtira olmaydi.
 */
export async function employeeLogin(
  phone: string,
  pin: string,
  tenantId?: string,
): Promise<LoginResult> {
  const matches = await findTenantsForPhone(phone);

  // "Bunday raqam yo'q" va "PIN xato" bir xil xabar beradi — aks holda
  // qaysi raqamlar ro'yxatda borligini tekshirib olish mumkin bo'lardi.
  const failed = () =>
    new ApiError(401, 'Telefon raqami yoki PIN-kod noto\'g\'ri', 'invalid_credentials');

  if (matches.length === 0) {
    // Vaqtni tenglashtirish uchun baribir bcrypt chaqiramiz.
    await verifyPin(pin, undefined);
    throw failed();
  }

  const target = tenantId
    ? matches.find((m) => m.tenantId === tenantId)
    : matches.length === 1
      ? matches[0]
      : undefined;

  if (!target) {
    if (tenantId) {
      await verifyPin(pin, undefined);
      throw failed();
    }
    // Bir nechta biznesda bir xil raqam bor — ilova qaysi biri ekanini
    // so'rashi kerak.
    throw new ApiError(
      409,
      'Bu raqam bir nechta biznesga bog\'langan. Qaysi biri ekanini tanlang.',
      'tenant_choice_required',
      { tenants: matches.map((m) => ({ tenantId: m.tenantId, name: m.tenantName })) },
    );
  }

  const ref = db().ref(`tenants/${target.tenantId}/employees/${target.employeeId}`);
  const snap = await ref.get();
  if (!snap.exists()) {
    await verifyPin(pin, undefined);
    throw failed();
  }

  const employee = snap.val() as EmployeeRecord;

  if (!employee.active) {
    throw new ApiError(
      403,
      'Hisobingiz faol emas. Boshqaruvchiga murojaat qiling.',
      'employee_inactive',
    );
  }

  const now = Date.now();
  if (employee.lockedUntil && employee.lockedUntil > now) {
    const minutes = Math.ceil((employee.lockedUntil - now) / 60000);
    throw new ApiError(
      429,
      `Juda ko'p noto'g'ri urinish. ${minutes} daqiqadan so'ng qayta urining.`,
      'locked_out',
    );
  }

  const ok = await verifyPin(pin, employee.pinHash);

  if (!ok) {
    const attempts = (employee.failedAttempts ?? 0) + 1;
    const updates: Partial<EmployeeRecord> = { failedAttempts: attempts };
    if (attempts >= MAX_FAILED_ATTEMPTS) {
      updates.lockedUntil = now + LOCKOUT_MS;
      updates.failedAttempts = 0;
    }
    await ref.update(updates);
    throw failed();
  }

  // Muvaffaqiyatli kirish — hisoblagichni tozalaymiz.
  if (employee.failedAttempts || employee.lockedUntil) {
    await ref.update({ failedAttempts: 0, lockedUntil: null });
  }

  const claims: AppClaims = {
    tenantId: target.tenantId,
    role: 'staff',
    employeeId: target.employeeId,
  };

  // Xodim uchun barqaror Firebase UID — har bir xodim o'z uid'iga ega
  // bo'lsa, kim nima qilgani auth darajasida ham kuzatiladi.
  const uid = `staff_${target.tenantId}_${target.employeeId}`;
  const customToken = await auth().createCustomToken(uid, { ...claims });

  return {
    customToken,
    claims,
    employee: {
      id: target.employeeId,
      firstName: employee.firstName,
      lastName: employee.lastName,
      sections: Object.entries(employee.sections ?? {})
        .filter(([, v]) => v === true)
        .map(([k]) => k),
      permissions: Object.entries(employee.permissions ?? {})
        .filter(([, v]) => v === true)
        .map(([k]) => k),
    },
    tenantName: target.tenantName,
  };
}
