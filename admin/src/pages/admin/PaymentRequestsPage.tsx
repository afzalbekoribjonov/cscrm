import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { api } from '@/lib/api';
import {
  formatDateTime,
  formatSom,
  type PendingPayment,
} from '@/lib/admin-types';
import type { Plan } from '@/lib/plans';

/**
 * To'lov so'rovlari navbati — panelning asosiy kundalik ishi.
 *
 * To'lov usuli qo'lda karta o'tkazma: mijoz pulni o'tkazgach ilovadan
 * "to'lov qildim" deb xabar beradi, biz esa bank ko'chirmasi bilan
 * solishtirib tasdiqlaymiz yoki rad etamiz.
 */
export function PaymentRequestsPage() {
  const [requests, setRequests] = useState<PendingPayment[] | null>(null);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ requests: PendingPayment[]; plans: Plan[] }>(
        '/api/v1/admin/payment-requests',
      );
      setRequests(r.requests);
      setPlans(r.plans.filter((p) => p.kind !== 'trial'));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function act(
    request: PendingPayment,
    action: 'confirm' | 'reject',
  ): Promise<void> {
    if (action === 'confirm') {
      const ok = window.confirm(
        `${request.tenantName} — ${request.planName} rejasi tasdiqlansinmi?\n` +
          `Summa: ${formatSom(request.amount)}\n\n` +
          'Obuna darhol uzayadi.',
      );
      if (!ok) return;
    }

    const reason =
      action === 'reject'
        ? window.prompt('Rad etish sababi (mijozga ko\'rinadi):') ?? ''
        : '';
    if (action === 'reject' && !reason.trim()) return;

    setBusyId(request.id);
    try {
      if (action === 'confirm') {
        await api.post(
          `/api/v1/admin/tenants/${request.tenantId}/confirm-payment`,
          {
            planId: request.planId,
            amount: request.amount,
            requestId: request.id,
            ...(request.reference ? { note: `O'tkazma: ${request.reference}` } : {}),
          },
        );
      } else {
        await api.post(
          `/api/v1/admin/tenants/${request.tenantId}/payment-requests/${request.id}/reject`,
          { reason: reason.trim() },
        );
      }
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusyId(null);
    }
  }

  if (error) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!requests) return <p className="muted">Yuklanmoqda…</p>;

  return (
    <>
      <h1 style={{ fontSize: 26, marginBottom: 6 }}>To'lov so'rovlari</h1>
      <p className="muted" style={{ marginTop: 0, marginBottom: 20 }}>
        Mijozlar "to'lov qildim" deb yuborgan xabarlar. Bank ko'chirmasi
        bilan solishtiring, keyin tasdiqlang.
      </p>

      {requests.length === 0 ? (
        <div className="card">
          <p style={{ margin: 0 }}>Ko'rib chiqilmagan so'rov yo'q.</p>
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          {requests.map((r) => (
            <section key={r.id} className="card">
              <div
                style={{
                  display: 'flex',
                  gap: 14,
                  flexWrap: 'wrap',
                  alignItems: 'baseline',
                  justifyContent: 'space-between',
                }}
              >
                <h3 style={{ margin: 0 }}>
                  <Link to={`/admin/tenants/${r.tenantId}`}>{r.tenantName}</Link>
                </h3>
                <span className="muted" style={{ fontSize: 13 }}>
                  {formatDateTime(r.createdAt)}
                </span>
              </div>

              <div
                style={{
                  display: 'flex',
                  gap: 20,
                  flexWrap: 'wrap',
                  margin: '12px 0',
                  fontSize: 14,
                }}
              >
                <Field label="Reja" value={planName(plans, r)} />
                <Field label="Summa" value={formatSom(r.amount)} strong />
                {r.reference && (
                  <Field label="O'tkazma raqami" value={r.reference} />
                )}
              </div>

              {r.note && (
                <p
                  className="muted"
                  style={{
                    margin: '0 0 12px',
                    padding: 10,
                    borderRadius: 'var(--radius)',
                    background: 'var(--surface-muted)',
                    fontSize: 14,
                  }}
                >
                  {r.note}
                </p>
              )}

              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <button
                  className="btn btn--primary"
                  disabled={busyId !== null}
                  onClick={() => act(r, 'confirm')}
                >
                  {busyId === r.id ? 'Bajarilmoqda…' : 'Tasdiqlash'}
                </button>
                <button
                  className="btn btn--ghost"
                  disabled={busyId !== null}
                  style={{ color: 'var(--danger)' }}
                  onClick={() => act(r, 'reject')}
                >
                  Rad etish
                </button>
              </div>
            </section>
          ))}
        </div>
      )}
    </>
  );
}

/** Reja nomi so'rov bilan birga keladi; ro'yxatdan topilsa yangisi olinadi. */
function planName(plans: Plan[], request: PendingPayment): string {
  return plans.find((p) => p.id === request.planId)?.name ?? request.planName;
}

function Field({
  label,
  value,
  strong,
}: {
  label: string;
  value: string;
  strong?: boolean;
}) {
  return (
    <div>
      <div className="muted" style={{ fontSize: 12.5 }}>
        {label}
      </div>
      <div style={{ fontWeight: strong ? 700 : 500 }}>{value}</div>
    </div>
  );
}
