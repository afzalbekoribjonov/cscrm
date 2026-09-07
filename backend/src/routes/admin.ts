import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, requireSuperAdmin } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  confirmPayment,
  getStats,
  getTenant,
  listTenants,
  setSuspended,
} from '../services/admin.js';
import {
  createBroadcast,
  deleteBroadcast,
  listBroadcasts,
} from '../services/broadcast.js';
import { sendToAll } from '../services/push.js';
import {
  plansWithPrices,
  resetPlanPrice,
  setPlanPrice,
} from '../services/plan-prices.js';
import {
  changeOwnerLoginByAdmin,
  ownerCredentials,
  resetOwnerPassword,
} from '../services/credentials.js';
import {
  listPendingPayments,
  rejectPaymentRequest,
} from '../services/payment-request.js';

/**
 * Super-admin yo'llari — CSCRM egasining o'z mijozlarini boshqarish
 * paneli uchun.
 *
 * BARCHA yo'llar ikki qatlamdan o'tadi: `requireAuth` (token haqiqiymi)
 * va `requireSuperAdmin` (UID ruxsat etilganlar ro'yxatidami). Ro'yxat
 * `SUPER_ADMIN_UIDS` sozlamasida — ya'ni bazadan emas, serverdan
 * boshqariladi va uni hech kim ilova orqali o'zgartira olmaydi.
 */
export const adminRouter: Router = Router();

adminRouter.use(requireAuth, requireSuperAdmin);

/** Joriy foydalanuvchi super-admin ekanini tasdiqlaydi (panel kirishi). */
adminRouter.get('/me', (req, res) => {
  res.json({
    ok: true,
    uid: req.user!.uid,
    email: req.user!.email ?? null,
  });
});

adminRouter.get(
  '/stats',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, stats: await getStats(Date.now()) });
  }),
);

adminRouter.get(
  '/tenants',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, tenants: await listTenants(Date.now()) });
  }),
);

adminRouter.get(
  '/tenants/:tenantId',
  asyncRoute(async (req, res) => {
    const tenant = await getTenant(req.params.tenantId!, Date.now());
    res.json({ ok: true, tenant, plans: await plansWithPrices() });
  }),
);

/**
 * Ko'rib chiqilmagan to'lov so'rovlari — panelning ish navbati.
 *
 * Tugunda faqat hal qilinmaganlari turadi, shuning uchun bu so'rov
 * mijozlar soni oshgani bilan og'irlashmaydi.
 */
adminRouter.get(
  '/payment-requests',
  asyncRoute(async (_req, res) => {
    res.json({
      ok: true,
      requests: await listPendingPayments(),
      plans: await plansWithPrices(),
    });
  }),
);

const confirmBody = z.object({
  planId: z.string().min(1).max(40),
  /** Haqiqatda olingan summa. Berilmasa reja narxi yoziladi. */
  amount: z.number().min(0).optional(),
  note: z.string().max(500).optional(),
  /** Mijozning so'rovi asosida tasdiqlansa — o'sha so'rov yopiladi. */
  requestId: z.string().min(1).max(60).optional(),
});

/**
 * To'lovni tasdiqlab, obunani uzaytiradi.
 *
 * To'lov usuli qo'lda karta o'tkazma, shuning uchun tasdiqni odam bosadi.
 */
adminRouter.post(
  '/tenants/:tenantId/confirm-payment',
  asyncRoute(async (req, res) => {
    const parsed = confirmBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Reja tanlanmagan yoki summa noto\'g\'ri.',
        parsed.error.flatten().fieldErrors,
      );
    }

    const result = await confirmPayment({
      tenantId: req.params.tenantId!,
      planId: parsed.data.planId,
      ...(parsed.data.amount !== undefined ? { amount: parsed.data.amount } : {}),
      ...(parsed.data.note ? { note: parsed.data.note } : {}),
      ...(parsed.data.requestId ? { requestId: parsed.data.requestId } : {}),
      byUid: req.user!.uid,
      now: Date.now(),
    });

    res.json({ ok: true, ...result });
  }),
);

const suspendBody = z.object({
  suspended: z.boolean(),
  reason: z.string().max(300).optional(),
});

adminRouter.post(
  '/tenants/:tenantId/suspend',
  asyncRoute(async (req, res) => {
    const parsed = suspendBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('So\'rov noto\'g\'ri.');

    await setSuspended(
      req.params.tenantId!,
      parsed.data.suspended,
      parsed.data.reason ?? null,
    );
    res.json({ ok: true });
  }),
);

const rejectBody = z.object({
  reason: z.string().min(1).max(300),
});

/**
 * To'lov so'rovini rad etadi.
 *
 * Sabab MAJBURIY va mijozga ko'rsatiladi - "rad etildi" deb sababsiz
 * qoldirish mijozni yordam xizmatiga qo'ng'iroq qilishga majbur qiladi.
 */
adminRouter.post(
  '/tenants/:tenantId/payment-requests/:requestId/reject',
  asyncRoute(async (req, res) => {
    const parsed = rejectBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Rad etish sababini yozing.');

    await rejectPaymentRequest({
      tenantId: req.params.tenantId!,
      requestId: req.params.requestId!,
      reason: parsed.data.reason,
      byUid: req.user!.uid,
      now: Date.now(),
    });

    res.json({ ok: true });
  }),
);

/**
 * Biznes egasining kirish ma'lumotlari.
 *
 * PAROL QAYTARILMAYDI va qaytarilishi ham mumkin emas - Firebase faqat
 * hash saqlaydi. Mijoz parolini unutgan bo'lsa, yagona yo'l - yangisini
 * qo'yish (quyidagi yo'l).
 */
