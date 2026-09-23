import { useSearchParams } from 'react-router-dom';

import { BarChart, type BarDatum } from '@/components/charts/BarChart';
import { StatusBar } from '@/components/charts/StatusBar';
import {
  Alert,
  Avatar,
  Badge,
  Button,
  ButtonLink,
  Card,
  ChartCard,
  ChipGroup,
  EmptyState,
  List,
  ListItem,
  ListSkeleton,
  PageHeader,
  Skeleton,
  Stack,
  StatCard,
  compactNumber,
  deltaOf,
  type ChartStatus,
} from '@/components/ui';
import { stateVisual, type Overview, type OverviewRange } from '@/lib/admin-types';
import { dayOfMonth, formatDay, formatMonth, formatRelative, formatTime, monthShort } from '@/lib/dates';
import { formatNumber, formatSom } from '@/lib/format';
import { useApi } from '@/lib/use-api';

const DAY = 86_400_000;

const RANGES: { id: OverviewRange; label: string; compare: string; unit: string }[] = [
  { id: '7d', label: '7 kun', compare: 'oldingi 7 kunga nisbatan', unit: 'Kunlik, oxirgi 7 kun' },
  { id: '30d', label: '30 kun', compare: 'oldingi 30 kunga nisbatan', unit: 'Kunlik, oxirgi 30 kun' },
  { id: '90d', label: '3 oy', compare: 'oldingi 3 oyga nisbatan', unit: 'Haftalik, oxirgi 13 hafta' },
  { id: '12m', label: '12 oy', compare: 'oldingi 12 oyga nisbatan', unit: 'Oylik, oxirgi 12 oy' },
];

/** Ustun yorliqlari — davrga qarab kun, hafta yoki oy. */
function toBars(range: OverviewRange, starts: number[], values: number[]): BarDatum[] {
  return starts.map((start, i) => {
    const value = values[i] ?? 0;
    if (range === '12m') return { label: monthShort(start), fullLabel: formatMonth(start), value };
    if (range === '90d') {
      return {
        label: `${dayOfMonth(start)} ${monthShort(start)}`,
        fullLabel: `${formatDay(start)} – ${formatDay(start + 6 * DAY)}`,
        value,
      };
    }
    return { label: String(dayOfMonth(start)), fullLabel: formatDay(start), value };
  });
}

function chartStatus(loading: boolean, error: string | null, hasData: boolean, values: number[]): ChartStatus {
  if (loading) return 'loading';
  if (!hasData) return error ? 'error' : 'loading';
  return values.some((v) => v > 0) ? 'ready' : 'empty';
}

/**
 * Super-admin "Umumiy" sahifasi — platformaning bir qarashdagi holati.
 *
 * Barcha raqamlar `GET /admin/overview` dan — bazadagi haqiqiy yozuvlar.
 * Ma'lumot bo'lmasa bo'sh holat ochiq aytiladi, "chiroyli" to'ldiruvchi
 * raqam ko'rsatilmaydi. Davr URL'da (`?davr=90d`) — sahifa yangilanganda
 * yoki havola yuborilganda saqlanadi.
 */
export function DashboardPage() {
  const [params, setParams] = useSearchParams();
  const range: OverviewRange = RANGES.find((r) => r.id === params.get('davr'))?.id ?? '30d';
  const meta = RANGES.find((r) => r.id === range)!;

  const { data, error, loading, refreshing, updatedAt, reload } = useApi(
    `/api/v1/admin/overview?range=${range}`,
    (json) => (json as { overview: Overview }).overview,
  );

  const setRange = (id: OverviewRange) => {
    const next = new URLSearchParams(params);
    if (id === '30d') next.delete('davr');
    else next.set('davr', id);
    setParams(next, { replace: true });
  };

  // Ma'lumot umuman yo'q va xato — butun sahifa bo'yicha xabar.
  if (error && !data) {
    return (
      <>
        <PageHeader title="Umumiy holat" />
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
      </>
    );
  }

  const revenueBars = data ? toBars(range, data.series.starts, data.series.revenue) : [];
  const regBars = data ? toBars(range, data.series.starts, data.series.registrations) : [];

  return (
    <>
      <PageHeader
        title="Umumiy holat"
        description={
          updatedAt ? `Ma'lumot ${formatTime(updatedAt)} holatiga` : 'Ma\'lumot yuklanmoqda…'
        }
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={6}>
        {/* Davr — barcha ko'rsatkich va chartlarga birdek ta'sir qiladi. */}
        <ChipGroup
          label="Davr"
          value={range}
          onChange={setRange}
          options={RANGES.map((r) => ({ id: r.id, label: r.label }))}
        />

        {error && data && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ma'lumot ko'rsatilmoqda. {error}
          </Alert>
        )}

        <Kpis data={data} loading={loading} compare={meta.compare} />

        <div className="ui-grid">
          <ChartCard
            title="Tushum"
            description={meta.unit}
            status={chartStatus(loading, error, Boolean(data), data?.series.revenue ?? [])}
            refreshing={refreshing}
            onRetry={reload}
            error={error ?? undefined}
            emptyTitle="Bu davrda to'lov tasdiqlanmagan"
            table={{ columns: ['Davr', 'Tushum'], rows: revenueBars.map((b) => [b.fullLabel, formatSom(b.value)]) }}
          >
            <BarChart data={revenueBars} format={formatSom} label={`Tushum, ${meta.unit.toLowerCase()}`} />
          </ChartCard>

          <ChartCard
            title="Yangi bizneslar"
            description={meta.unit}
            status={chartStatus(loading, error, Boolean(data), data?.series.registrations ?? [])}
            refreshing={refreshing}
            onRetry={reload}
            error={error ?? undefined}
            emptyTitle="Bu davrda yangi biznes ro'yxatdan o'tmagan"
            table={{ columns: ['Davr', 'Yangi bizneslar'], rows: regBars.map((b) => [b.fullLabel, `${b.value} ta`]) }}
          >
            <BarChart
              data={regBars}
              format={(v) => `${v} ta biznes`}
              formatAxis={(v) => String(v)}
              integer
              color="var(--chart-3)"
              label={`Yangi bizneslar, ${meta.unit.toLowerCase()}`}
            />
          </ChartCard>
        </div>

        <div className="ui-grid">
          <Attention data={data} />
          <SubscriptionMix data={data} />
        </div>

        <div className="ui-grid">
          <RecentPayments data={data} />
          <RecentTenants data={data} />
        </div>
      </Stack>
    </>
  );
}

