import { NavLink, Outlet, Link } from 'react-router-dom';

import { branding } from '@/lib/branding';
import { Wordmark } from './Logo';

const NAV = [
  { to: '/', label: 'Bosh sahifa', end: true },
  { to: '/imkoniyatlar', label: 'Imkoniyatlar' },
  { to: '/narxlar', label: 'Narxlar' },
  { to: '/aloqa', label: 'Aloqa' },
];

/** Marketing sahifalari uchun umumiy karkas (header + footer). */
export function SiteLayout() {
  return (
    <>
      <a className="skip-link" href="#main">
        Asosiy mazmunga o'tish
      </a>

      <header
        style={{
          position: 'sticky',
          top: 0,
          zIndex: 20,
          background: 'color-mix(in srgb, var(--bg) 88%, transparent)',
          backdropFilter: 'blur(10px)',
          borderBottom: '1px solid var(--border)',
        }}
      >
        <div
          className="container"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 20,
            minHeight: 68,
            flexWrap: 'wrap',
          }}
        >
          <Link to="/" style={{ textDecoration: 'none' }}>
            <Wordmark />
          </Link>

          <nav
            aria-label="Asosiy menyu"
            style={{ display: 'flex', gap: 4, marginInlineStart: 'auto' }}
          >
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
                  color: isActive ? 'var(--brand)' : 'var(--text-muted)',
                  background: isActive ? 'var(--surface-muted)' : 'transparent',
                  textDecoration: 'none',
                })}
              >
                {item.label}
              </NavLink>
            ))}
          </nav>

          <Link className="btn btn--primary" to="/kirish">
            Kirish
          </Link>
        </div>
      </header>

      <main id="main">
        <Outlet />
      </main>

      <footer
        style={{
          borderTop: '1px solid var(--border)',
          marginTop: 80,
          padding: '40px 0',
          background: 'var(--surface)',
        }}
      >
        <div
          className="container"
          style={{
            display: 'flex',
            gap: 24,
            flexWrap: 'wrap',
            justifyContent: 'space-between',
          }}
        >
          <div style={{ maxWidth: 320 }}>
            <Wordmark size={32} />
            <p className="muted" style={{ marginTop: 12, fontSize: 14 }}>
              {branding.shortDescription}.
            </p>
          </div>

          <div style={{ fontSize: 14 }}>
            <h4 style={{ fontSize: 14, marginBottom: 8 }}>Aloqa</h4>
            <p className="muted" style={{ margin: 0, lineHeight: 2 }}>
              <a href={`tel:${branding.supportPhone.replace(/\s/g, '')}`}>
                {branding.supportPhone}
              </a>
              <br />
              <a href={`mailto:${branding.supportEmail}`}>
                {branding.supportEmail}
              </a>
              <br />
              <a href={branding.supportTelegram} rel="noreferrer noopener">
                Telegram
              </a>
            </p>
          </div>
        </div>

        <div
          className="container muted"
          style={{ marginTop: 28, fontSize: 13 }}
        >
          © {new Date().getFullYear()} {branding.name}. Barcha huquqlar
          himoyalangan.
        </div>
      </footer>
    </>
  );
}
