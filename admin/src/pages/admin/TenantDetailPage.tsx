import { useNavigate, useParams, useSearchParams } from 'react-router-dom';

import {
  Alert,
  Badge,
  Button,
  Card,
  Cluster,
  DataTable,
  DescriptionList,
  DropdownMenu,
  EmptyState,
  PageHeader,
  Skeleton,
  SkeletonText,
  Stack,
  Tabs,
  useTable,
  type Column,
  type TabItem,
} from '@/components/ui';
import type { AuditEntry, PaymentRecord, PaymentRequestRecord, TenantDetail } from '@/lib/admin-types';
import { formatDay, formatRelative, formatTime } from '@/lib/dates';
import { formatNumber, formatPhone, formatSom } from '@/lib/format';
import { useAuth } from '@/lib/auth';
import type { Plan } from '@/lib/plans';
import { useApi } from '@/lib/use-api';

import { AuditList } from './tenant/AuditList';
import { OwnerAccess } from './tenant/OwnerAccess';
import { tenantRef, useTenantActions, type TenantRef } from './tenant/actions';
import { purgeText, TenantBadge, termText } from './tenant/status';

type Section = 'umumiy' | 'tolovlar' | 'kirish' | 'tarix';

interface DetailResponse {
  tenant: TenantDetail;
  plans: Plan[];
}

/**
 * Biznes kartasi.
 *
 * Tepada — holat va asosiy amallar; diqqat talab qiladigan narsa
 * (arxiv, to'xtatilgan, mijoz to'lov qilgani) sarlavha ostida alohida
 * ogohlantirishda. Bo'limlar URL'da (`?bolim=tolovlar`) — sahifa
 * yangilanganda yoki havola yuborilganda o'sha bo'lim ochiladi.
 */
