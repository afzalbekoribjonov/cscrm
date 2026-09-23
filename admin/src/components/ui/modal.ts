import { useEffect, useRef, type RefObject } from 'react';

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), ' +
  'select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export function focusables(root: Element | null): HTMLElement[] {
  if (!root) return [];
  return Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
    (el) => !el.hasAttribute('inert') && el.getClientRects().length > 0,
  );
}

/**
 * Modal oyna xatti-harakati — Dialog va Drawer uchun umumiy.
 *
 *  * orqa fon (`#root`) `inert` — ekran o'quvchi va Tab unga yetmaydi;
 *  * sahifa aylanmaydi (aylantirish chizig'i o'rni to'ldiriladi —
 *    tarkib yon tomonga sakramaydi);
 *  * ochilganda fokus ichkariga, Tab / Shift+Tab ichida aylanadi;
 *  * Esc yopadi (`dismissible` bo'lsa);
 *  * yopilgach fokus oynani OCHGAN elementga qaytadi.
 */
export function useModalBehavior({
  open,
  onClose,
  dismissible,
  panelRef,
  initialFocus,
}: {
  open: boolean;
  onClose: () => void;
  dismissible: boolean;
  panelRef: RefObject<HTMLElement | null>;
  /** Ochilganda fokus olishi kerak bo'lgan element (berilmasa — o'zi topadi). */
  initialFocus?: () => HTMLElement | null | undefined;
}): void {
  // Eng so'nggi qiymatlar — effekt har renderda qayta ulanmasligi uchun.
  const latest = useRef({ onClose, dismissible, initialFocus });
  latest.current = { onClose, dismissible, initialFocus };

  useEffect(() => {
    if (!open) return;

    const opener = document.activeElement as HTMLElement | null;
    const appRoot = document.getElementById('root');
    appRoot?.setAttribute('inert', '');

    const body = document.body.style;
    const saved = { overflow: body.overflow, paddingRight: body.paddingRight };
    const scrollbar = window.innerWidth - document.documentElement.clientWidth;
    body.overflow = 'hidden';
    if (scrollbar > 0) body.paddingRight = `${scrollbar}px`;

    const frame = requestAnimationFrame(() => {
      const panel = panelRef.current;
      const target = latest.current.initialFocus?.() ?? focusables(panel)[0] ?? panel;
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
      if (opener && document.contains(opener)) opener.focus();
    };
  }, [open, panelRef]);
}
