import { forwardRef, type ButtonHTMLAttributes } from 'react';

import { Icon, type IconName } from '../Icon';
import { cx } from './logic';
import { Tooltip } from './Tooltip';

export interface IconButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children' | 'aria-label'> {
  icon: IconName;
  /**
   * MAJBURIY. Ikonkaning o'zi ekran o'quvchiga hech narsa demaydi —
   * "tugma" deb o'qiladi va xolos. Shu matn ham nom, ham maslahat.
   */
  label: string;
  size?: 'sm' | 'md';
  outline?: boolean;
  /** Maslahatni o'chirish — masalan, yonida matn allaqachon bor bo'lsa. */
  noTooltip?: boolean;
}

export const IconButton = forwardRef<HTMLButtonElement, IconButtonProps>(function IconButton(
  { icon, label, size = 'md', outline, noTooltip, className, type = 'button', ...rest },
  ref,
) {
  const button = (
    <button
      ref={ref}
      type={type}
      aria-label={label}
      className={cx(
        'ui-icon-btn',
        size === 'sm' && 'ui-icon-btn--sm',
        outline && 'ui-icon-btn--outline',
        className,
      )}
      {...rest}
    >
      <Icon name={icon} size={size === 'sm' ? 16 : 18} />
    </button>
  );

  return noTooltip ? button : <Tooltip content={label}>{button}</Tooltip>;
});
