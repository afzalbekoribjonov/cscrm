import {
  cloneElement,
  useEffect,
  useId,
  useRef,
  useState,
  type FocusEvent,
  type MouseEvent,
  type ReactElement,
  type Ref,
} from 'react';
import { createPortal } from 'react-dom';

import { useFloatingPosition, type Side } from './anchor';
import { mergeRefs } from './refs';

type TriggerProps = {
  ref?: unknown;
  'aria-describedby'?: string;
  onMouseEnter?: (e: MouseEvent) => void;
  onMouseLeave?: (e: MouseEvent) => void;
  onFocus?: (e: FocusEvent) => void;
  onBlur?: (e: FocusEvent) => void;
};

const OPEN_DELAY = 350;

/**
 * Qisqa maslahat — sichqoncha ustiga kelganda yoki klaviatura fokusida.
 *
 * Maslahat MUHIM ma'lumotni yashirmasligi kerak: u faqat ikonkali
 * tugmaning nomini aytadi yoki qisqa izoh beradi. Telefonda "ustiga
 * olib borish" yo'q — shu sababli asosiy ma'lumot doim ko'rinib turadi.
 *
 * Esc bilan yopiladi (WCAG 1.4.13).
 */
export function Tooltip({
  content,
  children,
  side = 'top',
}: {
  content: string;
  children: ReactElement<TriggerProps>;
  side?: Side;
}) {
  const id = useId();
  const [open, setOpen] = useState(false);
  const anchorRef = useRef<HTMLElement | null>(null);
  const tipRef = useRef<HTMLDivElement | null>(null);
  const timer = useRef<number | undefined>(undefined);
  const pos = useFloatingPosition(anchorRef, tipRef, open, side, 'center');

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    const onScroll = () => setOpen(false);
    window.addEventListener('keydown', onKey);
    window.addEventListener('scroll', onScroll, true);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('scroll', onScroll, true);
    };
  }, [open]);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const show = (delay: number) => {
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setOpen(true), delay);
  };
  const hide = () => {
    window.clearTimeout(timer.current);
    setOpen(false);
  };

  const p = children.props;
  // React 18 da bolaning o'z ref'i `element.ref` da turadi.
  const childRef = (children as unknown as { ref?: Ref<HTMLElement> }).ref;
  const trigger = cloneElement(children, {
    ref: mergeRefs<HTMLElement>(anchorRef, childRef),
    'aria-describedby': open ? id : p['aria-describedby'],
    onMouseEnter: (e: MouseEvent) => {
      p.onMouseEnter?.(e);
      show(OPEN_DELAY);
    },
    onMouseLeave: (e: MouseEvent) => {
      p.onMouseLeave?.(e);
      hide();
    },
    onFocus: (e: FocusEvent) => {
      p.onFocus?.(e);
      // Faqat klaviatura fokusida — sichqoncha bosganda maslahat
      // tugma ustida qolib, natijani to'sib qo'ymasin.
      if ((e.target as HTMLElement).matches?.(':focus-visible')) show(0);
    },
    onBlur: (e: FocusEvent) => {
      p.onBlur?.(e);
      hide();
    },
  });

  return (
    <>
      {trigger}
      {open &&
        createPortal(
          <div
            ref={tipRef}
            id={id}
            role="tooltip"
            className="ui-tooltip"
            style={{
              top: pos?.top ?? -9999,
              left: pos?.left ?? -9999,
              visibility: pos ? 'visible' : 'hidden',
            }}
          >
            {content}
          </div>,
          document.body,
        )}
    </>
  );
}
