import {
  forwardRef,
  useEffect,
  useRef,
  type InputHTMLAttributes,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from 'react';

import { Icon } from '../Icon';
import { useFieldProps } from './Field';
import { IconButton } from './IconButton';
import { cx } from './logic';
import { mergeRefs } from './refs';

/** Matn, e-pochta, parol, sana va h.k. — bitta ko'rinishda. */
export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, ...props }, ref) {
    return <input ref={ref} className={cx('ui-input', className)} {...useFieldProps(props)} />;
  },
);

export const Textarea = forwardRef<
  HTMLTextAreaElement,
  TextareaHTMLAttributes<HTMLTextAreaElement>
>(function Textarea({ className, ...props }, ref) {
  return (
    <textarea
      ref={ref}
      className={cx('ui-input', 'ui-input--textarea', className)}
      {...useFieldProps(props)}
    />
  );
});

/**
 * Tanlov ro'yxati — brauzerning o'zinikidan foydalanadi.
 *
 * O'z ochiladigan ro'yxatimiz qilinmadi: telefonda tizimning tanlov
 * oynasi qulayroq (katta, aylantiriladigan), klaviatura va ekran
 * o'quvchi bilan esa u allaqachon mukammal ishlaydi.
 */
export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  function Select({ className, children, ...props }, ref) {
    return (
      <div className="ui-input-wrap">
        <select ref={ref} className={cx('ui-input', className)} {...useFieldProps(props)}>
          {children}
        </select>
        <span className="ui-select-chevron" aria-hidden="true">
          <Icon name="chevron-down" size={16} />
        </span>
      </div>
    );
  },
);

/**
 * Qidiruv maydoni.
 *
 * `shortcut` — "/" tugmasi bosilganda shu maydonga o'tadi (sichqonchani
 * olishga hojat qolmaydi). Boshqa maydonda yozilayotgan bo'lsa ishlamaydi.
 */
export const SearchInput = forwardRef<
  HTMLInputElement,
  Omit<InputHTMLAttributes<HTMLInputElement>, 'onChange' | 'value' | 'type'> & {
    value: string;
    onChange: (value: string) => void;
    shortcut?: boolean;
  }
>(function SearchInput(
  { value, onChange, shortcut = false, className, onKeyDown, ...props },
  ref,
) {
  const inner = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!shortcut) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
      const el = document.activeElement;
      if (
        el instanceof HTMLInputElement ||
        el instanceof HTMLTextAreaElement ||
        el instanceof HTMLSelectElement ||
        (el instanceof HTMLElement && el.isContentEditable)
      ) {
        return;
      }
      e.preventDefault();
      inner.current?.focus();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [shortcut]);

  const fieldProps = useFieldProps(props);

  return (
    <div className={cx('ui-input-wrap', className)}>
      <span className="ui-input-wrap__icon" aria-hidden="true">
        <Icon name="search" size={18} />
      </span>
      <input
        ref={mergeRefs(ref, inner)}
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => {
          // Esc — qidiruvni tozalaydi (bo'sh bo'lsa fokusdan chiqadi).
          if (e.key === 'Escape') {
            if (value) onChange('');
            else e.currentTarget.blur();
          }
          onKeyDown?.(e);
        }}
        className="ui-input ui-input--with-icon ui-input--with-end"
        autoComplete="off"
        spellCheck={false}
        {...fieldProps}
      />
      {value ? (
        <span className="ui-input-wrap__end">
          <IconButton
            icon="close"
            label="Qidiruvni tozalash"
            size="sm"
            noTooltip
            onClick={() => {
              onChange('');
              inner.current?.focus();
            }}
          />
        </span>
      ) : shortcut ? (
        <kbd className="ui-kbd ui-input-wrap__end" aria-hidden="true">
          /
        </kbd>
      ) : null}
    </div>
  );
});
