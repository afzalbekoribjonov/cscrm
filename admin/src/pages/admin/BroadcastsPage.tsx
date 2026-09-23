import { useState } from 'react';

import {
  Alert,
  Badge,
  Button,
  Card,
  ChipGroup,
  ConfirmDialog,
  EmptyState,
  Field,
  Input,
  ListSkeleton,
  PageHeader,
  Select,
  Stack,
  Textarea,
  useToast,
  type Tone,
} from '@/components/ui';
import { api } from '@/lib/api';
import { formatDay, formatRelative } from '@/lib/dates';
import { useApi } from '@/lib/use-api';

type BroadcastKind = 'yangilik' | 'eslatma' | 'taklif';

interface Broadcast {
  id: string;
  title: string;
  body: string;
  kind: BroadcastKind;
  createdAt: number;
  expiresAt: number | null;
}

const DAY = 86_400_000;
const TITLE_MAX = 120;
const BODY_MAX = 2000;

const KINDS: { id: BroadcastKind; label: string; tone: Tone }[] = [
  { id: 'yangilik', label: 'Yangilik', tone: 'brand' },
  { id: 'eslatma', label: 'Eslatma', tone: 'info' },
  { id: 'taklif', label: 'Taklif', tone: 'neutral' },
];

const DURATIONS: { days: number; label: string }[] = [
  { days: 0, label: 'Muddatsiz' },
  { days: 3, label: '3 kun' },
  { days: 7, label: '1 hafta' },
  { days: 14, label: '2 hafta' },
  { days: 30, label: '1 oy' },
];

function kindOf(k: BroadcastKind) {
  return KINDS.find((x) => x.id === k) ?? KINDS[0]!;
}

/**
 * Barcha bizneslarga xabar yuborish.
 *
 * Xabar BARCHA mijozlarning ilovasida darhol ko'rinadi va telefonlariga
 * bildirishnoma boradi — shuning uchun yuborishdan oldin oldindan ko'rish
 * va tasdiq bor. Yuborilgan xabarni o'chirish mumkin, tahrirlash — yo'q
 * (bildirishnoma allaqachon ketgan).
 */
