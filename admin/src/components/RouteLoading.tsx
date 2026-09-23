/**
 * Sahifa bo'lagi yuklanayotganda — bo'sh ekran o'rniga.
 *
 * Bir zumda chiqib-yo'qolib ko'zni qamashtirmasligi uchun belgi
 * yarim soniyadan keyin ko'rinadi (CSS `animation-delay`); tez
 * internetda foydalanuvchi uni umuman ko'rmaydi.
 */
export function RouteLoading({ label = 'Yuklanmoqda…' }: { label?: string }) {
  return (
    <div className="route-loading" role="status" aria-live="polite">
      <span className="route-loading__dot" aria-hidden="true" />
      <span className="route-loading__label">{label}</span>
    </div>
  );
}
