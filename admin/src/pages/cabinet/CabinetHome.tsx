import { useSearchParams } from 'react-router-dom';

import { BarChart, type BarDatum } from '@/components/charts/BarChart';
import {
  Alert,
  Button,
  Card,
  ChartCard,
  ChipGroup,
  DescriptionList,
  PageHeader,
  Stack,
  StatCard,
  compactNumber,
  deltaOf,
  type ChartStatus,
} from '@/components/ui';
import type { CabinetRange, CabinetSummary } from '@/lib/cabinet-types';
import { dayOfMonth, formatDay, formatTime } from '@/lib/dates';
import { formatNumber, formatSom } from '@/lib/format';
import { useOwnerAuth } from '@/lib/owner-auth';
import { useApi } from '@/lib/use-api';

const RANGES: { id: CabinetRange; label: string; compare: string }[] = [
  { id: 'today', label: 'Bugun', compare: 'kechagiga nisbatan' },
  { id: '7d', label: '7 kun', compare: 'oldingi 7 kunga nisbatan' },
  { id: '30d', label: '30 kun', compare: 'oldingi 30 kunga nisbatan' },
  { id: 'month', label: 'Shu oy', compare: 'o\'tgan oyning shu kunlariga nisbatan' },
];

const som = (v: number) => `${compactNumber(v)} so'm`;

function chartStatus(loading: boolean, error: string | null, data: CabinetSummary | null): ChartStatus {
  if (loading || (!data && !error)) return 'loading';
  if (!data) return 'error';
  return data.series.income.some((v) => v > 0) ? 'ready' : 'empty';
}

/**
 * Kabinet — biznesning bir qarashdagi holati.
 *
 * Raqamlar ilovadagi "Daromad" hisoboti bilan bir xil qoidada: pul qaysi
 * kuni olingan bo'lsa, o'sha kunga (yetkazishda olingan pul — yetkazilgan
 * kunga, qarz to'lovi — to'langan kunga).
 */
export function CabinetHome() {
  const { profile } = useOwnerAuth();
  const [params, setParams] = useSearchParams();
  const range: CabinetRange = RANGES.find((r) => r.id === params.get('davr'))?.id ?? 'month';
  const meta = RANGES.find((r) => r.id === range)!;

  const { data, error, loading, refreshing, updatedAt, reload } = useApi(
    `/api/v1/cabinet/summary?range=${range}`,
    (json) => (json as { summary: CabinetSummary }).summary,
  );

  const setRange = (id: CabinetRange) => {
    const next = new URLSearchParams(params);
    if (id === 'month') next.delete('davr');
    else next.set('davr', id);
    setParams(next, { replace: true });
  };

  const busy = loading || !data;
  const bars: BarDatum[] =
    data?.series.starts.map((s, i) => ({
      label: String(dayOfMonth(s)),
      fullLabel: formatDay(s),
      value: data.series.income[i] ?? 0,
    })) ?? [];

  return (
    <>
      <PageHeader
        title={profile?.name ?? 'Kabinet'}
        description={updatedAt ? `Ma'lumot ${formatTime(updatedAt)} holatiga` : 'Ma\'lumot yuklanmoqda…'}
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={6}>
        <ChipGroup label="Davr" value={range} onChange={setRange} options={RANGES.map((r) => ({ id: r.id, label: r.label }))} />

        {error && !data && (
          <Alert
            tone="danger"
            title="Ma'lumotni yuklab bo'lmadi"
            action={
              <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
                Qayta urinish
              </Button>
            }
          >
            {error}
          </Alert>
        )}
        {error && data && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ma'lumot ko'rsatilmoqda. {error}
          </Alert>
        )}

        <div className="ui-stat-grid">
          <StatCard
            label="Tushum"
            icon="money"
            loading={busy}
            value={data ? som(data.income.total) : ''}
            delta={data ? { ...deltaOf(data.income.total, data.previousIncome), period: meta.compare } : undefined}
            hint={data && data.income.debtPayments > 0 ? `shundan qarz to'lovi: ${formatSom(data.income.debtPayments)}` : undefined}
          />
          <StatCard
            label="Chiqim"
            icon="minus"
            loading={busy}
            value={data ? som(data.expenses) : ''}
            delta={data ? { ...deltaOf(data.expenses, data.previousExpenses), goodWhen: 'down', period: meta.compare } : undefined}
          />
          <StatCard
            label="Sof foyda"
            icon="chart"
            loading={busy}
            value={data ? som(data.profit) : ''}
            hint="tushum − chiqim"
          />
          <StatCard
            label="Qabul qilingan buyurtmalar"
            icon="orders"
            loading={busy}
            value={data ? formatNumber(data.orders.created) : ''}
            delta={data ? { ...deltaOf(data.orders.created, data.orders.previousCreated), period: meta.compare } : undefined}
            hint={data ? `${formatNumber(data.orders.delivered)} ta topshirildi` : undefined}
          />
        </div>

        <div className="ui-grid">
          <ChartCard
            title="Tushum"
            description="Kunlik, pul olingan kun bo'yicha"
            status={chartStatus(loading, error, data)}
            refreshing={refreshing}
            onRetry={reload}
            error={error ?? undefined}
            emptyTitle="Bu davrda pul tushmagan"
            table={{ columns: ['Kun', 'Tushum'], rows: bars.map((b) => [b.fullLabel ?? b.label, formatSom(b.value)]) }}
          >
            <BarChart data={bars} format={formatSom} label="Kunlik tushum" />
          </ChartCard>

          <Stack gap={4}>
            <Card title="Hozir">
              <DescriptionList
                items={[
                  { label: 'Ishda', value: data ? `${formatNumber(data.orders.active)} ta buyurtma` : '—' },
                  { label: 'Topshirishga tayyor', value: data ? `${formatNumber(data.orders.readyToDeliver)} ta` : '—' },
                  {
                    label: 'Qarzdorlar',
                    value: data ? (data.debt.count > 0 ? `${data.debt.count} ta · ${formatSom(data.debt.total)}` : 'Yo\'q') : '—',
                  },
                ]}
              />
            </Card>
            <Card title="Tushum qanday olingan">
              <DescriptionList
                items={[
                  { label: 'Naqd', value: data ? formatSom(data.income.cash) : '—' },
                  { label: 'Karta', value: data ? formatSom(data.income.card) : '—' },
                  ...(data && data.income.other > 0 ? [{ label: 'Boshqa usul', value: formatSom(data.income.other) }] : []),
                ]}
              />
            </Card>
          </Stack>
        </div>
      </Stack>
    </>
  );
}
