import { Link } from 'react-router-dom';

import { branding } from '@/lib/branding';

const FEATURES = [
  {
    icon: '📋',
    title: 'Buyurtmalarni boshqarish',
    text: 'Qabul qilishdan yetkazishgacha — har bir buyurtma qaysi bosqichda ekani doim ko\'rinib turadi.',
  },
  {
    icon: '👥',
    title: 'Xodimlar va vakolatlar',
    text: 'Har bir xodim faqat o\'z bo\'limida ishlaydi. Kim nima qilgani tarixda saqlanadi.',
  },
  {
    icon: '💰',
    title: 'Moliya va hisobot',
    text: 'Daromad, chiqim va qarzdorlar — kunlik, oylik va ixtiyoriy davr bo\'yicha.',
  },
  {
    icon: '📱',
    title: 'Telefonda ishlaydi',
    text: 'Sexda, yo\'lda yoki mijoz oldida — hamma joyda. Internet uzilsa ham ma\'lumot yo\'qolmaydi.',
  },
  {
    icon: '🔔',
    title: 'Bildirishnomalar',
    text: 'Yangi buyurtma, holat o\'zgarishi va to\'lov haqida darhol xabar oling.',
  },
  {
    icon: '🔒',
    title: 'Ma\'lumot xavfsizligi',
    text: 'Har bir biznesning ma\'lumoti alohida saqlanadi. Zaxira nusxa avtomatik olinadi.',
  },
];

export function LandingPage() {
  return (
    <>
      {/* Hero */}
      <section
        style={{
          padding: '72px 0 64px',
          background:
            'radial-gradient(1000px 400px at 50% -120px, color-mix(in srgb, var(--brand) 16%, transparent), transparent)',
        }}
      >
        <div className="container" style={{ textAlign: 'center' }}>
          <p
            style={{
              display: 'inline-block',
              padding: '6px 14px',
              borderRadius: 999,
              background: 'var(--surface-muted)',
              border: '1px solid var(--border)',
              fontSize: 14,
              fontWeight: 600,
              color: 'var(--text-muted)',
            }}
          >
            Gilam yuvish · Kimyoviy tozalash · Kir yuvish
          </p>

          <h1 style={{ marginTop: 20, maxWidth: 820, marginInline: 'auto' }}>
            Xizmat biznesingizni{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, var(--brand), var(--brand-light))',
                WebkitBackgroundClip: 'text',
                backgroundClip: 'text',
                color: 'transparent',
              }}
            >
              bitta tizimdan
            </span>{' '}
            boshqaring
          </h1>

          <p
            className="muted"
            style={{
              fontSize: 19,
              maxWidth: 620,
              marginInline: 'auto',
              marginBottom: 32,
            }}
          >
            Buyurtma qabul qilishdan pul yig'ishgacha. Daftar va telefon
            qo'ng'iroqlari o'rniga — aniq, tartibli va har doim qo'lingizda.
          </p>

          <div
            style={{
              display: 'flex',
              gap: 12,
              justifyContent: 'center',
              flexWrap: 'wrap',
            }}
          >
            <Link className="btn btn--primary" to="/narxlar">
              14 kun bepul sinab ko'rish
            </Link>
            <Link className="btn btn--ghost" to="/imkoniyatlar">
              Imkoniyatlar bilan tanishish
            </Link>
          </div>

          <p className="muted" style={{ marginTop: 16, fontSize: 14 }}>
            Karta kerak emas · Bir necha daqiqada ishga tushadi
          </p>
        </div>
      </section>

      {/* Imkoniyatlar */}
      <section className="container" style={{ paddingBlock: 24 }}>
        <div
          style={{
            display: 'grid',
            gap: 18,
            gridTemplateColumns: 'repeat(auto-fit, minmax(290px, 1fr))',
          }}
        >
          {FEATURES.map((f) => (
            <article key={f.title} className="card">
              <div style={{ fontSize: 28, marginBottom: 10 }} aria-hidden="true">
                {f.icon}
              </div>
              <h3>{f.title}</h3>
              <p className="muted" style={{ margin: 0, fontSize: 15 }}>
                {f.text}
              </p>
            </article>
          ))}
        </div>
      </section>

      {/* Yakuniy chaqiruv */}
      <section className="container" style={{ paddingBlock: 64 }}>
        <div
          className="card"
          style={{
            textAlign: 'center',
            padding: 44,
            background:
              'linear-gradient(135deg, var(--brand), var(--brand-light))',
            border: 'none',
            color: '#fff',
          }}
        >
          <h2 style={{ color: '#fff' }}>Bugundan boshlang</h2>
          <p style={{ opacity: 0.92, maxWidth: 520, marginInline: 'auto' }}>
            14 kun bepul. Yoqsa — obuna bo'lasiz, yoqmasa hech narsa to'lamaysiz.
          </p>
          <div
            style={{
              display: 'flex',
              gap: 12,
              justifyContent: 'center',
              flexWrap: 'wrap',
              marginTop: 20,
            }}
          >
            <Link
              className="btn"
              to="/narxlar"
              style={{ background: '#fff', color: 'var(--brand)' }}
            >
              Narxlarni ko'rish
            </Link>
            <a
              className="btn"
              href={branding.supportTelegram}
              rel="noreferrer noopener"
              style={{
                background: 'transparent',
                color: '#fff',
                borderColor: 'rgb(255 255 255 / 0.5)',
              }}
            >
              Savol berish
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
