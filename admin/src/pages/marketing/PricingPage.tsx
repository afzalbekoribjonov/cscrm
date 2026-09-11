import { useState } from 'react';

import { Icon } from '@/components/Icon';
import { Reveal } from '@/components/Reveal';
import { branding } from '@/lib/branding';
import { formatNumber } from '@/lib/format';
import { graceDays, isPriceUnset, trialDays, type Plan } from '@/lib/plans';
import { useSeo } from '@/lib/seo';
import { usePlans } from '@/lib/use-plans';

/**
 * Narxlar sahifasi.
 *
 * ASOSIY QARORI: kartadagi eng KATTA raqam — oyiga tushadigan narx,
 * jami summa emas.
 *
 * Sababi: rejalar bir-biridan faqat muddat bilan farq qiladi,
 * imkoniyatlar hammasida bir xil. Ya'ni tanlov "qaysi reja arzonroq"
 * degan savolga tayanadi, unga esa faqat oylik narx javob beradi.
 * Jami summa uzunroq muddatda tabiiy ravishda katta chiqadi va
 * taqqoslashda chalg'itadi.
 */

const FAQ = [
  {
    q: 'Rejani keyinroq o\'zgartira olamanmi?',
    a: 'Ha. Joriy muddat tugagach xohlagan rejani tanlaysiz. Muddat ichida uzunroq rejaga o\'tmoqchi bo\'lsangiz — yozing, qolgan kunlarni hisobga olamiz.',
  },
  {
    q: 'To\'lov qanday amalga oshiriladi?',
    a: 'Karta orqali o\'tkazma. Rekvizitlarni Telegram yoki telefon orqali beramiz. To\'lovni tasdiqlaganimizdan keyin obuna darhol uzayadi.',
  },
  {
    q: 'Xodimlar soni narxga ta\'sir qiladimi?',
    a: 'Yo\'q. Xodim va buyurtma soni cheklanmagan — narx faqat muddatga bog\'liq.',
  },
  {
    q: 'Muddat tugasa ma\'lumotlarim o\'chib ketadimi?',
    a: 'Yo\'q. Ma\'lumot saqlanib turadi, ilova esa vaqtincha bloklanadi. To\'lov qilishingiz bilan hammasi joyida bo\'ladi.',
  },
  {
    q: 'Bir umrlik rejada nega yillik to\'lov bor?',
    a: 'Ilova bir marta sotib olinadi, lekin ma\'lumotlaringiz har kuni serverda saqlanadi va zaxiralanadi — buning o\'z xarajati bor. Yillik to\'lov aynan shu xarajatni qoplaydi, boshqa hech narsani emas.',
  },
];

