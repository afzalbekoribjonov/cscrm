import { useEffect, useState } from 'react';

import { MoneyInput } from '@/components/MoneyInput';
import {
  Alert,
  Badge,
  Button,
  Card,
  Cluster,
  ConfirmDialog,
  Field,
  Input,
  PageHeader,
  SkeletonText,
  Stack,
  useToast,
} from '@/components/ui';
import { api } from '@/lib/api';
import { formatSom } from '@/lib/format';
import { plans as basePlans, type Plan } from '@/lib/plans';
import { useApi } from '@/lib/use-api';

interface PendingChange {
  plan: Plan;
  price: number;
  feeUsd?: number;
}

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
  const toast = useToast();
  const { data: plans, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/plans',
    (json) => (json as { plans: Plan[] }).plans,
  );
  const [saving, setSaving] = useState<PendingChange | null>(null);
  const [resetting, setResetting] = useState<Plan | null>(null);

  const header = (
    <PageHeader
      title="Tariflar"
      description="Narx o'zgartirilishi bilan ilovada ham, saytda ham darhol ko'rinadi. Reja muddati va turi o'zgarmaydi — ular obuna hisobiga bog'liq."
      actions={
        <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
          Yangilash
        </Button>
      }
    />
  );

  if (error && !plans) {
    return (
      <>
        {header}
        <Alert
          tone="danger"
          title="Tariflarni yuklab bo'lmadi"
          action={
            <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
              Qayta urinish
            </Button>
          }
        >
          {error}
        </Alert>
      </>
    );
  }

  const paid = plans?.filter((p) => p.kind !== 'trial') ?? [];
  const trial = plans?.find((p) => p.kind === 'trial');

  return (
    <>
      {header}
      <Stack gap={4}>
        {trial && (
          <Alert tone="info" title={trial.name}>
            {trial.days ?? 0} kun, bepul — narx qo'yilmaydi.
          </Alert>
        )}

        <div className="ui-grid" style={{ ['--min' as string]: '300px' }}>
          {loading || !plans
            ? [0, 1, 2, 3].map((i) => (
                <Card key={i}>
                  <SkeletonText lines={4} />
                </Card>
              ))
            : paid.map((plan) => (
                <PlanCard
                  key={plan.id}
                  plan={plan}
                  onSave={(price, feeUsd) => setSaving({ plan, price, ...(feeUsd !== undefined ? { feeUsd } : {}) })}
                  onReset={() => setResetting(plan)}
                />
              ))}
        </div>
      </Stack>

      <ConfirmDialog
        open={saving !== null}
        onClose={() => setSaving(null)}
        icon="money"
        title="Narxni o'zgartirish"
        description={saving ? `${saving.plan.name}: ${formatSom(saving.plan.price)} → ${formatSom(saving.price)}` : undefined}
        consequences={[
          'Yangi narx ilovadagi to\'lov ekranida va saytda darhol ko\'rinadi.',
          'Mavjud obunalar o\'zgarmaydi — narx keyingi to\'lovlarga qo\'llanadi.',
        ]}
        confirmLabel="Saqlash"
        onConfirm={async () => {
          if (!saving) return;
          await api.post(`/api/v1/admin/plans/${saving.plan.id}/price`, {
            price: saving.price,
            ...(saving.feeUsd !== undefined ? { lifetimeAnnualFeeUsd: saving.feeUsd } : {}),
          });
          toast.success('Narx yangilandi', saving.plan.name);
          reload();
        }}
      />

      <ConfirmDialog
        open={resetting !== null}
        onClose={() => setResetting(null)}
        icon="restore"
        title="Dastlabki narxga qaytarish"
        description={
          resetting
            ? `${resetting.name}: ${formatSom(basePlans.find((p) => p.id === resetting.id)?.price ?? 0)}`
            : undefined
        }
        consequences={['Panelda qo\'yilgan narx bekor qilinadi, ilova va sayt dastlabki narxni ko\'rsatadi.']}
        confirmLabel="Qaytarish"
        onConfirm={async () => {
          if (!resetting) return;
          await api.del(`/api/v1/admin/plans/${resetting.id}/price`);
          toast.success('Dastlabki narx tiklandi', resetting.name);
          reload();
        }}
      />
    </>
  );
}

function PlanCard({
  plan,
  onSave,
  onReset,
}: {
  plan: Plan;
  onSave: (price: number, feeUsd?: number) => void;
  onReset: () => void;
}) {
  const base = basePlans.find((p) => p.id === plan.id);
  const [price, setPrice] = useState(String(plan.price));
  const [fee, setFee] = useState(plan.lifetimeAnnualFeeUsd !== undefined ? String(plan.lifetimeAnnualFeeUsd) : '');

  // Narx serverdan yangilangach maydon ham yangilansin.
  useEffect(() => {
    setPrice(String(plan.price));
    if (plan.lifetimeAnnualFeeUsd !== undefined) setFee(String(plan.lifetimeAnnualFeeUsd));
  }, [plan.price, plan.lifetimeAnnualFeeUsd]);

  const parsed = Number(price);
  const valid = price !== '' && Number.isFinite(parsed) && parsed >= 0;
  const feeParsed = fee === '' ? undefined : Number(fee);
  const changed =
    parsed !== plan.price || (plan.kind === 'lifetime' && feeParsed !== plan.lifetimeAnnualFeeUsd);
  const overridden =
    base !== undefined &&
    (base.price !== plan.price || (plan.kind === 'lifetime' && base.lifetimeAnnualFeeUsd !== plan.lifetimeAnnualFeeUsd));
  const perMonth = plan.months && plan.months > 1 && parsed > 0 ? Math.round(parsed / plan.months) : null;

  return (
    <Card
      title={plan.name}
      description={plan.kind === 'lifetime' ? 'Muddatsiz' : `${plan.months} oy`}
      actions={
        <Cluster gap={1}>
          {plan.highlight && <Badge tone="brand">Ommabop</Badge>}
          {overridden && <Badge tone="neutral">O'zgartirilgan</Badge>}
        </Cluster>
      }
    >
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (valid && changed) onSave(parsed, plan.kind === 'lifetime' ? feeParsed : undefined);
        }}
      >
        <Stack gap={3}>
          <Field
            label="Narx (so'm)"
            error={!valid ? 'Narxni kiriting.' : undefined}
            hint={perMonth !== null ? `Oyiga ${formatSom(perMonth)}` : undefined}
          >
            <MoneyInput value={price} onChange={setPrice} />
          </Field>
          {plan.kind === 'lifetime' && (
            <Field label="Yillik baza to'lovi ($)" hint="Bir umrlik obuna uchun har yili olinadigan to'lov.">
              <Input type="number" inputMode="decimal" min={0} value={fee} onChange={(e) => setFee(e.target.value)} />
            </Field>
          )}
          <Cluster gap={2}>
            <Button type="submit" disabled={!valid || !changed}>
              Saqlash
            </Button>
            {overridden && (
              <Button variant="plain" icon="restore" onClick={onReset}>
                Dastlabki narx
              </Button>
            )}
          </Cluster>
        </Stack>
      </form>
    </Card>
  );
}
