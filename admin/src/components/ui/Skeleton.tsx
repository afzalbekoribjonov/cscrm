import type { CSSProperties } from 'react';

import { cx } from './logic';

/**
 * Yuklanish o'rni — kelajakdagi tarkib shaklida.
 *
 * "Yuklanmoqda…" matnidan farqi: sahifa tuzilishi darhol ko'rinadi va
 * ma'lumot kelganda hech narsa joyidan sakramaydi.
 */
export function Skeleton({
  width = '100%',
  height = 14,
  radius,
  className,
  style,
}: {
  width?: number | string;
  height?: number | string;
  radius?: number | string;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <span
      className={cx('ui-skeleton', className)}
      style={{ width, height, borderRadius: radius, ...style }}
      aria-hidden="true"
    />
  );
}

/** Bir necha qatorli matn o'rni; oxirgisi qisqaroq — haqiqiy matndek. */
export function SkeletonText({ lines = 3 }: { lines?: number }) {
  return (
    <span style={{ display: 'grid', gap: 8 }} aria-hidden="true">
      {Array.from({ length: lines }, (_, i) => (
        <Skeleton key={i} width={i === lines - 1 && lines > 1 ? '60%' : '100%'} />
      ))}
    </span>
  );
}