/* ------------------------------------------------------------------ */

function Kpis({ data, loading, compare }: { data: Overview | null; loading: boolean; compare: string }) {
  const busy = loading || !data;
  const revenue = data?.revenue;
  const reg = data?.registrations;
  const t = data?.tenants;
  const activity = data?.activity;

  return (
    <div className="ui-stat-grid">
      <StatCard
        label="Tushum"
        icon="money"
        loading={busy}
        value={revenue ? `${compactNumber(revenue.current)} so'm` : ''}
        delta={revenue ? { ...deltaOf(revenue.current, revenue.previous), period: compare } : undefined}
        hint={revenue && revenue.count > 0 ? `${revenue.count} ta to'lov` : undefined}
      />
      <StatCard
        label="Yangi bizneslar"
        icon="building"
        loading={busy}
        value={reg ? formatNumber(reg.current) : ''}
        delta={reg ? { ...deltaOf(reg.current, reg.previous), period: compare } : undefined}
      />
      <StatCard
        label="Faol obunalar"
        icon="card"
        loading={busy}
        href="/admin/tenants"
        value={t ? formatNumber(t.paid) : ''}
        hint={t ? `${t.onTrial} ta sinovda · jami ${formatNumber(t.total)} ta biznes` : undefined}
      />
      <StatCard
        label="Ilovadan foydalanmoqda"
        icon="activity"
        loading={busy}
        value={activity ? `${formatNumber(activity.activeTenants)} ta biznes` : '—'}
        hint={
          activity
            ? `oxirgi 7 kunda · ${formatNumber(activity.activeUsers)} ta foydalanuvchi`
            : data
              ? 'Hozircha aniqlab bo\'lmadi'
              : undefined
        }
      />
    </div>
  );
}

const REASON: Record<Overview['attention'][number]['reason'], string> = {
  pending_payment: 'To\'lov so\'rovi',
  blocked: 'Bloklangan',
  expiring: 'Muddati yaqin',
};

function Attention({ data }: { data: Overview | null }) {
  const pending = data?.pendingPayments ?? 0;
  const t = data?.tenants;

  return (
    <Card
      title="Bugun e'tibor bering"
      description={
        t
          ? `${pending} ta to'lov so'rovi · ${t.blocked} ta bloklangan · ${t.expiring} ta muddati yaqin`
          : 'To\'lov kutayotgan, bloklangan va muddati tugayotgan bizneslar'
      }
      footer={
        data &&
        (pending > 0 ? (
          <ButtonLink to="/admin/payment-requests" variant="primary" size="sm" iconEnd="arrow-right">
            To'lov so'rovlarini ko'rish
          </ButtonLink>
        ) : (
          <ButtonLink to="/admin/tenants" variant="outline" size="sm" iconEnd="arrow-right">
            Barcha bizneslar
          </ButtonLink>
        ))
      }
    >
      {!data ? (
        <ListSkeleton />
      ) : data.attention.length === 0 ? (
        <EmptyState
          compact
          icon="check"
          title="Hammasi joyida"
          description="To'lov kutayotgan, bloklangan yoki muddati tugayotgan biznes yo'q."
        />
      ) : (
        <List label="E'tibor talab qiladigan bizneslar">
          {data.attention.map((item) => (
            <ListItem
              key={`${item.reason}:${item.tenantId}`}
              to={`/admin/tenants/${item.tenantId}`}
              leading={<Avatar name={item.name} square />}
              title={item.name}
              meta={attentionMeta(item)}
              trailing={
                item.reason === 'pending_payment' ? (
                  <Badge tone="brand" icon="card">{REASON[item.reason]}</Badge>
                ) : item.reason === 'blocked' ? (
                  <Badge tone="danger" dot>{stateVisual(item.state).label}</Badge>
                ) : (
                  <Badge tone="warning" dot>{REASON[item.reason]}</Badge>
                )
              }
            />
          ))}
        </List>
      )}
    </Card>
  );
}

