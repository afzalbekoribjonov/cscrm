import { useCallback, useEffect, useState } from 'react';

import { api } from '@/lib/api';
import { formatSom } from '@/lib/admin-types';
import type { Plan } from '@/lib/plans';

const fieldStyle: React.CSSProperties = {
  width: '100%',
  marginTop: 4,
  padding: '10px 12px',
  borderRadius: 'var(--radius)',
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  font: 'inherit',
};

/**
 * Tarif narxlarini boshqarish.
 *
 * Narx BAZADA saqlanadi: o'zgartirilishi bilan ilova ham, websayt ham
 * yangisini ko'radi — qayta joylash shart emas.
 *
 * Reja TUZILISHI (necha oy, turi) bu yerdan o'zgartirilmaydi: u dastur
 * mantiqiga bog'liq. Masalan "3 oylik" rejaning oyi 5 bo'lib qolsa,
 * muddat hisobi buzilardi.
 */
export function PlansPage() {
  const [plans, setPlans] = useState<Plan[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ plans: Plan[] }>('/api/v1/admin/plans');
      setPlans(r.plans);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function save(plan: Plan, price: number, feeUsd?: number) {
    if (
      !window.confirm(
        `"${plan.name}" narxi ${formatSom(price)} bo'lsinmi?\n\n` +
          'Yangi narx ilovada ham, saytda ham darhol ko\'rinadi.',
      )
    ) {
      return;
    }

    setBusyId(plan.id);
    setDone(null);
    try {
      const r = await api.post<{ plans: Plan[] }>(
        `/api/v1/admin/plans/${plan.id}/price`,
        {
          price,
          ...(feeUsd !== undefined ? { lifetimeAnnualFeeUsd: feeUsd } : {}),
        },
      );
      setPlans(r.plans);
      setDone(`"${plan.name}" narxi yangilandi.`);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusyId(null);
    }
  }

  async function reset(plan: Plan) {
    if (
      !window.confirm(
        `"${plan.name}" narxi dastlabki qiymatga qaytarilsinmi?`,
      )
    ) {
      return;
    }
    setBusyId(plan.id);
    try {
      const r = await api.del<{ plans: Plan[] }>(
        `/api/v1/admin/plans/${plan.id}/price`,
      );
      setPlans(r.plans);
      setDone(`"${plan.name}" dastlabki narxga qaytarildi.`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusyId(null);
    }
  }

  if (error && !plans) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!plans) return <p className="muted">Yuklanmoqda…</p>;

  const paid = plans.filter((p) => p.kind !== 'trial');
  const trial = plans.find((p) => p.kind === 'trial');

  return (
    <>
      <div className="page-title">
        <h1>Tariflar</h1>
        <span className="muted">{paid.length} ta reja</span>
      </div>

      <p className="muted" style={{ maxWidth: 620, marginTop: -6 }}>
        Narx o'zgartirilishi bilan mijozlarning ilovasida va websaytda
        darhol ko'rinadi — qayta joylash shart emas. Reja muddati va
        turi o'zgartirilmaydi: ular obuna hisobiga bog'liq.
      </p>

      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}
      {done && <p style={{ color: 'var(--success)' }}>{done}</p>}

      {trial && (
        <div className="card" style={{ marginBottom: 16 }}>
          <strong>{trial.name}</strong>{' '}
          <span className="muted">
            — {trial.days ?? 0} kun, bepul. Narx qo'yilmaydi.
          </span>
        </div>
      )}

      <div className="grid grid--2">
        {paid.map((plan) => (
          <PlanCard
            key={plan.id}
            plan={plan}
            busy={busyId === plan.id}
            onSave={save}
            onReset={reset}
          />
        ))}
      </div>
    </>
  );
}

function PlanCard({
  plan,
  busy,
  onSave,
  onReset,
}: {
  plan: Plan;
  busy: boolean;
  onSave: (plan: Plan, price: number, feeUsd?: number) => void;
  onReset: (plan: Plan) => void;
}) {
  const [price, setPrice] = useState(String(plan.price));
  const [fee, setFee] = useState(
    plan.lifetimeAnnualFeeUsd !== undefined
      ? String(plan.lifetimeAnnualFeeUsd)
      : '',
  );

  // Narx serverdan yangilangach maydon ham yangilansin.
  useEffect(() => {
    setPrice(String(plan.price));
    if (plan.lifetimeAnnualFeeUsd !== undefined) {
      setFee(String(plan.lifetimeAnnualFeeUsd));
    }
  }, [plan.price, plan.lifetimeAnnualFeeUsd]);

  const parsed = Number(price);
  const valid = Number.isFinite(parsed) && parsed >= 0;
  const changed =
    parsed !== plan.price ||
    (plan.kind === 'lifetime' && Number(fee) !== plan.lifetimeAnnualFeeUsd);

  const perMonth =
    plan.months && parsed > 0 ? Math.round(parsed / plan.months) : null;

  return (
    <section className="card">
      <div
        style={{
          display: 'flex',
          gap: 10,
          alignItems: 'baseline',
          flexWrap: 'wrap',
        }}
      >
        <h3 style={{ margin: 0 }}>{plan.name}</h3>
        {plan.highlight && (
          <span
            className="badge"
            style={{
              color: 'var(--brand)',
              background: 'color-mix(in srgb, var(--brand) 14%, transparent)',
            }}
          >
            Ommabop
          </span>
        )}
        <span className="muted" style={{ marginInlineStart: 'auto', fontSize: 13 }}>
          {plan.kind === 'lifetime' ? 'Cheksiz' : `${plan.months} oy`}
        </span>
      </div>

      <p className="muted" style={{ fontSize: 13.5, margin: '6px 0 12px' }}>
        Hozirgi narx: <strong>{formatSom(plan.price)}</strong>
        {perMonth !== null && plan.months && plan.months > 1 && (
          <> · oyiga {formatSom(perMonth)}</>
        )}
      </p>

      <label style={{ display: 'block', marginBottom: 10 }}>
        <span className="muted" style={{ fontSize: 13 }}>Narx (so'm)</span>
        <input
          type="number"
          min={0}
          step={1000}
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          style={fieldStyle}
        />
      </label>

      {plan.kind === 'lifetime' && (
        <label style={{ display: 'block', marginBottom: 10 }}>
          <span className="muted" style={{ fontSize: 13 }}>
            Yillik baza to'lovi ($)
          </span>
          <input
            type="number"
            min={0}
            value={fee}
            onChange={(e) => setFee(e.target.value)}
            style={fieldStyle}
          />
        </label>
      )}

      <div style={{ display: 'flex', gap: 8, marginTop: 6 }}>
        <button
          className="btn btn--primary"
          style={{ flex: 1 }}
          disabled={busy || !valid || !changed}
          onClick={() =>
            onSave(
              plan,
              parsed,
              plan.kind === 'lifetime' && fee !== ''
                ? Number(fee)
                : undefined,
            )
          }
        >
          {busy ? 'Saqlanmoqda…' : 'Saqlash'}
        </button>
        <button
          className="btn btn--ghost"
          disabled={busy}
          onClick={() => onReset(plan)}
          title="Dastlabki narxga qaytarish"
        >
          Qaytarish
        </button>
      </div>
    </section>
  );
}
