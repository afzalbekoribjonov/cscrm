import { Router } from 'express';
import { z } from 'zod';

import { env } from '../config/env.js';
import { parseCards } from '../lib/card.js';
import { requireAuth, requireTenant } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import { listBroadcasts } from '../services/broadcast.js';
import { PLANS, evaluate, loadLicense, signed } from '../services/license.js';
import {
  latestPaymentRequest,
  submitPaymentRequest,
} from '../services/payment-request.js';

export const licenseRouter: Router = Router();

/**
 * Ochiq: mavjud rejalar ro'yxati. Ilovadagi to'lov ekrani va websaytdagi
 * narxlar bo'limi shu bitta manbadan oziqlanadi - narx ikki joyda
 * boshqacha ko'rinishi mumkin emas.
 */
licenseRouter.get('/plans', (_req, res) => {
  res.json({ ok: true, plans: PLANS, payment: paymentInfo() });
});

/**
 * To'lov ma'lumotlari — ilovadagi to'lov ekrani shulardan foydalanadi.
 *
 * Tanlangan usul: qo'lda karta o'tkazma. Qiymatlar sozlamadan olinadi,
 * shuning uchun karta almashsa ilovani qayta yig'ish shart emas.
 */
function paymentInfo() {
  const cards = parseCards(env.PAYMENT_CARDS);
  return {
    method: 'card_transfer',
    cards,
    cardHolder: env.PAYMENT_CARD_HOLDER,
    phone: env.PAYMENT_PHONE,
    email: env.PAYMENT_EMAIL,
    telegram: env.PAYMENT_TELEGRAM,
    note: env.PAYMENT_NOTE,
    /** Sozlanmagan bo'lsa ilova "yordam xizmatiga murojaat qiling" deydi. */
    configured: cards.length > 0,
  };
}

/**
 * Litsenziya holati - ilova ishga tushganda va davriy ravishda chaqiradi.
 *
 * `tenantId` SO'ROVDAN OLINMAYDI, faqat tokendagi da'vodan. Aks holda
 * istalgan foydalanuvchi boshqa biznesning obuna holatini ko'ra olardi.
 *
 * Javob IMZOLANGAN: ilova imzoni tekshirgach natijaga ishonadi. Shu sabab
 * qurilma soatini o'zgartirish yoki javobni yo'lda almashtirish bloklashni
 * chetlab o'tishga imkon bermaydi.
 */
licenseRouter.get(
  '/status',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req);

    const license = await loadLicense(tenantId);
    if (!license) throw ApiError.notFound('Biznes topilmadi.');

    res.json({ ok: true, ...signed(evaluate(license, Date.now())) });
  }),
);

const paymentRequestBody = z.object({
  planId: z.string().min(1).max(40),
  /** Mijoz to'lagan summa. Berilmasa reja narxi olinadi. */
  amount: z.number().min(0).optional(),
  /** O'tkazma/chek raqami - bank ko'chirmasi bilan solishtirish uchun. */
  reference: z.string().max(120).optional(),
  note: z.string().max(500).optional(),
});

/**
 * "Men to'ladim, tekshiring" - mijozning to'lov haqidagi xabari.
 *
 * Faqat EGA yubora oladi: pulni u to'laydi va reja tanlash uning qarori.
 * Xodim so'rov holatini ko'ra oladi (quyidagi GET), lekin yubora olmaydi.
 *
 * Bu so'rov obunani UZAYTIRMAYDI - u faqat super-admin navbatiga tushadi.
 * Uzaytirishni odam tasdiqlaydi, aks holda istalgan kishi "to'ladim" deb
 * ilovani cheksiz ochib olardi.
 */
licenseRouter.post(
  '/payment-request',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId, uid } = requireTenant(req, 'owner');

    const parsed = paymentRequestBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'So\'rov to\'liq emas. Rejani tanlang.',
        parsed.error.flatten().fieldErrors,
      );
    }

    const result = await submitPaymentRequest({
      tenantId,
      planId: parsed.data.planId,
      ...(parsed.data.amount !== undefined
        ? { amount: parsed.data.amount }
        : {}),
      ...(parsed.data.reference ? { reference: parsed.data.reference } : {}),
      ...(parsed.data.note ? { note: parsed.data.note } : {}),
      uid,
      now: Date.now(),
    });

    res.status(201).json({
      ok: true,
      requestId: result.requestId,
      request: result.request,
    });
  }),
);

/**
 * Oxirgi to'lov so'rovining holati.
 *
 * XODIMGA HAM ochiq: bloklangan ekranda "rahbar to'lov haqida xabar
 * bergan, tasdiq kutilmoqda" deb ko'rsatish uchun. Aks holda xodim
 * nima bo'layotganini bilmaydi va qayta-qayta "Tekshirish" bosadi.
 */
licenseRouter.get(
  '/payment-request',
  requireAuth,
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req);
    res.json({ ok: true, request: await latestPaymentRequest(tenantId) });
  }),
);

/**
 * CSCRM'dan kelgan xabarlar.
 *
 * Ilovadagi qo'ng'iroq ostidagi "Xabarlar" bo'limi shu yerdan
 * oziqlanadi. Xodimga ham ochiq: xabar biznesning o'ziga emas,
 * ilovadan foydalanayotgan hammaga tegishli.
 *
 * Muddati o'tgan xabarlar bu yerda KO'RSATILMAYDI - eskirgan e'lon
 * ro'yxatni to'ldirib turmasin.
 */
licenseRouter.get(
  '/messages',
  requireAuth,
  asyncRoute(async (req, res) => {
    // Tenant tekshiruvi: xabar faqat tizimga bog'langan hisoblarga.
    requireTenant(req);
    res.json({
      ok: true,
      messages: await listBroadcasts({ now: Date.now(), activeOnly: true }),
    });
  }),
);
