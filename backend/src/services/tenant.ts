import { customAlphabet } from 'nanoid';

import { auth, db } from '../lib/firebase.js';
import { normalizePhone } from '../lib/phone.js';
import { ApiError } from '../middleware/error.js';
import type {
  AppClaims,
  EmployeeRecord,
  PhoneIndexEntry,
  TenantProfile,
} from '../types/tenant.js';
import type { License } from '../types/license.js';
import { directoryEntry } from './admin.js';
import { computeExpiry, findPlan } from './license.js';
import { hashPin, isValidPin } from './pin.js';

/**
 * Tenant ID - o'qishga qulay, adashtirmaydigan alifbo (0/O, 1/I/l yo'q).
 * Bu ID yordam xizmatida og'zaki aytiladi, shuning uchun chalkash
 * belgilar ishlatilmaydi.
 */
const newTenantId = customAlphabet('23456789abcdefghjkmnpqrstuvwxyz', 12);
const newEmployeeId = customAlphabet('23456789abcdefghjkmnpqrstuvwxyz', 16);

/**
 * Login uchun ruxsat etilgan belgilar.
 *
 * NUQTA ATAYLAB YO'Q. Login `admin_logins/{login}` yo'lida kalit bo'lib
 * yoziladi, RTDB kalitida esa `.` `#` `$` `/` `[` `]` bo'lishi mumkin
 * emas - aks holda "ali.vali" yozgan odam ro'yxatdan o'ta olmasdi.
 *
 * Nuqta rad etilmaydi, OLIB TASHLANADI: "ali.vali" -> "alivali". Ham
 * ro'yxatdan o'tishda, ham kirishda bir xil tozalash qo'llangani uchun
 * foydalanuvchi o'zi yozgan matn bilan baribir kira oladi.
 *
 * DIQQAT: `app/lib/services/auth_service.dart` dagi nusxasi bilan AYNAN
 * bir xil bo'lishi shart.
 */
export function sanitizeLogin(input: string): string {
  return input.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
}

export const AUTH_EMAIL_DOMAIN = '@cscrm.local';

interface RegisterInput {
  businessName: string;
  login: string;
  password: string;
  phone?: string;
}

interface RegisterResult {
  tenantId: string;
  uid: string;
  customToken: string;
}

/**
 * Yangi biznes va uning egasini yaratadi.
 *
 * Hammasi SHU YERDA bajariladi (ilovada emas), chunki:
 *  * custom claim'larni faqat Admin SDK qo'ya oladi
 *  * tenant tuguni va litsenziya birgalikda yaratilishi kerak
 *  * login band emasligini ishonchli tekshirish kerak
 */
export async function registerTenant(
  input: RegisterInput,
): Promise<RegisterResult> {
  const login = sanitizeLogin(input.login);
  if (login.length < 3) {
    throw ApiError.badRequest('Login kamida 3 ta belgidan iborat bo\'lsin.');
  }
  if (input.password.length < 6) {
    throw ApiError.badRequest('Parol kamida 6 ta belgidan iborat bo\'lsin.');
  }
  const businessName = input.businessName.trim();
  if (businessName.length < 2) {
    throw ApiError.badRequest('Biznes nomini kiriting.');
  }

  const loginRef = db().ref(`admin_logins/${login}`);
  if ((await loginRef.get()).exists()) {
    throw ApiError.badRequest('Bu login band. Boshqasini tanlang.');
  }

  const email = `${login}${AUTH_EMAIL_DOMAIN}`;
  const tenantId = newTenantId();

  let uid: string;
  try {
    const user = await auth().createUser({ email, password: input.password });
    uid = user.uid;
  } catch (err) {
    const code = (err as { code?: string }).code;
    if (code === 'auth/email-already-exists') {
      throw ApiError.badRequest('Bu login band. Boshqasini tanlang.');
    }
    throw err;
  }

  // Sinov muddati - ro'yxatdan o'tgan zahoti boshlanadi.
  const trial = findPlan('trial');
  if (!trial) {
    throw new Error('`trial` rejasi shared/plans.json da topilmadi');
  }

  const now = Date.now();
  const license: Omit<License, 'tenantId'> = {
    planId: trial.id,
    kind: trial.kind,
    startedAt: now,
    expiresAt: computeExpiry(trial, now),
  };

  const profile: TenantProfile = {
    name: businessName,
    ownerUid: uid,
    createdAt: now,
    ...(input.phone ? { phone: normalizePhone(input.phone) } : {}),
  };

  // Bitta yozuvda - yarim yaratilgan tenant qolib ketmasligi uchun.
  await db().ref().update({
    [`tenants/${tenantId}/profile`]: profile,
    [`tenants/${tenantId}/license`]: license,
    [`tenants/${tenantId}/members/${uid}`]: true,
    [`admin_logins/${login}`]: { uid, tenantId },
    [`user_tenants/${uid}`]: tenantId,
    // Super-admin paneli bizneslarni SHU tugundan sanaydi. `tenants` ni
    // o'qish butun bazani (barcha buyurtmalar bilan) yuklab olardi.
    ...directoryEntry(tenantId, now),
  });

  const claims: AppClaims = { tenantId, role: 'owner' };
  await auth().setCustomUserClaims(uid, { ...claims });

  return {
    tenantId,
    uid,
    customToken: await auth().createCustomToken(uid, { ...claims }),
  };
}

