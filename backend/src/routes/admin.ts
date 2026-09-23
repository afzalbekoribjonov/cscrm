import { Router } from 'express';
import { z } from 'zod';

import {
  actorOf,
  requireAdmin,
  requireAuth,
  requirePermission,
} from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  IDEMPOTENCY_KEY,
  confirmPayment,
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
import {
  OVERVIEW_RANGES,
  loadOverview,
  type OverviewRange,
} from '../services/overview.js';
import { getSiteSettings, setSiteSettings } from '../services/site-settings.js';
import { AUDIT_CURSOR, listAudit, writeAudit } from '../services/audit.js';
import {
  archiveTenant,
  deleteTenantPermanently,
  restoreTenant,
  setLicenseManually,
  updateTenantProfile,
} from '../services/tenant-admin.js';
import { peopleRouter } from './admin-people.js';

/**
 * Boshqaruv paneli yo'llari — CSCRM egasining o'z mijozlarini
 * boshqarish paneli uchun.
 *
 * BARCHA yo'llar uch qatlamdan o'tadi: `requireAuth` (token haqiqiymi),
 * `requireAdmin` (super-admin — `SUPER_ADMIN_UIDS` sozlamasida — yoki
 * rolga ega panel xodimi) va har yo'lning o'z `requirePermission` i.
 */
export const adminRouter: Router = Router();

adminRouter.use(requireAuth, requireAdmin);

/**
 * Panelga kirish: kim va nimalarga vakolatli. Panel menyu va tugmalarni
 * shunga qarab ko'rsatadi (haqiqiy tekshiruv baribir har yo'lda).
 */
adminRouter.get('/me', (req, res) => {
  const access = req.user!.access!;
  res.json({
    ok: true,
    uid: req.user!.uid,
    email: req.user!.email ?? null,
    isSuperAdmin: access.kind === 'super',
    role: access.kind === 'super' ? null : access.role,
    permissions: access.permissions,
  });
});

adminRouter.use(peopleRouter);

/**
 * Menyudagi hisoblagichlar — har bir panel sahifasida ko'rinadi.
 *
 * ATAYLAB yengil: faqat kutilayotgan to'lov so'rovlari (tugunda faqat
 * hal qilinmaganlari turadi, u o'smaydi). Mijoz to'lab, tasdiq kutib
 * turgan bo'lsa — admin qaysi sahifada bo'lmasin, buni ko'rishi kerak.
 */
adminRouter.get(
  '/badges',
  requirePermission('tenants.read'),
  asyncRoute(async (_req, res) => {
    const pending = await listPendingPayments();
    res.json({ ok: true, badges: { pendingPayments: pending.length } });
  }),
);

const overviewQuery = z.object({
  range: z.enum(OVERVIEW_RANGES as [OverviewRange, ...OverviewRange[]]).default('30d'),
});

/**
 * "Umumiy" sahifasi — ko'rsatkichlar, chartlar va ro'yxatlar BITTA
 * so'rovda. Sahifa bir nechta so'rov yuborib, ularni kutib turmasin.
 */
adminRouter.get(
  '/overview',
  requirePermission('tenants.read'),
  asyncRoute(async (req, res) => {
    const parsed = overviewQuery.safeParse(req.query);
    if (!parsed.success) throw ApiError.badRequest('Davr noto\'g\'ri tanlangan.');
    res.json({ ok: true, overview: await loadOverview(parsed.data.range, Date.now()) });
  }),
);

adminRouter.get(
  '/tenants',
  requirePermission('tenants.read'),
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, tenants: await listTenants(Date.now()) });
  }),
);

adminRouter.get(
  '/tenants/:tenantId',
  requirePermission('tenants.read'),
  asyncRoute(async (req, res) => {
    const tenant = await getTenant(req.params.tenantId!, Date.now());
    res.json({ ok: true, tenant, plans: await plansWithPrices() });
  }),
);

const profileBody = z
  .object({
    name: z.string().max(200).optional(),
    phone: z.string().max(32).nullable().optional(),
    address: z.string().max(400).nullable().optional(),
  })
  .strict();

/** Biznes ma'lumotini tahrirlash (nom, telefon, manzil). */
adminRouter.patch(
  '/tenants/:tenantId/profile',
  requirePermission('tenants.edit'),
  asyncRoute(async (req, res) => {
    const parsed = profileBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Ma\'lumotlarni to\'g\'ri kiriting.');
    const result = await updateTenantProfile({
      tenantId: req.params.tenantId!,
      input: parsed.data,
      actor: actorOf(req),
      now: Date.now(),
    });
    res.json({ ok: true, ...result });
  }),
);