export function PricingPage() {
  useSeo(
    'Narxlar',
    'CSCRM obuna rejalari: oylik, 3 oylik, 5 oylik, yillik va bir umrlik. Yashirin to\'lov yo\'q.',
  );

  // Narx serverdan olinadi — panelda o'zgartirilsa sayt ham darhol
  // yangisini ko'rsatadi.
  const { plans } = usePlans();
  const [tab, setTab] = useState<'subscription' | 'lifetime'>('subscription');

  const subs = plans.filter((p) => p.kind === 'subscription');
  const lifetime = plans.find((p) => p.kind === 'lifetime');
  const trial = plans.find((p) => p.kind === 'trial');
  const anyPriceUnset = plans.some(isPriceUnset);

  /* Taqqoslash uchun tayanch — eng qisqa rejaning oylik narxi.
     Undan uzoqroq rejalar necha foiz arzonlashini shunga qarab
     hisoblaymiz. */
  const baseline = subs
    .filter((p) => p.months === 1 && !isPriceUnset(p))
    .map((p) => p.price)[0];

  return (
    <>
      <section className="section--tight">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Narxlar</span>
            <h1>Faqat muddatni tanlaysiz</h1>
            <p>
              Barcha rejalarda imkoniyatlar bir xil: cheksiz xodim, cheksiz
              buyurtma, to&apos;liq hisobot. Uzoqroq muddat — arzonroq oylik
              narx.
            </p>
          </div>

          {/* Sinov — alohida va birinchi o'rinda: sahifaga kirgan odam
              avvalo hech narsa to'lamasdan ko'ra olishini bilishi kerak. */}
          {trial && (
            <div
              className="card"
              style={{
                marginBottom: 26,
                display: 'flex',
                gap: 18,
                alignItems: 'center',
                flexWrap: 'wrap',
                borderColor: 'var(--brand)',
              }}
            >
              <span className="icon-box" style={{ margin: 0 }}>
                <Icon name="sparkle" />
              </span>
              <div style={{ flex: '1 1 300px' }}>
                <h3 style={{ marginBottom: 4 }}>
                  {trialDays} kun bepul sinov
                </h3>
                <p className="muted" style={{ margin: 0, fontSize: '0.94rem' }}>
                  Barcha imkoniyatlar ochiq. Karta so&apos;ralmaydi, o&apos;zi
                  yangilanmaydi.
                </p>
              </div>
              <a
                className="btn btn--primary"
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Boshlash
              </a>
            </div>
          )}

          <div className="center" style={{ marginBottom: 6 }}>
            <div
              className="seg"
              role="tablist"
              aria-label="Reja turini tanlash"
            >
              <button
                type="button"
                role="tab"
                aria-selected={tab === 'subscription'}
                className={tab === 'subscription' ? 'is-active' : ''}
                onClick={() => setTab('subscription')}
              >
                Obuna
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={tab === 'lifetime'}
                className={tab === 'lifetime' ? 'is-active' : ''}
                onClick={() => setTab('lifetime')}
              >
                Bir umrlik
              </button>
            </div>
          </div>

          {tab === 'subscription' ? (
            <div className="plan-grid">
              {subs.map((plan) => (
                <PlanCard key={plan.id} plan={plan} baseline={baseline} />
              ))}
            </div>
          ) : lifetime ? (
            <LifetimeCard plan={lifetime} />
          ) : null}

          <p
            className="muted center"
            style={{ marginTop: 22, fontSize: '0.9rem' }}
          >
            Obuna muddati tugagach {graceDays} kun qo&apos;shimcha vaqt
            beriladi — ilova ishlashda davom etadi, shu vaqt ichida
            to&apos;lovni amalga oshirasiz.
          </p>
        </div>
      </section>

      {/* ---------------- Oylik narx taqqoslashi ---------------- */}
      {baseline !== undefined && subs.length > 1 && (
        <section className="section band">
          <div className="container" style={{ maxWidth: 900 }}>
            <div className="section-head">
              <span className="eyebrow">Taqqoslash</span>
              <h2>Oyiga qancha tushadi</h2>
              <p>
                Bir xil imkoniyat, turli muddat. Ustun qanchalik qisqa
                bo&apos;lsa — shuncha arzon.
              </p>
            </div>

            <Reveal>
              <div className="chart-card">
                <MonthlyBars plans={subs} />
              </div>
            </Reveal>
          </div>
        </section>
      )}

      {/* ---------------- To'liq jadval ---------------- */}
      <section className="section">
        <div className="container" style={{ maxWidth: 900 }}>
          <div className="section-head">
            <span className="eyebrow">Barcha rejalar</span>
            <h2>Yonma-yon</h2>
          </div>

          <div className="table-wrap">
            <div className="table-scroll">
              <table className="compare">
                <thead>
                  <tr>
                    <th>Reja</th>
                    <th>Muddat</th>
                    <th>Jami</th>
                    <th>Oyiga</th>
                    <th>Tejaysiz</th>
                  </tr>
                </thead>
                <tbody>
                  {plans
                    .filter((p) => p.kind !== 'trial')
                    .map((plan) => {
                      const per = perMonth(plan);
                      const save = savingPercent(plan, baseline);
                      return (
                        <tr
                          key={plan.id}
                          className={plan.highlight ? 'is-highlight' : ''}
                        >
                          <td>{plan.name}</td>
                          <td data-label="Muddat">{term(plan)}</td>
                          <td data-label="Jami">
                            {isPriceUnset(plan)
                              ? 'Kelishiladi'
                              : `${formatNumber(plan.price)} so'm`}
                          </td>
                          <td data-label="Oyiga">
                            {per === null ? '—' : `${formatNumber(per)} so'm`}
                          </td>
                          <td data-label="Tejaysiz">
                            {save === null ? '—' : `${save}%`}
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </div>
          </div>

          {anyPriceUnset && (
            <p
              style={{
                marginTop: 20,
                padding: 14,
                borderRadius: 'var(--radius)',
                background:
                  'color-mix(in srgb, var(--warning) 14%, transparent)',
                border:
                  '1px solid color-mix(in srgb, var(--warning) 40%, transparent)',
                fontSize: 14,
              }}
            >
              <strong>Eslatma:</strong> ba&apos;zi rejalarning narxi hali
              belgilanmagan. Narxni boshqaruv panelidagi &laquo;Tariflar&raquo;
              bo&apos;limidan kiriting.
            </p>
          )}
        </div>
      </section>

      {/* ---------------- Savol-javob ---------------- */}
      <section className="section band">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="section-head">
            <span className="eyebrow">Savol-javob</span>
            <h2>Narx haqida</h2>
          </div>

          {FAQ.map((item) => (
            <details key={item.q} className="faq">
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* ---------------- Chaqiruv ---------------- */}
      <section className="section--tight">
        <div className="container">
          <div className="cta">
            <h2>Avval sinab ko&apos;ring</h2>
            <p>
              {trialDays} kun bepul. Yoqmasa hech narsa to&apos;lamaysiz —
              obuna o&apos;zi yangilanmaydi.
            </p>
            <div
              style={{
                display: 'flex',
                gap: 12,
                justifyContent: 'center',
                flexWrap: 'wrap',
                marginTop: 22,
              }}
            >
              <a
                className="btn btn--on-brand btn--lg"
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Telegram orqali yozish
              </a>
              <a
                className="btn btn--outline-light btn--lg"
                href={`tel:${branding.supportPhone.replace(/\s/g, '')}`}
              >
                {branding.supportPhone}
              </a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Hisob yordamchilari                                                 */
/* ------------------------------------------------------------------ */

/** Oyiga tushadigan narx. Muddatsiz rejada ma'nosi yo'q. */
function perMonth(plan: Plan): number | null {
  if (!plan.months || plan.months < 1 || isPriceUnset(plan)) return null;
  return Math.round(plan.price / plan.months);
}

/** Eng qisqa rejaga nisbatan necha foiz arzon. */
function savingPercent(plan: Plan, baseline: number | undefined): number | null {
  const per = perMonth(plan);
  if (per === null || baseline === undefined || baseline <= 0) return null;
  const pct = Math.round((1 - per / baseline) * 100);
  // 1-2 foizlik farq "tejaysiz" deb ko'rsatishga arzimaydi — u
  // yaxlitlash xatosiga o'xshab qoladi.
  return pct >= 3 ? pct : null;
}

function term(plan: Plan): string {
  if (plan.kind === 'lifetime') return 'Cheksiz';
  if (!plan.months) return '—';
  return plan.months === 12 ? '1 yil' : `${plan.months} oy`;
}

/* ------------------------------------------------------------------ */
/* Bo'laklar                                                           */
/* ------------------------------------------------------------------ */

function PlanCard({ plan, baseline }: { plan: Plan; baseline?: number }) {
  const per = perMonth(plan);
  const save = savingPercent(plan, baseline);

  return (
    <article className={`plan${plan.highlight ? ' plan--highlight' : ''}`}>
      {plan.highlight && <span className="plan__badge">Ommabop</span>}

      <h3 className="plan__name">{plan.name}</h3>
      <p className="plan__term">{term(plan)}</p>

      {isPriceUnset(plan) ? (
        <div className="plan__price" style={{ color: 'var(--text-muted)' }}>
          Kelishiladi
        </div>
      ) : (
        <>
          <div className="plan__price">
            {formatNumber(per ?? plan.price)} <span>so&apos;m/oy</span>
          </div>
          <p className="plan__total">
            Jami {formatNumber(plan.price)} so&apos;m
          </p>
          {save !== null && (
            <span className="plan__save">{save}% tejaysiz</span>
          )}
        </>
      )}

      <p className="plan__desc">{plan.description}</p>

      <a
        className={`btn ${plan.highlight ? 'btn--primary' : 'btn--ghost'} plan__cta`}
        href={branding.supportTelegram}
        rel="noreferrer noopener"
      >
        Tanlash
      </a>
    </article>
  );
}

function LifetimeCard({ plan }: { plan: Plan }) {
  return (
    <div className="lifetime" style={{ marginTop: 14 }}>
      <div>
        <span className="eyebrow">Bir martalik to&apos;lov</span>
        <h3 style={{ fontSize: '1.4rem', marginBottom: 10 }}>{plan.name}</h3>
        <p className="muted" style={{ fontSize: '0.98rem' }}>
          {plan.description}
        </p>

        <ul className="check-list" style={{ marginTop: 16 }}>
          <li>Obuna muddati yo&apos;q — ilova doim sizniki</li>
          <li>Cheksiz xodim va buyurtma</li>
          <li>Barcha yangilanishlar kiradi</li>
        </ul>
      </div>

      <div>
        <div className="lifetime__price">
          {isPriceUnset(plan) ? 'Kelishiladi' : formatNumber(plan.price)}
          {!isPriceUnset(plan) && (
            <span
              style={{
                fontSize: '0.9rem',
                fontWeight: 700,
                color: 'var(--text-muted)',
                letterSpacing: 0,
              }}
            >
              {' '}
              so&apos;m
            </span>
          )}
        </div>

        {plan.lifetimeAnnualFeeUsd != null && (
          <p
            style={{
              fontSize: '0.9rem',
              margin: '14px 0 0',
              padding: '12px 14px',
              borderRadius: 'var(--radius)',
              background: 'var(--surface-muted)',
            }}
          >
            + yiliga <strong>${plan.lifetimeAnnualFeeUsd}</strong> — ma&apos;lumotlar
            bazasi va zaxira nusxalari uchun. Bu ilova uchun emas,
            serverdagi ma&apos;lumotingizni saqlash uchun.
          </p>
        )}

        <a
          className="btn btn--primary btn--block"
          style={{ marginTop: 16 }}
          href={branding.supportTelegram}
          rel="noreferrer noopener"
        >
          Bog&apos;lanish
        </a>
      </div>
    </div>
  );
}

/**
 * Oylik narxlar ustunlari.
 *
 * Bitta o'lchov (oylik narx) bo'ylab taqqoslash — shuning uchun
 * kategoriya ranglari EMAS, urg'u ishlatiladi: eng arzoni brend
 * rangida, qolganlari bir xil neytral tusda. Har biriga boshqa rang
 * berilsa, rang "bu boshqa turdagi narsa" degan yolg'on ishorani
 * berardi.
 */
function MonthlyBars({ plans }: { plans: Plan[] }) {
  const rows = plans
    .map((p) => ({ plan: p, per: perMonth(p) }))
    .filter((r): r is { plan: Plan; per: number } => r.per !== null);

  if (rows.length === 0) return null;

  const max = Math.max(...rows.map((r) => r.per));
  const min = Math.min(...rows.map((r) => r.per));

  return (
    <div className="price-bars">
      {rows.map(({ plan, per }) => {
        const cheapest = per === min;
        return (
          <div key={plan.id}>
            <div className="price-bar__head">
              <span>{plan.name}</span>
              <span className="price-bar__value">
                {formatNumber(per)} so&apos;m/oy
              </span>
            </div>
            <div className="price-bar__track">
              <div
                className="price-bar__fill"
                style={{
                  width: `${Math.max(6, (per / max) * 100)}%`,
                  background: cheapest ? 'var(--chart-1)' : 'var(--border-strong)',
                }}
              />
            </div>
          </div>
        );
      })}
      <p className="muted" style={{ fontSize: '0.82rem', margin: '4px 0 0' }}>
        Ko&apos;k ustun — oyiga eng arzon tushadigan reja.
      </p>
    </div>
  );
}
