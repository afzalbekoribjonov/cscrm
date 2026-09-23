/**
 * Foydalanuvchilar va panel xodimlari uchun NAMUNAVIY ma'lumot — FAQAT
 * ko'rib chiqish sahifasi (admin-preview.html) uchun. Xotirada turadi.
 */
import type { AccessOverview, AdminMember, AdminRole, PlatformUser } from '@/lib/admin-types';
import { ApiError } from '@/lib/api';
import type { Permission } from '@/lib/permissions';

const DAY = 86_400_000;
const HOUR = 3_600_000;

const FIRST = ['Ali', 'Dilnoza', 'Jasur', 'Malika', 'Sardor', 'Nodira', 'Bekzod', 'Gulnora', 'Otabek', 'Zarina'];
const LAST = ['Karimov', 'Tosheva', 'Rahimov', 'Yusupova', 'Aliyev', 'Qodirova', 'Ergashev', 'Nazarova'];
const TENANTS = ['Toza Gilam', 'Oq Parda', 'Nur Kimyoviy', 'Shabada', 'Musaffo', 'Yangi Uy', 'Orzu Servis', 'Tong Servis'];

function seedUsers(now: number): PlatformUser[] {
  const out: PlatformUser[] = [];
  TENANTS.forEach((tenantName, t) => {
    const tenantId = `t${t + 3}`;
    const archived = tenantName === 'Tong Servis';
    const login = tenantName.toLowerCase().replace(/[^a-z]/g, '');
    out.push({
      uid: `owner_${tenantId}`,
      kind: 'owner',
      tenantId,
      tenantName,
      tenantArchived: archived,
      name: login,
      login,
      active: true,
      hasAccount: true,
      createdAt: now - (t * 11 + 20) * DAY,
      lastActiveAt: t === 5 ? now - 45 * DAY : now - (t * 3 + 1) * HOUR,
      disabled: false,
    });
    for (let e = 0; e < (t % 4) + 1; e++) {
      const i = t * 3 + e;
      const never = i % 5 === 4;
      out.push({
        uid: `staff_${tenantId}_e${e + 1}`,
        kind: 'staff',
        tenantId,
        tenantName,
        tenantArchived: archived,
        name: `${FIRST[i % FIRST.length]} ${LAST[i % LAST.length]}`,
        phone: `99890${String(2000000 + i * 7331).slice(0, 7)}`,
        active: i % 7 !== 3,
        hasAccount: !never,
        createdAt: now - (i * 4 + 2) * DAY,
        lastActiveAt: never ? null : now - (i * 5 + 1) * 40 * 60_000,
        disabled: false,
      });
    }
  });
  return out;
}

