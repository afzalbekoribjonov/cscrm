import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';

import { Icon, type IconName } from '@/components/Icon';
import { Wordmark } from '@/components/Logo';
import { Button, Cluster, Drawer, IconButton } from '@/components/ui';
import { cx } from '@/components/ui/logic';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useTheme } from '@/lib/theme';

interface NavItem {
  to: string;
  label: string;
  icon: IconName;
  end?: boolean;
  /** Yonida ko'rsatiladigan son (masalan, kutilayotgan to'lovlar). */
  badge?: keyof Badges;
}

/**
 * Menyu — faqat HOZIR ishlaydigan bo'limlar. Yangi bo'lim (masalan,
 * "Foydalanuvchilar") u haqiqatan tayyor bo'lgandagina qo'shiladi.
 */
const NAV: NavItem[] = [
  { to: '/admin', label: 'Umumiy', icon: 'grid', end: true },
  { to: '/admin/tenants', label: 'Bizneslar', icon: 'building' },
  { to: '/admin/payment-requests', label: 'To\'lov so\'rovlari', icon: 'card', badge: 'pendingPayments' },
  { to: '/admin/broadcasts', label: 'Xabarlar', icon: 'bell' },
  { to: '/admin/plans', label: 'Tariflar', icon: 'money' },
  { to: '/admin/settings', label: 'Sozlamalar', icon: 'settings' },
];

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
function useBadges(pathname: string): Badges | null {
  const [badges, setBadges] = useState<Badges | null>(null);

  useEffect(() => {
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
    return () => {
      cancelled = true;
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', load);
    };
  }, [pathname]);

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

/** Super-admin panelining karkasi: yon menyu (telefonda — ochiladigan panel). */
export function AdminLayout() {
  const { user, signOutNow } = useAuth();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const badges = useBadges(pathname);

  // Menyudan sahifa tanlanganda panel o'zi yopilsin.
  useEffect(() => setMenuOpen(false), [pathname]);

  const nav = (
    <nav aria-label="Boshqaruv menyusi" className="ui-nav">
      {NAV.map((item) => {
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
    </nav>
  );

  const account = (
    <div className="ui-shell__foot">
      <div className="ui-shell__user" title={user?.email ?? undefined}>
        <Icon name="people" size={16} />
        <span>{user?.email}</span>
      </div>
      <Cluster justify="between">
        <ThemeButton />
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
    </div>
  );
}
