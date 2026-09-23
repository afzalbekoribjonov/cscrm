import { cx } from './logic';

/**
 * Aylanma yuklanish belgisi.
 *
 * `label` berilsa ekran o'quvchiga aytiladi ("Yuklanmoqda"). Tugma
 * ichida berilmaydi: u yerda holatni tugmaning `aria-busy` si aytadi,
 * ikkinchi e'lon faqat shovqin.
 */
export function Spinner({
  label,
  className,
}: {
  label?: string | null;
  className?: string;
}) {
  return label ? (
    <span className={cx('ui-spinner', className)} role="status" aria-label={label} />
  ) : (
    <span className={cx('ui-spinner', className)} aria-hidden="true" />
  );
}