export function TenantDetailPage() {
  const { tenantId = '' } = useParams();
  const navigate = useNavigate();
  const { can } = useAuth();
  const [params, setParams] = useSearchParams();

  const { data, error, loading, refreshing, reload } = useApi(
    `/api/v1/admin/tenants/${tenantId}`,
    (json) => json as DetailResponse,
  );
  const tenant = data?.tenant ?? null;
  const plans = data?.plans ?? [];

  const actions = useTenantActions({
    plans,
    onChanged: reload,
    onDeleted: () => navigate('/admin/tenants', { replace: true }),
  });

  // Bo'lim faqat vakolati bo'lsa: kirish ma'lumotlari va jurnal — alohida huquq.
  const tabs: TabItem<Section>[] = [
    { id: 'umumiy', label: 'Umumiy' },
    { id: 'tolovlar', label: 'To\'lovlar', ...(tenant ? { count: tenant.payments.length } : {}) },
    ...(can('credentials.manage') ? [{ id: 'kirish' as const, label: 'Kirish' }] : []),
    ...(can('audit.read') ? [{ id: 'tarix' as const, label: 'Tarix' }] : []),
  ];
  const section: Section = tabs.find((t) => t.id === params.get('bolim'))?.id ?? 'umumiy';
  const setSection = (id: Section) => {
    const next = new URLSearchParams(params);
    if (id === 'umumiy') next.delete('bolim');
    else next.set('bolim', id);
    setParams(next, { replace: true });
  };

  const back = { to: '/admin/tenants', label: 'Bizneslar' };

  if (error && !tenant) {
    return (
      <>
        <PageHeader title="Biznes" back={back} />
        <Alert
          tone="danger"
          title="Biznes ma'lumotini yuklab bo'lmadi"
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

  if (loading || !tenant) return <DetailSkeleton back={back} />;

  const ref = tenantRef(tenant);
  const archived = tenant.archive !== null;
  const pending = tenant.paymentRequest?.status === 'pending' ? tenant.paymentRequest : null;
  const menu = actions.menuItems(ref, { detail: tenant }).filter((i) => i.id !== 'pay' && i.id !== 'restore');
  const canPay = can('payments.manage');

  return (
    <>
      <PageHeader
        back={back}
        title={tenant.name}
        meta={<TenantBadge tenant={tenant} />}
        description={`Reja: ${tenant.planName} · Qo'shilgan: ${formatDay(tenant.createdAt)}`}
        actions={
          <Cluster gap={2}>
            {archived
              ? can('tenants.archive') && (
                  <Button variant="secondary" icon="restore" onClick={() => actions.openRestore(ref)}>
                    Arxivdan qaytarish
                  </Button>
                )
              : canPay && (
                  <Button icon="card" disabled={plans.length === 0} onClick={() => actions.openPayment(ref, pending)}>
                    To'lov qabul qilish
                  </Button>
                )}
            {menu.length > 0 && <DropdownMenu items={menu} label="Boshqa amallar" />}
          </Cluster>
        }
      />

      <Stack gap={5}>
        {error && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ma'lumot ko'rsatilmoqda. {error}
          </Alert>
        )}
        <StatusAlerts tenant={tenant} tenantRef={ref} actions={actions} />

        <Tabs label="Biznes bo'limlari" items={tabs} value={section} onChange={setSection}>
          <div aria-busy={refreshing}>
            {section === 'umumiy' && (
              <Overview
                tenant={tenant}
                onEdit={archived || !can('tenants.edit') ? undefined : () => actions.openEdit(ref, tenant)}
                onLicense={
                  archived || plans.length === 0 || !can('subscriptions.manage')
                    ? undefined
                    : () => actions.openLicense(ref, tenant)
                }
              />
            )}
            {section === 'tolovlar' && (
              <Payments
                tenant={tenant}
                onConfirm={archived || !canPay ? undefined : (r) => actions.openPayment(ref, r)}
                onReject={archived || !canPay ? undefined : (r) => actions.openReject(ref, r)}
              />
            )}
            {section === 'kirish' && <OwnerAccess tenantId={tenant.tenantId} archived={archived} />}
            {section === 'tarix' && <History tenantId={tenant.tenantId} plans={plans} />}
          </div>
        </Tabs>
      </Stack>

      {actions.dialogs}
    </>
  );
}

/* ------------------------------------------------------------------ */

function DetailSkeleton({ back }: { back: { to: string; label: string } }) {
  return (
    <>
      <PageHeader back={back} title={<Skeleton width={220} height={28} />} />
      <div className="ui-split" aria-busy="true">
        <Card>
          <SkeletonText lines={6} />
        </Card>
        <Card>
          <SkeletonText lines={4} />
        </Card>
      </div>
    </>
  );
}

/** Sarlavha ostidagi ogohlantirishlar — faqat haqiqatan diqqat kerak bo'lganda. */
function StatusAlerts({
  tenant,
  tenantRef: ref,
  actions,
}: {
  tenant: TenantDetail;
  tenantRef: TenantRef;
  actions: ReturnType<typeof useTenantActions>;
}) {
  const { can } = useAuth();
  const alerts = [];

  if (tenant.archive) {
    alerts.push(
      <Alert
        key="archive"
        tone="warning"
        title={`Biznes arxivda — ${purgeText(tenant.archive)}`}
        action={
          can('tenants.delete') && (
            <Button variant="danger-outline" size="sm" icon="trash" onClick={() => actions.openDelete(ref)}>
              Hozir o'chirish
            </Button>
          )
        }
      >
        {formatDay(tenant.archive.archivedAt)} kuni arxivlangan. Sabab: {tenant.archive.reason}
      </Alert>,
    );
  } else if (tenant.license.suspended) {
    alerts.push(
      <Alert
        key="suspended"
        tone="danger"
        title="Biznes to'xtatilgan"
        action={
          can('tenants.suspend') && (
            <Button variant="outline" size="sm" icon="unlock" onClick={() => actions.openUnsuspend(ref)}>
              Qayta ochish
            </Button>
          )
        }
      >
        {tenant.license.suspendedReason
          ? `Mijozga ko'rsatilayotgan sabab: ${tenant.license.suspendedReason}`
          : 'Egasi va xodimlari ilovada ishlay olmaydi.'}
      </Alert>,
    );
  }

  const request = tenant.paymentRequest;
  if (request?.status === 'pending' && !tenant.archive) {
    alerts.push(
      <Alert
        key="request"
        tone="info"
        title="Mijoz to'lov qilganini bildirdi"
        action={
          can('payments.manage') && (
            <Cluster gap={2}>
              <Button size="sm" icon="check" onClick={() => actions.openPayment(ref, request)}>
                Tasdiqlash
              </Button>
              <Button variant="plain" size="sm" onClick={() => actions.openReject(ref, request)}>
                Rad etish
              </Button>
            </Cluster>
          )
        }
      >
        {request.planName} · {formatSom(request.amount)} · {formatRelative(request.createdAt)}
        {request.reference ? ` · o'tkazma: ${request.reference}` : ''}
      </Alert>,
    );
  }

  return alerts.length > 0 ? <Stack gap={3}>{alerts}</Stack> : null;
}

/* ------------------------------------------------------------------ */

function Overview({
  tenant,
  onEdit,
  onLicense,
}: {
  tenant: TenantDetail;
  onEdit?: () => void;
  onLicense?: () => void;
}) {
  const term = termText(tenant.status);
  const lifetime = tenant.license.kind === 'lifetime';

  return (
    <div className="ui-split">
      <Card
        title="Biznes ma'lumoti"
        actions={
          onEdit && (
            <Button variant="plain" size="sm" icon="edit" onClick={onEdit}>
              Tahrirlash
            </Button>
          )
        }
      >
        <DescriptionList
          items={[
            { label: 'Nomi', value: tenant.name },
            { label: 'Telefon', value: tenant.phone ? formatPhone(tenant.phone) : <Missing /> },
            { label: 'Manzil', value: tenant.address || <Missing /> },
            { label: 'Ro\'yxatdan o\'tgan', value: formatDay(tenant.createdAt) },
            {
              label: 'Oxirgi faollik',
              value: tenant.lastActiveAt ? formatRelative(tenant.lastActiveAt) : <span className="ui-muted">Ma'lumot yo'q</span>,
            },
            { label: 'Xodimlar', value: `${formatNumber(tenant.employeeCount)} ta` },
            { label: 'Buyurtmalar', value: `${formatNumber(tenant.orderCount)} ta` },
            { label: 'Biznes ID', value: <code className="ui-code">{tenant.tenantId}</code> },
          ]}
        />
      </Card>

      <Card
        title="Obuna"
        actions={
          onLicense && (
            <Button variant="plain" size="sm" icon="calendar" onClick={onLicense}>
              O'zgartirish
            </Button>
          )
        }
      >
        <DescriptionList
          items={[
            { label: 'Holat', value: <TenantBadge tenant={tenant} /> },
            { label: 'Reja', value: tenant.planName },
            {
              label: lifetime ? 'Muddat' : 'Tugash sanasi',
              value: (
                <>
                  {term.main}
                  {term.sub && <span className="ui-table__sub">{term.sub}</span>}
                </>
              ),
            },
            ...(lifetime && tenant.license.nextAnnualFeeAt
              ? [{ label: 'Yillik to\'lov', value: formatDay(tenant.license.nextAnnualFeeAt) }]
              : []),
            { label: 'Boshlangan', value: formatDay(tenant.license.startedAt) },
            // Ilova mijozga ko'rsatayotgan ogohlantirish (bo'lsa).
            ...(tenant.status.message ? [{ label: 'Ilovadagi xabar', value: tenant.status.message }] : []),
          ]}
        />
      </Card>
    </div>
  );
}

function Missing() {
  return <span className="ui-muted">Kiritilmagan</span>;
}

/* ------------------------------------------------------------------ */

const PAYMENT_COLUMNS: Column<PaymentRecord>[] = [
  {
    key: 'date',
    header: 'Sana',
    primary: true,
    sortValue: (p) => p.confirmedAt,
    cell: (p) => (
      <>
        <span className="ui-table__primary">{formatDay(p.confirmedAt)}</span>
        <span className="ui-table__sub">{formatTime(p.confirmedAt)}</span>
      </>
    ),
  },
  { key: 'plan', header: 'Reja', cell: (p) => p.planName },
  { key: 'amount', header: 'Summa', align: 'end', numeric: true, sortValue: (p) => p.amount, cell: (p) => formatSom(p.amount) },
  {
    key: 'until',
    header: 'Yangi muddat',
    cell: (p) => (p.newExpiresAt ? formatDay(p.newExpiresAt) : 'Cheksiz'),
  },
  { key: 'note', header: 'Izoh', hideOnMobile: true, cell: (p) => p.note || <span className="ui-muted">—</span> },
];

const REQUEST_STATUS: Record<PaymentRequestRecord['status'], { label: string; tone: 'warning' | 'success' | 'danger' }> = {
  pending: { label: 'Ko\'rib chiqilmagan', tone: 'warning' },
  approved: { label: 'Tasdiqlangan', tone: 'success' },
  rejected: { label: 'Rad etilgan', tone: 'danger' },
};

function Payments({
  tenant,
  onConfirm,
  onReject,
}: {
  tenant: TenantDetail;
  onConfirm?: (r: PaymentRequestRecord) => void;
  onReject?: (r: PaymentRequestRecord) => void;
}) {
  const table = useTable({
    rows: tenant.payments,
    columns: PAYMENT_COLUMNS,
    pageSize: 10,
    initialSort: { key: 'date', dir: 'desc' },
  });
  const total = tenant.payments.reduce((sum, p) => sum + p.amount, 0);
  const request = tenant.paymentRequest;

  return (
    <Stack gap={4}>
      {request && (
        <Card
          title="Mijozning so'nggi so'rovi"
          actions={<Badge tone={REQUEST_STATUS[request.status].tone}>{REQUEST_STATUS[request.status].label}</Badge>}
          footer={
            request.status === 'pending' && onConfirm && onReject ? (
              <Cluster gap={2}>
                <Button icon="check" onClick={() => onConfirm(request)}>
                  Tasdiqlash
                </Button>
                <Button variant="plain" onClick={() => onReject(request)}>
                  Rad etish
                </Button>
              </Cluster>
            ) : undefined
          }
        >
          <DescriptionList
            items={[
              { label: 'Yuborilgan', value: `${formatDay(request.createdAt)} ${formatTime(request.createdAt)}` },
              { label: 'Reja', value: request.planName },
              { label: 'Summa', value: formatSom(request.amount) },
              ...(request.reference ? [{ label: 'O\'tkazma raqami', value: request.reference }] : []),
              ...(request.note ? [{ label: 'Mijoz izohi', value: request.note }] : []),
              ...(request.rejectReason ? [{ label: 'Rad etish sababi', value: request.rejectReason }] : []),
            ]}
          />
        </Card>
      )}

      <Card
        title="To'lovlar tarixi"
        description={
          tenant.payments.length > 0
            ? `${tenant.payments.length} ta to'lov · jami ${formatSom(total)}`
            : undefined
        }
        padded={false}
      >
        <DataTable
          caption="To'lovlar tarixi"
          columns={PAYMENT_COLUMNS}
          rows={table.slice?.rows ?? []}
          rowKey={(p) => p.id}
          sort={table.sort}
          onSortChange={table.setSort}
          pagination={table.slice ? { slice: table.slice, onPageChange: table.setPage } : undefined}
          empty={
            <EmptyState
              icon="card"
              title="Hali to'lov yo'q"
              description="Tasdiqlangan to'lovlar shu yerda ko'rinadi."
              compact
            />
          }
        />
      </Card>
    </Stack>
  );
}

/* ------------------------------------------------------------------ */

function History({ tenantId, plans }: { tenantId: string; plans: Plan[] }) {
  const { data, error, loading, reload } = useApi(
    `/api/v1/admin/tenants/${tenantId}/audit?limit=100`,
    (json) => (json as { entries: AuditEntry[] }).entries,
  );
  const planNames = Object.fromEntries(plans.map((p) => [p.id, p.name]));

  return (
    <Card title="Amallar tarixi" description="Panel orqali shu biznes ustida bajarilgan amallar.">
      <AuditList
        entries={data}
        error={error}
        loading={loading}
        onRetry={reload}
        planNames={planNames}
        emptyText="Bu biznes ustida hali panel orqali amal bajarilmagan."
      />
    </Card>
  );
}