/**
 * Foydalanuvchi tokenida `tenantId` da'vosi borligini ta'minlaydi.
 *
 * Ega email/parol bilan to'g'ridan-to'g'ri Firebase Auth orqali kiradi -
 * bunda backend ishtirok etmaydi. Agar da'volar biror sababdan yo'q bo'lsa,
 * ilova shu yo'lni chaqirib ularni tiklaydi.
 */
export async function syncOwnerClaims(uid: string): Promise<AppClaims> {
  const snap = await db().ref(`user_tenants/${uid}`).get();
  if (!snap.exists()) {
    throw ApiError.forbidden('Bu hisob hech qanday biznesga bog\'lanmagan.');
  }
  const tenantId = snap.val() as string;
  const claims: AppClaims = { tenantId, role: 'owner' };
  await auth().setCustomUserClaims(uid, { ...claims });
  return claims;
}

interface CreateEmployeeInput {
  tenantId: string;
  firstName: string;
  lastName: string;
  phone: string;
  pin: string;
  sections: string[];
  permissions: string[];
  createdBy: string;
}

/**
 * Xodim yaratadi.
 *
 * Ilovada emas, SHU YERDA - chunki PIN bcrypt bilan hash'lanishi va
 * telefon indeksi (mijozga berk tugun) yangilanishi kerak.
 */
export async function createEmployee(
  input: CreateEmployeeInput,
): Promise<{ employeeId: string }> {
  if (!isValidPin(input.pin)) {
    throw ApiError.badRequest('PIN 4-8 xonali raqam bo\'lishi kerak.');
  }
  const phone = normalizePhone(input.phone);
  if (phone.length !== 12) {
    throw ApiError.badRequest('Telefon raqamini to\'liq kiriting.');
  }

  const profileSnap = await db().ref(`tenants/${input.tenantId}/profile`).get();
  if (!profileSnap.exists()) throw ApiError.notFound('Biznes topilmadi.');
  const tenantName = (profileSnap.val() as TenantProfile).name;

  // Shu biznesda bu raqam allaqachon bormi.
  const existing = await db()
    .ref(`tenants/${input.tenantId}/employees`)
    .orderByChild('phone')
    .equalTo(phone)
    .get();
  if (existing.exists()) {
    throw ApiError.badRequest('Bu telefon raqamli xodim allaqachon mavjud.');
  }

  const employeeId = newEmployeeId();
  const record: EmployeeRecord = {
    firstName: input.firstName.trim(),
    lastName: input.lastName.trim(),
    phone,
    pinHash: await hashPin(input.pin),
    active: true,
    createdAt: Date.now(),
    createdBy: input.createdBy,
    sections: Object.fromEntries(input.sections.map((s) => [s, true])),
    permissions: Object.fromEntries(input.permissions.map((p) => [p, true])),
  };

  const indexEntry: PhoneIndexEntry = {
    tenantId: input.tenantId,
    employeeId,
    tenantName,
  };

  await db().ref().update({
    [`tenants/${input.tenantId}/employees/${employeeId}`]: record,
    [`employee_phone_index/${phone}/${input.tenantId}`]: indexEntry,
  });

  return { employeeId };
}

/** Xodim PIN'ini almashtiradi (faqat ega chaqira oladi). */
export async function resetEmployeePin(
  tenantId: string,
  employeeId: string,
  newPin: string,
): Promise<void> {
  if (!isValidPin(newPin)) {
    throw ApiError.badRequest('PIN 4-8 xonali raqam bo\'lishi kerak.');
  }
  const ref = db().ref(`tenants/${tenantId}/employees/${employeeId}`);
  if (!(await ref.get()).exists()) throw ApiError.notFound('Xodim topilmadi.');

  await ref.update({
    pinHash: await hashPin(newPin),
    failedAttempts: 0,
    lockedUntil: null,
  });
}

/** Xodimni o'chiradi - telefon indeksidan ham olib tashlaydi. */
export async function deleteEmployee(
  tenantId: string,
  employeeId: string,
): Promise<void> {
  const ref = db().ref(`tenants/${tenantId}/employees/${employeeId}`);
  const snap = await ref.get();
  if (!snap.exists()) return;
  const phone = (snap.val() as EmployeeRecord).phone;

  await db().ref().update({
    [`tenants/${tenantId}/employees/${employeeId}`]: null,
    [`employee_phone_index/${phone}/${tenantId}`]: null,
  });
}