adminRouter.get(
  '/tenants/:tenantId/credentials',
  asyncRoute(async (req, res) => {
    res.json({
      ok: true,
      credentials: await ownerCredentials(req.params.tenantId!),
    });
  }),
);

const credentialsBody = z
  .object({
    login: z.string().min(3).max(64).optional(),
    password: z.string().min(6).max(128).optional(),
  })
  .refine((v) => v.login !== undefined || v.password !== undefined, {
    message: 'Login yoki parol - kamida bittasini kiriting.',
  });

/**
 * Biznes egasining loginini va/yoki parolini almashtiradi.
 *
 * "Login-parolimni unutdim" holati uchun: mijoz yordam xizmatiga
 * murojaat qiladi, super-admin esa shu yerdan yangisini qo'yib beradi.
 *
 * Eski parolni bilish TALAB QILINMAYDI - aynan shuning uchun bu yo'l
 * faqat super-adminga ochiq. Parolning o'zi javobga ham, logga ham
 * hech qachon tushmaydi.
 */
adminRouter.post(
  '/tenants/:tenantId/credentials',
  asyncRoute(async (req, res) => {
    const parsed = credentialsBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Login kamida 3 ta, parol kamida 6 ta belgidan iborat bo\'lsin.',
        parsed.error.flatten().fieldErrors,
      );
    }

    const tenantId = req.params.tenantId!;
    const changed: string[] = [];

    if (parsed.data.login !== undefined) {
      await changeOwnerLoginByAdmin({ tenantId, newLogin: parsed.data.login });
      changed.push('login');
    }
    if (parsed.data.password !== undefined) {
      await resetOwnerPassword({ tenantId, newPassword: parsed.data.password });
      changed.push('parol');
    }

    req.log?.info({ tenantId, changed, by: req.user!.uid },
      'egasining kirish ma\'lumotlari o\'zgartirildi');

    res.json({
      ok: true,
      changed,
      credentials: await ownerCredentials(tenantId),
    });
  }),
);

const broadcastBody = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(2000),
  kind: z.enum(['yangilik', 'eslatma', 'taklif']).default('yangilik'),
  /** Muddat (ms). Berilmasa xabar muddatsiz turadi. */
  expiresAt: z.number().int().positive().nullable().optional(),
});

/** Barcha bizneslarga yuboriladigan xabarlar ro'yxati (muddati o'tgani ham). */
adminRouter.get(
  '/broadcasts',
  asyncRoute(async (_req, res) => {
    res.json({
      ok: true,
      broadcasts: await listBroadcasts({ now: Date.now(), activeOnly: false }),
    });
  }),
);

/** Yangi xabar yuboradi — u barcha bizneslarning ilovasida ko'rinadi. */
adminRouter.post(
  '/broadcasts',
  asyncRoute(async (req, res) => {
    const parsed = broadcastBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Sarlavha va matnni to\'ldiring.',
        parsed.error.flatten().fieldErrors,
      );
    }

    const result = await createBroadcast({
      title: parsed.data.title,
      body: parsed.data.body,
      kind: parsed.data.kind,
      ...(parsed.data.expiresAt !== undefined
        ? { expiresAt: parsed.data.expiresAt }
        : {}),
      byUid: req.user!.uid,
      now: Date.now(),
    });

    // Push — QO'SHIMCHA yetkazish yo'li. Ishlamasa ham xabar bazada
    // saqlangan va ilova ochilganda baribir ko'rinadi, shuning uchun
    // bu yerda xatolik javobni buzmaydi.
    const push = await sendToAll({
      title: result.broadcast.title,
      body: result.broadcast.body,
      data: { type: 'broadcast', id: result.id },
    });
    req.log?.info({ broadcastId: result.id, push }, 'xabar yuborildi');

    res.status(201).json({ ok: true, ...result, push });
  }),
);

adminRouter.delete(
  '/broadcasts/:id',
  asyncRoute(async (req, res) => {
    await deleteBroadcast(req.params.id!);
    res.json({ ok: true });
  }),
);

/** Rejalar joriy narxlari bilan. */
adminRouter.get(
  '/plans',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, plans: await plansWithPrices() });
  }),
);

const priceBody = z.object({
  price: z.number().min(0),
  /** Faqat bir umrlik reja uchun — yillik baza to'lovi (dollarda). */
  lifetimeAnnualFeeUsd: z.number().min(0).optional(),
});

/**
 * Reja narxini o'zgartiradi.
 *
 * Narx BAZADA saqlanadi: o'zgartirilishi bilan ilova ham, websayt ham
 * yangisini ko'radi — qayta joylash shart emas.
 *
 * Reja TUZILISHI (necha oy, turi) o'zgartirilmaydi: u dastur mantiqiga
 * bog'liq, narx esa emas.
 */
adminRouter.post(
  '/plans/:planId/price',
  asyncRoute(async (req, res) => {
    const parsed = priceBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest('Narxni to\'g\'ri kiriting.');
    }

    const plan = await setPlanPrice({
      planId: req.params.planId!,
      price: parsed.data.price,
      ...(parsed.data.lifetimeAnnualFeeUsd !== undefined
        ? { lifetimeAnnualFeeUsd: parsed.data.lifetimeAnnualFeeUsd }
        : {}),
      byUid: req.user!.uid,
      now: Date.now(),
    });

    req.log?.info(
      { planId: plan.id, price: plan.price, by: req.user!.uid },
      'reja narxi o\'zgartirildi',
    );

    res.json({ ok: true, plan, plans: await plansWithPrices() });
  }),
);

/** Narxni fayldagi boshlang'ich qiymatga qaytaradi. */
adminRouter.delete(
  '/plans/:planId/price',
  asyncRoute(async (req, res) => {
    await resetPlanPrice(req.params.planId!);
    res.json({ ok: true, plans: await plansWithPrices() });
  }),
);
