import { useEffect, useRef, useState } from 'react';
import { NavLink, Outlet, Link, useLocation } from 'react-router-dom';

import { branding } from '@/lib/branding';
import { Icon } from './Icon';
import { Wordmark } from './Logo';

const NAV = [
  { to: '/', label: 'Bosh sahifa', end: true },
  { to: '/imkoniyatlar', label: 'Imkoniyatlar' },
  { to: '/narxlar', label: 'Narxlar' },
  { to: '/aloqa', label: 'Aloqa' },
];

/** Marketing sahifalari uchun umumiy karkas (header + footer). */
export function SiteLayout() {
  const [menuOpen, setMenuOpen] = useState(false);
  const narrow = useIsNarrow();
  const { pathname } = useLocation();
  const toggleRef = useRef<HTMLButtonElement>(null);

  // Sahifa almashganda menyu yopiladi — aks holda u ochiq qolib,
  // yangi sahifaning ustini bosib turardi.
  useEffect(() => setMenuOpen(false), [pathname]);

  // Esc bilan yopish: menyu ochiq qolib ketmasin.
  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setMenuOpen(false);
        toggleRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [menuOpen]);

  return (
    <>
      <a className="skip-link" href="#main">
        Asosiy mazmunga o'tish
      </a>

      <header className="site-header">
        <div
          className="container site-header__inner"
          style={{ position: 'relative' }}
        >
          <Link to="/" style={{ textDecoration: 'none' }} aria-label="CSCRM">
            <Wordmark />
          </Link>

          <button
            ref={toggleRef}
            className="nav-toggle"
            aria-expanded={menuOpen}
            aria-controls="site-nav"
            aria-label={menuOpen ? 'Menyuni yopish' : 'Menyuni ochish'}
            onClick={() => setMenuOpen((v) => !v)}
          >
            <Icon name={menuOpen ? 'close' : 'menu'} size={22} />
          </button>

          <nav
            id="site-nav"
            className="site-nav"
            aria-label="Asosiy menyu"
            // Tor ekranda tugma boshqaradi; keng ekranda CSS uni doim
            // ko'rsatadi, shuning uchun `hidden` faqat tor ekranda
            // ma'noga ega.
            hidden={!menuOpen && narrow}
          >
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
            <Link className="btn btn--primary" to="/kirish">
              Kirish
            </Link>
          </nav>

          <Link className="btn btn--primary site-header__cta" to="/kirish">
            Kirish
          </Link>
        </div>
      </header>

      <main id="main">
        <Outlet />
      </main>

      <footer className="site-footer">
        <div className="container">
          <div className="site-footer__grid">
            <div>
              <Wordmark size={32} />
              <p className="muted" style={{ marginTop: 12, fontSize: '0.94rem' }}>
                {branding.shortDescription}.
              </p>
            </div>

            <div>
              <h4>Sahifalar</h4>
              <ul>
                {NAV.map((item) => (
                  <li key={item.to}>
                    <Link to={item.to}>{item.label}</Link>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h4>Aloqa</h4>
              <ul>
                <li>
                  <a href={`tel:${branding.supportPhone.replace(/\s/g, '')}`}>
                    {branding.supportPhone}
                  </a>
                </li>
                <li>
                  <a href={`mailto:${branding.supportEmail}`}>
                    {branding.supportEmail}
                  </a>
                </li>
                <li>
                  <a href={branding.supportTelegram} rel="noreferrer noopener">
                    Telegram
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <div className="site-footer__bottom">
            <span>
              © {new Date().getFullYear()} {branding.name}. Barcha huquqlar
              himoyalangan.
            </span>
            <Link to="/kirish">Boshqaruv paneli</Link>
          </div>
        </div>
      </footer>
    </>
  );
}

/**
 * Ekran tor ekanini KUZATADI — CSS'dagi 820px chegarasi bilan bir xil.
 *
 * Kerak, chunki `hidden` atributi CSS'dan kuchliroq: keng ekranda uni
 * qo'ysak, menyu butunlay yo'qolib qolardi.
 *
 * Kuzatuv shart: bir martalik tekshiruv bo'lsa, oynani kattalashtirgan
 * foydalanuvchida menyu yo'qolgan holicha qolardi.
 */
function useIsNarrow(): boolean {
  const query = '(max-width: 820px)';
  const [narrow, setNarrow] = useState(
    () => typeof window !== 'undefined' && window.matchMedia(query).matches,
  );

  useEffect(() => {
    const mq = window.matchMedia(query);
    const onChange = (e: MediaQueryListEvent) => setNarrow(e.matches);
    mq.addEventListener('change', onChange);
    setNarrow(mq.matches);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  return narrow;
}
