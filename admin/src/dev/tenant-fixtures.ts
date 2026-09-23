/**
 * Bizneslar bo'limi uchun NAMUNAVIY ma'lumot — FAQAT ko'rib chiqish
 * sahifasi (admin-preview.html) uchun. Xotirada turadi: amallar
 * (arxivlash, to'lov, tahrirlash) shu ro'yxatni o'zgartiradi, sahifa
 * yangilansa asliga qaytadi. Haqiqiy server va bazaga ULANMAYDI.
 */
import type {
  ArchiveInfo,
  AuditAction,
  AuditEntry,
  LicenseState,
  LicenseStatus,
  OwnerCredentials,
  PaymentRecord,
  PaymentRequestRecord,
  PendingPayment,
  TenantDetail,
  TenantSummary,
} from '@/lib/admin-types';
import { ApiError } from '@/lib/api';
import { formatNumber } from '@/lib/format';
import { plans, type Plan } from '@/lib/plans';

const DAY = 86_400_000;
const HOUR = 3_600_000;
const ACTOR = { uid: 'preview', email: 'admin@cscrm.uz' };

interface Row {
  tenantId: string;
  name: string;
  phone?: string;
  address?: string;
  createdAt: number;
  planId: string;
  kind: 'trial' | 'subscription' | 'lifetime';
  startedAt: number;
  expiresAt: number | null;
  nextAnnualFeeAt?: number | null;
  suspended?: boolean;
  suspendedReason?: string | null;
  archive: ArchiveInfo | null;
  lastActiveAt: number | null;
  employeeCount: number;
  orderCount: number;
  payments: PaymentRecord[];
  request: PaymentRequestRecord | null;
  login: string;
}

const NAMES = [
  'Toza Gilam', "G'olib Servis", 'Oq Parda', 'Nur Kimyoviy', 'Shabada', 'Bahor Kir Yuvish',
  'Musaffo', 'Yangi Uy', 'Sof Gilam', 'Orzu Servis', 'Chinor Tozalash', "Oltin Qo'l",
  'Barakali Xizmat', 'Ipak Yo\'li Gilam', 'Moviy Osmon', 'Zilol', 'Samarqand Gilam', 'Tong Servis',
  'Iqbol', 'Yashil Vodiy', 'Mehr Tozalik', 'Shoxrux Servis', 'Kamalak', 'Diyor Gilam',
];

function planOf(id: string): Plan {
  return plans.find((p) => p.id === id) ?? plans[0]!;
}

