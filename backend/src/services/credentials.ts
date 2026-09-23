import { env } from '../config/env.js';
import { auth, db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';
import { AUTH_EMAIL_DOMAIN, sanitizeLogin } from './tenant.js';

/**
 * Biznes egasining LOGIN'ini almashtiradi.
 *
 * Nega serverda: login `admin_logins/{login}` indeksining kaliti, u esa
 * mijozga berk (aks holda birov boshqa biznesning loginini o'ziga
 * ko'chirib olishi mumkin bo'lardi). Bundan tashqari Firebase Auth
 * email'i ham shu logindan yasaladi va uni Admin SDK yangilaydi -
 * mijoz SDK'si buni ishonchli qila olmaydi.
 *
 * Parol bu yerda O'ZGARMAYDI: uni foydalanuvchi o'zi, Firebase Auth
 * orqali almashtiradi (joriy parolni bilishi shart).
 */
export async function changeOwnerLogin(
  uid: string,
  tenantId: string,
  rawNewLogin: string,
): Promise<{ login: string }> {
  const newLogin = sanitizeLogin(rawNewLogin);
  if (newLogin.length < 3) {
    throw ApiError.badRequest('Login kamida 3 ta belgidan iborat bo\'lsin.');
  }

  const existing = await db().ref(`admin_logins/${newLogin}`).get();
  if (existing.exists()) {
    const owner = existing.val() as { uid?: string };
    if (owner?.uid !== uid) {
      throw ApiError.badRequest('Bu login band. Boshqasini tanlang.');
    }
    // Ayni login allaqachon o'ziniki - o'zgartirishga hojat yo'q.
    return { login: newLogin };
  }

  // Eski loginni topamiz (indeksni tozalash uchun).
  const user = await auth().getUser(uid);
  const oldEmail = user.email ?? '';
  const oldLogin = oldEmail.endsWith(AUTH_EMAIL_DOMAIN)
    ? oldEmail.slice(0, -AUTH_EMAIL_DOMAIN.length)
    : null;

  // Avval Auth email'i - u muvaffaqiyatsiz bo'lsa indeks buzilmasin.
  await auth().updateUser(uid, { email: `${newLogin}${AUTH_EMAIL_DOMAIN}` });

  await db().ref().update({
    [`admin_logins/${newLogin}`]: { uid, tenantId },
    ...(oldLogin && oldLogin !== newLogin
      ? { [`admin_logins/${oldLogin}`]: null }
      : {}),
  });

  return { login: newLogin };
}

/**
 * Biznes egasining hozirgi login ma'lumotlari.
 *
 * Super-admin panelida ko'rsatiladi: mijoz "loginimni unutdim" deb
 * murojaat qilganda uni AYTIB berish uchun. Parolni ko'rsatib
 * bo'lmaydi - Firebase faqat hash saqlaydi, ochiq matn hech qayerda
 * yo'q. Shuning uchun parol bo'yicha yagona yo'l - yangisini qo'yish.
 */
export async function ownerCredentials(tenantId: string): Promise<{
  uid: string;
  login: string | null;
  email: string | null;
  lastSignInAt: string | null;
  disabled: boolean;
}> {
  const uid = await ownerUidOf(tenantId);

  const user = await auth().getUser(uid);
  const email = user.email ?? null;
  const login =
    email && email.endsWith(AUTH_EMAIL_DOMAIN)
      ? email.slice(0, -AUTH_EMAIL_DOMAIN.length)
      : null;

  return {
    uid,
    login,
    email,
    lastSignInAt: user.metadata.lastSignInTime ?? null,
    disabled: user.disabled,
  };
}

/**
 * Nomzod haqiqatan shu biznesning egasimi.
 *
 * NEGA KERAK. `profile/ownerUid` ni biznes egasi ilova orqali O'ZI
 * yoza oladi. Unga ko'r-ko'rona ishonilsa zanjir hosil bo'ladi: ega
 * u yerga super-admin UID'ini yozadi, "parolimni unutdim" deb
 * murojaat qiladi — va panel SUPER-ADMINNING parolini almashtirib,
 * uni hujumchiga beradi.
 *
 * Shu sabab nomzod faqat MIJOZ YOZA OLMAYDIGAN manbalar orqali
 * tasdiqlanadi (ikkalasini ham faqat Admin SDK yozadi):
 *   * token da'volari — `tenantId` mos va `role === 'owner'`;
 *   * `user_tenants/{uid}` + `members/{uid}` — ro'yxatdan o'tishda
 *     yoziladi; da'vosi hali tiklanmagan eski hisoblar uchun.
 *
 * Super-admin HECH QACHON biznes egasi deb qabul qilinmaydi.
 *
 * Sof funksiya — sinovda bazasiz tekshiriladi.
 */
export function isVerifiedOwner(input: {
  tenantId: string;
  uid: string;
  claims: Record<string, unknown> | undefined;
  userTenant: unknown;
  isMember: boolean;
  superAdminUids: ReadonlySet<string>;
}): boolean {
  if (input.uid.length === 0) return false;
  if (input.superAdminUids.has(input.uid)) return false;

  const claimsOk =
    input.claims?.tenantId === input.tenantId && input.claims?.role === 'owner';
  const indexOk = input.userTenant === input.tenantId && input.isMember;

  return claimsOk || indexOk;
}

/**
 * Tenant'ning ega UID'sini qaytaradi — faqat tasdiqlangan bo'lsa.
 *
 * Tasdiqlanmasa amal bekor qilinadi va logga yoziladi: bu yo
 * ma'lumotdagi nosozlik, yo qasddan qilingan urinish.
 */
async function ownerUidOf(tenantId: string): Promise<string> {
  const snap = await db().ref(`tenants/${tenantId}/profile/ownerUid`).get();
  if (!snap.exists()) throw ApiError.notFound('Biznes topilmadi.');

  const uid = String(snap.val());

  const [claims, userTenantSnap, memberSnap] = await Promise.all([
    auth()
      .getUser(uid)
      .then((u) => u.customClaims as Record<string, unknown> | undefined)
      .catch(() => undefined),
    db().ref(`user_tenants/${uid}`).get(),
    db().ref(`tenants/${tenantId}/members/${uid}`).get(),
  ]);

  const verified = isVerifiedOwner({
    tenantId,
    uid,
    claims,
    userTenant: userTenantSnap.val(),
    isMember: memberSnap.val() === true,
    superAdminUids: env.superAdminUids,
  });

  if (!verified) {
    // eslint-disable-next-line no-console
    console.warn(
      `[cscrm] ega tasdiqlanmadi: tenant=${tenantId} — ownerUid ishonchli manbalar bilan mos emas`,
    );
    throw new ApiError(
      409,
      'Bu biznes egasining hisobi tasdiqlanmadi. Amal bajarilmadi.',
      'owner_unverified',
    );
  }

  return uid;
}

/**
 * Super-admin biznes egasiga YANGI PAROL qo'yadi.
 *
 * "Parolni unutdim" holati uchun: eski parolni bilish shart emas.
 * Shu sabab bu yo'l faqat super-adminga ochiq va har chaqiruv logga
 * tushadi (parolning O'ZI hech qayerda yozilmaydi).
 *
 * Mavjud seanslar BEKOR QILINADI. Sabab: parol almashtirilyaptimi,
 * demak eskisiga ishonch yo'q — birov o'g'irlab olgan bo'lishi ham
 * mumkin. Token bekor qilinmasa, u eski parol bilan kirgan holda
 * ishlashda davom etardi.
 */
export async function resetOwnerPassword(params: {
  tenantId: string;
  newPassword: string;
}): Promise<{ uid: string }> {
  if (params.newPassword.length < 6) {
    throw ApiError.badRequest('Parol kamida 6 ta belgidan iborat bo\'lsin.');
  }

  const uid = await ownerUidOf(params.tenantId);
  await auth().updateUser(uid, { password: params.newPassword });
  await auth().revokeRefreshTokens(uid);

  return { uid };
}

/** Super-admin biznes egasining loginini almashtiradi. */
export async function changeOwnerLoginByAdmin(params: {
  tenantId: string;
  newLogin: string;
}): Promise<{ login: string }> {
  const uid = await ownerUidOf(params.tenantId);
  return changeOwnerLogin(uid, params.tenantId, params.newLogin);
}
