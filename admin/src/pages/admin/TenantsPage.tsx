import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';

import { api } from '@/lib/api';
import {
  formatDate,
  stateVisual,
  type LicenseState,
  type TenantSummary,
} from '@/lib/admin-types';

/** Filtr guruhlari — har biri bir nechta holatni qamrab oladi. */
type FilterId = 'all' | 'attention' | 'active' | 'trial' | 'lifetime' | 'blocked';

const FILTERS: { id: FilterId; label: string }[] = [
  { id: 'all', label: 'Hammasi' },
  { id: 'attention', label: 'Diqqat talab qiladi' },
  { id: 'active', label: 'Faol' },
  { id: 'trial', label: 'Sinovda' },
  { id: 'lifetime', label: 'Bir umrlik' },
  { id: 'blocked', label: 'Bloklangan' },
];

/**
 * "Diqqat talab qiladi" — bloklangan yoki muddati yaqinlar.
 *
 * Panelning asosiy savoli "kim bilan bugun ishlash kerak" — shu filtr
 * aynan shunga javob beradi.
 */
const NEEDS_ATTENTION: LicenseState[] = [
  'expired',
  'suspended',
  'grace',
  'expiring',
  'lifetime_fee_due',
];

function matchesFilter(t: TenantSummary, filter: FilterId): boolean {
  switch (filter) {
    case 'all':
      return true;
    case 'attention':
      return NEEDS_ATTENTION.includes(t.status.state);
    case 'active':
      return t.status.state === 'active';
    case 'trial':
      return t.status.kind === 'trial';
    case 'lifetime':
      return t.status.kind === 'lifetime';
    case 'blocked':
      return t.status.blocked;
  }
}

type SortId = 'attention' | 'name' | 'expires' | 'created';

/** Muhimlik: bloklangan → muddati yaqin → faol. */
function urgency(t: TenantSummary): number {
  if (t.status.blocked) return 0;
  if (NEEDS_ATTENTION.includes(t.status.state)) return 1;
  return 2;
}

