import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';

import {
  Alert,
  Badge,
  Button,
  ChipGroup,
  ConfirmDialog,
  DataTable,
  EmptyState,
  PageHeader,
  SearchInput,
  Stack,
  useTable,
  useToast,
  type Column,
  type MenuItem,
  type SortState,
  type Tone,
} from '@/components/ui';
import type { PlatformUser } from '@/lib/admin-types';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatDay, formatRelative } from '@/lib/dates';
import { formatNumber, formatPhone } from '@/lib/format';
import { useApi } from '@/lib/use-api';

const DAY = 86_400_000;
const ACTIVE_WINDOW = 30 * DAY;

type FilterId = 'all' | 'owners' | 'staff' | 'active' | 'never' | 'off';

const FILTERS: { id: FilterId; label: string }[] = [
  { id: 'all', label: 'Hammasi' },
  { id: 'owners', label: 'Egalar' },
  { id: 'staff', label: 'Xodimlar' },
  { id: 'active', label: 'Faol (30 kun)' },
  { id: 'never', label: 'Hali kirmagan' },
  { id: 'off', label: 'O\'chirilgan' },
];

function matchesFilter(u: PlatformUser, f: FilterId, now: number): boolean {
  switch (f) {
    case 'all':
      return true;
    case 'owners':
      return u.kind === 'owner';
    case 'staff':
      return u.kind === 'staff';
    case 'active':
      return u.lastActiveAt !== null && now - u.lastActiveAt <= ACTIVE_WINDOW;
    case 'never':
      return u.lastActiveAt === null;
    case 'off':
      return !u.active || u.disabled || u.tenantArchived;
  }
}

function matchesQuery(u: PlatformUser, q: string): boolean {
  if (!q) return true;
  const digits = q.replace(/\D/g, '');
  return (
    u.name.toLowerCase().includes(q) ||
    (u.login ?? '').includes(q) ||
    u.tenantName.toLowerCase().includes(q) ||
    (digits.length >= 3 && (u.phone ?? '').includes(digits))
  );
}

/** Holat — bitta, eng muhimi: nega bu odam hozir ishlay olmasligi mumkin. */
function userState(u: PlatformUser): { label: string; tone: Tone } {
  if (u.tenantArchived) return { label: 'Biznes arxivda', tone: 'neutral' };
  if (u.disabled) return { label: 'Hisob bloklangan', tone: 'danger' };
  if (!u.active) return { label: 'Ilovada o\'chirilgan', tone: 'warning' };
  if (u.lastActiveAt === null) return { label: 'Hali kirmagan', tone: 'neutral' };
  return { label: 'Faol', tone: 'success' };
}

const COLUMNS: Column<PlatformUser>[] = [
  {
    key: 'name',
    header: 'Foydalanuvchi',
    primary: true,
    sortValue: (u) => u.name,
    cell: (u) => (
      <>
        <span className="ui-table__primary">{u.name}</span>
        <span className="ui-table__sub">
          {u.kind === 'owner' ? (u.login ? `Login: ${u.login}` : 'Login yo\'q') : u.phone ? formatPhone(u.phone) : '—'}
        </span>
      </>
    ),
  },
  {
    key: 'kind',
    header: 'Turi',
    sortValue: (u) => u.kind,
    cell: (u) => <Badge tone={u.kind === 'owner' ? 'brand' : 'neutral'}>{u.kind === 'owner' ? 'Ega' : 'Xodim'}</Badge>,
  },
  {
    key: 'tenant',
    header: 'Biznes',
    sortValue: (u) => u.tenantName,
    cell: (u) => <Link to={`/admin/tenants/${u.tenantId}`}>{u.tenantName}</Link>,
  },
  {
    key: 'state',
    header: 'Holat',
    sortValue: (u) => userState(u).label,
    cell: (u) => {
      const s = userState(u);
      return (
        <Badge tone={s.tone} dot>
          {s.label}
        </Badge>
      );
    },
  },
  {
    key: 'active',
    header: 'Oxirgi faollik',
    sortValue: (u) => u.lastActiveAt,
    cell: (u) => (u.lastActiveAt ? formatRelative(u.lastActiveAt) : <span className="ui-muted">—</span>),
  },
  {
    key: 'created',
    header: 'Qo\'shilgan',
    hideOnMobile: true,
    sortValue: (u) => u.createdAt,
    cell: (u) => (u.createdAt ? formatDay(u.createdAt) : '—'),
  },
];

const SORT_KEYS = new Set(COLUMNS.filter((c) => c.sortValue).map((c) => c.key));
const DEFAULT_SORT: SortState = { key: 'active', dir: 'desc' };

function parseSort(raw: string | null): SortState {
  if (!raw) return DEFAULT_SORT;
  const [key = '', dir] = raw.split('-');
  return SORT_KEYS.has(key) ? { key, dir: dir === 'asc' ? 'asc' : 'desc' } : DEFAULT_SORT;
}

/**
 * Foydalanuvchilar — bizneslarning egalari va xodimlari.
 *
 * Asosiy savol: "bu odam kim, qaysi biznesdan, oxirgi marta qachon
 * ishlagan". Mijoz qo'ng'iroq qilganda uni ismi, logini yoki telefoni
 * bo'yicha topish uchun.
 */
