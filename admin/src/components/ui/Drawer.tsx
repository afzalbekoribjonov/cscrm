import { useId, useRef, type ReactNode } from 'react';
import { createPortal } from 'react-dom';

import { IconButton } from './IconButton';
import { useModalBehavior } from './modal';

/**
 * Yon panel — telefonda menyu uchun.
 *
 * Xatti-harakati Dialog bilan bir xil (`useModalBehavior`): fokus
 * ichida, orqa fon `inert`, Esc va fon bosilganda yopiladi, fokus
 * ochgan tugmaga qaytadi.
 */
export function Drawer({
  open,
  onClose,
  title,
  children,
  footer,
}: {
  open: boolean;
  onClose: () => void;
  /** Ekran o'quvchi uchun nom; ko'rinadigan sarlavha `header` da. */
  title: string;
  children: ReactNode;
  footer?: ReactNode;
}) {
  const titleId = useId();
  const panelRef = useRef<HTMLElement | null>(null);

  useModalBehavior({ open, onClose, dismissible: true, panelRef });

  if (!open) return null;

  return createPortal(
    <div
      className="ui-drawer-overlay"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <aside
        ref={(el) => {
          panelRef.current = el;
        }}
        className="ui-drawer"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
      >
        <div className="ui-drawer__head">
          <h2 id={titleId} className="ui-sr-only">
            {title}
          </h2>
          <IconButton icon="close" label="Menyuni yopish" noTooltip onClick={onClose} />
        </div>
        <div className="ui-drawer__body">{children}</div>
        {footer && <div className="ui-drawer__foot">{footer}</div>}
      </aside>
    </div>,
    document.body,
  );
}
