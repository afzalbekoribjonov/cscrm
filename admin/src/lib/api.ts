import { firebaseAuth } from './firebase';
import { env } from './env';

/** Serverdan kelgan, ko'rsatish mumkin bo'lgan xatolik. */
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status?: number,
    readonly code?: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

/**
 * CSCRM API ga so'rov yuboradi.
 *
 * Har bir so'rovga joriy foydalanuvchining Firebase ID token'i qo'shiladi —
 * super-admin ekanini server aynan shu token orqali tekshiradi (UID
 * `SUPER_ADMIN_UIDS` ro'yxatida bo'lishi kerak).
 */
async function request<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const user = firebaseAuth().currentUser;
  if (!user) throw new ApiError('Tizimga kirilmagan.', 401, 'unauthorized');

  const token = await user.getIdToken();

  let response: Response;
  try {
    response = await fetch(`${env.apiBaseUrl}${path}`, {
      ...init,
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
        ...(init.headers ?? {}),
      },
    });
  } catch {
    throw new ApiError('Serverga ulanib bo\'lmadi. Aloqani tekshiring.');
  }

  let json: unknown;
  try {
    json = await response.json();
  } catch {
    throw new ApiError(
      `Serverdan tushunarsiz javob keldi (${response.status}).`,
      response.status,
    );
  }

  if (!response.ok) {
    const err = (json as { error?: { message?: string; code?: string } }).error;
    throw new ApiError(
      err?.message ?? `Xatolik yuz berdi (${response.status}).`,
      response.status,
      err?.code,
    );
  }

  return json as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
};
