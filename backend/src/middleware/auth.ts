import type { NextFunction, Request, Response } from 'express';

import { env } from '../config/env.js';
import { auth } from '../lib/firebase.js';
import { hasPermission, type Permission } from '../lib/permissions.js';
import { resolveAccess, type Access } from '../services/admin-access.js';
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
        /**
         * Rol orqali berilgan vakolatlar (super-admin hammasiga ega).
         * `requireAdmin` to'ldiradi.
         */
        permissions?: Set<Permission> | undefined;
        /** Panelga kirish turi — `requireAdmin` dan keyin bor. */
        access?: Access | undefined;
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

/**
 * Panel xodimi (`requireAuth` dan KEYIN): super-admin yoki rolga ega.
 *
 * `req.user.permissions` shu yerda to'ldiriladi — keyingi
 * `requirePermission` aynan shu to'plamni tekshiradi.
 */
export async function requireAdmin(req: Request, _res: Response, next: NextFunction) {
  if (!req.user) return next(ApiError.unauthorized());
  try {
    const access = await resolveAccess(req.user.uid);
    if (!access) {
      req.log?.warn({ uid: req.user.uid }, 'panelga ruxsatsiz urinish');
      return next(ApiError.forbidden());
    }
    req.user.isSuperAdmin = access.kind === 'super';
    req.user.permissions = new Set(access.permissions);
    req.user.access = access;
    next();
  } catch (err) {
    next(err);
  }
}

/**
 * Aniq vakolatni talab qiladi (`requireAdmin` dan keyin).
 *
 * Super-admin hammasiga ega; boshqa panel xodimi — faqat roli bergan
 * vakolatlarga.
 */
export function requirePermission(permission: Permission) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) return next(ApiError.unauthorized());
    if (!hasPermission(req.user, permission)) {
      req.log?.warn({ uid: req.user.uid, permission }, 'vakolat yo\'q');
      return next(ApiError.forbidden('Bu amal uchun vakolatingiz yo\'q.'));
    }
    next();
  };
}

/** So'rovni bajarayotgan admin — jurnal uchun. */
export function actorOf(req: Request): { uid: string; email: string | null } {
  return { uid: req.user?.uid ?? 'unknown', email: req.user?.email ?? null };
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
