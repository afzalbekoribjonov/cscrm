import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import { api } from '@/lib/api';
import {
  formatDate,
  stateVisual,
  type TenantSummary,
} from '@/lib/admin-types';

export function TenantsPage() {
  const [tenants, setTenants] = useState<TenantSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState('');

  useEffect(() => {
    api
      .get<{ tenants: TenantSummary[] }>('/api/v1/admin/tenants')
      .then((r) => setTenants(r.tenants))
      .catch((e) => setError(e instanceof Error ? e.message : 'Xatolik'));
  }, []);

  const filtered = useMemo(() => {
    if (!tenants) return null;
    const q = query.trim().toLowerCase();
    if (!q) return tenants;
    return tenants.filter(
      (t) =>
        t.name.toLowerCase().includes(q) ||
        t.tenantId.includes(q) ||
        (t.phone ?? '').includes(q),
    );
  }, [tenants, query]);

  if (error) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!filtered) return <p className="muted">Yuklanmoqda…</p>;

  return (
    <>
      <div
        style={{
          display: 'flex',
          gap: 16,
          alignItems: 'center',
          flexWrap: 'wrap',
          marginBottom: 18,
        }}
      >
        <h1 style={{ fontSize: 26, margin: 0 }}>Bizneslar</h1>
        <span className="muted">{filtered.length} ta</span>
        <input
          type="search"
          placeholder="Nom, ID yoki telefon…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          style={{
            marginInlineStart: 'auto',
            minWidth: 240,
            padding: '9px 13px',
            borderRadius: 'var(--radius)',
            border: '1px solid var(--border)',
            background: 'var(--surface-muted)',
            color: 'var(--text)',
            font: 'inherit',
          }}
        />
      </div>

      {filtered.length === 0 ? (
        <div className="card">
          <p className="muted" style={{ margin: 0 }}>
            {tenants && tenants.length === 0
              ? 'Hali birorta biznes ro\'yxatdan o\'tmagan.'
              : 'Qidiruv bo\'yicha hech narsa topilmadi.'}
          </p>
        </div>
      ) : (
        <div className="card" style={{ padding: 0, overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 700 }}>
            <thead>
              <tr>
                <Th>Biznes</Th>
                <Th>Holat</Th>
                <Th>Reja</Th>
                <Th>Muddat</Th>
                <Th>Qo'shilgan</Th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((t) => {
                const visual = stateVisual(t.status.state);
                return (
                  <tr key={t.tenantId}>
                    <Td>
                      <Link
                        to={`/admin/tenants/${t.tenantId}`}
                        style={{ fontWeight: 600 }}
                      >
                        {t.name}
                      </Link>
                      <div className="muted" style={{ fontSize: 12 }}>
                        {t.phone ?? t.tenantId}
                      </div>
                    </Td>
                    <Td>
                      <span
                        style={{
                          display: 'inline-block',
                          padding: '3px 10px',
                          borderRadius: 999,
                          fontSize: 12,
                          fontWeight: 700,
                          color: visual.color,
                          background: `color-mix(in srgb, ${visual.color} 14%, transparent)`,
                        }}
                      >
                        {visual.label}
                      </span>
                    </Td>
                    <Td>{t.status.planId}</Td>
                    <Td>
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
                    </Td>
                    <Td>{formatDate(t.createdAt)}</Td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

const Th = ({ children }: { children: React.ReactNode }) => (
  <th
    style={{
      textAlign: 'start',
      padding: '12px 16px',
      fontSize: 12,
      fontWeight: 700,
      textTransform: 'uppercase',
      letterSpacing: '0.04em',
      color: 'var(--text-muted)',
      borderBottom: '1px solid var(--border)',
    }}
  >
    {children}
  </th>
);

const Td = ({ children }: { children: React.ReactNode }) => (
  <td
    style={{
      padding: '12px 16px',
      borderBottom: '1px solid var(--border)',
      fontSize: 14,
      verticalAlign: 'top',
    }}
  >
    {children}
  </td>
);
