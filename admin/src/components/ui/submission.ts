import { useEffect, useRef, useState } from 'react';

const FALLBACK_ERROR = 'Amalni bajarib bo\'lmadi. Qayta urinib ko\'ring.';

export function errorText(e: unknown): string {
  return e instanceof Error && e.message ? e.message : FALLBACK_ERROR;
}

/**
 * Oyna ichidagi bitta so'rov: takroriy bosishdan himoya + xato holati.
 *
 * `inFlight` — ref, holat emas: holat keyingi renderda yangilanadi,
 * tez ikki marta bosilganda ikkinchisi hali "band emas" deb o'tib
 * ketardi. Ref darhol o'zgaradi.
 *
 * Xato bo'lsa oyna OCHIQ qoladi — foydalanuvchi nima bo'lganini
 * ko'radi va qayta urina oladi.
 */
export function useSubmission(open: boolean) {
  const inFlight = useRef(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setError(null);
      setBusy(false);
      inFlight.current = false;
    }
  }, [open]);

  async function run(action: () => Promise<void> | void, onDone: () => void) {
    if (inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setError(null);
    try {
      await action();
      onDone();
    } catch (e) {
      setError(errorText(e));
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  }

  return { busy, error, run };
}
