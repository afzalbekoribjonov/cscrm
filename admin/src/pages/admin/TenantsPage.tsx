import { useMemo } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';

import {
  Alert,
  Button,
  ChipGroup,
  DataTable,
  EmptyState,
  PageHeader,
  SearchInput,
  Stack,
  useTable,
  type Column,
  type SortState,
} from '@/components/ui';
import type { LicenseState, TenantSummary } from '@/lib/admin-types';
import { formatDay, formatRelative } from '@/lib/dates';
import { formatNumber, formatPhone } from '@/lib/format';
import type { Plan } from '@/lib/plans';
import { useApi } from '@/lib/use-api';

import { tenantRef, useTenantActions } from './tenant/actions';
import { purgeText, TenantBadge, termText } from './tenant/status';

/** Filtrlar. "Hammasi" — arxivdagilarsiz: ular alohida, o'chirilish arafasida. */
type FilterId = 'all' | 'attention' | 'active' | 'trial' | 'lifetime' | 'blocked' | 'archived';

const FILTERS: { id: FilterId; label: string }[] = [
  { id: 'all', label: 'Hammasi' },
  { id: 'attention', label: 'Diqqat talab' },
  { id: 'active', label: 'Faol' },
  { id: 'trial', label: 'Sinovda' },
  { id: 'lifetime', label: 'Bir umrlik' },
  { id: 'blocked', label: 'Bloklangan' },
  { id: 'archived', label: 'Arxivda' },
];

/**
 * "Diqqat talab" — bloklangan yoki muddati yaqinlar.
 *
 * Panelning asosiy savoli "kim bilan bugun ishlash kerak" — shu filtr
 * aynan shunga javob beradi.
 */
const NEEDS_ATTENTION: LicenseState[] = ['expired', 'suspended', 'grace', 'expiring', 'lifetime_fee_due'];

function matchesFilter(t: TenantSummary, filter: FilterId): boolean {
  if (filter === 'archived') return t.archive !== null;
  if (t.archive) return false;
  switch (filter) {
    case 'all':
      return true;
    case 'attention':
      return NEEDS_ATTENTION.includes(t.status.state);
    case 'active':
      // To'lagan va ishlayapti (muddati yaqinlari ham).
      return !t.status.blocked && t.status.kind !== 'trial';
    case 'trial':
      return !t.status.blocked && t.status.kind === 'trial';
    case 'lifetime':
      return t.status.kind === 'lifetime';
    case 'blocked':
      return t.status.blocked;
  }
}

/** Muhimlik: bloklangan → muddati yaqin → qolganlari; ichida — kam kun qolgani oldin. */
function urgency(t: TenantSummary): number {
  const group = t.status.blocked ? 0 : NEEDS_ATTENTION.includes(t.status.state) ? 1 : 2;
  const days = Math.max(-9999, Math.min(9999, t.status.daysLeft ?? 9999));
  return group * 100_000 + days;
}

function matchesQuery(t: TenantSummary, q: string): boolean {
  if (!q) return true;
  const digits = q.replace(/\D/g, '');
  return (
    t.name.toLowerCase().includes(q) ||
    t.tenantId.toLowerCase().includes(q) ||
    (digits.length >= 3 && (t.phone ?? '').replace(/\D/g, '').includes(digits))
  );
}

const COLUMNS: Column<TenantSummary>[] = [
  {
    key: 'name',
    header: 'Biznes',
    primary: true,
    sortValue: (t) => t.name,
    cell: (t) => (
      <>
        <Link to={`/admin/tenants/${t.tenantId}`} className="ui-table__primary">
          {t.name}
        </Link>
        <span className="ui-table__sub">{t.phone ? formatPhone(t.phone) : 'Telefon kiritilmagan'}</span>
      </>
    ),
  },
  {
    key: 'status',
    header: 'Holat',
    sortValue: urgency,
    cell: (t) => (
      <span>
        <TenantBadge tenant={t} />
        {t.archive && <span className="ui-table__sub">{purgeText(t.archive)}</span>}
      </span>
    ),
  },
  { key: 'plan', header: 'Reja', sortValue: (t) => t.planName, cell: (t) => t.planName },
  {
    key: 'term',
    header: 'Muddat',
    // Bir umrlik — muddatsiz, saralashda oxirida.
    sortValue: (t) => (t.status.kind === 'lifetime' ? null : t.status.expiresAt),
    cell: (t) => {
      const term = termText(t.status);
      return (
        <span>
          {term.main}
          {term.sub && <span className="ui-table__sub">{term.sub}</span>}
        </span>
      );
    },
  },
  {
    key: 'active',
    header: 'Oxirgi faollik',
    sortValue: (t) => t.lastActiveAt,
    cell: (t) => (t.lastActiveAt ? formatRelative(t.lastActiveAt) : <span className="ui-muted">Ma'lumot yo'q</span>),
  },
  {
    key: 'created',
    header: 'Qo\'shilgan',
    hideOnMobile: true,
    sortValue: (t) => t.createdAt,
    cell: (t) => formatDay(t.createdAt),
  },
];

