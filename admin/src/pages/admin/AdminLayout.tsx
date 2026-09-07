import { NavLink, Outlet, useNavigate } from 'react-router-dom';

import { Wordmark } from '@/components/Logo';
import { useAuth } from '@/lib/auth';

const NAV = [
  { to: '/admin', label: 'Umumiy', end: true },
  { to: '/admin/payment-requests', label: "To'lov so'rovlari" },
  { to: '/admin/tenants', label: 'Bizneslar' },
  { to: '/admin/broadcasts', label: 'Xabarlar' },
];

/** Super-admin panelining umumiy karkasi. */
export function AdminLayout() {
  const { user, signOutNow } = useAuth();
  const navigate = useNavigate();

  return (
    <div style={{ minHeight: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <header className="admin-header">
        <div className="container admin-header__inner">
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

          <nav className="admin-nav" aria-label="Panel menyusi">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) => (isActive ? 'is-active' : '')}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <div
            className="admin-header__user"
            style={{ display: 'flex', alignItems: 'center', gap: 10 }}
          >
            <span
              className="muted"
              style={{ fontSize: 13, maxWidth: 180, overflow: 'hidden',
                       textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
            >
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
