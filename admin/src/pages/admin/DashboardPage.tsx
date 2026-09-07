import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { api } from '@/lib/api';
import { formatSom, type AdminStats } from '@/lib/admin-types';

export function DashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .get<{ stats: AdminStats }>('/api/v1/admin/stats')
      .then((r) => setStats(r.stats))
      .catch((e) => setError(e instanceof Error ? e.message : 'Xatolik'));
  }, []);

  if (error) {
    return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  }
  if (!stats) return <p className="muted">Yuklanmoqda…</p>;

  return (
    <>
      <div className="page-title">
        <h1>Umumiy holat</h1>
      </div>

      <div className="grid grid--4">
        <Stat label="Jami biznes" value={stats.totalTenants} />
        <Stat
          label="Faol"
          value={stats.activeTenants}
          color="var(--success)"
        />
        <Stat
          label="Bloklangan"
          value={stats.blockedTenants}
          color="var(--danger)"
          href={stats.blockedTenants > 0 ? '/admin/tenants' : undefined}
        />
        <Stat
          label="To'lov so'rovlari"
          value={stats.pendingPayments}
          color={stats.pendingPayments > 0 ? 'var(--warning)' : undefined}
          href={
            stats.pendingPayments > 0 ? '/admin/payment-requests' : undefined
          }
        />
        <Stat label="Sinov muddatida" value={stats.trialTenants} />
        <Stat label="Bir umrlik" value={stats.lifetimeTenants} />
        <Stat
          label="30 kunlik tushum"
          value={formatSom(stats.revenue30d)}
          color="var(--brand)"
        />
      </div>

      {stats.pendingPayments > 0 && (
        <div
          className="card"
          style={{
            marginTop: 20,
            borderColor: 'color-mix(in srgb, var(--warning) 45%, transparent)',
            background: 'color-mix(in srgb, var(--warning) 8%, transparent)',
          }}
        >
          <strong>
            {stats.pendingPayments} ta to'lov so'rovi kutilmoqda.
          </strong>{' '}
          Mijoz to'lov qilganini aytdi —{' '}
          <Link to="/admin/payment-requests">ko'rib chiqish</Link>.
        </div>
      )}

      {stats.blockedTenants > 0 && (
        <div
          className="card"
          style={{
            marginTop: 20,
            borderColor: 'color-mix(in srgb, var(--danger) 40%, transparent)',
            background: 'color-mix(in srgb, var(--danger) 8%, transparent)',
          }}
        >
          <strong>{stats.blockedTenants} ta biznes bloklangan.</strong>{' '}
          To'lov qilgan bo'lsa tasdiqlash kerak —{' '}
          <Link to="/admin/tenants">ro'yxatga o'tish</Link>.
        </div>
      )}
    </>
  );
}

function Stat({
  label,
  value,
  color,
  href,
}: {
  label: string;
  value: number | string;
  color?: string;
  href?: string;
}) {
  const body = (
    <div className="card" style={{ padding: 18 }}>
      <div className="muted" style={{ fontSize: 13 }}>{label}</div>
      <div
        style={{
          fontSize: 26,
          fontWeight: 800,
          letterSpacing: '-0.02em',
          marginTop: 4,
          color: color ?? 'var(--text)',
        }}
      >
        {value}
      </div>
    </div>
  );

  return href ? (
    <Link to={href} style={{ textDecoration: 'none' }}>
      {body}
    </Link>
  ) : (
    body
  );
}