const SORT_KEYS = new Set(COLUMNS.filter((c) => c.sortValue).map((c) => c.key));
const DEFAULT_SORT: SortState = { key: 'status', dir: 'asc' };
const PAGE_SIZE = 20;

/** `?tartib=muddat-desc` ↔ `{ key, dir }`. */
function parseSort(raw: string | null): SortState {
  if (!raw) return DEFAULT_SORT;
  const [key = '', dir] = raw.split('-');
  if (!SORT_KEYS.has(key)) return DEFAULT_SORT;
  return { key, dir: dir === 'desc' ? 'desc' : 'asc' };
}

/**
 * Bizneslar ro'yxati.
 *
 * Qidiruv, filtr, saralash va sahifa URL'da (`?q=&holat=&tartib=&sahifa=`):
 * biznes kartasidan orqaga qaytilganda ro'yxat o'sha holatida turadi,
 * havolani boshqasiga yuborish ham mumkin.
 */
export function TenantsPage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();

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

  const { data: tenants, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/tenants',
    (json) => (json as { tenants: TenantSummary[] }).tenants,
  );
  const { data: plans } = useApi('/api/v1/admin/plans', (json) => (json as { plans: Plan[] }).plans, {
    staleMs: 10 * 60_000,
  });

  const actions = useTenantActions({ plans: plans ?? [], onChanged: reload });

  const q = query.trim().toLowerCase();
  const searched = useMemo(() => tenants?.filter((t) => matchesQuery(t, q)) ?? null, [tenants, q]);

  /** Har filtr yonidagi son — qidiruvni hisobga olib. */
  const counts = useMemo(() => {
    const map = {} as Record<FilterId, number>;
    for (const f of FILTERS) map[f.id] = searched?.filter((t) => matchesFilter(t, f.id)).length ?? 0;
    return map;
  }, [searched]);

  const rows = useMemo(() => searched?.filter((t) => matchesFilter(t, filter)) ?? null, [searched, filter]);

  const table = useTable({
    rows,
    columns: COLUMNS,
    pageSize: PAGE_SIZE,
    sort,
    onSortChange: (s) =>
      update({
        tartib: s.key === DEFAULT_SORT.key && s.dir === DEFAULT_SORT.dir ? null : `${s.key}-${s.dir}`,
        sahifa: null,
      }),
    page,
    onPageChange: (p) => update({ sahifa: p > 1 ? String(p) : null }),
  });

  // `paginate` mavjud bo'lmagan sahifani (ro'yxat qisqargan) oxirgisiga tushiradi.
  const slice = table.slice;

  if (error && !tenants) {
    return (
      <>
        <PageHeader title="Bizneslar" />
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

  const total = tenants?.filter((t) => !t.archive).length ?? 0;
  const noTenantsAtAll = tenants !== null && tenants.length === 0;

  return (
    <>
      <PageHeader
        title="Bizneslar"
        description={tenants ? `${formatNumber(total)} ta biznes` : 'Yuklanmoqda…'}
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={4}>
        {error && tenants && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ro'yxat ko'rsatilmoqda. {error}
          </Alert>
        )}

        <div className="ui-toolbar">
          <div className="ui-toolbar__search">
            <SearchInput
              value={query}
              onChange={(v) => update({ q: v, sahifa: null })}
              placeholder="Nom, telefon yoki ID"
              aria-label="Bizneslar orasidan qidirish"
              shortcut
            />
          </div>
          <ChipGroup
            label="Holat bo'yicha filtr"
            value={filter}
            onChange={(id) => update({ holat: id === 'all' ? null : id, sahifa: null })}
            options={FILTERS.map((f) => ({ ...f, count: counts[f.id] }))}
          />
        </div>

        <DataTable
          caption="Bizneslar"
          columns={COLUMNS}
          rows={loading ? null : (slice?.rows ?? null)}
          rowKey={(t) => t.tenantId}
          sort={table.sort}
          onSortChange={table.setSort}
          refreshing={refreshing}
          rowActions={(t) =>
            actions.menuItems(tenantRef(t), { openLink: () => navigate(`/admin/tenants/${t.tenantId}`) })
          }
          pagination={slice ? { slice, onPageChange: table.setPage } : undefined}
          empty={
            noTenantsAtAll ? (
              <EmptyState
                icon="building"
                title="Hali birorta biznes yo'q"
                description="Biznes egasi ilovada ro'yxatdan o'tgach, u shu yerda paydo bo'ladi."
                compact
              />
            ) : (
              <EmptyState
                title="Hech narsa topilmadi"
                description={
                  q ? `"${query.trim()}" bo'yicha mos biznes yo'q.` : 'Bu filtr bo\'yicha biznes yo\'q.'
                }
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

      {actions.dialogs}
    </>
  );
}