const licenseBody = z.object({
  planId: z.string().min(1).max(40),
  expiresAt: z.number().int().positive().nullable().optional(),
  nextAnnualFeeAt: z.number().int().positive().nullable().optional(),
  reason: z.string().min(3).max(300),
});

/**
 * Obunani TO'LOVSIZ o'zgartirish — reja va muddat.
 *
 * Tushumga yozilmaydi (bu to'lov emas); sabab majburiy va jurnalga
 * tushadi. Pul olingan bo'lsa — `confirm-payment` ishlatiladi.
 */
adminRouter.put(
  '/tenants/:tenantId/license',
  requirePermission('subscriptions.manage'),
  asyncRoute(async (req, res) => {
    const parsed = licenseBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Reja, sana va sababni to\'g\'ri kiriting.');
    const result = await setLicenseManually({
      tenantId: req.params.tenantId!,
      input: parsed.data,
      actor: actorOf(req),
      now: Date.now(),
    });
    res.json({ ok: true, ...result });
  }),
);

const archiveBody = z.object({ reason: z.string().min(3).max(300) });

/** Arxivlash: ilova bloklanadi, ma'lumot 30 kun saqlanadi. */
adminRouter.post(
  '/tenants/:tenantId/archive',
  requirePermission('tenants.archive'),
  asyncRoute(async (req, res) => {
    const parsed = archiveBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Arxivlash sababini yozing.');
    const result = await archiveTenant({
      tenantId: req.params.tenantId!,
      reason: parsed.data.reason,
      actor: actorOf(req),
      now: Date.now(),
    });
    res.json({ ok: true, ...result });
  }),
);

/** Arxivdan qaytarish. */
adminRouter.post(
  '/tenants/:tenantId/restore',
  requirePermission('tenants.archive'),
  asyncRoute(async (req, res) => {
    await restoreTenant({ tenantId: req.params.tenantId!, actor: actorOf(req), now: Date.now() });
    res.json({ ok: true });
  }),
);

const deleteBody = z.object({ confirmName: z.string().min(1).max(200) });

/**
 * Butunlay o'chirish — QAYTARIB BO'LMAYDI.
 *
 * Faqat arxivdagi biznes; biznes nomi so'rovda qo'lda yozilgan bo'lishi
 * shart (server ham tekshiradi — to'g'ridan-to'g'ri API chaqiruvi ham
 * nomsiz o'tmaydi).
 */
adminRouter.delete(
  '/tenants/:tenantId',
  requirePermission('tenants.delete'),
  asyncRoute(async (req, res) => {
    const parsed = deleteBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Tasdiqlash uchun biznes nomini yozing.');
    const tenantId = req.params.tenantId!;
    const result = await deleteTenantPermanently({
      tenantId,
      confirmName: parsed.data.confirmName,
      actor: actorOf(req),
      now: Date.now(),
      mode: 'manual',
    });
    req.log?.info({ tenantId, ...result, by: req.user!.uid }, 'biznes butunlay o\'chirildi');
    res.json({ ok: true, ...result });
  }),
);

const auditQuery = z.object({
  limit: z.coerce.number().int().min(1).max(200).default(50),
  /** Sahifalash: shu yozuvdan OLDINGILARI (oxirgi ko'rilganining `id` si). */
  before: z.string().regex(AUDIT_CURSOR).optional(),
});

/** Shu biznes bo'yicha amallar jurnali. */
adminRouter.get(
  '/tenants/:tenantId/audit',
  requirePermission('audit.read'),
  asyncRoute(async (req, res) => {
    const limit = auditQuery.safeParse(req.query).data?.limit ?? 50;
    res.json({ ok: true, entries: await listAudit({ tenantId: req.params.tenantId!, limit }) });
  }),
);

