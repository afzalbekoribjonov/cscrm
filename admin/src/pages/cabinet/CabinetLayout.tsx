import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';

import { Icon, type IconName } from '@/components/Icon';
import { Wordmark } from '@/components/Logo';
import { Alert, Button, ButtonLink, Cluster, Drawer, IconButton } from '@/components/ui';
import { cx } from '@/components/ui/logic';
import { useOwnerAuth } from '@/lib/owner-auth';
import { useTheme } from '@/lib/theme';

const NAV: { to: string; label: string; icon: IconName; end?: boolean }[] = [
  { to: '/kabinet', label: 'Umumiy', icon: 'grid', end: true },
  { to: '/kabinet/obuna', label: 'Obuna va to\'lov', icon: 'card' },
  { to: '/kabinet/xodimlar', label: 'Xodimlar', icon: 'people' },
  { to: '/kabinet/xabarlar', label: 'Xabarlar', icon: 'bell' },
];

function ThemeButton() {
  const { theme, toggle } = useTheme();
  return (
    <IconButton icon={theme === 'dark' ? 'sun' : 'moon'} label={theme === 'dark' ? 'Kunduzgi rejim' : 'Tungi rejim'} onClick={toggle} />
  );
}

/** Biznes egasi kabinetining karkasi — panel bilan bir xil tuzilish. */
export function CabinetLayout() {
  const { profile, signOutNow } = useOwnerAuth();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => setMenuOpen(false), [pathname]);

  if (!profile) return null;
  const status = profile.status;
  const warn = status.blocked || status.state === 'expiring' || status.state === 'grace' || status.state === 'lifetime_fee_due';

  const brand = (
    <Link to="/kabinet" className="ui-shell__brand" aria-label="Kabinet — bosh sahifa">
      <Wordmark size={28} />
      <span className="ui-shell__brand-tag">Kabinet</span>
    </Link>
  );

  const nav = (
    <nav aria-label="Kabinet menyusi" className="ui-nav">
      <div className="ui-nav__group">
        {NAV.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => cx('ui-nav__link', isActive && 'is-active')}
          >
            <Icon name={item.icon} size={19} />
            {item.label}
          </NavLink>
        ))}
      </div>
    </nav>
  );

  const account = (
    <div className="ui-shell__foot">
      <div className="ui-shell__user" title={profile.name}>
        <Icon name="building" size={16} />
        <span className="ui-shell__user-text">
          <span>{profile.name}</span>
          <span className="ui-shell__role">{profile.login ? `Login: ${profile.login}` : 'Biznes egasi'}</span>
        </span>
      </div>
      <Cluster justify="between">
        <ThemeButton />
        <Button
          variant="plain"
          size="sm"
          icon="logout"
          onClick={async () => {
            await signOutNow();
            navigate('/kabinet/kirish');
          }}
        >
          Chiqish
        </Button>
      </Cluster>
    </div>
  );

  return (
    <div className="ui-shell">
      <a className="skip-link" href="#cabinet-main">
        Asosiy qismga o'tish
      </a>
      <aside className="ui-shell__sidebar">
        {brand}
        {nav}
        {account}
      </aside>

      <div className="ui-shell__main">
        <header className="ui-shell__topbar">
          <IconButton icon="menu" label="Menyuni ochish" noTooltip aria-expanded={menuOpen} onClick={() => setMenuOpen(true)} />
          <Link to="/kabinet" aria-label="Kabinet — bosh sahifa">
            <Wordmark size={26} />
          </Link>
          <div className="ui-shell__topbar-end">
            <ThemeButton />
          </div>
        </header>

        <Drawer open={menuOpen} onClose={() => setMenuOpen(false)} title="Kabinet menyusi" footer={account}>
          {brand}
          {nav}
        </Drawer>

        <main id="cabinet-main" className="ui-shell__content" tabIndex={-1}>
          {/* Obuna muammosi — har sahifada ko'rinsin (to'lov sahifasidan tashqari). */}
          {warn && pathname !== '/kabinet/obuna' && (
            <div className="cab-banner">
              <Alert
                tone={status.blocked ? 'danger' : 'warning'}
                title={status.blocked ? 'Ilova bloklangan' : 'Obuna muddati tugayapti'}
                action={
                  <ButtonLink to="/kabinet/obuna" size="sm" variant={status.blocked ? 'danger' : 'outline'}>
                    To'lash
                  </ButtonLink>
                }
              >
                {status.message}
              </Alert>
            </div>
          )}
          <Outlet />
        </main>
      </div>
    </div>
  );
}
