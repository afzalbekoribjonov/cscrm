import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';

import { Icon } from '../Icon';
import { cx } from './logic';
import { Skeleton } from './Skeleton';

/**
 * Ro'yxat — kartalar ichidagi qisqa qatorlar ("E'tibor talab qiladi",
 * "Oxirgi to'lovlar"). Jadvaldan yengil: ustunlar yo'q, har qator —
 * belgi · nom va izoh · o'ng tomonda qiymat.
 */
export function List({ children, label }: { children: ReactNode; label?: string }) {
  return (
    <ul className="ui-list" aria-label={label}>
      {children}
    </ul>
  );
}

export function ListItem({
  leading,
  title,
  meta,
  trailing,
  to,
}: {
  /** Chapdagi belgi (avatar, ikonka). */
  leading?: ReactNode;
  title: ReactNode;
  /** Ikkinchi qator — izoh. */
  meta?: ReactNode;
  /** O'ng tomon — qiymat yoki nishon. */
  trailing?: ReactNode;
  /** Berilsa butun qator havola. */
  to?: string;
}) {
  const body = (
    <>
      {leading && <span className="ui-list__leading">{leading}</span>}
      <span className="ui-list__main">
        <span className="ui-list__title">{title}</span>
        {meta && <span className="ui-list__meta">{meta}</span>}
      </span>
      {trailing && <span className="ui-list__trailing">{trailing}</span>}
      {to && (
        <span className="ui-list__chevron" aria-hidden="true">
          <Icon name="chevron-right" size={16} />
        </span>
      )}
    </>
  );

  return (
    <li>
      {to ? (
        <Link to={to} className={cx('ui-list__item', 'is-link')}>
          {body}
        </Link>
      ) : (
        <div className="ui-list__item">{body}</div>
      )}
    </li>
  );
}

/** Ro'yxat yuklanayotganda — qatorlar shaklida. */
export function ListSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className="ui-list-skeleton" aria-hidden="true">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="ui-list-skeleton__row">
          <Skeleton width={32} height={32} radius={10} />
          <div className="ui-list-skeleton__text">
            <Skeleton width="55%" />
            <Skeleton width="35%" height={12} />
          </div>
        </div>
      ))}
    </div>
  );
}