export function TenantsPage() {
  const [tenants, setTenants] = useState<TenantSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<FilterId>('all');
  const [sort, setSort] = useState<SortId>('attention');
  const [asc, setAsc] = useState(true);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    api
      .get<{ tenants: TenantSummary[] }>('/api/v1/admin/tenants')
      .then((r) => setTenants(r.tenants))
      .catch((e) => setError(e instanceof Error ? e.message : 'Xatolik'));
  }, []);

  // "/" bilan qidiruvga o'tish — ko'p ishlatiladigan amal, sichqonchani
  // olishga hojat qolmasin.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
      const el = document.activeElement;
      if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) {
        return;
      }
      e.preventDefault();
      searchRef.current?.focus();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  /** Har bir filtr yonida nechta biznes borligi — qidiruvni hisobga olib. */
  const searched = useMemo(() => {
    if (!tenants) return null;
    const q = query.trim().toLowerCase();
    if (!q) return tenants;
    return tenants.filter(
      (t) =>
        t.name.toLowerCase().includes(q) ||
        t.tenantId.toLowerCase().includes(q) ||
        (t.phone ?? '').includes(q),
    );
  }, [tenants, query]);

  const counts = useMemo(() => {
    const map = {} as Record<FilterId, number>;
    for (const f of FILTERS) {
      map[f.id] = (searched ?? []).filter((t) => matchesFilter(t, f.id)).length;
    }
    return map;
  }, [searched]);

  const rows = useMemo(() => {
    if (!searched) return null;
    const list = searched.filter((t) => matchesFilter(t, filter));

    const dir = asc ? 1 : -1;
    return [...list].sort((a, b) => {
      switch (sort) {
        case 'name':
          return dir * a.name.localeCompare(b.name, 'uz');
        case 'created':
          return dir * (a.createdAt - b.createdAt);
        case 'expires':
          // Bir umrlik muddatsiz — u doim oxirida tursin.
          return (
            dir *
            ((a.status.expiresAt ?? Number.MAX_SAFE_INTEGER) -
              (b.status.expiresAt ?? Number.MAX_SAFE_INTEGER))
          );
        case 'attention': {
          const byUrgency = urgency(a) - urgency(b);
          if (byUrgency !== 0) return dir * byUrgency;
          return (
            dir *
            ((a.status.daysLeft ?? 1e9) - (b.status.daysLeft ?? 1e9))
          );
        }
      }
    });
  }, [searched, filter, sort, asc]);

  function toggleSort(id: SortId) {
    if (sort === id) setAsc((v) => !v);
    else {
      setSort(id);
      setAsc(true);
    }
  }

  if (error) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!rows) return <p className="muted">Yuklanmoqda…</p>;

  return (
    <>
      <div className="page-title">
        <h1>Bizneslar</h1>
        <span className="muted">
          {rows.length} ta
          {tenants && rows.length !== tenants.length && ` / ${tenants.length}`}
        </span>
      </div>

      <div className="toolbar">
        <div className="search-box">
          <input
            ref={searchRef}
            type="search"
            placeholder="Nom, ID yoki telefon…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            aria-label="Bizneslar orasidan qidirish"
          />
          {!query && <span className="search-box__hint">/</span>}
        </div>

        <div className="chips">
          {FILTERS.map((f) => (
            <button
              key={f.id}
              type="button"
              className={`chip${filter === f.id ? ' is-active' : ''}`}
              onClick={() => setFilter(f.id)}
              aria-pressed={filter === f.id}
            >
              {f.label}
              <span className="chip__count">{counts[f.id]}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="table-wrap">
        {rows.length === 0 ? (
          <p className="empty-state">
            {tenants && tenants.length === 0
              ? 'Hali birorta biznes ro\'yxatdan o\'tmagan.'
              : 'Bu shart bo\'yicha hech narsa topilmadi.'}
          </p>
        ) : (
          <div className="table-scroll">
            <table className="data-table">
              <thead>
                <tr>
                  <th>
                    <SortButton
                      id="name"
                      label="Biznes"
                      sort={sort}
                      asc={asc}
                      onSort={toggleSort}
                    />
                  </th>
                  <th>
                    <SortButton
                      id="attention"
                      label="Holat"
                      sort={sort}
                      asc={asc}
                      onSort={toggleSort}
                    />
                  </th>
                  <th>Reja</th>
                  <th>
                    <SortButton
                      id="expires"
                      label="Muddat"
                      sort={sort}
                      asc={asc}
                      onSort={toggleSort}
                    />
                  </th>
                  <th>
                    <SortButton
                      id="created"
                      label="Qo'shilgan"
                      sort={sort}
                      asc={asc}
                      onSort={toggleSort}
                    />
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((t) => {
                  const visual = stateVisual(t.status.state);
                  return (
                    <tr key={t.tenantId}>
                      <td data-label="Biznes">
                        <Link
                          to={`/admin/tenants/${t.tenantId}`}
                          style={{ fontWeight: 700 }}
                        >
                          {t.name}
                        </Link>
                        <div className="muted" style={{ fontSize: 12 }}>
                          {t.phone ?? t.tenantId}
                        </div>
                      </td>
                      <td data-label="Holat">
                        <span
                          className="badge"
                          style={{
                            color: visual.color,
                            background: `color-mix(in srgb, ${visual.color} 14%, transparent)`,
                          }}
                        >
                          {visual.label}
                        </span>
                      </td>
                      <td data-label="Reja">{t.status.planId}</td>
                      <td data-label="Muddat">
                        {t.status.kind === 'lifetime' ? (
                          <span className="muted">Cheksiz</span>
                        ) : (
                          <>
                            {formatDate(t.status.expiresAt)}
                            {t.status.daysLeft !== null && (
                              <div className="muted" style={{ fontSize: 12 }}>
                                {t.status.daysLeft >= 0
                                  ? `${t.status.daysLeft} kun qoldi`
                                  : `${-t.status.daysLeft} kun o'tdi`}
                              </div>
                            )}
                          </>
                        )}
                      </td>
                      <td data-label="Qo'shilgan">{formatDate(t.createdAt)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function SortButton({
  id,
  label,
  sort,
  asc,
  onSort,
}: {
  id: SortId;
  label: string;
  sort: SortId;
  asc: boolean;
  onSort: (id: SortId) => void;
}) {
  const active = sort === id;
  return (
    <button
      type="button"
      onClick={() => onSort(id)}
      aria-sort={active ? (asc ? 'ascending' : 'descending') : 'none'}
      title={`${label} bo'yicha saralash`}
    >
      {label}
      <span aria-hidden="true">{active ? (asc ? '↑' : '↓') : '↕'}</span>
    </button>
  );
}
