import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

import { requireAuth, requireTenant } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  changeOwnPin,
  createEmployee,
  deleteEmployee,
  resetEmployeePin,
} from '../services/tenant.js';

export const employeesRouter: Router = Router();

/**
 * Xodimlarni boshqarish — faqat biznes EGASI.
 *
 * Bu amallar backendda bajariladi (to'g'ridan-to'g'ri Database'ga yozish
 * o'rniga), chunki:
 *  * PIN bcrypt bilan hash'lanishi kerak
 *  * telefon indeksi (`employee_phone_index`) mijozga berk tugun
 * Ikkalasini ham ilova o'zi qila olmaydi.
 */

/**
 * Baza KALITI bo'lib yoziladigan qiymat.
 *
 * Bo'lim va vakolat nomlari `sections/{nom}` ko'rinishida saqlanadi.
 * RTDB kalitida `.` `#` `$` `/` `[` `]` bo'lishi mumkin emas — tekshirmasak
 * bunday nom bazaga yetib borib 500 qaytaradi va mijoz nima noto'g'ri
 * ekanini bilmay qoladi.
 */
const dbKey = z
  .string()
  .min(1)
  .max(40)
  .regex(/^[a-z0-9_-]+$/, 'Faqat kichik harf, raqam, _ va - ishlatiladi.');

const createBody = z.object({
  firstName: z.string().min(1).max(60),
  lastName: z.string().max(60).default(''),
  phone: z.string().min(7).max(20),
  pin: z.string().min(4).max(8),
  sections: z.array(dbKey).max(20).default([]),
  permissions: z.array(dbKey).max(40).default([]),
});

employeesRouter.post(
  '/',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId, uid } = requireTenant(req, 'owner');
    const parsed = createBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Xodim ma\'lumotlarini to\'liq kiriting.',
        parsed.error.flatten().fieldErrors,
      );
    }
    const result = await createEmployee({
      tenantId,
      createdBy: uid,
      ...parsed.data,
    });
    res.status(201).json({ ok: true, ...result });
  }),
);

const pinBody = z.object({ pin: z.string().min(4).max(8) });

employeesRouter.post(
  '/:employeeId/pin',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    const parsed = pinBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest('PIN 4-8 xonali raqam bo\'lishi kerak.');
    }
    await resetEmployeePin(tenantId, req.params.employeeId!, parsed.data.pin);
    res.json({ ok: true });
  }),
);

employeesRouter.delete(
  '/:employeeId',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    await deleteEmployee(tenantId, req.params.employeeId!);
    res.json({ ok: true });
  }),
);

/**
 * O'z PIN'ini almashtirish — HISOB bo'yicha cheklov.
 *
 * Joriy PIN so'raladi, lekin cheklovsiz uni tanlab topish mumkin edi:
 * ochiq qolgan telefonni olgan odam 10 000 variantni sinab, PIN'ni
 * o'zinikiga almashtirib olardi. Kalit — IP emas, foydalanuvchi: hujum
 * aynan shu hisobga qaratilgan, IP esa o'zgartirilishi oson.
 *
 * Faqat xato urinishlar sanaladi — to'g'ri PIN bilan almashtirish
 * cheklanmaydi.
 */
const ownPinLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  skipSuccessfulRequests: true,
  keyGenerator: (req) => req.user?.uid ?? req.ip ?? 'noma\'lum',
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: {
    ok: false,
    error: {
      code: 'rate_limited',
      message: 'Juda ko\'p xato urinish. 15 daqiqadan so\'ng qayta urining.',
    },
  },
});

const ownPinBody = z.object({
  currentPin: z.string().min(4).max(8),
  newPin: z.string().min(4).max(8),
});

/**
 * Xodim O'Z PIN-kodini almashtiradi.
 *
 * `/:employeeId/pin` dan farqi:
 *   * boshqaruvchi emas, XODIMNING O'ZI chaqiradi;
 *   * qaysi xodim ekani tanaga emas, TOKENGA qarab aniqlanadi —
 *     aks holda bir xodim boshqasining PIN'ini almashtira olardi;
 *   * joriy PIN so'raladi.
 */
employeesRouter.post(
  '/me/pin',
  requireAuth,
  ownPinLimiter,
  asyncRoute(async (req, res) => {
    const { tenantId, claims } = requireTenant(req);
    const employeeId = claims.employeeId;
    if (!employeeId) {
      throw ApiError.forbidden('Bu amal faqat xodimlar uchun.');
    }

    const parsed = ownPinBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest('PIN 4-8 xonali raqam bo\'lishi kerak.');
    }

    await changeOwnPin({
      tenantId,
      employeeId,
      currentPin: parsed.data.currentPin,
      newPin: parsed.data.newPin,
    });
    res.json({ ok: true });
  }),
);
