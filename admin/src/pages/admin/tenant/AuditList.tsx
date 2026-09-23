import { Link } from 'react-router-dom';

import type { IconName } from '@/components/Icon';
import { Icon } from '@/components/Icon';
import { Alert, Button, EmptyState, ListSkeleton } from '@/components/ui';
import type { AuditAction, AuditEntry } from '@/lib/admin-types';
import { formatDay, formatRelative, formatTime } from '@/lib/dates';

/** Amal nomi va belgisi — jurnal texnik kod emas, oddiy gap bilan o'qiladi. */
const ACTIONS: Record<AuditAction, { label: string; icon: IconName; tone?: 'danger' | 'success' }> = {
  'payment.confirm': { label: 'To\'lov tasdiqlandi', icon: 'card', tone: 'success' },
  'payment.reject': { label: 'To\'lov so\'rovi rad etildi', icon: 'close' },
  'tenant.update': { label: 'Ma\'lumot tahrirlandi', icon: 'edit' },
  'tenant.suspend': { label: 'To\'xtatildi', icon: 'lock', tone: 'danger' },
  'tenant.unsuspend': { label: 'Qayta ochildi', icon: 'unlock' },
  'tenant.archive': { label: 'Arxivlandi', icon: 'archive', tone: 'danger' },
  'tenant.restore': { label: 'Arxivdan qaytarildi', icon: 'restore' },
  'tenant.delete': { label: 'Butunlay o\'chirildi', icon: 'trash', tone: 'danger' },
  'tenant.purge': { label: 'Muddati tugab, butunlay o\'chirildi', icon: 'trash', tone: 'danger' },
  'license.update': { label: 'Obuna qo\'lda o\'zgartirildi', icon: 'calendar' },
  'credentials.login': { label: 'Egasining logini almashtirildi', icon: 'edit' },
  'credentials.password': { label: 'Egasiga yangi parol qo\'yildi', icon: 'lock' },
  'plan.price': { label: 'Tarif narxi o\'zgartirildi', icon: 'money' },
  'plan.price_reset': { label: 'Tarif narxi asliga qaytarildi', icon: 'money' },
  'broadcast.create': { label: 'Xabar yuborildi', icon: 'bell' },
  'broadcast.delete': { label: 'Xabar o\'chirildi', icon: 'bell' },
  'site.settings': { label: 'Sayt sozlamalari o\'zgartirildi', icon: 'settings' },
};

const FIELDS: Record<string, string> = {
  name: 'Nom',
  phone: 'Telefon',
  address: 'Manzil',
  planId: 'Reja',
  expiresAt: 'Tugash sanasi',
  nextAnnualFeeAt: 'Yillik to\'lov sanasi',
  suspended: 'To\'xtatilgan',
  price: 'Narx',
};

/** O'zgarish qiymati: sana bo'lsa sana, reja bo'lsa nomi, bo'sh bo'lsa "—". */
function valueText(key: string, v: unknown, planNames: Record<string, string>): string {
  if (v === null || v === undefined || v === '') return '—';
  if (typeof v === 'boolean') return v ? 'Ha' : 'Yo\'q';
  if (typeof v === 'number' && key.endsWith('At')) return formatDay(v);
  if (key === 'planId' && typeof v === 'string') return planNames[v] ?? v;
  return String(v);
}

function actorText(entry: AuditEntry): string {
  if (entry.actor.uid === 'system') return 'Tizim (avtomatik)';
  return entry.actor.email ?? 'Administrator';
}

/**
 * Amallar jurnali — kim, qachon, nima qildi.
 *
 * `showTenant` — umumiy jurnalda har yozuv yonida biznes nomi (havola).
 */
export function AuditList({
  entries,
  error,
  loading,
  onRetry,
  showTenant = false,
  planNames = {},
  emptyText = 'Hali birorta amal bajarilmagan.',
}: {
  entries: AuditEntry[] | null;
  error: string | null;
  loading: boolean;
  onRetry: () => void;
  showTenant?: boolean;
  /** Reja ID → nomi ("m3" o'rniga "3 oylik"). */
  planNames?: Record<string, string>;
  emptyText?: string;
}) {
  if (loading || (!entries && !error)) return <ListSkeleton rows={4} />;
  if (!entries) {
    return (
      <Alert
        tone="danger"
        action={
          <Button variant="outline" size="sm" icon="refresh" onClick={onRetry}>
            Qayta urinish
          </Button>
        }
      >
        {error}
      </Alert>
    );
  }
  if (entries.length === 0) {
    return <EmptyState icon="clock" title="Jurnal bo'sh" description={emptyText} compact />;
  }

  return (
    <ol className="ui-timeline" aria-label="Amallar jurnali">
      {entries.map((e) => {
        const meta = ACTIONS[e.action] ?? { label: e.action, icon: 'info' as IconName };
        const changes = Object.entries(e.changes ?? {});
        return (
          <li key={e.id} className="ui-timeline__item">
            <span className={`ui-timeline__icon${meta.tone ? ` ui-timeline__icon--${meta.tone}` : ''}`} aria-hidden="true">
              <Icon name={meta.icon} size={16} />
            </span>
            <div className="ui-timeline__body">
              <p className="ui-timeline__title">
                {meta.label}
                {showTenant && e.tenantId && (
                  <>
                    {' — '}
                    {e.action === 'tenant.delete' || e.action === 'tenant.purge' ? (
                      <span>{e.tenantName ?? e.tenantId}</span>
                    ) : (
                      <Link to={`/admin/tenants/${e.tenantId}`}>{e.tenantName ?? e.tenantId}</Link>
                    )}
                  </>
                )}
              </p>
              {e.note && <p className="ui-timeline__note">{e.note}</p>}
              {changes.length > 0 && (
                <ul className="ui-timeline__changes">
                  {changes.map(([key, c]) => (
                    <li key={key}>
                      <span className="ui-timeline__field">{FIELDS[key] ?? key}:</span>{' '}
                      <del>{valueText(key, c.from, planNames)}</del> → <ins>{valueText(key, c.to, planNames)}</ins>
                    </li>
                  ))}
                </ul>
              )}
              <p className="ui-timeline__meta">
                <time dateTime={new Date(e.at).toISOString()} title={`${formatDay(e.at)} ${formatTime(e.at)}`}>
                  {formatRelative(e.at)}
                </time>
                {' · '}
                {actorText(e)}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