function attentionMeta(item: Overview['attention'][number]): string {
  if (item.reason === 'pending_payment') {
    const parts = [item.amount !== undefined ? formatSom(item.amount) : null, item.at ? formatRelative(item.at) : null];
    return parts.filter(Boolean).join(' · ');
  }
  if (item.reason === 'expiring') {
    return item.daysLeft !== null ? `Muddat tugashiga ${item.daysLeft} kun qoldi` : 'Muddat tugamoqda';
  }
  if (item.state === 'suspended') return 'Hisob to\'xtatilgan';
  return item.daysLeft !== null && item.daysLeft < 0
    ? `Muddat ${-item.daysLeft} kun oldin tugagan`
    : 'Obuna muddati tugagan';
}

function SubscriptionMix({ data }: { data: Overview | null }) {
  const t = data?.tenants;
  return (
    <Card title="Obunalar holati" description={t ? `Jami ${formatNumber(t.total)} ta biznes` : undefined}>
      {!t ? (
        <Stack gap={3}>
          <Skeleton height={36} radius={6} />
          <Skeleton width="70%" />
        </Stack>
      ) : t.total === 0 ? (
        <EmptyState compact icon="building" title="Bizneslar hali yo'q" description="Birinchi biznes ilovadan ro'yxatdan o'tgach shu yerda ko'rinadi." />
      ) : (
        <StatusBar
          totalLabel="biznes"
          segments={[
            { label: 'Faol obuna', value: t.active, color: 'var(--success)' },
            { label: 'Sinovda', value: t.trial, color: 'var(--chart-1)' },
            { label: 'Muddati yaqin', value: t.expiring, color: 'var(--warning)' },
            { label: 'Bloklangan', value: t.blocked, color: 'var(--danger)' },
          ]}
        />
      )}
    </Card>
  );
}

function RecentPayments({ data }: { data: Overview | null }) {
  return (
    <Card title="Oxirgi to'lovlar" description="Tasdiqlangan to'lovlar">
      {!data ? (
        <ListSkeleton />
      ) : data.recentPayments.length === 0 ? (
        <EmptyState compact icon="money" title="Hali to'lov tasdiqlanmagan" />
      ) : (
        <List label="Oxirgi to'lovlar">
          {data.recentPayments.map((p) => (
            <ListItem
              key={p.id}
              to={p.tenantId ? `/admin/tenants/${p.tenantId}` : undefined}
              leading={<Avatar name={p.tenantName || '?'} square />}
              title={p.tenantName || 'Noma\'lum biznes'}
              meta={`${p.planName} · ${formatRelative(p.at)}`}
              trailing={formatSom(p.amount)}
            />
          ))}
        </List>
      )}
    </Card>
  );
}

function RecentTenants({ data }: { data: Overview | null }) {
  const knowsActivity = data?.activity !== null;
  return (
    <Card title="Yangi bizneslar" description="Oxirgi ro'yxatdan o'tganlar">
      {!data ? (
        <ListSkeleton />
      ) : data.recentTenants.length === 0 ? (
        <EmptyState compact icon="building" title="Bizneslar hali yo'q" />
      ) : (
        <List label="Oxirgi ro'yxatdan o'tgan bizneslar">
          {data.recentTenants.map((t) => {
            const visual = stateVisual(t.state);
            const activity = !knowsActivity
              ? null
              : t.lastActiveAt
                ? `faol: ${formatRelative(t.lastActiveAt)}`
                : 'ilovaga hali kirmagan';
            return (
              <ListItem
                key={t.tenantId}
                to={`/admin/tenants/${t.tenantId}`}
                leading={<Avatar name={t.name} square />}
                title={t.name}
                meta={[`qo'shildi ${formatRelative(t.createdAt)}`, activity].filter(Boolean).join(' · ')}
                trailing={
                  <Badge tone={t.kind === 'trial' && visual.tone === 'success' ? 'info' : visual.tone} dot>
                    {t.kind === 'trial' && visual.tone === 'success' ? 'Sinovda' : visual.label}
                  </Badge>
                }
              />
            );
          })}
        </List>
      )}
    </Card>
  );
}
