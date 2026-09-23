import { Alert, Badge, Button, Card, EmptyState, ListSkeleton, PageHeader, type Tone } from '@/components/ui';
import type { CabinetMessage } from '@/lib/cabinet-types';
import { formatDay, formatRelative } from '@/lib/dates';
import { useApi } from '@/lib/use-api';

const KIND: Record<CabinetMessage['kind'], { label: string; tone: Tone }> = {
  yangilik: { label: 'Yangilik', tone: 'brand' },
  eslatma: { label: 'Eslatma', tone: 'info' },
  taklif: { label: 'Taklif', tone: 'neutral' },
};

/** CSCRM jamoasidan xabarlar — ilovadagi «Xabarlar» bo'limi bilan bir xil. */
export function CabinetMessages() {
  const { data, error, loading, reload } = useApi(
    '/api/v1/license/messages',
    (j) => (j as { messages: CabinetMessage[] }).messages,
  );

  return (
    <>
      <PageHeader title="Xabarlar" description="CSCRM jamoasidan yangiliklar, eslatmalar va takliflar." />
      <Card>
        {loading ? (
          <ListSkeleton rows={3} />
        ) : error && !data ? (
          <Alert
            tone="danger"
            action={
              <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
                Qayta urinish
              </Button>
            }
          >
            {error}
          </Alert>
        ) : !data || data.length === 0 ? (
          <EmptyState icon="bell" title="Hozircha xabar yo'q" description="Yangi xabar kelsa, shu yerda va ilovada ko'rinadi." compact />
        ) : (
          <ul className="ui-feed">
            {data.map((m) => (
              <li key={m.id}>
                <div className="ui-feed__head">
                  <Badge tone={KIND[m.kind]?.tone ?? 'neutral'}>{KIND[m.kind]?.label ?? 'Xabar'}</Badge>
                  {m.expiresAt && <span className="ui-note">{formatDay(m.expiresAt)} gacha</span>}
                  <span className="ui-feed__time">{formatRelative(m.createdAt)}</span>
                </div>
                <p className="ui-feed__title">{m.title}</p>
                <p className="ui-feed__body">{m.body}</p>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </>
  );
}
