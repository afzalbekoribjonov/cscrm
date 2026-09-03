import type { NextFunction, Request, Response } from 'express';

import { env } from '../config/env.js';
import { auth } from '../lib/firebase.js';
import type { AppClaims, Role } from '../types/tenant.js';
import { ApiError } from './error.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      /** Firebase ID token tekshiruvidan o'tgan foydalanuvchi. */
      user?: {
        uid: string;
        email?: string | undefined;
        isSuperAdmin: boolean;
        /**
         * Tokendagi ilova da'volari. Bularni faqat Admin SDK yozadi,
         * shuning uchun ularga ishonish mumkin. Hisob hali biznesga
         * bog'lanmagan bo'lsa `undefined`.
         */
        claims?: AppClaims | undefined;
      };
    }
  }
}

function bearer(req: Request): string | null {
  const header = req.header('authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
}

/** Tokendan ilova da'volarini ajratib oladi (formati kutilgandekmi). */
function readClaims(decoded: Record<string, unknown>): AppClaims | undefined {
  const tenantId = decoded.tenantId;
  const role = decoded.role;
  if (typeof tenantId !== 'string' || tenantId.length === 0) return undefined;
  if (role !== 'owner' && role !== 'staff') return undefined;

  const employeeId = decoded.employeeId;
  return {
    tenantId,
    role: role as Role,
    ...(typeof employeeId === 'string' ? { employeeId } : {}),
  };
}

/**
 * Firebase ID token'ni tekshiradi va `req.user` ni to'ldiradi.
 *
 * Token yaroqsiz bo'lsa 401 qaytaradi - sababi aytilmaydi (muddati
 * tugagan/soxta ekani hujumchiga ma'lumot bermasligi uchun), lekin
 * loglarga yoziladi.
 */
export async function requireAuth(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  const token = bearer(req);
  if (!token) return next(ApiError.unauthorized());

  try {
    const decoded = await auth().verifyIdToken(token, true);
    req.user = {
      uid: decoded.uid,
      email: decoded.email,
      isSuperAdmin: env.superAdminUids.has(decoded.uid),
      claims: readClaims(decoded as unknown as Record<string, unknown>),
    };
    next();
  } catch (err) {
    req.log?.warn({ err }, 'ID token tekshiruvdan o\'tmadi');
    next(ApiError.unauthorized());
  }
}

/** `requireAuth` dan KEYIN ishlatiladi - faqat super-adminlarga ruxsat. */
export function requireSuperAdmin(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  if (!req.user) return next(ApiError.unauthorized());
  if (!req.user.isSuperAdmin) {
    req.log?.warn({ uid: req.user.uid }, 'super-admin bo\'lmagan urinish');
    return next(ApiError.forbidden());
  }
  next();
}

/**
 * Joriy foydalanuvchining tenant'ini qaytaradi.
 *
 * `role` berilsa, aynan shu rol talab qilinadi. Da'vo yo'q bo'lsa yoki
 * rol mos kelmasa - 403.
 */
export function requireTenant(
  req: Request,
  role?: Role,
): { tenantId: string; uid: string; claims: AppClaims } {
  const user = req.user;
  if (!user) throw ApiError.unauthorized();

  const claims = user.claims;
  if (!claims) {
    throw ApiError.forbidden('Hisob biznesga bog\'lanmagan.');
  }
  if (role && claims.role !== role) {
    throw ApiError.forbidden(
      role === 'owner'
        ? 'Bu amal faqat boshqaruvchi uchun.'
        : 'Bu amal uchun ruxsat yo\'q.',
    );
  }
  return { tenantId: claims.tenantId, uid: user.uid, claims };
}
