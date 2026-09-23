import {
  forwardRef,
  type ButtonHTMLAttributes,
  type MouseEvent,
  type ReactNode,
} from 'react';
import { Link, type LinkProps } from 'react-router-dom';

import { Icon, type IconName } from '../Icon';
import { cx } from './logic';
import { Spinner } from './Spinner';

export type ButtonVariant =
  | 'primary'
  | 'secondary'
  | 'outline'
  | 'plain'
  | 'danger'
  | 'danger-outline';

export type ButtonSize = 'sm' | 'md' | 'lg';

const VARIANT: Record<ButtonVariant, string> = {
  primary: 'btn--primary',
  secondary: 'btn--secondary',
  outline: 'btn--ghost',
  plain: 'btn--plain',
  danger: 'btn--danger',
  'danger-outline': 'btn--danger-outline',
};

const ICON_SIZE: Record<ButtonSize, number> = { sm: 16, md: 18, lg: 20 };

interface Look {
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** Matndan oldingi ikonka. */
  icon?: IconName;
  /** Matndan keyingi ikonka. */
  iconEnd?: IconName;
  /** Butun kenglikni egallaydi. */
  block?: boolean;
}

function buttonClass(
  { variant = 'primary', size = 'md', block }: Look,
  extra?: string,
  loading?: boolean,
): string {
  return cx('btn', VARIANT[variant], `btn--${size}`, block && 'btn--block', loading && 'is-loading', extra);
}

function Content({ icon, iconEnd, size = 'md', children }: Look & { children?: ReactNode }) {
  return (
    <span className="btn__label">
      {icon && <Icon name={icon} size={ICON_SIZE[size]} />}
      {children}
      {iconEnd && <Icon name={iconEnd} size={ICON_SIZE[size]} />}
    </span>
  );
}

export interface ButtonProps
  extends Look,
    Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  children?: ReactNode;
  /**
   * Amal bajarilmoqda. Tugma bosilmaydi, o'lchami o'zgarmaydi.
   *
   * `disabled` o'rniga `aria-disabled` ishlatiladi: haqiqiy `disabled`
   * tugma fokusni yo'qotadi va klaviatura bilan ishlayotgan
   * foydalanuvchi sahifa boshiga "uloqtiriladi".
   */
  loading?: boolean;
}

/**
 * Tugma — ilovadagi har bir amal shu orqali.
 *
 * Takroriy bosishdan himoya shu yerda: `loading` paytida bosish va
 * Enter bilan formani yuborish ham to'xtatiladi (`preventDefault`).
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant,
    size = 'md',
    icon,
    iconEnd,
    block,
    loading = false,
    className,
    children,
    type = 'button',
    onClick,
    ...rest
  },
  ref,
) {
  const handleClick = (e: MouseEvent<HTMLButtonElement>) => {
    if (loading) {
      e.preventDefault();
      return;
    }
    onClick?.(e);
  };

  return (
    <button
      ref={ref}
      type={type}
      className={buttonClass({ variant, size, block }, className, loading)}
      aria-busy={loading || undefined}
      aria-disabled={loading || undefined}
      onClick={handleClick}
      {...rest}
    >
      {loading && <Spinner className="btn__spinner" />}
      <Content icon={icon} iconEnd={iconEnd} size={size}>
        {children}
      </Content>
    </button>
  );
});

export interface ButtonLinkProps extends Look, Omit<LinkProps, 'children'> {
  children?: ReactNode;
}

/** Tugma ko'rinishidagi havola — boshqa sahifaga o'tish uchun. */
export function ButtonLink({
  variant,
  size = 'md',
  icon,
  iconEnd,
  block,
  className,
  children,
  ...rest
}: ButtonLinkProps) {
  return (
    <Link className={buttonClass({ variant, size, block }, className)} {...rest}>
      <Content icon={icon} iconEnd={iconEnd} size={size}>
        {children}
      </Content>
    </Link>
  );
}
