import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

import { requireAuth, requireTenant } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import { changeOwnerLogin } from '../services/credentials.js';
import { employeeLogin } from '../services/employee-auth.js';
import { registerTenant, syncOwnerClaims } from '../services/tenant.js';

export const authRouter: Router = Router();

/**
 * Kirish yo'llari uchun alohida, QATTIQ cheklov.
 *
 * Umumiy `/api` cheklovi daqiqasiga 120 ta so'rovga ruxsat beradi - bu PIN
 * tanlash uchun juda ko'p (10 000 ta variantni ~1.5 soatda sinab ko'rish
 * mumkin bo'lardi). Shu sabab bu yerda ancha qattiq chegara qo'yiladi.
 * Xodim hisobining o'zi ham 5 ta xatodan keyin bloklanadi.
 */
const loginLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: {
    ok: false,
    error: {
      code: 'rate_limited',
      message: 'Juda ko\'p urinish. 10 daqiqadan so\'ng qayta urining.',
    },
  },
});

const employeeLoginBody = z.object({
  phone: z.string().min(7).max(20),
  pin: z.string().min(4).max(8),
  /** Bir raqam bir nechta biznesga tegishli bo'lsa - qaysi biri. */
  tenantId: z.string().min(1).max(64).optional(),
});

/**
 * Xodim kirishi.
 *
 * PIN tekshiruvi ENDI SHU YERDA - qurilmaga hech qanday hash yuborilmaydi.
 * Javob: Firebase custom token (`tenantId`, `role`, `employeeId` da'volari
 * bilan). Ilova uni `signInWithCustomToken` ga beradi.
 */
authRouter.post(
  '/employee/login',
  loginLimiter,
  asyncRoute(async (req, res) => {
    const parsed = employeeLoginBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Telefon raqami va PIN-kodni to\'g\'ri kiriting.',
        parsed.error.flatten().fieldErrors,
      );
    }
    const { phone, pin, tenantId } = parsed.data;
    const result = await employeeLogin(phone, pin, tenantId);
    res.json({ ok: true, ...result });
  }),
);

const registerBody = z.object({
  businessName: z.string().min(2).max(120),
  login: z.string().min(3).max(64),
  password: z.string().min(6).max(128),
  phone: z.string().max(20).optional(),
});

/** Yangi biznes ro'yxatdan o'tkazish (ega hisobi bilan birga). */
authRouter.post(
  '/register',
  loginLimiter,
  asyncRoute(async (req, res) => {
    const parsed = registerBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Ma\'lumotlarni to\'liq kiriting.',
        parsed.error.flatten().fieldErrors,
      );
    }
    const result = await registerTenant(parsed.data);
    res.status(201).json({ ok: true, ...result });
  }),
);

/**
 * Tokendagi da'volarni tiklaydi.
 *
 * Ega email/parol bilan to'g'ridan-to'g'ri Firebase Auth orqali kiradi.
 * Agar tokenda `tenantId` bo'lmasa (masalan hisob boshqa yo'l bilan
 * yaratilgan), ilova shu yo'lni chaqiradi va tokenni yangilaydi.
 */
authRouter.post(
  '/claims/sync',
  requireAuth,
  asyncRoute(async (req, res) => {
    const claims = await syncOwnerClaims(req.user!.uid);
    res.json({ ok: true, claims });
  }),
);

const changeLoginBody = z.object({
  newLogin: z.string().min(3).max(64),
});

/**
 * Biznes egasining loginini almashtiradi.
 *
 * Parol bu yerda o'zgarmaydi — uni ilova Firebase Auth orqali, joriy
 * parolni so'rab, o'zi almashtiradi.
 */
authRouter.post(
  '/credentials/login',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId, uid } = requireTenant(req, 'owner');
    const parsed = changeLoginBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest('Login kamida 3 ta belgidan iborat bo\'lsin.');
    }
    const result = await changeOwnerLogin(uid, tenantId, parsed.data.newLogin);
    res.json({ ok: true, ...result });
  }),
);
