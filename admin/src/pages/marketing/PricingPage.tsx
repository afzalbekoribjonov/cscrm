import { branding } from '@/lib/branding';
import { formatPrice, graceDays, isPriceUnset, monthlyPrice } from '@/lib/plans';
import { usePlans } from '@/lib/use-plans';

export function PricingPage() {
  // Narx serverdan olinadi — panelda o'zgartirilsa sayt ham darhol
  // yangisini ko'rsatadi.
  const { plans } = usePlans();
  const paid = plans.filter((p) => p.kind !== 'trial');
  const trial = plans.find((p) => p.kind === 'trial');
  const anyPriceUnset = paid.some(isPriceUnset);

  return (
    <section className="section container">
      <header className="section-head">
        <span className="eyebrow">Narxlar</span>
        <h1>Har bir biznesga mos reja</h1>
        <p>
          Yashirin to'lov yo'q. Xohlagan paytda rejani o'zgartirishingiz
          mumkin.
        </p>
      </header>

      {trial && (
        <div
          className="card"
          style={{
            marginBottom: 24,
            display: 'flex',
            gap: 16,
            alignItems: 'center',
            flexWrap: 'wrap',
            borderColor: 'var(--brand)',
          }}
        >
          <div style={{ flex: '1 1 320px' }}>
            <h3 style={{ marginBottom: 4 }}>{trial.name} — bepul</h3>
            <p className="muted" style={{ margin: 0, fontSize: 15 }}>
              {trial.description}
            </p>
          </div>
          <a className="btn btn--primary" href={branding.supportTelegram} rel="noreferrer noopener">
            Boshlash
          </a>
        </div>
      )}

      <div className="grid grid--4">
        {paid.map((plan) => {
          const perMonth = monthlyPrice(plan);
          return (
            <article
              key={plan.id}
              className="card"
              style={{
                display: 'flex',
                flexDirection: 'column',
                position: 'relative',
                borderColor: plan.highlight ? 'var(--brand)' : 'var(--border)',
                borderWidth: plan.highlight ? 2 : 1,
              }}
            >
              {plan.highlight && (
                <span
                  style={{
                    position: 'absolute',
                    top: -12,
                    insetInlineStart: 24,
                    background: 'var(--brand)',
                    color: '#fff',
                    fontSize: 12,
                    fontWeight: 700,
                    padding: '4px 12px',
                    borderRadius: 999,
                  }}
                >
                  Ommabop
                </span>
              )}

              <h3 style={{ marginBottom: 6 }}>{plan.name}</h3>

              <div
                style={{
                  fontSize: 26,
                  fontWeight: 800,
                  letterSpacing: '-0.02em',
                  color: isPriceUnset(plan) ? 'var(--text-muted)' : 'var(--text)',
                }}
              >
                {formatPrice(plan)}
              </div>
              {perMonth && (
                <div className="muted" style={{ fontSize: 14 }}>
                  {perMonth}
                </div>
              )}

              <p className="muted" style={{ fontSize: 15, marginTop: 12, flex: 1 }}>
                {plan.description}
              </p>

              {plan.kind === 'lifetime' && plan.lifetimeAnnualFeeUsd != null && (
                <p
                  style={{
                    fontSize: 14,
                    margin: '0 0 12px',
                    padding: '10px 12px',
                    borderRadius: 10,
                    background: 'var(--surface-muted)',
                  }}
                >
                  + yiliga ${plan.lifetimeAnnualFeeUsd} — ma'lumotlar bazasi uchun
                </p>
              )}

              <a
                className={plan.highlight ? 'btn btn--primary' : 'btn btn--ghost'}
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Tanlash
              </a>
            </article>
          );
        })}
      </div>

      <p className="muted" style={{ marginTop: 28, fontSize: 14, textAlign: 'center' }}>
        Obuna muddati tugagach {graceDays} kun qo'shimcha vaqt beriladi — ilova
        ishlashda davom etadi, shu vaqt ichida to'lovni amalga oshirasiz.
      </p>

      {anyPriceUnset && (
        <p
          style={{
            marginTop: 20,
            padding: 14,
            borderRadius: 'var(--radius)',
            background: 'color-mix(in srgb, var(--warning) 14%, transparent)',
            border: '1px solid color-mix(in srgb, var(--warning) 40%, transparent)',
            fontSize: 14,
          }}
        >
          <strong>Eslatma (faqat ishlab chiqishda ko'rinadi):</strong> ba'zi
          rejalarning narxi hali belgilanmagan. Narxlarni{' '}
          <code>shared/plans.json</code> faylida kiriting — u yagona manba, ilova
          va websayt ikkalasi ham shu yerdan oladi.
        </p>
      )}
    </section>
  );
}