export function BroadcastsPage() {
  const toast = useToast();
  const { data: list, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/broadcasts',
    (json) => (json as { broadcasts: Broadcast[] }).broadcasts,
  );

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [kind, setKind] = useState<BroadcastKind>('yangilik');
  const [days, setDays] = useState(0);
  const [errors, setErrors] = useState<{ title?: string; body?: string }>({});
  const [confirmSend, setConfirmSend] = useState(false);
  const [removing, setRemoving] = useState<Broadcast | null>(null);

  const now = Date.now();
  const k = kindOf(kind);

  const trySend = () => {
    const e: typeof errors = {};
    if (!title.trim()) e.title = 'Sarlavhani kiriting.';
    if (!body.trim()) e.body = 'Xabar matnini kiriting.';
    setErrors(e);
    if (Object.keys(e).length === 0) setConfirmSend(true);
  };

  return (
    <>
      <PageHeader
        title="Xabarlar"
        description="Barcha bizneslar ilovasidagi «Xabarlar» bo'limiga — yangiliklar, eslatmalar, takliflar."
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <div className="ui-split">
        <Card title="Yangi xabar">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              trySend();
            }}
          >
            <Stack gap={4}>
              <ChipGroup
                label="Xabar turi"
                value={kind}
                onChange={setKind}
                options={KINDS.map((x) => ({ id: x.id, label: x.label }))}
              />
              <Field label="Sarlavha" required error={errors.title} hint={`${title.length} / ${TITLE_MAX}`}>
                <Input
                  value={title}
                  maxLength={TITLE_MAX}
                  onChange={(e) => {
                    setTitle(e.target.value);
                    setErrors((x) => ({ ...x, title: undefined }));
                  }}
                  placeholder="Masalan: Yangi imkoniyat qo'shildi"
                />
              </Field>
              <Field label="Matn" required error={errors.body} hint={`${body.length} / ${BODY_MAX}`}>
                <Textarea
                  value={body}
                  maxLength={BODY_MAX}
                  rows={5}
                  onChange={(e) => {
                    setBody(e.target.value);
                    setErrors((x) => ({ ...x, body: undefined }));
                  }}
                />
              </Field>
              <Field label="Ko'rinish muddati" hint="Muddat o'tgach xabar ilovada ko'rinmaydi, lekin shu ro'yxatda qoladi.">
                <Select value={String(days)} onChange={(e) => setDays(Number(e.target.value))}>
                  {DURATIONS.map((d) => (
                    <option key={d.days} value={d.days}>
                      {d.label}
                    </option>
                  ))}
                </Select>
              </Field>

              {(title.trim() || body.trim()) && (
                <div className="ui-preview" aria-label="Ilovada shunday ko'rinadi">
                  <p className="ui-preview__label">Ilovada shunday ko'rinadi</p>
                  <Badge tone={k.tone}>{k.label}</Badge>
                  <p className="ui-preview__title">{title.trim() || 'Sarlavha'}</p>
                  <p className="ui-preview__body">{body.trim() || 'Xabar matni'}</p>
                </div>
              )}

              <Button type="submit" icon="bell" block>
                Barchaga yuborish
              </Button>
            </Stack>
          </form>
        </Card>

        <Card title="Yuborilganlar" description={list ? `${list.length} ta xabar` : undefined}>
          {loading ? (
            <ListSkeleton rows={3} />
          ) : error && !list ? (
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
          ) : !list || list.length === 0 ? (
            <EmptyState icon="bell" title="Hali xabar yuborilmagan" compact />
          ) : (
            <ul className="ui-feed">
              {list.map((b) => {
                const bk = kindOf(b.kind);
                const expired = b.expiresAt !== null && b.expiresAt < now;
                return (
                  <li key={b.id} className={expired ? 'is-muted' : undefined}>
                    <div className="ui-feed__head">
                      <Badge tone={bk.tone}>{bk.label}</Badge>
                      {expired ? (
                        <Badge tone="neutral">Muddati o'tgan</Badge>
                      ) : b.expiresAt ? (
                        <span className="ui-note">{formatDay(b.expiresAt)} gacha</span>
                      ) : null}
                      <span className="ui-feed__time">{formatRelative(b.createdAt)}</span>
                    </div>
                    <p className="ui-feed__title">{b.title}</p>
                    <p className="ui-feed__body">{b.body}</p>
                    <Button variant="plain" size="sm" icon="trash" onClick={() => setRemoving(b)}>
                      O'chirish
                    </Button>
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      </div>

      <ConfirmDialog
        open={confirmSend}
        onClose={() => setConfirmSend(false)}
        icon="bell"
        title="Xabarni barchaga yuborish"
        description={`«${title.trim()}»`}
        consequences={[
          'Xabar barcha bizneslarning ilovasida darhol ko\'rinadi.',
          'Egalar va xodimlarning telefonlariga bildirishnoma boradi — uni qaytarib bo\'lmaydi.',
          days > 0 ? `${DURATIONS.find((d) => d.days === days)?.label} ko'rinib turadi.` : 'Muddatsiz — o\'chirilguncha ko\'rinadi.',
        ]}
        confirmLabel="Yuborish"
        onConfirm={async () => {
          await api.post('/api/v1/admin/broadcasts', {
            title: title.trim(),
            body: body.trim(),
            kind,
            ...(days > 0 ? { expiresAt: Date.now() + days * DAY } : {}),
          });
          toast.success('Xabar yuborildi', title.trim());
          setTitle('');
          setBody('');
          setDays(0);
          reload();
        }}
      />

      <ConfirmDialog
        open={removing !== null}
        onClose={() => setRemoving(null)}
        tone="danger"
        icon="trash"
        title="Xabarni o'chirish"
        description={removing ? `«${removing.title}»` : undefined}
        consequences={[
          'Xabar ilovalardagi «Xabarlar» bo\'limidan yo\'qoladi.',
          'Yuborilgan bildirishnomalar telefonlarda qolishi mumkin.',
        ]}
        confirmLabel="O'chirish"
        onConfirm={async () => {
          if (!removing) return;
          await api.del(`/api/v1/admin/broadcasts/${removing.id}`);
          toast.success('Xabar o\'chirildi');
          reload();
        }}
      />
    </>
  );
}
