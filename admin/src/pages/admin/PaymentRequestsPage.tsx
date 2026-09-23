import { Link } from 'react-router-dom';

import {
  Alert,
  Button,
  Card,
  Cluster,
  DescriptionList,
  EmptyState,
  PageHeader,
  SkeletonText,
  Stack,
} from '@/components/ui';
import type { PendingPayment } from '@/lib/admin-types';
import { formatDay, formatRelative, formatTime } from '@/lib/dates';
import { formatSom } from '@/lib/format';
import type { Plan } from '@/lib/plans';
import { useApi } from '@/lib/use-api';

import { useTenantActions, type TenantRef } from './tenant/actions';

interface QueueResponse {
  requests: PendingPayment[];
  plans: Plan[];
}

function refOf(r: PendingPayment): TenantRef {
  // Navbatda faqat faol bizneslarning so'rovlari turadi; arxivdagisi
  // bo'lsa ham server tasdiqni rad etadi va sababini aytadi.
  return { tenantId: r.tenantId, name: r.tenantName, archive: null, suspended: false };
}

/**
 * To'lov so'rovlari navbati — panelning asosiy kundalik ishi.
 *
 * To'lov usuli qo'lda karta o'tkazma: mijoz pulni o'tkazgach ilovadan
 * "to'lov qildim" deb xabar beradi, biz esa bank ko'chirmasi bilan
 * solishtirib tasdiqlaymiz yoki sababini yozib rad etamiz.
 *
 * Eng eski so'rov birinchi — kim ko'proq kutgan bo'lsa, o'sha oldin.
 */
export function PaymentRequestsPage() {
  const { data, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/payment-requests',
    (json) => json as QueueResponse,
    { staleMs: 30_000 },
  );
  const actions = useTenantActions({ plans: data?.plans ?? [], onChanged: reload });

  const requests = data ? [...data.requests].sort((a, b) => a.createdAt - b.createdAt) : null;

  const header = (
    <PageHeader
      title="To'lov so'rovlari"
      description="Mijozlar ilovadan yuborgan to'lov xabarlari. Bank ko'chirmasi bilan solishtirib, tasdiqlang yoki rad eting."
      actions={
        <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
          Yangilash
        </Button>
      }
    />
  );

  if (error && !data) {
    return (
      <>
        {header}
        <Alert
          tone="danger"
          title="So'rovlarni yuklab bo'lmadi"
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

  return (
    <>
      {header}

      <Stack gap={4}>
        {error && data && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan ro'yxat ko'rsatilmoqda. {error}
          </Alert>
        )}

        {loading || !requests ? (
          <div className="ui-grid ui-grid--fill" aria-busy="true">
            {[0, 1].map((i) => (
              <Card key={i}>
                <SkeletonText lines={4} />
              </Card>
            ))}
          </div>
        ) : requests.length === 0 ? (
          <Card>
            <EmptyState
              icon="check"
              title="Hammasi ko'rib chiqilgan"
              description="Yangi to'lov so'rovi kelsa, u shu yerda va menyudagi hisoblagichda ko'rinadi."
            />
          </Card>
        ) : (
          <div className="ui-grid ui-grid--fill" aria-busy={refreshing}>
            {requests.map((r) => (
              <Card
                key={`${r.tenantId}/${r.id}`}
                title={<Link to={`/admin/tenants/${r.tenantId}?bolim=tolovlar`}>{r.tenantName}</Link>}
                description={
                  <time dateTime={new Date(r.createdAt).toISOString()} title={`${formatDay(r.createdAt)} ${formatTime(r.createdAt)}`}>
                    {formatRelative(r.createdAt)}
                  </time>
                }
                footer={
                  <Cluster gap={2}>
                    <Button icon="check" onClick={() => actions.openPayment(refOf(r), r)}>
                      Tasdiqlash
                    </Button>
                    <Button variant="plain" onClick={() => actions.openReject(refOf(r), r)}>
                      Rad etish
                    </Button>
                  </Cluster>
                }
              >
                <DescriptionList
                  items={[
                    { label: 'Reja', value: data?.plans.find((p) => p.id === r.planId)?.name ?? r.planName },
                    { label: 'Summa', value: <strong>{formatSom(r.amount)}</strong> },
                    ...(r.reference ? [{ label: 'O\'tkazma raqami', value: r.reference }] : []),
                    ...(r.note ? [{ label: 'Mijoz izohi', value: r.note }] : []),
                  ]}
                />
              </Card>
            ))}
          </div>
        )}
      </Stack>

      {actions.dialogs}
    </>
  );
}
