import { useId, type ReactNode } from 'react';

import { Icon } from '../Icon';
import { cx } from './logic';

/**
 * Belgilash katakchasi — yorlig'i bilan birga bosiladi.
 *
 * Haqiqiy `<input type="checkbox">` (ko'rinmas, lekin fokuslanadi) —
 * klaviatura (Space) va ekran o'quvchi o'z-o'zidan ishlaydi. Ko'rinadigan
 * kvadrat faqat bezak.
 */
export function Checkbox({
  checked,
  onChange,
  label,
  description,
  disabled = false,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: ReactNode;
  description?: ReactNode;
  disabled?: boolean;
}) {
  const id = useId();
  const descId = description ? `${id}-desc` : undefined;
  return (
    <label className={cx('ui-check', disabled && 'is-disabled')} htmlFor={id}>
      <input
        id={id}
        type="checkbox"
        className="ui-check__input"
        checked={checked}
        disabled={disabled}
        aria-describedby={descId}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="ui-check__box" aria-hidden="true">
        <Icon name="check" size={14} strokeWidth={2.6} />
      </span>
      <span className="ui-check__text">
        <span className="ui-check__label">{label}</span>
        {description && (
          <span id={descId} className="ui-check__desc">
            {description}
          </span>
        )}
      </span>
    </label>
  );
}
