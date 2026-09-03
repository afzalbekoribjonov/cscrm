import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';

import { api } from '@/lib/api';
import {
  formatDate,
  formatDateTime,
  formatSom,
  stateVisual,
  type PaymentRequestRecord,
  type TenantDetail,
} from '@/lib/admin-types';
import type { Plan } from '@/lib/plans';

export function TenantDetailPage() {
  const { tenantId = '' } = useParams();

  const [tenant, setTenant] = useState<TenantDetail | null>(null);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ tenant: TenantDetail; plans: Plan[] }>(
        `/api/v1/admin/tenants/${tenantId}`,
      );
      setTenant(r.tenant);
      // Sinov rejasini qo'lda berib bo'lmaydi - ro'yxatda ko'rsatmaymiz.
      setPlans(r.plans.filter((p) => p.kind !== 'trial'));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, [tenantId]);

  useEffect(() => {
    load();
  }, [load]);

  if (error) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!tenant) return <p className="muted">Yuklanmoqda…</p>;

  const visual = stateVisual(tenant.status.state);
  const suspended = tenant.license.suspended === true;

  async function confirmPayment(
    planId: string,
    amount: number,
    note: string,
    requestId?: string,
  ) {
    setBusy(true);
    try {
      await api.post(`/api/v1/admin/tenants/${tenantId}/confirm-payment`, {
        planId,
        amount,
        ...(note.trim() ? { note: note.trim() } : {}),
        // So'rov asosida tasdiqlansa - o'sha so'rov navbatdan yopiladi.
        ...(requestId ? { requestId } : {}),
      });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  async function rejectRequest(requestId: string) {
    const reason =
      window.prompt('Rad etish sababi (mijozga ko\'rinadi):') ?? '';
    if (!reason.trim()) return;

    setBusy(true);
    try {
      await api.post(
        `/api/v1/admin/tenants/${tenantId}/payment-requests/${requestId}/reject`,
        { reason: reason.trim() },
      );
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  async function toggleSuspend() {
    const next = !suspended;
    const reason = next
      ? window.prompt('To\'xtatish sababi (mijozga ko\'rinadi):') ?? ''
      : '';
    if (next && !reason.trim()) return;

    setBusy(true);
    try {
      await api.post(`/api/v1/admin/tenants/${tenantId}/suspend`, {
        suspended: next,
        ...(next ? { reason: reason.trim() } : {}),
      });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <Link to="/admin/tenants" style={{ fontSize: 14 }}>
        ← Bizneslar
      </Link>

      <div
        style={{
          display: 'flex',
          gap: 14,
          alignItems: 'center',
          flexWrap: 'wrap',
          margin: '12px 0 22px',
        }}
      >
        <h1 style={{ fontSize: 26, margin: 0 }}>{tenant.name}</h1>
        <span
          style={{
            padding: '4px 12px',
            borderRadius: 999,
            fontSize: 12.5,
            fontWeight: 700,
            color: visual.color,
            background: `color-mix(in srgb, ${visual.color} 14%, transparent)`,
          }}
        >
          {visual.label}
        </span>
      </div>

      <div
        style={{
          display: 'grid',
          gap: 18,
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
          alignItems: 'start',
        }}
      >
        {/* --- Ma'lumot --- */}
        <section className="card">
          <h3>Ma'lumot</h3>
          <Row label="ID" value={<code style={{ fontSize: 12 }}>{tenant.tenantId}</code>} />
          <Row label="Telefon" value={tenant.phone ?? '—'} />
          <Row label="Ro'yxatdan o'tgan" value={formatDate(tenant.createdAt)} />
          <Row label="Xodimlar" value={String(tenant.employeeCount)} />
          <Row label="Buyurtmalar" value={String(tenant.orderCount)} />
        </section>

        {/* --- Obuna --- */}
        <section className="card">
          <h3>Obuna</h3>
          <Row label="Reja" value={tenant.license.planId} />
          <Row label="Tur" value={tenant.license.kind} />
          <Row
            label="Muddat"
            value={
              tenant.license.kind === 'lifetime'
                ? 'Cheksiz'
                : formatDate(tenant.license.expiresAt)
            }
          />
          {tenant.license.kind === 'lifetime' && (
            <Row
              label="Yillik baza to'lovi"
              value={formatDate(tenant.license.nextAnnualFeeAt)}
            />
          )}
          <Row label="Server xabari" value={tenant.status.message} />

          <button
            className="btn btn--ghost"
            disabled={busy}
            onClick={toggleSuspend}
            style={{
              marginTop: 14,
              width: '100%',
              color: suspended ? 'var(--success)' : 'var(--danger)',
            }}
          >
            {suspended ? 'To\'xtatishni bekor qilish' : 'Hisobni to\'xtatish'}
          </button>
        </section>

        {/* --- Mijozning to'lov so'rovi --- */}
        {tenant.paymentRequest && (
          <RequestCard
            request={tenant.paymentRequest}
            busy={busy}
            onConfirm={() =>
              confirmPayment(
                tenant.paymentRequest!.planId,
                tenant.paymentRequest!.amount,
                tenant.paymentRequest!.reference
                  ? `O'tkazma: ${tenant.paymentRequest!.reference}`
                  : '',
                tenant.paymentRequest!.id,
              )
            }
            onReject={() => rejectRequest(tenant.paymentRequest!.id)}
          />
        )}

        {/* --- To'lovni tasdiqlash --- */}
        <ConfirmPaymentCard
          plans={plans}
          busy={busy}
          onConfirm={confirmPayment}
        />
      </div>

      {/* --- To'lovlar tarixi --- */}
      <section className="card" style={{ marginTop: 18 }}>
        <h3>To'lovlar tarixi</h3>
        {tenant.payments.length === 0 ? (
          <p className="muted" style={{ margin: 0 }}>
            Hali to'lov tasdiqlanmagan.
          </p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 520 }}>
              <tbody>
                {tenant.payments.map((p) => (
                  <tr key={p.id}>
                    <td style={cellStyle}>{formatDate(p.confirmedAt)}</td>
                    <td style={cellStyle}>{p.planName}</td>
                    <td style={{ ...cellStyle, fontWeight: 600 }}>
                      {formatSom(p.amount)}
                    </td>
                    <td style={{ ...cellStyle, color: 'var(--text-muted)' }}>
                      {p.newExpiresAt
                        ? `→ ${formatDate(p.newExpiresAt)}`
                        : '→ cheksiz'}
                    </td>
                    <td style={{ ...cellStyle, color: 'var(--text-muted)' }}>
                      {p.note ?? ''}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}

/**
 * Mijozning "men to'ladim" so'rovi.
 *
 * Tasdiqlash tugmasi reja va summani so'rovdan oladi — super-admin
 * qo'lda qayta kiritmasligi kerak, aks holda xato qilish oson.
 */
function RequestCard({
  request,
  busy,
  onConfirm,
  onReject,
}: {
  request: PaymentRequestRecord;
  busy: boolean;
  onConfirm: () => void;
  onReject: () => void;
}) {
  const pending = request.status === 'pending';
  const color = pending
    ? 'var(--warning)'
    : request.status === 'approved'
      ? 'var(--success)'
      : 'var(--danger)';
  const label = pending
    ? 'Ko\'rib chiqilmagan'
    : request.status === 'approved'
      ? 'Tasdiqlangan'
      : 'Rad etilgan';

  return (
    <section
      className="card"
      style={{
        borderColor: `color-mix(in srgb, ${color} 45%, transparent)`,
      }}
    >
      <div
        style={{
          display: 'flex',
          gap: 10,
          alignItems: 'baseline',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
        }}
      >
        <h3 style={{ margin: 0 }}>Mijozning so'rovi</h3>
        <span style={{ color, fontSize: 13, fontWeight: 700 }}>{label}</span>
      </div>

      <Row label="Yuborilgan" value={formatDateTime(request.createdAt)} />
      <Row label="Reja" value={request.planName} />
      <Row label="Summa" value={formatSom(request.amount)} />
      {request.reference && (
        <Row label="O'tkazma raqami" value={request.reference} />
      )}
      {request.note && <Row label="Izoh" value={request.note} />}
      {request.rejectReason && (
        <Row label="Rad etish sababi" value={request.rejectReason} />
      )}

      {pending && (
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <button
            className="btn btn--primary"
            style={{ flex: 1 }}
            disabled={busy}
            onClick={onConfirm}
          >
            {busy ? 'Bajarilmoqda…' : 'Tasdiqlash'}
          </button>
          <button
            className="btn btn--ghost"
            style={{ color: 'var(--danger)' }}
            disabled={busy}
            onClick={onReject}
          >
            Rad etish
          </button>
        </div>
      )}
    </section>
  );
}

function ConfirmPaymentCard({
  plans,
  busy,
  onConfirm,
}: {
  plans: Plan[];
  busy: boolean;
  onConfirm: (planId: string, amount: number, note: string) => void;
}) {
  const [planId, setPlanId] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');

  const plan = plans.find((p) => p.id === planId);

  return (
    <section className="card">
      <h3>To'lovni tasdiqlash</h3>
      <p className="muted" style={{ fontSize: 14 }}>
        Karta o'tkazmasi kelganini tekshirgach, rejani tanlab tasdiqlang.
        Obuna darhol uzayadi va ilova ochiladi.
      </p>

      <label style={{ display: 'block', marginBottom: 10 }}>
        <span className="muted" style={{ fontSize: 13 }}>Reja</span>
        <select
          value={planId}
          onChange={(e) => {
            setPlanId(e.target.value);
            const p = plans.find((x) => x.id === e.target.value);
            setAmount(p && p.price > 0 ? String(p.price) : '');
          }}
          style={fieldStyle}
        >
          <option value="">— tanlang —</option>
          {plans.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
      </label>

      <label style={{ display: 'block', marginBottom: 10 }}>
        <span className="muted" style={{ fontSize: 13 }}>
          Olingan summa (so'm)
        </span>
        <input
          type="number"
          min={0}
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder={plan && plan.price > 0 ? String(plan.price) : '0'}
          style={fieldStyle}
        />
      </label>

      <label style={{ display: 'block', marginBottom: 14 }}>
        <span className="muted" style={{ fontSize: 13 }}>Izoh (ixtiyoriy)</span>
        <input
          type="text"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="masalan: chek raqami"
          style={fieldStyle}
        />
      </label>

      <button
        className="btn btn--primary"
        style={{ width: '100%' }}
        disabled={busy || !planId}
        onClick={() => {
          if (!planId) return;
          onConfirm(planId, Number(amount) || 0, note);
          setPlanId('');
          setAmount('');
          setNote('');
        }}
      >
        {busy ? 'Bajarilmoqda…' : 'To\'lovni tasdiqlash'}
      </button>
    </section>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div
      style={{
        display: 'flex',
        gap: 12,
        justifyContent: 'space-between',
        padding: '7px 0',
        borderBottom: '1px solid var(--border)',
        fontSize: 14,
      }}
    >
      <span className="muted">{label}</span>
      <span style={{ textAlign: 'end' }}>{value}</span>
    </div>
  );
}

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

const cellStyle: React.CSSProperties = {
  padding: '9px 10px',
  borderBottom: '1px solid var(--border)',
  fontSize: 14,
};
