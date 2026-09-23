import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';

import { Icon, type IconName } from '../Icon';
import { cx, formatDelta, type Direction } from './logic';
import { Skeleton } from './Skeleton';

export interface StatDelta {
  /** Foiz; oldingi davr 0 bo'lsa `null` — faqat yo'nalish ko'rsatiladi. */
  pct: number | null;
  direction: Direction;
  /**
   * Qaysi yo'nalish YAXSHI. Tushum uchun "up", qarzdorlik yoki
   * bloklangan bizneslar uchun "down". Rang shundan kelib chiqadi —
   * strelka yo'nalishidan emas.
   */
  goodWhen?: 'up' | 'down';
  /** Nimaga nisbatan: "o'tgan 30 kunga nisbatan". Majburiy — davrsiz foiz ma'nosiz. */
  period: string;
}

/**
 * Ko'rsatkich kartasi: nom · qiymat · o'zgarish.
 *
 * Qiymat oldindan qisqartirilgan bo'lishi kerak (`compactNumber`) —
 * karta uzun raqamni sig'dirish uchun kichraytirilmaydi.
 * `href` berilsa butun karta havola bo'ladi.
 */
export function StatCard({
  label,
  value,
  delta,
  hint,
  icon,
  href,
  loading = false,
  className,
}: {
  label: string;
  value: ReactNode;
  delta?: StatDelta;
  hint?: ReactNode;
  icon?: IconName;
  href?: string;
  loading?: boolean;
  className?: string;
}) {
  const body = (
    <>
      <div className="ui-stat__head">
        <span className="ui-stat__label">{label}</span>
        {icon && (
          <span className="ui-stat__icon" aria-hidden="true">
            <Icon name={icon} size={18} />
          </span>
        )}
      </div>

      {loading ? (
        <Skeleton width="60%" height={32} />
      ) : (
        <div className="ui-stat__value">{value}</div>
      )}

      {!loading && (delta || hint) && (
        <div className="ui-stat__foot">
          {delta && <DeltaBadge delta={delta} />}
          {hint && <span>{hint}</span>}
        </div>
      )}
    </>
  );

  const cls = cx('ui-card', 'ui-stat', className);
  return href ? (
    <Link to={href} className={cls}>
      {body}
    </Link>
  ) : (
    <div className={cls}>{body}</div>
  );
}

function DeltaBadge({ delta }: { delta: StatDelta }) {
  const good = delta.goodWhen ?? 'up';
  const tone =
    delta.direction === 'flat' ? 'neutral' : delta.direction === good ? 'good' : 'bad';

  const text =
    delta.pct !== null
      ? formatDelta(delta.pct)
      : delta.direction === 'up'
        ? 'o\'sdi'
        : delta.direction === 'down'
          ? 'kamaydi'
          : 'o\'zgarmadi';

  return (
    <>
      <span className={`ui-stat__delta ui-stat__delta--${tone}`}>
        {delta.direction !== 'flat' && (
          <Icon name={delta.direction === 'up' ? 'arrow-up' : 'arrow-down'} size={14} strokeWidth={2.2} />
        )}
        {text}
      </span>
      <span>{delta.period}</span>
    </>
  );
}
