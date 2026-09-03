import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, requireTenant } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
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