/** Umumiy amallar jurnali. */
adminRouter.get(
  '/audit',
  requirePermission('audit.read'),
  asyncRoute(async (req, res) => {
    const q = auditQuery.safeParse(req.query).data;
    res.json({
      ok: true,
      entries: await listAudit({ limit: q?.limit ?? 50, ...(q?.before ? { before: q.before } : {}) }),
    });
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
  requirePermission('payments.manage'),
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
  /**
   * Qo'lda tasdiqlashda takroriy bosishdan himoya: bir xil kalit bilan
   * kelgan ikkinchi so'rov yangi to'lov yaratmaydi.
   */
  idempotencyKey: z.string().regex(IDEMPOTENCY_KEY).optional(),
});

/**
 * To'lovni tasdiqlab, obunani uzaytiradi.
 *
 * To'lov usuli qo'lda karta o'tkazma, shuning uchun tasdiqni odam bosadi.
 */
adminRouter.post(
  '/tenants/:tenantId/confirm-payment',
  requirePermission('payments.manage'),
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
      ...(parsed.data.idempotencyKey
        ? { idempotencyKey: parsed.data.idempotencyKey }
        : {}),
      actor: actorOf(req),
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
  requirePermission('tenants.suspend'),
  asyncRoute(async (req, res) => {
    const parsed = suspendBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('So\'rov noto\'g\'ri.');
    if (parsed.data.suspended && !parsed.data.reason?.trim()) {
      throw ApiError.badRequest('To\'xtatish sababini yozing — u mijozga ko\'rsatiladi.');
    }

    await setSuspended({
      tenantId: req.params.tenantId!,
      suspended: parsed.data.suspended,
      reason: parsed.data.reason?.trim() ?? null,
      actor: actorOf(req),
      now: Date.now(),
    });
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
  requirePermission('payments.manage'),
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
    await writeAudit({
      at: Date.now(),
      action: 'payment.reject',
      actor: actorOf(req),
      tenantId: req.params.tenantId!,
      note: parsed.data.reason,
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
  requirePermission('credentials.manage'),
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
  requirePermission('credentials.manage'),
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
    // Parolning O'ZI hech qayerga yozilmaydi — faqat o'zgargani.
    if (parsed.data.login !== undefined) {
      await writeAudit({
        at: Date.now(),
        action: 'credentials.login',
        actor: actorOf(req),
        tenantId,
        note: `Yangi login: ${parsed.data.login.trim()}`,
      });
    }
    if (parsed.data.password !== undefined) {
      await writeAudit({ at: Date.now(), action: 'credentials.password', actor: actorOf(req), tenantId });
    }

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
  requirePermission('broadcasts.manage'),
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
  requirePermission('broadcasts.manage'),
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
    await writeAudit({
      at: Date.now(),
      action: 'broadcast.create',
      actor: actorOf(req),
      note: result.broadcast.title,
    });

    res.status(201).json({ ok: true, ...result, push });
  }),
);

adminRouter.delete(
  '/broadcasts/:id',
  requirePermission('broadcasts.manage'),
  asyncRoute(async (req, res) => {
    await deleteBroadcast(req.params.id!);
    await writeAudit({ at: Date.now(), action: 'broadcast.delete', actor: actorOf(req), note: req.params.id! });
    res.json({ ok: true });
  }),
);

/** Rejalar joriy narxlari bilan. */
adminRouter.get(
  '/plans',
  requirePermission('tenants.read'),
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
  requirePermission('plans.manage'),
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
    await writeAudit({
      at: Date.now(),
      action: 'plan.price',
      actor: actorOf(req),
      note: `${plan.name}: ${plan.price} so'm`,
    });

    res.json({ ok: true, plan, plans: await plansWithPrices() });
  }),
);

/** Narxni fayldagi boshlang'ich qiymatga qaytaradi. */
adminRouter.delete(
  '/plans/:planId/price',
  requirePermission('plans.manage'),
  asyncRoute(async (req, res) => {
    await resetPlanPrice(req.params.planId!);
    await writeAudit({ at: Date.now(), action: 'plan.price_reset', actor: actorOf(req), note: req.params.planId! });
    res.json({ ok: true, plans: await plansWithPrices() });
  }),
);

/* ------------------------------------------------------------------ */
/* Sayt sozlamalari                                                    */
/* ------------------------------------------------------------------ */

adminRouter.get(
  '/site-settings',
  requirePermission('settings.manage'),
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, settings: await getSiteSettings() });
  }),
);

const siteBody = z.object({
  downloadUrl: z.string().max(500),
  version: z.string().max(20),
  sizeMb: z.number().min(0).max(4096),
  note: z.string().max(300),
});

/**
 * Ilovani yuklab olish manzilini o'zgartiradi.
 *
 * Yangi APK chiqqanda faqat shu yerdagi havola almashtiriladi — sayt
 * darhol yangisini beradi, qayta yig'ish va qayta joylash shart emas.
 */
adminRouter.put(
  '/site-settings',
  requirePermission('settings.manage'),
  asyncRoute(async (req, res) => {
    const parsed = siteBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest('Sozlamalarni to\'g\'ri kiriting.');
    }

    const settings = await setSiteSettings({
      ...parsed.data,
      byUid: req.user!.uid,
      now: Date.now(),
    });

    req.log?.info(
      { url: settings.downloadUrl, by: req.user!.uid },
      'sayt sozlamalari o\'zgartirildi',
    );
    await writeAudit({
      at: Date.now(),
      action: 'site.settings',
      actor: actorOf(req),
      note: `Yuklab olish: ${settings.version || '—'}`,
    });

    res.json({ ok: true, settings });
  }),
);
