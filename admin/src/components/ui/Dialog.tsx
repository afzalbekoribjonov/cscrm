import {
  useEffect,
  useId,
  useRef,
  type FormEvent,
  type ReactNode,
  type RefObject,
} from 'react';
import { createPortal } from 'react-dom';

import { Icon, type IconName } from '../Icon';
import { IconButton } from './IconButton';
import { cx } from './logic';

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), ' +
  'select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

function focusables(root: HTMLElement | null): HTMLElement[] {
  if (!root) return [];
  return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
    (el) => !el.hasAttribute('inert') && el.getClientRects().length > 0,
  );
}

export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  description?: ReactNode;
  icon?: IconName;
  tone?: 'default' | 'danger' | 'warning';
  size?: 'sm' | 'md' | 'lg';
  /**
   * Esc, fon yoki "×" bilan yopish mumkinmi. Amal bajarilayotganda
   * `false` — aks holda foydalanuvchi natijani ko'rmay qoladi.
   */
  dismissible?: boolean;
  /** Ochilganda fokus qayerga tushadi. Berilmasa — birinchi maydon. */
  initialFocusRef?: RefObject<HTMLElement | null>;
  /** Berilsa oyna `<form>` bo'ladi: Enter bilan yuborish ishlaydi. */
  onSubmit?: (e: FormEvent<HTMLFormElement>) => void;
  footer?: ReactNode;
  children?: ReactNode;
}

/**
 * Muloqot oynasi.
 *
 * Kirish imkoniyati (WAI-ARIA "dialog (modal)" namunasi):
 *  * fokus oyna ichida aylanadi (Tab / Shift+Tab);
 *  * orqa fon `inert` — ekran o'quvchi va klaviatura unga yetmaydi;
 *  * Esc yopadi (`dismissible` bo'lsa);
 *  * yopilgach fokus oynani ochgan tugmaga QAYTADI — foydalanuvchi
 *    sahifada qayerda ekanini yo'qotmaydi;
 *  * sahifa orqada aylanmaydi.
 *
 * Telefonda oyna pastdan chiqadi (CSS) — bosh barmoq yetadigan joyda.
 */
export function Dialog({
  open,
  onClose,
  title,
  description,
  icon,
  tone = 'default',
  size = 'md',
  dismissible = true,
  initialFocusRef,
  onSubmit,
  footer,
  children,
}: DialogProps) {
  const titleId = useId();
  const descId = useId();
  const panelRef = useRef<HTMLElement | null>(null);
  const pointerDownOnOverlay = useRef(false);

  // Eng so'nggi qiymatlar — effekt har renderda qayta ulanmasligi uchun.
  const latest = useRef({ onClose, dismissible, initialFocusRef });
  latest.current = { onClose, dismissible, initialFocusRef };

  useEffect(() => {
    if (!open) return;

    const opener = document.activeElement as HTMLElement | null;
    const appRoot = document.getElementById('root');
    appRoot?.setAttribute('inert', '');

    // Sahifani qotiramiz; aylantirish chizig'i yo'qolganda tarkib
    // yon tomonga sakramasligi uchun uning kengligini to'ldiramiz.
    const body = document.body.style;
    const saved = { overflow: body.overflow, paddingRight: body.paddingRight };
    const scrollbar = window.innerWidth - document.documentElement.clientWidth;
    body.overflow = 'hidden';
    if (scrollbar > 0) body.paddingRight = `${scrollbar}px`;

    const frame = requestAnimationFrame(() => {
      const panel = panelRef.current;
      const preferred = latest.current.initialFocusRef?.current;
      const inBody = focusables(panel?.querySelector('.ui-dialog__body') ?? null)[0];
      const target = preferred ?? inBody ?? focusables(panel)[0] ?? panel;
      target?.focus();
    });

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (latest.current.dismissible) {
          e.stopPropagation();
          latest.current.onClose();
        }
        return;
      }
      if (e.key !== 'Tab') return;

      const items = focusables(panelRef.current);
      if (items.length === 0) {
        e.preventDefault();
        return;
      }
      const first = items[0]!;
      const last = items[items.length - 1]!;
      const active = document.activeElement;
      if (e.shiftKey && (active === first || !panelRef.current?.contains(active))) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', onKey);

    return () => {
      cancelAnimationFrame(frame);
      document.removeEventListener('keydown', onKey);
      appRoot?.removeAttribute('inert');
      body.overflow = saved.overflow;
      body.paddingRight = saved.paddingRight;
      // Fokusni ochgan joyga qaytaramiz (u hali sahifada bo'lsa).
      if (opener && document.contains(opener)) opener.focus();
    };
  }, [open]);

  if (!open) return null;

  const head = (
    <div className="ui-dialog__head">
      {icon && (
        <span
          className={cx('ui-dialog__icon', tone !== 'default' && `ui-dialog__icon--${tone}`)}
          aria-hidden="true"
        >
          <Icon name={icon} size={20} />
        </span>
      )}
      <div className="ui-dialog__titles">
        <h2 id={titleId} className="ui-dialog__title">
          {title}
        </h2>
        {description && (
          <p id={descId} className="ui-dialog__desc">
            {description}
          </p>
        )}
      </div>
      {dismissible && (
        <IconButton icon="close" label="Yopish" size="sm" noTooltip onClick={onClose} />
      )}
    </div>
  );

  const inner = (
    <>
      {head}
      {children !== undefined && <div className="ui-dialog__body">{children}</div>}
      {footer && <div className="ui-dialog__foot">{footer}</div>}
    </>
  );

  const panelProps = {
    className: cx('ui-dialog', size !== 'md' && `ui-dialog--${size}`),
    role: 'dialog',
    'aria-modal': true,
    'aria-labelledby': titleId,
    'aria-describedby': description ? descId : undefined,
    tabIndex: -1,
  } as const;

  return createPortal(
    <div
      className="ui-overlay"
      // Fonni bosish yopadi — lekin faqat bosish HAM, qo'yib yuborish HAM
      // fonda bo'lsa. Aks holda maydondagi matnni sichqoncha bilan
      // belgilab, fonga chiqib qo'yib yuborganda oyna yopilib ketardi.
      onPointerDown={(e) => {
        pointerDownOnOverlay.current = e.target === e.currentTarget;
      }}
      onClick={(e) => {
        if (pointerDownOnOverlay.current && e.target === e.currentTarget && dismissible) {
          onClose();
        }
        pointerDownOnOverlay.current = false;
      }}
    >
      {onSubmit ? (
        <form
          {...panelProps}
          ref={(el) => {
            panelRef.current = el;
          }}
          onSubmit={(e) => {
            e.preventDefault();
            onSubmit(e);
          }}
          noValidate
        >
          {inner}
        </form>
      ) : (
        <div
          {...panelProps}
          ref={(el) => {
            panelRef.current = el;
          }}
        >
          {inner}
        </div>
      )}
    </div>,
    document.body,
  );
}