export function UsersPage() {
  const { can } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [signOut, setSignOut] = useState<PlatformUser | null>(null);

  const query = params.get('q') ?? '';
  const filter: FilterId = FILTERS.find((f) => f.id === params.get('holat'))?.id ?? 'all';
  const sort = parseSort(params.get('tartib'));
  const page = Math.max(1, Number(params.get('sahifa')) || 1);
  const update = (patch: Record<string, string | null>) => {
    const next = new URLSearchParams(params);
    for (const [k, v] of Object.entries(patch)) {
      if (v === null || v === '') next.delete(k);
      else next.set(k, v);
    }
    setParams(next, { replace: true });
  };

  const { data: users, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/users',
    (json) => (json as { users: PlatformUser[] }).users,
  );

  // Sahifa ochilgan payt — "oxirgi 30 kun" filtri render sayin siljimasin.
  const [now] = useState(() => Date.now());
  const q = query.trim().toLowerCase();
  const searched = useMemo(() => users?.filter((u) => matchesQuery(u, q)) ?? null, [users, q]);
  const counts = useMemo(() => {
    const map = {} as Record<FilterId, number>;
    for (const f of FILTERS) map[f.id] = searched?.filter((u) => matchesFilter(u, f.id, now)).length ?? 0;
    return map;
  }, [searched, now]);
  const rows = useMemo(() => searched?.filter((u) => matchesFilter(u, filter, now)) ?? null, [searched, filter, now]);

  const table = useTable({
    rows,
    columns: COLUMNS,
    pageSize: 25,
    sort,
    onSortChange: (s) =>
      update({
        tartib: s.key === DEFAULT_SORT.key && s.dir === DEFAULT_SORT.dir ? null : `${s.key}-${s.dir}`,
        sahifa: null,
      }),
    page,
    onPageChange: (p) => update({ sahifa: p > 1 ? String(p) : null }),
  });

  const rowActions = (u: PlatformUser): MenuItem[] => [
    {
      id: 'tenant',
      label: 'Biznesni ochish',
      icon: 'building',
      disabled: !can('tenants.read'),
      onSelect: () => navigate(`/admin/tenants/${u.tenantId}`),
    },
    ...(can('users.manage')
      ? [
          {
            id: 'signout',
            label: 'Barcha qurilmalardan chiqarish',
            icon: 'logout' as const,
            disabled: !u.hasAccount,
            onSelect: () => setSignOut(u),
          },
        ]
      : []),
  ];

  if (error && !users) {
    return (
      <>
        <PageHeader title="Foydalanuvchilar" />
        <Alert
          tone="danger"
          title="Ro'yxatni yuklab bo'lmadi"
          action={
            <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
              Qayta urinish
            </Button>
          }
        >
          {error}
        </Alert>
      </>
    );
  }

  const owners = users?.filter((u) => u.kind === 'owner').length ?? 0;

  return (
    <>
      <PageHeader
        title="Foydalanuvchilar"
        description={
          users
            ? `${formatNumber(users.length)} ta: ${formatNumber(owners)} ega, ${formatNumber(users.length - owners)} xodim`
            : 'Yuklanmoqda…'
        }
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={4}>
        {error && users && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ro'yxat ko'rsatilmoqda. {error}
          </Alert>
        )}

        <div className="ui-toolbar">
          <div className="ui-toolbar__search">
            <SearchInput
              value={query}
              onChange={(v) => update({ q: v, sahifa: null })}
              placeholder="Ism, login, telefon yoki biznes"
              aria-label="Foydalanuvchilar orasidan qidirish"
              shortcut
            />
          </div>
          <ChipGroup
            label="Filtr"
            value={filter}
            onChange={(id) => update({ holat: id === 'all' ? null : id, sahifa: null })}
            options={FILTERS.map((f) => ({ ...f, count: counts[f.id] }))}
          />
        </div>

        <DataTable
          caption="Foydalanuvchilar"
          columns={COLUMNS}
          rows={loading ? null : (table.slice?.rows ?? null)}
          rowKey={(u) => u.uid}
          sort={table.sort}
          onSortChange={table.setSort}
          refreshing={refreshing}
          rowActions={rowActions}
          pagination={table.slice ? { slice: table.slice, onPageChange: table.setPage } : undefined}
          empty={
            users && users.length === 0 ? (
              <EmptyState
                icon="people"
                title="Hali foydalanuvchi yo'q"
                description="Biznes ro'yxatdan o'tgach, uning egasi va xodimlari shu yerda ko'rinadi."
                compact
              />
            ) : (
              <EmptyState
                title="Hech kim topilmadi"
                description={q ? `"${query.trim()}" bo'yicha mos foydalanuvchi yo'q.` : 'Bu filtr bo\'yicha hech kim yo\'q.'}
                action={
                  <Button variant="outline" size="sm" onClick={() => update({ q: null, holat: null, sahifa: null })}>
                    Filtrni tozalash
                  </Button>
                }
                compact
              />
            )
          }
        />
      </Stack>

      <ConfirmDialog
        open={signOut !== null}
        onClose={() => setSignOut(null)}
        icon="logout"
        title="Barcha qurilmalardan chiqarish"
        description={signOut ? `${signOut.name} — ${signOut.tenantName}` : undefined}
        consequences={[
          'Ochiq seanslar yopiladi — ilova ko\'pi bilan bir soat ichida qayta kirishni so\'raydi.',
          'Parol va PIN o\'zgarmaydi: egasi yoki xodim ular bilan yana kira oladi.',
          'Telefon yo\'qolganda yoki xodim ishdan ketganda foydali.',
        ]}
        confirmLabel="Chiqarish"
        onConfirm={async () => {
          if (!signOut) return;
          await api.post(`/api/v1/admin/users/${encodeURIComponent(signOut.uid)}/signout`, {});
          toast.success('Seanslar yopildi', signOut.name);
        }}
      />
    </>
  );
}