function seed(now: number): Row[] {
  return NAMES.map((name, i) => {
    const createdAt = now - (i * 9 + 3) * DAY - i * HOUR;
    const planId = i % 7 === 0 ? 'trial' : i % 11 === 5 ? 'lifetime' : ['m1', 'm3', 'y1', 'm5'][i % 4]!;
    const plan = planOf(planId);
    const daysLeft = [24, 2, -3, 61, 5, 140, -1, 12, 33, 1, 88, 7][i % 12]!;
    const lifetime = plan.kind === 'lifetime';
    const payments: PaymentRecord[] =
      plan.kind === 'trial'
        ? []
        : Array.from({ length: 1 + (i % 3) }, (_, k) => ({
            id: `p${i}_${k}`,
            planId,
            planName: plan.name,
            amount: plan.price,
            confirmedBy: 'preview',
            confirmedAt: now - (k * 40 + 6 + i) * DAY,
            ...(k === 0 && i % 2 ? { note: 'Chek: 00' + (4812 + i) } : {}),
            newExpiresAt: lifetime ? null : now + daysLeft * DAY - k * 30 * DAY,
          }));
    return {
      tenantId: `t${i + 1}`,
      name,
      ...(i % 5 === 3 ? {} : { phone: `99890${String(1234567 + i * 7919).slice(0, 7)}` }),
      ...(i % 3 === 0 ? { address: `Toshkent, ${['Chilonzor', 'Yunusobod', 'Sergeli'][i % 3]} tumani, ${10 + i}-uy` } : {}),
      createdAt,
      planId,
      kind: plan.kind,
      startedAt: createdAt,
      expiresAt: lifetime ? null : now + daysLeft * DAY,
      ...(lifetime ? { nextAnnualFeeAt: now + 140 * DAY } : {}),
      ...(i === 8 ? { suspended: true, suspendedReason: 'To\'lov bo\'yicha kelishuv buzildi' } : {}),
      archive:
        i === 17
          ? { archivedAt: now - 18 * DAY, purgeAfter: now + 12 * DAY, reason: 'Egasi faoliyatni to\'xtatdi' }
          : null,
      lastActiveAt: i % 6 === 4 ? null : now - (i * 37 + 5) * 60_000 * (i % 4 === 0 ? 30 : 1),
      employeeCount: 1 + (i % 6),
      orderCount: (i * 137) % 900,
      payments,
      request:
        i === 1 || i === 4
          ? {
              id: `rq${i}`,
              planId: i === 1 ? 'm3' : 'm1',
              planName: i === 1 ? '3 oylik' : '1 oylik',
              amount: i === 1 ? 537_000 : 199_000,
              reference: i === 1 ? '8600 **** 4412' : undefined,
              note: i === 4 ? 'Click orqali to\'ladim' : undefined,
              createdAt: now - (i === 1 ? 3 : 26) * HOUR,
              createdBy: 'owner',
              status: 'pending',
            }
          : i === 2
            ? {
                id: 'rq2',
                planId: 'm1',
                planName: '1 oylik',
                amount: 199_000,
                createdAt: now - 9 * DAY,
                createdBy: 'owner',
                status: 'rejected',
                resolvedAt: now - 8 * DAY,
                rejectReason: 'To\'lov kartaga tushmagan',
              }
            : null,
      login: name.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 12) || `biznes${i}`,
    };
  });
}

function stateOf(r: Row, now: number): LicenseStatus {
  const daysLeft =
    r.kind === 'lifetime'
      ? r.nextAnnualFeeAt
        ? Math.ceil((r.nextAnnualFeeAt - now) / DAY)
        : null
      : r.expiresAt
        ? Math.ceil((r.expiresAt - now) / DAY)
        : null;
  let state: LicenseState = 'active';
  if (r.suspended) state = 'suspended';
  else if (r.kind !== 'lifetime' && daysLeft !== null && daysLeft < 0) state = 'expired';
  else if (daysLeft !== null && daysLeft <= 3) state = r.kind === 'lifetime' ? 'lifetime_fee_due' : 'expiring';
  const blocked = state === 'suspended' || state === 'expired';
  return {
    tenantId: r.tenantId,
    state,
    planId: r.planId,
    kind: r.kind,
    expiresAt: r.expiresAt,
    daysLeft,
    checkedAt: now,
    message: r.suspended
      ? r.suspendedReason ?? 'Hisob to\'xtatilgan.'
      : blocked
        ? 'Obuna muddati tugagan. To\'lov qiling.'
        : daysLeft !== null && daysLeft <= 7
          ? `Obuna ${daysLeft} kundan keyin tugaydi.`
          : '',
    blocked,
  };
}

function summary(r: Row, now: number): TenantSummary {
  return {
    tenantId: r.tenantId,
    name: r.name,
    ...(r.phone ? { phone: r.phone } : {}),
    createdAt: r.createdAt,
    status: stateOf(r, now),
    planName: planOf(r.planId).name,
    archive: r.archive,
    lastActiveAt: r.lastActiveAt,
  };
}

function detail(r: Row, now: number): TenantDetail {
  return {
    ...summary(r, now),
    ...(r.address ? { address: r.address } : {}),
    license: {
      planId: r.planId,
      kind: r.kind,
      startedAt: r.startedAt,
      expiresAt: r.expiresAt,
      nextAnnualFeeAt: r.nextAnnualFeeAt ?? null,
      suspended: r.suspended ?? false,
      suspendedReason: r.suspendedReason ?? null,
    },
    payments: [...r.payments].sort((a, b) => b.confirmedAt - a.confirmedAt),
    employeeCount: r.employeeCount,
    orderCount: r.orderCount,
    paymentRequest: r.request,
  };
}

