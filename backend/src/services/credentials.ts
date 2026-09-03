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
