import { NavLink, Outlet, useNavigate } from 'react-router-dom';

import { Wordmark } from '@/components/Logo';
import { useAuth } from '@/lib/auth';

const NAV = [
  { to: '/admin', label: 'Umumiy', end: true },
  { to: '/admin/payment-requests', label: "To'lov so'rovlari" },
  { to: '/admin/tenants', label: 'Bizneslar' },
];

/** Super-admin panelining umumiy karkasi. */
export function AdminLayout() {
  const { user, signOutNow } = useAuth();
  const navigate = useNavigate();

  return (
    <div style={{ minHeight: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <header
        style={{
          borderBottom: '1px solid var(--border)',
          background: 'var(--surface)',
        }}
      >
        <div
          className="container"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 20,
            minHeight: 64,
            flexWrap: 'wrap',
          }}
        >
          <Wordmark size={30} />
          <span
            style={{
              fontSize: 12,
              fontWeight: 700,
              padding: '3px 9px',
              borderRadius: 999,
              background: 'var(--surface-muted)',
              color: 'var(--text-muted)',
            }}
          >
            Boshqaruv
          </span>

          <nav style={{ display: 'flex', gap: 4, marginInlineStart: 'auto' }}>
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                style={({ isActive }) => ({
                  padding: '8px 12px',
                  borderRadius: 10,
                  fontWeight: 600,
                  fontSize: 15,
                  textDecoration: 'none',
                  color: isActive ? 'var(--brand)' : 'var(--text-muted)',
                  background: isActive ? 'var(--surface-muted)' : 'transparent',
                })}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className="muted" style={{ fontSize: 13 }}>
              {user?.email}
            </span>
            <button
              className="btn btn--ghost"
              style={{ padding: '8px 14px', fontSize: 14 }}
              onClick={async () => {
                await signOutNow();
                navigate('/kirish');
              }}
            >
              Chiqish
            </button>
          </div>
        </div>
      </header>

      <main className="container" style={{ flex: 1, paddingBlock: 28 }}>
        <Outlet />
      </main>
    </div>
  );
}
