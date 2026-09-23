import { useCallback, useEffect, useRef, useState } from 'react';

import { api } from './api';

export interface ApiState<T> {
  data: T | null;
  error: string | null;
  /** Birinchi yuklanish — hali ma'lumot yo'q. */
  loading: boolean;
  /** Qayta yuklanish — eski ma'lumot ekranda qoladi. */
  refreshing: boolean;
  /** Oxirgi muvaffaqiyatli javob vaqti. */
  updatedAt: number | null;
  reload: () => void;
}

/**
 * GET so'rov holati: yuklanish, xato, qayta yuklash.
 *
 * * Yo'l o'zgarsa (masalan, davr tanlandi) eski so'rov BEKOR qilinadi —
 *   kech kelgan eski javob yangisining ustiga yozilib qolmaydi.
 * * Qayta yuklashda eski ma'lumot ekranda qoladi (`refreshing`) —
 *   sahifa skeletga sakramaydi.
 * * Oynaga qaytilganda ma'lumot eskirgan bo'lsa (`staleMs`) o'zi
 *   yangilanadi. Doimiy so'rov (polling) YO'Q — keraksiz trafik.
 */
export function useApi<T>(
  path: string | null,
  pick: (json: unknown) => T,
  { staleMs = 60_000 }: { staleMs?: number } = {},
): ApiState<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [updatedAt, setUpdatedAt] = useState<number | null>(null);
  const [nonce, setNonce] = useState(0);

  // `pick` har renderda yangi funksiya bo'lishi mumkin — effektni
  // qayta ishga tushirmasligi uchun ref'da.
  const pickRef = useRef(pick);
  pickRef.current = pick;
  const updatedRef = useRef<number | null>(null);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    if (!path) return;
    const ctrl = new AbortController();
    setBusy(true);
    setError(null);

    api
      .get<unknown>(path, { signal: ctrl.signal })
      .then((json) => {
        setData(pickRef.current(json));
        const t = Date.now();
        updatedRef.current = t;
        setUpdatedAt(t);
      })
      .catch((e: unknown) => {
        if (ctrl.signal.aborted) return;
        setError(e instanceof Error ? e.message : 'Ma\'lumotni yuklashda muammo yuz berdi.');
      })
      .finally(() => {
        if (!ctrl.signal.aborted) setBusy(false);
      });

    return () => ctrl.abort();
  }, [path, nonce]);

  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState !== 'visible') return;
      const last = updatedRef.current;
      if (last !== null && Date.now() - last > staleMs) reload();
    };
    document.addEventListener('visibilitychange', onVisible);
    window.addEventListener('focus', onVisible);
    return () => {
      document.removeEventListener('visibilitychange', onVisible);
      window.removeEventListener('focus', onVisible);
    };
  }, [staleMs, reload]);

  return {
    data,
    error,
    loading: busy && data === null,
    refreshing: busy && data !== null,
    updatedAt,
    reload,
  };
}
