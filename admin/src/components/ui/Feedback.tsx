import type { ReactNode } from 'react';

import { Icon, type IconName } from '../Icon';
import { cx } from './logic';

type AlertTone = 'info' | 'success' | 'warning' | 'danger';

const ALERT_ICON: Record<AlertTone, IconName> = {
  info: 'info',
  success: 'check',
  warning: 'alert',
  danger: 'error',
};

/**
 * Sahifa ichidagi ogohlantirish bloki ("3 ta to'lov so'rovi kutilmoqda").
 *
 * `live` — blok birdan PAYDO bo'lganda (masalan, amal xatosi) ekran
 * o'quvchiga aytiladi. Sahifa bilan birga chiziladigan doimiy blok
 * uchun kerak emas: u sahifa ochilganda keraksiz e'lon qilinardi.
 */
export function Alert({
  tone = 'info',
  title,
  children,
  action,
  live = false,
  className,
}: {
  tone?: AlertTone;
  title?: ReactNode;
  children?: ReactNode;
  action?: ReactNode;
  live?: boolean;
  className?: string;
}) {
  return (
    <div
      className={cx('ui-alert', `ui-alert--${tone}`, className)}
      role={live ? (tone === 'danger' ? 'alert' : 'status') : undefined}
    >
      <span className="ui-alert__icon" aria-hidden="true">
        <Icon name={ALERT_ICON[tone]} size={18} />
      </span>
      <div className="ui-alert__body">
        {title && <p className="ui-alert__title">{title}</p>}
        {children && <div className="ui-alert__text">{children}</div>}
      </div>
      {action && <div className="ui-alert__action">{action}</div>}
    </div>
  );
}

/**
 * Bo'sh holat — ma'lumot yo'q joyda bo'sh bo'shliq qolmasligi uchun.
 *
 * Doim nima uchun bo'shligini aytadi ("Bizneslar hali yo'q" va
 * "Bu shart bo'yicha hech narsa topilmadi" — ikki xil vaziyat) va
 * iloji bo'lsa keyingi qadamni taklif qiladi.
 */
export function EmptyState({
  icon = 'search',
  title,
  description,
  action,
  compact = false,
}: {
  icon?: IconName;
  title: ReactNode;
  description?: ReactNode;
  action?: ReactNode;
  compact?: boolean;
}) {
  return (
    <div className={cx('ui-empty', compact && 'ui-empty--compact')}>
      <span className="ui-empty__icon" aria-hidden="true">
        <Icon name={icon} size={22} />
      </span>
      <p className="ui-empty__title">{title}</p>
      {description && <p className="ui-empty__desc">{description}</p>}
      {action && <div className="ui-empty__action">{action}</div>}
    </div>
  );
}
