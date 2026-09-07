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
  const snap = await db().ref(`tenants/${tenantId}/profile/ownerUid`).get();
  if (!snap.exists()) throw ApiError.notFound('Biznes topilmadi.');
  const uid = snap.val() as string;

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

/** Tenant'ning ega UID'sini qaytaradi. */
async function ownerUidOf(tenantId: string): Promise<string> {
  const snap = await db().ref(`tenants/${tenantId}/profile/ownerUid`).get();
  if (!snap.exists()) throw ApiError.notFound('Biznes topilmadi.');
  return snap.val() as string;
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
