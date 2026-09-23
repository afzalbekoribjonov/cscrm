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
/**
 * FAQAT ISHLAB CHIQISH UCHUN: ko'rib chiqish sahifalari (src/dev/)
 * haqiqiy serverga va bazaga ulanmasdan ishlashi uchun javoblarni
 * almashtiradi. Prod yig'ilishida `import.meta.env.DEV` = false —
 * bu shox kodga umuman kirmaydi.
 */
type DevTransport = (path: string, init: RequestInit) => Promise<unknown>;
let devTransport: DevTransport | null = null;

export function setDevTransport(fn: DevTransport): void {
  if (import.meta.env.DEV) devTransport = fn;
}

async function request<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  if (import.meta.env.DEV && devTransport) {
    return (await devTransport(path, init)) as T;
  }

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
  } catch (e) {
    // Ataylab bekor qilingan so'rov (sahifadan chiqildi, davr
    // almashtirildi) — bu xato emas, "aloqa yo'q" deyish yolg'on bo'lardi.
    if (init.signal?.aborted) throw e;
    throw new ApiError(MESSAGES.offline);
  }

  let json: unknown;
  try {
    json = await response.json();
  } catch {
    // Holat kodi FOYDALANUVCHIGA ko'rsatilmaydi, lekin `status` sifatida
    // saqlanadi — sahifa kerak bo'lsa unga qarab qaror qiladi.
    throw new ApiError(MESSAGES.failed, response.status);
  }

  if (!response.ok) {
    const err = (json as { error?: { message?: string; code?: string } }).error;
    throw new ApiError(
      humanMessage(response.status, err?.message),
      response.status,
      err?.code,
    );
  }

  return json as T;
}

/**
 * Foydalanuvchiga ko'rsatiladigan matnlar.
 *
 * "500", "Server", "token" kabi so'zlar bu yerda ATAYLAB yo'q: ular
 * foydalanuvchiga nima qilish kerakligini aytmaydi.
 */
const MESSAGES = {
  offline: 'Aloqa o\'rnatilmadi. Internetni tekshirib, qayta urinib ko\'ring.',
  failed: 'Amalni bajarib bo\'lmadi. Birozdan so\'ng qayta urinib ko\'ring.',
  signedOut: 'Sessiya muddati tugagan. Qaytadan kiring.',
} as const;

/**
 * Server javobidan foydalanuvchi matnini tanlaydi.
 *
 * 4xx — server aniq sababni aytadi ("Bu login band" va h.k.), uni
 * ko'rsatamiz. 5xx — ichki nosozlik, uning matni foydalanuvchiga
 * foyda bermaydi, umumiy matn chiqadi.
 */
export function humanMessage(status: number, serverMessage?: string): string {
  if (status === 401) return MESSAGES.signedOut;
  if (status >= 500) return MESSAGES.failed;
  return serverMessage?.trim() || MESSAGES.failed;
}

export const api = {
  get: <T>(path: string, opts: { signal?: AbortSignal } = {}) =>
    request<T>(path, { signal: opts.signal }),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  put: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'PUT', body: JSON.stringify(body) }),
  patch: <T>(path: string, body: unknown) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
  /** Tana ixtiyoriy: butunlay o'chirishda tasdiq (`confirmName`) tanada yuboriladi. */
  del: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: 'DELETE', ...(body === undefined ? {} : { body: JSON.stringify(body) }) }),
};