export function createPeopleStore() {
  const now = Date.now();
  const users = seedUsers(now);
  let roles: Omit<AdminRole, 'memberCount'>[] = [
    {
      id: 'r1',
      name: 'Operator',
      description: 'To\'lovlarni tasdiqlaydi, bizneslarni ko\'radi',
      permissions: ['tenants.read', 'payments.manage', 'users.read'],
      createdAt: now - 20 * DAY,
      createdBy: 'preview',
    },
  ];
  let members: AdminMember[] = [
    {
      uid: 'm1',
      email: 'operator@cscrm.uz',
      roleId: 'r1',
      roleName: 'Operator',
      addedAt: now - 19 * DAY,
      lastSignInAt: now - 3 * HOUR,
      disabled: false,
    },
  ];
  let seq = 2;

  const overview = (): AccessOverview => ({
    roles: roles.map((r) => ({ ...r, memberCount: members.filter((m) => m.roleId === r.id).length })),
    members: members.map((m) => ({ ...m, roleName: roles.find((r) => r.id === m.roleId)?.name ?? null })),
    superAdmins: [{ uid: 'preview', email: 'admin@cscrm.uz', lastSignInAt: now - 5 * 60_000 }],
    permissions: [],
  });

  return function handle(method: string, pathname: string, body: Record<string, unknown>): unknown {
    const base = '/api/v1/admin';
    if (method === 'GET' && pathname === `${base}/users`) return { ok: true, users };
    const signout = pathname.match(/^\/api\/v1\/admin\/users\/([^/]+)\/signout$/);
    if (method === 'POST' && signout) return { ok: true };

    if (method === 'GET' && pathname === `${base}/access`) return { ok: true, ...overview() };

    if (method === 'POST' && pathname === `${base}/access/roles`) {
      const name = String(body.name ?? '').trim();
      if (roles.some((r) => r.name.toLowerCase() === name.toLowerCase())) {
        throw new ApiError('Bunday nomli rol bor. Boshqa nom tanlang.', 409);
      }
      const id = `r${seq++}`;
      roles.push({
        id,
        name,
        ...(body.description ? { description: String(body.description) } : {}),
        permissions: (body.permissions as Permission[]) ?? [],
        createdAt: Date.now(),
        createdBy: 'preview',
      });
      return { ok: true, id };
    }
    const role = pathname.match(/^\/api\/v1\/admin\/access\/roles\/([^/]+)$/);
    if (role) {
      const r = roles.find((x) => x.id === role[1]);
      if (!r) throw new ApiError('Rol topilmadi.', 404);
      if (method === 'PATCH') {
        Object.assign(r, {
          name: String(body.name ?? r.name),
          description: body.description ? String(body.description) : undefined,
          permissions: (body.permissions as Permission[]) ?? r.permissions,
        });
        return { ok: true, changed: ['name'] };
      }
      if (method === 'DELETE') {
        roles = roles.filter((x) => x !== r);
        return { ok: true };
      }
    }

    if (method === 'POST' && pathname === `${base}/access/members`) {
      const email = String(body.email).trim().toLowerCase();
      if (email.endsWith('@cscrm.local')) {
        throw new ApiError('Bu biznes egasining ilova logini. Panel uchun alohida email kiriting.', 400);
      }
      if (members.some((m) => m.email === email)) {
        throw new ApiError('Bu xodim allaqachon panelda. Rolini ro\'yxatdan o\'zgartiring.', 409);
      }
      members.push({
        uid: `m${seq++}`,
        email,
        roleId: String(body.roleId),
        roleName: null,
        addedAt: Date.now(),
        lastSignInAt: null,
        disabled: false,
      });
      return { ok: true, created: true, temporaryPassword: 'Kd7mPq2xRt4w' };
    }
    const member = pathname.match(/^\/api\/v1\/admin\/access\/members\/([^/]+)$/);
    if (member) {
      const m = members.find((x) => x.uid === member[1]);
      if (!m) throw new ApiError('Xodim topilmadi.', 404);
      if (method === 'PATCH') {
        m.roleId = String(body.roleId);
        return { ok: true };
      }
      if (method === 'DELETE') {
        members = members.filter((x) => x !== m);
        return { ok: true };
      }
    }
    return undefined;
  };
}

/** Xabarlar, tarif narxlari, sayt sozlamalari — xotirada. */
export function createContentStore(basePlans: { id: string; price: number }[]) {
  const now = Date.now();
  let broadcasts = [
    { id: 'b1', title: 'Yangi imkoniyat: qarzdorlar hisoboti', body: 'Endi qarzdor mijozlar ro\'yxatini bir bosishda ko\'rasiz.', kind: 'yangilik', createdAt: now - 2 * DAY, expiresAt: null },
    { id: 'b2', title: 'Texnik ishlar', body: 'Yakshanba 02:00–03:00 da ilova qisqa vaqt ishlamasligi mumkin.', kind: 'eslatma', createdAt: now - 12 * DAY, expiresAt: now - 5 * DAY },
  ];
  const prices = new Map<string, number>();
  let settings = { downloadUrl: 'https://example.uz/cscrm.apk', version: '1.4.0', sizeMb: 54.5, note: 'Tezroq ishlaydi', updatedAt: now - 3 * DAY };

  return function handle(method: string, pathname: string, body: Record<string, unknown>): unknown {
    const base = '/api/v1/admin';
    if (pathname === `${base}/broadcasts`) {
      if (method === 'GET') return { ok: true, broadcasts };
      if (method === 'POST') {
        broadcasts = [{ id: `b${Date.now()}`, title: String(body.title), body: String(body.body), kind: String(body.kind), createdAt: Date.now(), expiresAt: (body.expiresAt as number) ?? null }, ...broadcasts];
        return { ok: true };
      }
    }
    const b = pathname.match(/^\/api\/v1\/admin\/broadcasts\/([^/]+)$/);
    if (b && method === 'DELETE') {
      broadcasts = broadcasts.filter((x) => x.id !== b[1]);
      return { ok: true };
    }
    const p = pathname.match(/^\/api\/v1\/admin\/plans\/([^/]+)\/price$/);
    if (p) {
      if (method === 'POST') prices.set(p[1]!, Number(body.price));
      if (method === 'DELETE') prices.delete(p[1]!);
      return { ok: true };
    }
    if (method === 'GET' && pathname === `${base}/plans`) {
      return { ok: true, plans: basePlans.map((x) => ({ ...x, price: prices.get(x.id) ?? x.price })) };
    }
    if (pathname === `${base}/site-settings`) {
      if (method === 'PUT') settings = { ...(body as typeof settings), updatedAt: Date.now() };
      return { ok: true, settings };
    }
    return undefined;
  };
}
