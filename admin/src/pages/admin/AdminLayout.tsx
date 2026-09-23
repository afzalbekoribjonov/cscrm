import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';

import { Icon } from '@/components/Icon';
import { Wordmark } from '@/components/Logo';
import { Button, Cluster, Drawer, IconButton, useToast } from '@/components/ui';
import { cx } from '@/components/ui/logic';
import { onBadgesChanged } from '@/lib/admin-events';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useTheme } from '@/lib/theme';

import { NAV } from './nav';
import { OwnPasswordDialog } from './OwnPasswordDialog';

interface Badges {
  pendingPayments: number;
}

const BADGE_REFRESH_MS = 60_000;

/**
 * Menyudagi hisoblagichlar.
 *
 * Kutilayotgan to'lov — vaqtga bog'liq: mijoz to'lagan va ilovasi
 * tasdiqni kutib turibdi. Shuning uchun son sahifa almashganda va har
 * daqiqada yangilanadi — lekin faqat oyna OCHIQ va ko'rinib turganda
 * (orqa fondagi tab so'rov yubormaydi). So'rov juda yengil: tugunda
 * faqat hal qilinmagan so'rovlar turadi.
 */
function useBadges(pathname: string, enabled: boolean): Badges | null {
  const [badges, setBadges] = useState<Badges | null>(null);

  useEffect(() => {
    if (!enabled) return;
    let cancelled = false;
    const load = () => {
      if (document.visibilityState !== 'visible') return;
      api
        .get<{ badges: Badges }>('/api/v1/admin/badges')
        .then((r) => {
          if (!cancelled) setBadges(r.badges);
        })
        // Hisoblagich — qo'shimcha ma'lumot; olinmasa menyu baribir ishlaydi.
        .catch(() => undefined);
    };
    load();
    const timer = window.setInterval(load, BADGE_REFRESH_MS);
    document.addEventListener('visibilitychange', load);
    const off = onBadgesChanged(load);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', load);
      off();
    };
  }, [pathname, enabled]);

  return badges;
}

function ThemeButton() {
  const { theme, toggle } = useTheme();
  return (
    <IconButton
      icon={theme === 'dark' ? 'sun' : 'moon'}
      label={theme === 'dark' ? 'Kunduzgi rejim' : 'Tungi rejim'}
      onClick={toggle}
    />
  );
}

function Brand() {
  return (
    <Link to="/admin" className="ui-shell__brand" aria-label="Boshqaruv paneli — bosh sahifa">
      <Wordmark size={28} />
      <span className="ui-shell__brand-tag">Boshqaruv</span>
    </Link>
  );
}

/** Boshqaruv panelining karkasi: yon menyu (telefonda — ochiladigan panel). */
export function AdminLayout() {
  const { user, access, can, signOutNow } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const badges = useBadges(pathname, can('tenants.read'));

  // Menyudan sahifa tanlanganda panel o'zi yopilsin.
  useEffect(() => setMenuOpen(false), [pathname]);

  const groups = NAV.map((group) => group.filter((item) => can(item.permission))).filter((g) => g.length > 0);

  const nav = (
    <nav aria-label="Boshqaruv menyusi" className="ui-nav">
      {groups.map((group, i) => (
        <div key={i} className="ui-nav__group">
          {group.map((item) => {
            const count = item.badge ? badges?.[item.badge] ?? 0 : 0;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) => cx('ui-nav__link', isActive && 'is-active')}
              >
                <Icon name={item.icon} size={19} />
                {item.label}
                {count > 0 && (
                  <span className="ui-nav__count">
                    {count}
                    <span className="ui-sr-only"> ta kutilmoqda</span>
                  </span>
                )}
              </NavLink>
            );
          })}
        </div>
      ))}
    </nav>
  );

  const roleName = access?.isSuperAdmin ? 'Bosh administrator' : (access?.role?.name ?? 'Rol berilmagan');

  const account = (
    <div className="ui-shell__foot">
      <div className="ui-shell__user" title={user?.email ?? undefined}>
        <Icon name="people" size={16} />
        <span className="ui-shell__user-text">
          <span>{user?.email}</span>
          <span className="ui-shell__role">{roleName}</span>
        </span>
      </div>
      <Cluster justify="between">
        <Cluster gap={1}>
          <ThemeButton />
          <IconButton icon="lock" label="Parolni almashtirish" onClick={() => setPasswordOpen(true)} />
        </Cluster>
        <Button
          variant="plain"
          size="sm"
          icon="logout"
          onClick={async () => {
            await signOutNow();
            navigate('/kirish');
          }}
        >
          Chiqish
        </Button>
      </Cluster>
    </div>
  );

  return (
    <div className="ui-shell">
      <a className="skip-link" href="#admin-main">
        Asosiy qismga o'tish
      </a>

      <aside className="ui-shell__sidebar">
        <Brand />
        {nav}
        {account}
      </aside>

      <div className="ui-shell__main">
        <header className="ui-shell__topbar">
          <IconButton
            icon="menu"
            label="Menyuni ochish"
            noTooltip
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
          />
          <Link to="/admin" aria-label="Boshqaruv paneli — bosh sahifa">
            <Wordmark size={26} />
          </Link>
          <div className="ui-shell__topbar-end">
            <ThemeButton />
          </div>
        </header>

        <Drawer
          open={menuOpen}
          onClose={() => setMenuOpen(false)}
          title="Boshqaruv menyusi"
          footer={account}
        >
          <Brand />
          {nav}
        </Drawer>

        <main id="admin-main" className="ui-shell__content" tabIndex={-1}>
          <Outlet />
        </main>
      </div>

      <OwnPasswordDialog
        open={passwordOpen}
        onClose={() => setPasswordOpen(false)}
        onDone={() => toast.success('Parol almashtirildi', 'Keyingi kirishda yangi parolni ishlating.')}
      />
    </div>
  );
}
