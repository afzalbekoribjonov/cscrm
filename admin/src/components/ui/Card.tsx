import { useId, type ReactNode } from 'react';

import { cx } from './logic';

/**
 * Karta — sahifadagi mantiqiy bo'lim.
 *
 * Sarlavha berilsa karta `<section>` bo'lib, sarlavhasi bilan
 * bog'lanadi (ekran o'quvchi bo'limlar bo'ylab sakray oladi).
 */
export function Card({
  title,
  description,
  actions,
  footer,
  children,
  padded = true,
  className,
}: {
  title?: ReactNode;
  description?: ReactNode;
  /** Sarlavha o'ng tomonidagi tugmalar. */
  actions?: ReactNode;
  footer?: ReactNode;
  children?: ReactNode;
  /** Ichki bo'shliq. Jadval kabi o'zi chetgacha boradigan tarkib uchun `false`. */
  padded?: boolean;
  className?: string;
}) {
  const titleId = useId();
  const hasHead = Boolean(title || actions);

  const content = (
    <>
      {hasHead && (
        <div className="ui-card__head">
          <div className="ui-card__titles">
            {title && (
              <h2 id={titleId} className="ui-card__title">
                {title}
              </h2>
            )}
            {description && <p className="ui-card__desc">{description}</p>}
          </div>
          {actions && <div className="ui-card__actions">{actions}</div>}
        </div>
      )}
      {children !== undefined && (
        <div className={padded ? 'ui-card__body' : undefined}>{children}</div>
      )}
      {footer && <div className="ui-card__foot">{footer}</div>}
    </>
  );

  return title ? (
    <section className={cx('ui-card', className)} aria-labelledby={titleId}>
      {content}
    </section>
  ) : (
    <div className={cx('ui-card', className)}>{content}</div>
  );
}

/**
 * Kalit–qiymat ro'yxati ("Telefon", "Ro'yxatdan o'tgan"...).
 *
 * `<dl>` — ekran o'quvchi har bir qiymatni o'z nomi bilan o'qiydi.
 */
export function DescriptionList({
  items,
  className,
}: {
  items: { label: ReactNode; value: ReactNode }[];
  className?: string;
}) {
  return (
    <dl className={cx('ui-dl', className)}>
      {items.map((item, i) => (
        <div key={i} className="ui-dl__row">
          <dt>{item.label}</dt>
          <dd>{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}