/** Xotiradagi "server". `handle` — topilmasa `undefined` (boshqa yo'l). */
export function createTenantStore(empty: boolean) {
  let rows = empty ? [] : seed(Date.now());
  const audit: AuditEntry[] = [];
  let auditSeq = 0;

  const log = (action: AuditAction, r: Row, extra: Partial<AuditEntry> = {}) => {
    audit.unshift({ id: `a${++auditSeq}`, at: Date.now(), action, actor: ACTOR, tenantId: r.tenantId, tenantName: r.name, ...extra });
  };

  if (!empty) {
    const r = rows[3]!;
    audit.push(
      { id: 'a-old1', at: Date.now() - 2 * DAY, action: 'tenant.update', actor: ACTOR, tenantId: r.tenantId, tenantName: r.name, changes: { phone: { from: null, to: '998901234567' } } },
      { id: 'a-old2', at: Date.now() - 5 * DAY, action: 'license.update', actor: ACTOR, tenantId: r.tenantId, tenantName: r.name, note: 'Texnik nosozlik uchun kompensatsiya', changes: { expiresAt: { from: Date.now() + 54 * DAY, to: Date.now() + 61 * DAY } } },
    );
  }

  const find = (id: string) => {
    const r = rows.find((x) => x.tenantId === id);
    if (!r) throw new ApiError('Biznes topilmadi.', 404);
    return r;
  };
  const notArchived = (r: Row) => {
    if (r.archive) throw new ApiError('Biznes arxivda. Avval arxivdan qaytaring.', 409);
  };

  return function handle(method: string, pathname: string, body: Record<string, unknown>): unknown {
    const now = Date.now();
    const base = '/api/v1/admin';

    if (method === 'GET' && pathname === `${base}/tenants`) {
      return { ok: true, tenants: rows.map((r) => summary(r, now)) };
    }
    if (method === 'GET' && pathname === `${base}/plans`) return { ok: true, plans };
    if (method === 'GET' && pathname === `${base}/payment-requests`) {
      const requests: PendingPayment[] = rows
        .filter((r) => r.request?.status === 'pending')
        .map((r) => ({ ...r.request!, tenantId: r.tenantId, tenantName: r.name }));
      return { ok: true, requests, plans };
    }
    if (method === 'GET' && pathname === `${base}/audit`) return { ok: true, entries: audit.slice(0, 100) };

    const m = pathname.match(/^\/api\/v1\/admin\/tenants\/([^/]+)(?:\/(.+))?$/);
    if (!m) return undefined;
    const [, id = '', rest = ''] = m;

    if (method === 'GET' && rest === '') return { ok: true, tenant: detail(find(id), now), plans };
    if (method === 'GET' && rest === 'audit') {
      return { ok: true, entries: audit.filter((a) => a.tenantId === id) };
    }
    if (method === 'GET' && rest === 'credentials') {
      const r = find(id);
      const creds: OwnerCredentials = {
        uid: `owner_${id}`,
        login: r.login,
        email: `${r.login}@cscrm.local`,
        lastSignInAt: r.lastActiveAt ? new Date(r.lastActiveAt).toUTCString() : null,
        disabled: false,
      };
      return { ok: true, credentials: creds };
    }

    const r = find(id);
    switch (`${method} ${rest}`) {
      case 'PATCH profile': {
        notArchived(r);
        const changes: Record<string, { from: unknown; to: unknown }> = {};
        for (const key of ['name', 'phone', 'address'] as const) {
          if (!(key in body)) continue;
          const to = (body[key] as string | null) || undefined;
          if ((r[key] ?? undefined) !== to) {
            changes[key] = { from: r[key] ?? null, to: to ?? null };
            if (key === 'name') r.name = to ?? r.name;
            else r[key] = to;
          }
        }
        if (Object.keys(changes).length) log('tenant.update', r, { changes });
        return { ok: true, changed: Object.keys(changes) };
      }
      case 'PUT license': {
        notArchived(r);
        const plan = planOf(String(body.planId));
        const before = { planId: r.planId, expiresAt: r.expiresAt, nextAnnualFeeAt: r.nextAnnualFeeAt ?? null };
        r.planId = plan.id;
        r.kind = plan.kind;
        if (plan.kind === 'lifetime') {
          r.expiresAt = null;
          r.nextAnnualFeeAt = body.nextAnnualFeeAt as number;
        } else {
          r.expiresAt = body.expiresAt as number;
          r.nextAnnualFeeAt = null;
        }
        const after = { planId: r.planId, expiresAt: r.expiresAt, nextAnnualFeeAt: r.nextAnnualFeeAt ?? null };
        const changes = Object.fromEntries(
          Object.entries(after)
            .filter(([k, v]) => before[k as keyof typeof before] !== v)
            .map(([k, v]) => [k, { from: before[k as keyof typeof before], to: v }]),
        );
        log('license.update', r, { note: String(body.reason), changes });
        return { ok: true };
      }
      case 'POST confirm-payment': {
        notArchived(r);
        const plan = planOf(String(body.planId));
        const base0 = Math.max(now, r.expiresAt ?? now);
        const until = plan.kind === 'lifetime' ? null : base0 + (plan.months ?? 1) * 30 * DAY;
        r.payments.push({
          id: `p${now}`,
          planId: plan.id,
          planName: plan.name,
          amount: Number(body.amount) || plan.price,
          confirmedBy: 'preview',
          confirmedAt: now,
          ...(body.note ? { note: String(body.note) } : {}),
          newExpiresAt: until,
        });
        r.planId = plan.id;
        r.kind = plan.kind;
        r.expiresAt = until;
        if (body.requestId && r.request) r.request = { ...r.request, status: 'approved', resolvedAt: now };
        log('payment.confirm', r, { note: `${plan.name} · ${formatNumber(Number(body.amount) || plan.price)} so'm` });
        return { ok: true };
      }
      case 'POST suspend': {
        notArchived(r);
        r.suspended = Boolean(body.suspended);
        r.suspendedReason = r.suspended ? String(body.reason) : null;
        log(r.suspended ? 'tenant.suspend' : 'tenant.unsuspend', r, r.suspended ? { note: String(body.reason) } : {});
        return { ok: true };
      }
      case 'POST archive': {
        notArchived(r);
        r.archive = { archivedAt: now, purgeAfter: now + 30 * DAY, reason: String(body.reason) };
        log('tenant.archive', r, { note: String(body.reason) });
        return { ok: true };
      }
      case 'POST restore': {
        r.archive = null;
        log('tenant.restore', r);
        return { ok: true };
      }
      case 'DELETE ': {
        if (!r.archive) throw new ApiError('Faqat arxivdagi biznesni o\'chirish mumkin.', 409);
        rows = rows.filter((x) => x !== r);
        log('tenant.delete', r);
        return { ok: true };
      }
      case 'POST credentials': {
        notArchived(r);
        if (typeof body.login === 'string') {
          if (body.login === 'band') throw new ApiError('Bu login band. Boshqasini tanlang.', 400);
          r.login = body.login;
          log('credentials.login', r, { note: `Yangi login: ${body.login}` });
        }
        if (typeof body.password === 'string') log('credentials.password', r);
        return { ok: true, changed: [] };
      }
    }
    const reject = rest.match(/^payment-requests\/([^/]+)\/reject$/);
    if (method === 'POST' && reject && r.request) {
      r.request = { ...r.request, status: 'rejected', resolvedAt: now, rejectReason: String(body.reason) };
      log('payment.reject', r, { note: String(body.reason) });
      return { ok: true };
    }
    return undefined;
  };
}
