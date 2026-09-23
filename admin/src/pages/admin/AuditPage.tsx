import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { Alert, Button, Card, ChipGroup, PageHeader, SearchInput, Stack } from '@/components/ui';
import type { AuditAction, AuditEntry } from '@/lib/admin-types';
import { api } from '@/lib/api';
import { useApi } from '@/lib/use-api';

import { AuditList } from './tenant/AuditList';

const PAGE = 100;

type GroupId = 'all' | 'payments' | 'tenants' | 'access' | 'panel' | 'content';

/** Guruhlar — admin odatda "to'lovlar bo'yicha nima bo'ldi" deb qidiradi. */
const GROUPS: { id: GroupId; label: string; match?: (a: AuditAction) => boolean }[] = [
  { id: 'all', label: 'Hammasi' },
  { id: 'payments', label: 'To\'lovlar', match: (a) => a.startsWith('payment.') },
  { id: 'tenants', label: 'Bizneslar', match: (a) => a.startsWith('tenant.') || a === 'license.update' },
  { id: 'access', label: 'Kirish', match: (a) => a.startsWith('credentials.') || a === 'user.signout' },
  { id: 'panel', label: 'Panel xodimlari', match: (a) => a.startsWith('role.') || a.startsWith('admin.') },
  {
    id: 'content',
    label: 'Tarif va sozlamalar',
    match: (a) => a.startsWith('plan.') || a.startsWith('broadcast.') || a === 'site.settings',
  },
];

function matchesText(e: AuditEntry, q: string): boolean {
  if (!q) return true;
  return [e.tenantName, e.note, e.actor.email].some((s) => s?.toLowerCase().includes(q));
}

/**
 * Amallar jurnali — panel orqali kim, qachon, nima qilgani.
 *
 * Eng yangisi tepada; pastda "Oldingilarini ko'rsatish" — keyingi 100 ta.
 * Filtr va qidiruv yuklangan yozuvlar ichida ishlaydi (shu ochiq aytiladi).
 */
export function AuditPage() {
  const [params, setParams] = useSearchParams();
  const group: GroupId = GROUPS.find((g) => g.id === params.get('tur'))?.id ?? 'all';
  const query = params.get('q') ?? '';
  const update = (patch: Record<string, string | null>) => {
    const next = new URLSearchParams(params);
    for (const [k, v] of Object.entries(patch)) {
      if (v === null || v === '') next.delete(k);
      else next.set(k, v);
    }
    setParams(next, { replace: true });
  };

  const first = useApi(`/api/v1/admin/audit?limit=${PAGE}`, (json) => (json as { entries: AuditEntry[] }).entries);
  const [older, setOlder] = useState<AuditEntry[]>([]);
  const [hasMore, setHasMore] = useState(true);
  const [moreBusy, setMoreBusy] = useState(false);
  const [moreError, setMoreError] = useState<string | null>(null);

  // Birinchi sahifa yangilansa — oldingi "ko'proq" qismlari qaytadan.
  useEffect(() => {
    if (!first.data) return;
    setOlder([]);
    setHasMore(first.data.length === PAGE);
    setMoreError(null);
  }, [first.data]);

  const all = useMemo(() => (first.data ? [...first.data, ...older] : null), [first.data, older]);

  const loadMore = async () => {
    const last = all?.[all.length - 1];
    if (!last) return;
    setMoreBusy(true);
    setMoreError(null);
    try {
      const r = await api.get<{ entries: AuditEntry[] }>(
        `/api/v1/admin/audit?limit=${PAGE}&before=${encodeURIComponent(last.id)}`,
      );
      setOlder((list) => [...list, ...r.entries]);
      setHasMore(r.entries.length === PAGE);
    } catch (e) {
      setMoreError(e instanceof Error ? e.message : 'Yuklab bo\'lmadi.');
    } finally {
      setMoreBusy(false);
    }
  };

  const q = query.trim().toLowerCase();
  const matcher = GROUPS.find((g) => g.id === group)?.match;
  const visible = all?.filter((e) => (!matcher || matcher(e.action)) && matchesText(e, q)) ?? null;
  const filtered = group !== 'all' || q.length > 0;

  return (
    <>
      <PageHeader
        title="Amallar jurnali"
        description="Panel orqali bajarilgan har bir o'zgarish — kim, qachon, nima."
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={first.refreshing} onClick={first.reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={4}>
        <div className="ui-toolbar">
          <div className="ui-toolbar__search">
            <SearchInput
              value={query}
              onChange={(v) => update({ q: v })}
              placeholder="Biznes, izoh yoki administrator"
              aria-label="Jurnaldan qidirish"
              shortcut
            />
          </div>
          <ChipGroup
            label="Amal turi"
            value={group}
            onChange={(id) => update({ tur: id === 'all' ? null : id })}
            options={GROUPS.map((g) => ({ id: g.id, label: g.label }))}
          />
        </div>

        {first.error && first.data && (
          <Alert tone="warning" live>
            Yangilab bo'lmadi — oxirgi olingan jurnal ko'rsatilmoqda. {first.error}
          </Alert>
        )}

        <Card
          description={
            all && filtered
              ? `Yuklangan ${all.length} ta yozuv ichidan ${visible?.length ?? 0} ta mos keldi.`
              : undefined
          }
        >
          <AuditList
            entries={visible}
            error={first.error}
            loading={first.loading}
            onRetry={first.reload}
            showTenant
            emptyText={filtered ? 'Bu shart bo\'yicha yozuv topilmadi.' : 'Panel orqali hali amal bajarilmagan.'}
          />
        </Card>

        {moreError && (
          <Alert tone="danger" live>
            {moreError}
          </Alert>
        )}
        {all && all.length > 0 && hasMore && (
          <Button variant="secondary" block loading={moreBusy} onClick={() => void loadMore()}>
            Oldingilarini ko'rsatish
          </Button>
        )}
      </Stack>
    </>
  );
}
