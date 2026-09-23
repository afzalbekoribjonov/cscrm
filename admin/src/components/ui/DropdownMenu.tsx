import { Fragment, useEffect, useId, useRef, useState, type KeyboardEvent } from 'react';
import { createPortal } from 'react-dom';

import { Icon, type IconName } from '../Icon';
import { useFloatingPosition } from './anchor';
import { IconButton } from './IconButton';
import { cx } from './logic';

export interface MenuItem {
  id: string;
  label: string;
  icon?: IconName;
  onSelect: () => void;
  /** Xavfli amal (o'chirish, arxivlash) — qizil va boshqalardan ajratilgan. */
  tone?: 'danger';
  disabled?: boolean;
}

/**
 * Qator amallari menyusi ("…").
 *
 * Jadval qatorida amal ko'p bo'lsa (tahrirlash, obuna, arxivlash…),
 * ularni tugmalar qatori qilish o'rniga shu yerga yig'iladi.
 * Xavfli amallar oxirida, chiziq bilan ajratilgan — tasodifan bosib
 * yuborilmasin.
 *
 * Klaviatura (WAI-ARIA "menu button"): Enter/Space/↓ ochadi, ↑↓ yuradi,
 * Home/End, Esc yopib tugmaga qaytaradi, Tab yopadi.
 */
export function DropdownMenu({
  items,
  label = 'Amallar',
}: {
  items: MenuItem[];
  /** Tugma nomi — ekran o'quvchi va maslahat uchun. */
  label?: string;
}) {
  const menuId = useId();
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const menuRef = useRef<HTMLDivElement | null>(null);
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const pos = useFloatingPosition(triggerRef, menuRef, open, 'bottom', 'end');

  // Xavfsizlarni tepaga, xavflilarni pastga — ajratuvchi bilan.
  const safe = items.filter((i) => i.tone !== 'danger');
  const danger = items.filter((i) => i.tone === 'danger');
  const ordered = [...safe, ...danger];

  const enabledIndexes = ordered
    .map((item, i) => (item.disabled ? -1 : i))
    .filter((i) => i >= 0);

  const focusItem = (index: number | undefined) => {
    if (index !== undefined) itemRefs.current[index]?.focus();
  };

  const close = (returnFocus: boolean) => {
    setOpen(false);
    if (returnFocus) triggerRef.current?.focus();
  };

  // Ochilgach birinchi faol bandga fokus.
  useEffect(() => {
    if (open && pos) focusItem(enabledIndexes[0]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, pos !== null]);

  useEffect(() => {
    if (!open) return;
    const onPointer = (e: PointerEvent) => {
      const t = e.target as Node;
      if (!menuRef.current?.contains(t) && !triggerRef.current?.contains(t)) close(false);
    };
    // Aylantirish yoki o'lcham o'zgarsa menyu tugmadan ajralib qolardi.
    const onMove = () => close(false);
    document.addEventListener('pointerdown', onPointer);
    window.addEventListener('scroll', onMove, true);
    window.addEventListener('resize', onMove);
    return () => {
      document.removeEventListener('pointerdown', onPointer);
      window.removeEventListener('scroll', onMove, true);
      window.removeEventListener('resize', onMove);
    };
  }, [open]);

  const onMenuKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const current = itemRefs.current.findIndex((el) => el === document.activeElement);
    const pos = enabledIndexes.indexOf(current);
    const last = enabledIndexes.length - 1;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        focusItem(enabledIndexes[pos >= last ? 0 : pos + 1]);
        break;
      case 'ArrowUp':
        e.preventDefault();
        focusItem(enabledIndexes[pos <= 0 ? last : pos - 1]);
        break;
      case 'Home':
        e.preventDefault();
        focusItem(enabledIndexes[0]);
        break;
      case 'End':
        e.preventDefault();
        focusItem(enabledIndexes[last]);
        break;
      case 'Escape':
        e.preventDefault();
        e.stopPropagation();
        close(true);
        break;
      case 'Tab':
        close(false);
        break;
    }
  };

  return (
    <>
      <IconButton
        ref={triggerRef}
        icon="more"
        label={label}
        size="sm"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((v) => !v)}
        onKeyDown={(e) => {
          if (e.key === 'ArrowDown' && !open) {
            e.preventDefault();
            setOpen(true);
          }
        }}
      />
      {open &&
        createPortal(
          <div
            ref={menuRef}
            id={menuId}
            role="menu"
            aria-label={label}
            className="ui-menu"
            onKeyDown={onMenuKey}
            style={{
              top: pos?.top ?? -9999,
              left: pos?.left ?? -9999,
              visibility: pos ? 'visible' : 'hidden',
            }}
          >
            {ordered.map((item, i) => (
              <Fragment key={item.id}>
                {i === safe.length && safe.length > 0 && (
                  <div className="ui-menu__sep" role="separator" />
                )}
                <button
                  ref={(el) => {
                    itemRefs.current[i] = el;
                  }}
                  type="button"
                  role="menuitem"
                  tabIndex={-1}
                  disabled={item.disabled}
                  className={cx('ui-menu__item', item.tone === 'danger' && 'ui-menu__item--danger')}
                  onClick={() => {
                    close(true);
                    item.onSelect();
                  }}
                >
                  {item.icon && <Icon name={item.icon} size={17} />}
                  {item.label}
                </button>
              </Fragment>
            ))}
          </div>,
          document.body,
        )}
    </>
  );
}
