/**
 * Panel ichidagi kichik xabarlar.
 *
 * Menyudagi hisoblagich (kutilayotgan to'lovlar) daqiqada bir
 * yangilanadi. To'lov tasdiqlangan yoki rad etilgan zahoti esa u
 * darhol kamayishi kerak — aks holda admin "hali bittasi qoldimi?"
 * deb o'ylaydi.
 */
const BADGES_CHANGED = 'cscrm:badges-changed';

export function notifyBadgesChanged(): void {
  window.dispatchEvent(new Event(BADGES_CHANGED));
}

export function onBadgesChanged(listener: () => void): () => void {
  window.addEventListener(BADGES_CHANGED, listener);
  return () => window.removeEventListener(BADGES_CHANGED, listener);
}
