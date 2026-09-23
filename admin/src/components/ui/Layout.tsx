import { useEffect, type CSSProperties, type ElementType, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

import { Icon } from '../Icon';
import { cx, initials, toneIndex } from './logic';

/** Tokenlardagi oraliq qadamlari. */
export type Space = 1 | 2 | 3 | 4 | 5 | 6 | 8 | 10 | 12 | 16;

const gapStyle = (gap: Space | undefined): CSSProperties | undefined =>
  gap ? ({ '--gap': `var(--space-${gap})` } as CSSProperties) : undefined;

/**
 * Elementlarni USTMA-UST joylaydi, bir xil oraliq bilan.
 *
 * Har bir sahifada `style={{ marginTop: 18 }}` yozish o'rniga — oraliq
 * shkaladan olinadi va sahifalar bir xil "nafas" oladi.
 */
export function Stack({
  gap = 4,
  as: As = 'div',
  className,
  children,
}: {
  gap?: Space;
  as?: ElementType;
  className?: string;
  children: ReactNode;
}) {
  return (
    <As className={cx('ui-stack', className)} style={gapStyle(gap)}>
      {children}
    </As>
  );
}

/** Elementlarni YONMA-YON joylaydi, sig'masa keyingi qatorga o'tadi. */
export function Cluster({
  gap = 2,
  justify,
  className,
  children,
}: {
  gap?: Space;
  justify?: 'start' | 'end' | 'between' | 'center';
  className?: string;
  children: ReactNode;
}) {
  const justifyContent =
    justify === 'between' ? 'space-between' : justify === 'end' ? 'flex-end' : justify;
  return (
    <div className={cx('ui-cluster', className)} style={{ ...gapStyle(gap), justifyContent }}>
      {children}
    </div>
  );
}

/**
 * Sahifa sarlavhasi — har bir panel sahifasining boshi.
 *
 * Sahifaning YAGONA `h1` i shu yerda. Orqaga havola (`back`) sarlavha
 * ustida turadi: ko'z avval "qayerdaman", keyin "nima qilaman" ni
 * ko'radi.
 */
export function PageHeader({
  title,
  description,
  meta,
  actions,
  back,
}: {
  title: ReactNode;
  description?: ReactNode;
  /** Sarlavha yonidagi nishon (holat). */
  meta?: ReactNode;
  actions?: ReactNode;
  back?: { to: string; label: string };
}) {
  // Brauzer yorlig'i sahifa nomini ko'rsatsin — bir nechta yorliq ochiq
  // bo'lganda qaysi biri qaysi ekanini bilish uchun.
  useEffect(() => {
    if (typeof title === 'string') document.title = `${title} — CSCRM`;
  }, [title]);

  return (
    <header className="ui-page-header">
      <div className="ui-page-header__main">
        {back && (
          <Link to={back.to} className="ui-page-header__back">
            <Icon name="chevron-left" size={16} />
            {back.label}
          </Link>
        )}
        <h1 className="ui-page-header__title">
          {title}
          {meta && <span className="ui-page-header__meta">{meta}</span>}
        </h1>
        {description && <p className="ui-page-header__desc">{description}</p>}
      </div>
      {actions && <div className="ui-page-header__actions">{actions}</div>}
    </header>
  );
}

/** Avatar ranglari — chart palitrasidan, har doim `--text` bilan o'qiladi. */
const AVATAR_TONES = ['--chart-1', '--chart-2', '--chart-3', '--chart-4'];

/**
 * Bosh harfli belgi. Rang nomdan hisoblanadi — bir biznes har doim bir
 * xil rangda, ro'yxatda ko'z uni tez topadi. Matn rangi rangdan
 * qat'i nazar `--text` (fon faqat 20% tus).
 */
export function Avatar({
  name,
  size = 32,
  square = false,
}: {
  name: string;
  size?: number;
  square?: boolean;
}) {
  const tone = AVATAR_TONES[toneIndex(name, AVATAR_TONES.length)];
  return (
    <span
      className={cx('ui-avatar', square && 'ui-avatar--square')}
      style={
        {
          width: size,
          height: size,
          fontSize: Math.round(size * 0.4),
          '--avatar-tone': `var(${tone})`,
        } as CSSProperties
      }
      aria-hidden="true"
    >
      {initials(name)}
    </span>
  );
}

/**
 * Filtr tugmachalari — bitta tanlov, har birida son.
 *
 * `aria-pressed` — ekran o'quvchi qaysi filtr yoqilganini aytadi.
 * Son yonida: filtrni bosmasdan oldin natija bo'sh bo'lishini ko'rish.
 */
export function ChipGroup<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: { id: T; label: string; count?: number }[];
  value: T;
  onChange: (id: T) => void;
  /** Guruh nomi — ekran o'quvchi uchun ("Holat bo'yicha filtr"). */
  label: string;
}) {
  return (
    <div className="chips" role="group" aria-label={label}>
      {options.map((o) => (
        <button
          key={o.id}
          type="button"
          className={cx('chip', value === o.id && 'is-active')}
          aria-pressed={value === o.id}
          onClick={() => onChange(o.id)}
        >
          {o.label}
          {o.count !== undefined && <span className="chip__count">{o.count}</span>}
        </button>
      ))}
    </div>
  );
}
