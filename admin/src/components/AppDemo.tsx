import { useState } from 'react';

import { Icon, type IconName } from './Icon';
import { formatNumber } from '@/lib/format';

/**
 * Bosiladigan ilova demosi.
 *
 * Nega chizma, haqiqiy skrinshot emas: skrinshotda mijozning haqiqiy
 * ismi, telefon raqami va buyurtmalari bo'lardi. Bu yerdagi
 * ma'lumotlar o'ylab topilgan, ranglar esa saytning o'z
 * o'zgaruvchilaridan olinadi — tun rejimiga o'tilsa demo ham u bilan
 * birga o'zgaradi.
 *
 * Ekran SVG emas, oddiy HTML: shrift saytning o'zi bilan bir xil,
 * matn har o'lchamda to'g'ri o'raladi va ekranni bosib ko'rish mumkin.
 */

type Screen = {
  id: string;
  tab: string;
  icon: IconName;
  title: string;
  /** Yon tomondagi tugmadagi izoh. */
  blurb: string;
  body: React.ReactNode;
};

function Row({
  title,
  sub,
  tag,
}: {
  title: string;
  sub: string;
  tag?: string;
}) {
  return (
    <div className="mini">
      <div className="mini__row">
        <span className="mini__title">{title}</span>
        {tag && <span className="mini__tag">{tag}</span>}
      </div>
      <div className="mini__muted">{sub}</div>
    </div>
  );
}

const SCREENS: Screen[] = [
  {
    id: 'order',
    tab: 'Qabul',
    icon: 'orders',
    title: 'Yangi buyurtma',
    blurb:
      'Mijoz, telefon raqami va xizmatlar. Olib kelish kerak bo\'lsa — dastavchikka topshiriladi.',
    body: (
      <>
        <div className="mini">
          <div className="mini__title">Mijoz</div>
          <div className="mini__muted">Nodira opa · +998 90 123 45 67</div>
        </div>
        <Row title="Gilam yuvish" sub="12 m² × 18 000" tag="216 000" />
        <Row title="Kursi tozalash" sub="4 dona × 35 000" tag="140 000" />
        <div className="mini" style={{ borderColor: 'var(--brand)' }}>
          <div className="mini__row">
            <span className="mini__title">Jami</span>
            <span className="mini__title" style={{ color: 'var(--brand-ink)' }}>
              {formatNumber(356000)} so&apos;m
            </span>
          </div>
          <div className="mini__muted">Oldindan to&apos;lov: 100 000 so&apos;m</div>
        </div>
      </>
    ),
  },
  {
    id: 'wash',
    tab: 'Yuvish',
    icon: 'box',
    title: 'Sex bo\'limi',
    blurb:
      'Yuvish, qadoqlash, tayyor. Har bir xodim faqat o\'z bo\'limini ko\'radi.',
    body: (
      <>
        <div style={{ display: 'flex', gap: 8 }}>
          <div className="mini" style={{ flex: 1 }}>
            <div className="mini__muted">Bugun yuvildi</div>
            <div className="mini__title" style={{ fontSize: '0.95rem' }}>
              64 m²
            </div>
          </div>
          <div className="mini" style={{ flex: 1 }}>
            <div className="mini__muted">Navbatda</div>
            <div className="mini__title" style={{ fontSize: '0.95rem' }}>
              9 buyurtma
            </div>
          </div>
        </div>
        <Row title="№ 1284 · Nodira opa" sub="Gilam 12 m²" tag="Yuvishda" />
        <Row title="№ 1283 · Sardor aka" sub="Gilam 8 m²" tag="Qadoqlashda" />
        <Row title="№ 1281 · Malika" sub="Ko'rpa 3 dona" tag="Tayyor" />
      </>
    ),
  },
  {
    id: 'delivery',
    tab: 'Yetgazish',
    icon: 'truck',
    title: 'Yetgazish va to\'lov',
    blurb:
      'Dastavchik marshrutini ko\'radi. Naqd yoki karta — qarz qolsa ro\'yxatda turadi.',
    body: (
      <>
        <Row
          title="№ 1281 · Malika"
          sub="Chilonzor 9-kvartal, 14-uy"
          tag="Yo'lda"
        />
        <Row title="№ 1279 · Jasur aka" sub="Yunusobod, 4-mavze" tag="Tayyor" />
        <div className="mini" style={{ borderColor: 'var(--warning)' }}>
          <div className="mini__row">
            <span className="mini__title">Qarzdorlik</span>
            <span className="mini__title" style={{ color: 'var(--warning)' }}>
              {formatNumber(180000)}
            </span>
          </div>
          <div className="mini__muted">3 ta mijoz · eslatma yuborilgan</div>
        </div>
      </>
    ),
  },
  {
    id: 'report',
    tab: 'Hisobot',
    icon: 'chart',
    title: 'Kunlik hisobot',
    blurb:
      'Daromad, chiqim va qarzdorlar — kunlik, oylik yoki ixtiyoriy davr bo\'yicha.',
    body: (
      <>
        <div className="mini" style={{ borderColor: 'var(--brand)' }}>
          <div className="mini__muted">Bugungi daromad</div>
          <div style={{ fontWeight: 800, fontSize: '1.05rem', letterSpacing: '-0.02em' }}>
            {formatNumber(2840000)} so&apos;m
          </div>
        </div>
        <div className="mini">
          <div className="mini__row">
            <span className="mini__muted">Naqd</span>
            <span className="mini__title">{formatNumber(1720000)}</span>
          </div>
          <div className="mini__bar">
            <span style={{ width: '61%' }} />
          </div>
        </div>
        <div className="mini">
          <div className="mini__row">
            <span className="mini__muted">Karta</span>
            <span className="mini__title">{formatNumber(1120000)}</span>
          </div>
          <div className="mini__bar">
            <span style={{ width: '39%' }} />
          </div>
        </div>
        <Row title="Chiqim" sub="Kimyo, yoqilg'i" tag="320 000" />
      </>
    ),
  },
];

export function AppDemo() {
  const [active, setActive] = useState(0);
  const screen = SCREENS[active] ?? SCREENS[0]!;

  return (
    <div className="demo">
      <div className="phone">
        <div className="phone__notch" />
        <div className="phone__screen">
          <div className="phone__bar">
            <strong>{screen.title}</strong>
            <span className="phone__bell">
              <Icon name="bell" size={14} />
            </span>
          </div>

          <div className="phone__body">{screen.body}</div>

          {/* Pastki tabla — telefonning o'zidagidek. Yon tomondagi
              tugmalar bilan BITTA holatni boshqaradi, shuning uchun
              qaysi biri bosilsa ham ikkalasi birga o'zgaradi. */}
          <div className="phone__tabs">
            {SCREENS.map((s, i) => (
              <button
                key={s.id}
                type="button"
                className={`phone__tab${i === active ? ' is-active' : ''}`}
                onClick={() => setActive(i)}
                aria-label={`${s.tab} ekranini ko'rsatish`}
                aria-pressed={i === active}
              >
                <Icon name={s.icon} size={17} />
                {s.tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="demo__steps">
        {SCREENS.map((s, i) => (
          <button
            key={s.id}
            type="button"
            className={`demo__step${i === active ? ' is-active' : ''}`}
            onClick={() => setActive(i)}
            aria-pressed={i === active}
          >
            <span className="demo__dot">{i + 1}</span>
            <span>
              <h3>{s.title}</h3>
              <p>{s.blurb}</p>
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
