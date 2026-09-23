import { Router } from 'express';
import { z } from 'zod';

import { actorOf, requirePermission } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  addMember,
  createRole,
  deleteRole,
  loadAccessOverview,
  panelUids,
  removeMember,
  setMemberRole,
  updateRole,
} from '../services/admin-access.js';
import { loadUsers, signOutEverywhere } from '../services/users.js';

/**
 * Odamlar: platforma foydalanuvchilari va panel xodimlari (rollar).
 *
 * `adminRouter` ichida ulanadi — ya'ni `requireAuth` + `requireAdmin`
 * allaqachon o'tgan. Har bir yo'l o'z vakolatini alohida tekshiradi.
 */
export const peopleRouter: Router = Router();

/* ------------------------------------------------------------------ */
/* Foydalanuvchilar                                                    */
/* ------------------------------------------------------------------ */

peopleRouter.get(
  '/users',
  requirePermission('users.read'),
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, users: await loadUsers(await panelUids()) });
  }),
);

peopleRouter.post(
  '/users/:uid/signout',
  requirePermission('users.manage'),
  asyncRoute(async (req, res) => {
    await signOutEverywhere({
      uid: req.params.uid!,
      excluded: await panelUids(),
      actor: actorOf(req),
      now: Date.now(),
    });
    res.json({ ok: true });
  }),
);

/* ------------------------------------------------------------------ */
/* Rollar va panel xodimlari — faqat super-admin (`admins.manage`)     */
/* ------------------------------------------------------------------ */

peopleRouter.get(
  '/access',
  requirePermission('admins.manage'),
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, ...(await loadAccessOverview()) });
  }),
);

const roleBody = z
  .object({
    name: z.string().max(100).optional(),
    description: z.string().max(400).nullable().optional(),
    permissions: z.array(z.string().max(60)).max(50).optional(),
  })
  .strict();

peopleRouter.post(
  '/access/roles',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    const parsed = roleBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Rol ma\'lumotlarini to\'g\'ri kiriting.');
    res.json({ ok: true, ...(await createRole({ input: parsed.data, actor: actorOf(req), now: Date.now() })) });
  }),
);

peopleRouter.patch(
  '/access/roles/:roleId',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    const parsed = roleBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Rol ma\'lumotlarini to\'g\'ri kiriting.');
    const result = await updateRole({
      roleId: req.params.roleId!,
      input: parsed.data,
      actor: actorOf(req),
      now: Date.now(),
    });
    res.json({ ok: true, ...result });
  }),
);

peopleRouter.delete(
  '/access/roles/:roleId',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    await deleteRole({ roleId: req.params.roleId!, actor: actorOf(req), now: Date.now() });
    res.json({ ok: true });
  }),
);

const memberBody = z.object({
  email: z.string().min(3).max(200),
  roleId: z.string().min(1).max(60),
});

/**
 * Panel xodimini qo'shish. Hisob yo'q bo'lsa yaratiladi — vaqtinchalik
 * parol javobda BIR MARTA qaytadi (logga va jurnalga tushmaydi).
 */
peopleRouter.post(
  '/access/members',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    const parsed = memberBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Email va rolni kiriting.');
    const result = await addMember({ ...parsed.data, actor: actorOf(req), now: Date.now() });
    res.json({ ok: true, ...result });
  }),
);

peopleRouter.patch(
  '/access/members/:uid',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    const parsed = z.object({ roleId: z.string().min(1).max(60) }).safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Rolni tanlang.');
    await setMemberRole({ uid: req.params.uid!, roleId: parsed.data.roleId, actor: actorOf(req), now: Date.now() });
    res.json({ ok: true });
  }),
);

peopleRouter.delete(
  '/access/members/:uid',
  requirePermission('admins.manage'),
  asyncRoute(async (req, res) => {
    await removeMember({ uid: req.params.uid!, actor: actorOf(req), now: Date.now() });
    res.json({ ok: true });
  }),
);
