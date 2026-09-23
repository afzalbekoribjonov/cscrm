import { useLayoutEffect, useState, type RefObject } from 'react';

/**
 * Suzuvchi element (menyu, maslahat) uchun ekrandagi joy.
 *
 * NEGA `position: fixed` VA PORTAL. Jadval telefonda gorizontal
 * aylantiriladigan konteyner ichida turadi — `absolute` menyu o'sha
 * konteyner chegarasida KESILIB qolardi. Portal orqali `body` ga
 * chiqarilgan `fixed` element hech narsaga qirqilmaydi.
 *
 * Joy yetmasa teskari tomonga o'tadi (pastda joy yo'q — tepaga) va
 * ekran chetidan chiqib ketmaydi.
 */
export type Side = 'top' | 'bottom';
export type Align = 'start' | 'center' | 'end';

export interface FloatingPosition {
  top: number;
  left: number;
  side: Side;
}

const GAP = 6;
const EDGE = 8;

/** Sof hisob — sinovda va hookda bir xil ishlatiladi. */
export function computePosition(
  anchor: { top: number; left: number; width: number; height: number },
  floating: { width: number; height: number },
  viewport: { width: number; height: number },
  side: Side,
  align: Align,
): FloatingPosition {
  const spaceBelow = viewport.height - (anchor.top + anchor.height);
  const spaceAbove = anchor.top;
  const need = floating.height + GAP + EDGE;

  let actual: Side = side;
  if (side === 'bottom' && spaceBelow < need && spaceAbove > spaceBelow) actual = 'top';
  if (side === 'top' && spaceAbove < need && spaceBelow > spaceAbove) actual = 'bottom';

  const top =
    actual === 'bottom'
      ? anchor.top + anchor.height + GAP
      : anchor.top - floating.height - GAP;

  let left =
    align === 'start'
      ? anchor.left
      : align === 'end'
        ? anchor.left + anchor.width - floating.width
        : anchor.left + anchor.width / 2 - floating.width / 2;

  left = Math.min(Math.max(EDGE, left), viewport.width - floating.width - EDGE);

  return { top: Math.max(EDGE, top), left, side: actual };
}

export function useFloatingPosition(
  anchorRef: RefObject<HTMLElement | null>,
  floatingRef: RefObject<HTMLElement | null>,
  open: boolean,
  side: Side,
  align: Align,
): FloatingPosition | null {
  const [pos, setPos] = useState<FloatingPosition | null>(null);

  useLayoutEffect(() => {
    if (!open) {
      setPos(null);
      return;
    }
    const anchor = anchorRef.current;
    const floating = floatingRef.current;
    if (!anchor || !floating) return;

    const a = anchor.getBoundingClientRect();
    const f = floating.getBoundingClientRect();
    setPos(
      computePosition(
        { top: a.top, left: a.left, width: a.width, height: a.height },
        { width: f.width, height: f.height },
        { width: window.innerWidth, height: window.innerHeight },
        side,
        align,
      ),
    );
  }, [open, side, align, anchorRef, floatingRef]);

  return pos;
}
