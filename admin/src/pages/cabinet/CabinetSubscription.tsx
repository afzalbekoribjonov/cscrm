import { useEffect, useMemo, useState } from 'react';

import { MoneyInput } from '@/components/MoneyInput';
import {
  Alert,
  Button,
  Card,
  ChipGroup,
  Cluster,
  ConfirmDialog,
  DataTable,
  DescriptionList,
  EmptyState,
  Field,
  IconButton,
  Input,
  PageHeader,
  SkeletonText,
  Stack,
  useToast,
  type Column,
} from '@/components/ui';
import type { CabinetPayment, OwnerPaymentRequest, PlansResponse } from '@/lib/cabinet-types';
import { api } from '@/lib/api';
import { formatDay, formatRelative } from '@/lib/dates';
import { formatSom } from '@/lib/format';
import { useOwnerAuth } from '@/lib/owner-auth';
import { useApi } from '@/lib/use-api';
import { TenantBadge, termText } from '@/pages/admin/tenant/status';

const PAYMENT_COLUMNS: Column<CabinetPayment>[] = [
  { key: 'date', header: 'Sana', primary: true, cell: (p) => formatDay(p.confirmedAt) },
  { key: 'plan', header: 'Reja', cell: (p) => p.planName },
  { key: 'amount', header: 'Summa', align: 'end', numeric: true, cell: (p) => formatSom(p.amount) },
  { key: 'until', header: 'Yangi muddat', cell: (p) => (p.newExpiresAt ? formatDay(p.newExpiresAt) : 'Cheksiz') },
];

async function copy(text: string, toast: ReturnType<typeof useToast>) {
  try {
    await navigator.clipboard.writeText(text.replace(/\s/g, ''));
    toast.success('Karta raqami nusxalandi');
  } catch {
    toast.error('Nusxalab bo\'lmadi', 'Raqamni qo\'lda belgilab oling.');
  }
}

/**
 * Obuna va to'lov — ilovadagi to'lov ekranining veb nusxasi.
 *
 * To'lov — qo'lda karta o'tkazma: ega pulni kartaga o'tkazadi va shu
 * yerdan xabar beradi; CSCRM jamoasi bank ko'chirmasi bilan solishtirib
 * tasdiqlaydi. Tasdiqlangach obuna o'zi uzayadi.
 */
