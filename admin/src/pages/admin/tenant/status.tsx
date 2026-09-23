import { Badge, type Tone } from '@/components/ui';
import { formatDate, stateVisual, type ArchiveInfo, type LicenseStatus } from '@/lib/admin-types';
import { daysUntil } from '@/lib/dates';

/**
 * Biznes holati — ro'yxat va kartada BIR XIL ko'rinishda.
 *
 * Arxiv har qanday obuna holatidan ustun: arxivdagi biznes
 * "bloklangan" emas, u o'chirilish arafasida.
 * Sinovdagi faol biznes "Faol" emas, "Sinovda" — u hali pul to'lamagan.
 */
export function tenantState(t: { status: LicenseStatus; archive: ArchiveInfo | null }): {
  label: string;
  tone: Tone;
} {
  if (t.archive) return { label: 'Arxivda', tone: 'neutral' };
  if (t.status.kind === 'trial' && !t.status.blocked && t.status.state === 'active') {
    return { label: 'Sinovda', tone: 'info' };
  }
  return stateVisual(t.status.state);
}

export function TenantBadge({ tenant }: { tenant: { status: LicenseStatus; archive: ArchiveInfo | null } }) {
  const s = tenantState(tenant);
  return (
    <Badge tone={s.tone} dot>
      {s.label}
    </Badge>
  );
}

/** Obuna muddati: asosiy qator va izoh. */
export function termText(status: LicenseStatus): { main: string; sub?: string } {
  if (status.kind === 'lifetime') {
    return {
      main: 'Cheksiz',
      ...(status.daysLeft !== null ? { sub: `yillik to'lovgacha ${status.daysLeft} kun` } : {}),
    };
  }
  if (!status.expiresAt) return { main: '—' };
  const d = status.daysLeft;
  return {
    main: formatDate(status.expiresAt),
    ...(d !== null ? { sub: d >= 0 ? `${d} kun qoldi` : `${-d} kun o'tdi` } : {}),
  };
}

/** "12 kundan keyin o'chiriladi". */
export function purgeText(archive: ArchiveInfo, now = Date.now()): string {
  const days = daysUntil(archive.purgeAfter, now);
  if (days <= 0) return 'bugun butunlay o\'chiriladi';
  return `${days} kundan keyin butunlay o'chiriladi`;
}
