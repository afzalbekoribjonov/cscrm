import { Link } from 'react-router-dom';

import { useNoIndex } from '@/lib/seo';

export function NotFoundPage() {
  // Server mavjud bo'lmagan manzilga ham index.html qaytaradi (SPA) —
  // bu sahifa qidiruv natijasiga "haqiqiy sahifa" bo'lib tushmasin.
  useNoIndex();
  return (
    <section
      className="container"
      style={{ paddingBlock: 96, textAlign: 'center' }}
    >
      <h1 style={{ fontSize: 72, marginBottom: 0 }}>404</h1>
      <p className="muted" style={{ fontSize: 18 }}>
        Bunday sahifa topilmadi.
      </p>
      <Link className="btn btn--primary" to="/">
        Bosh sahifaga qaytish
      </Link>
    </section>
  );
}