export function CabinetSubscription() {
  const toast = useToast();
  const { profile, refresh } = useOwnerAuth();
  const plansApi = useApi('/api/v1/license/plans', (j) => j as PlansResponse, { staleMs: 10 * 60_000 });
  const requestApi = useApi('/api/v1/license/payment-request', (j) => (j as { request: OwnerPaymentRequest | null }).request);
  const paymentsApi = useApi('/api/v1/cabinet/payments', (j) => (j as { payments: CabinetPayment[] }).payments);

  const paid = useMemo(() => plansApi.data?.plans.filter((p) => p.kind !== 'trial') ?? [], [plansApi.data]);
  const [planId, setPlanId] = useState('');
  const [amount, setAmount] = useState('');
  const [reference, setReference] = useState('');
  const [confirming, setConfirming] = useState(false);

  // Boshlang'ich tanlov — joriy reja (pullik bo'lsa), aks holda ommabop.
  useEffect(() => {
    if (planId || paid.length === 0) return;
    const current = paid.find((p) => p.id === profile?.status.planId);
    const pick = current ?? paid.find((p) => p.highlight) ?? paid[0]!;
    setPlanId(pick.id);
    setAmount(pick.price > 0 ? String(pick.price) : '');
  }, [paid, planId, profile]);

  if (!profile) return null;
  const status = profile.status;
  const term = termText(status);
  const plan = paid.find((p) => p.id === planId);
  const request = requestApi.data;
  const pending = request?.status === 'pending';
  const payment = plansApi.data?.payment;

  return (
    <>
      <PageHeader title="Obuna va to'lov" description="Obuna holati, to'lov rekvizitlari va to'lovlar tarixi." />

      <Stack gap={5}>
        <div className="ui-split">
          <Card title="Obuna" actions={<TenantBadge tenant={{ status, archive: null }} />}>
            <DescriptionList
              items={[
                { label: 'Reja', value: profile.planName },
                {
                  label: status.kind === 'lifetime' ? 'Muddat' : 'Tugash sanasi',
                  value: (
                    <>
                      {term.main}
                      {term.sub && <span className="ui-table__sub">{term.sub}</span>}
                    </>
                  ),
                },
                ...(status.message ? [{ label: 'Holat', value: status.message }] : []),
              ]}
            />
          </Card>

          <Card title="Oxirgi to'lov xabaringiz">
            {requestApi.loading ? (
              <SkeletonText lines={2} />
            ) : !request ? (
              <p className="ui-note">Hali to'lov haqida xabar yubormagansiz.</p>
            ) : request.status === 'pending' ? (
              <Alert tone="info" title="Ko'rib chiqilmoqda">
                {request.planName} · {formatSom(request.amount)} · {formatRelative(request.createdAt)} yuborilgan.
                Tasdiqlangach obuna o'zi uzayadi.
              </Alert>
            ) : request.status === 'rejected' ? (
              <Alert tone="warning" title="Rad etilgan">
                {request.rejectReason ? `Sabab: ${request.rejectReason}.` : ''} Muammo bo'lsa yordam xizmatiga yozing.
              </Alert>
            ) : (
              <Alert tone="success" title="Tasdiqlangan">
                {request.planName} · {formatSom(request.amount)}
                {request.resolvedAt ? ` · ${formatDay(request.resolvedAt)}` : ''}
              </Alert>
            )}
          </Card>
        </div>

        <Card title="To'lash" description="1. Rejani tanlang · 2. Kartaga o'tkazing · 3. Shu yerdan xabar bering.">
          {plansApi.loading || !plansApi.data ? (
            plansApi.error ? (
              <Alert
                tone="danger"
                action={
                  <Button variant="outline" size="sm" icon="refresh" onClick={plansApi.reload}>
                    Qayta urinish
                  </Button>
                }
              >
                {plansApi.error}
              </Alert>
            ) : (
              <SkeletonText lines={4} />
            )
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (plan && !pending) setConfirming(true);
              }}
            >
              <Stack gap={5}>
                <ChipGroup
                  label="Reja"
                  value={planId}
                  onChange={(id) => {
                    setPlanId(id);
                    const p = paid.find((x) => x.id === id);
                    setAmount(p && p.price > 0 ? String(p.price) : '');
                  }}
                  options={paid.map((p) => ({ id: p.id, label: `${p.name} — ${formatSom(p.price)}` }))}
                />

                {payment && payment.configured ? (
                  <div className="cab-cards">
                    {payment.cards.map((c) => (
                      <div key={c.number} className="cab-card">
                        <span className="cab-card__type">{c.type || 'Karta'}</span>
                        <span className="cab-card__number">{c.number}</span>
                        {payment.cardHolder && <span className="cab-card__holder">{payment.cardHolder}</span>}
                        <IconButton icon="copy" size="sm" label="Raqamni nusxalash" onClick={() => void copy(c.number, toast)} />
                      </div>
                    ))}
                    {payment.note && <p className="ui-note">{payment.note}</p>}
                  </div>
                ) : (
                  <Alert tone="warning">
                    To'lov rekvizitlari hozircha ko'rsatilmagan. Yordam xizmatiga murojaat qiling.
                  </Alert>
                )}

                <div className="ui-grid" style={{ ['--min' as string]: '220px' }}>
                  <Field label="O'tkazilgan summa (so'm)" hint={plan ? `Reja narxi: ${formatSom(plan.price)}` : undefined}>
                    <MoneyInput value={amount} onChange={setAmount} />
                  </Field>
                  <Field label="O'tkazma yoki chek raqami" optional hint="Tasdiqlashni tezlashtiradi.">
                    <Input value={reference} onChange={(e) => setReference(e.target.value)} maxLength={120} />
                  </Field>
                </div>

                {pending && (
                  <Alert tone="info">Oldingi xabaringiz hali ko'rib chiqilmoqda — yangisini u hal bo'lgach yuborish mumkin.</Alert>
                )}
                <Cluster>
                  <Button type="submit" icon="check" disabled={!plan || pending}>
                    Men to'ladim
                  </Button>
                </Cluster>
              </Stack>
            </form>
          )}
        </Card>

        <Card
          title="To'lovlar tarixi"
          description={paymentsApi.data ? `${paymentsApi.data.length} ta tasdiqlangan to'lov` : undefined}
          padded={false}
        >
          <DataTable
            caption="To'lovlar tarixi"
            columns={PAYMENT_COLUMNS}
            rows={paymentsApi.loading ? null : (paymentsApi.data ?? [])}
            rowKey={(p) => p.id}
            empty={<EmptyState icon="card" title="Hali to'lov yo'q" description="Tasdiqlangan to'lovlar shu yerda ko'rinadi." compact />}
          />
        </Card>
      </Stack>

      <ConfirmDialog
        open={confirming}
        onClose={() => setConfirming(false)}
        icon="card"
        title="To'lov haqida xabar berish"
        description={plan ? `${plan.name} · ${formatSom(Number(amount) || plan.price)}` : undefined}
        consequences={[
          'Xabar CSCRM jamoasiga boradi — bank ko\'chirmasi bilan solishtiriladi.',
          'Tasdiqlangach obuna o\'zi uzayadi, ilova ham yangilanadi.',
          'Pulni hali o\'tkazmagan bo\'lsangiz — avval o\'tkazing.',
        ]}
        confirmLabel="Yuborish"
        onConfirm={async () => {
          if (!plan) return;
          await api.post('/api/v1/license/payment-request', {
            planId: plan.id,
            ...(Number(amount) > 0 ? { amount: Number(amount) } : {}),
            ...(reference.trim() ? { reference: reference.trim() } : {}),
          });
          toast.success('Xabar yuborildi', 'Tasdiqlanishi bilan obuna uzayadi.');
          setReference('');
          requestApi.reload();
          void refresh();
        }}
      />
    </>
  );
}
