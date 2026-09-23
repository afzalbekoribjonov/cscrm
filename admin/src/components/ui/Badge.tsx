import type { ReactNode } from 'react';

import { Icon, type IconName } from '../Icon';
import { cx } from './logic';

export type Tone = 'neutral' | 'brand' | 'info' | 'success' | 'warning' | 'danger';

/**
 * Holat nishoni.
 *
 * Rang faqat qo'shimcha belgi — ma'no MATNDA ("Faol", "Bloklangan").
 * Rang ajrata olmaydigan foydalanuvchi ham, oq-qora chop etilgan
 * sahifa ham holatni o'qiy oladi. Nuqta (`dot`) holat ro'yxatlarida
 * ko'z bilan tez ajratish uchun.
 *
 * Matn ranglari `--*-ink` tokenlaridan — o'z fonida >= 4.5:1.
 */
export function Badge({
  tone = 'neutral',
  dot = false,
  icon,
  children,
  className,
}: {
  tone?: Tone;
  dot?: boolean;
  icon?: IconName;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span className={cx('ui-badge', tone !== 'neutral' && `ui-badge--${tone}`, className)}>
      {dot && <span className="ui-badge__dot" aria-hidden="true" />}
      {icon && <Icon name={icon} size={13} strokeWidth={2.2} />}
      {children}
    </span>
  );
}
