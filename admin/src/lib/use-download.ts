import { useEffect, useState } from 'react';

import { env } from './env';

/**
 * Ilovani yuklab olish ma'lumoti.
 *
 * Manzil kodda emas, panelda saqlanadi — yangi APK chiqqanda faqat
 * havolani almashtirish yetarli, saytni qayta yig'ish shart emas.
 */
export interface DownloadInfo {
  url: string;
  version: string;
  sizeMb: number;
  note: string;
  updatedAt: number;
}

const EMPTY: DownloadInfo = {
  url: '',
  version: '',
  sizeMb: 0,
  note: '',
  updatedAt: 0,
};

/**
 * `loading` ATAYLAB ajratilgan: manzil hali kelmaganida ham,
 * umuman yo'q bo'lganida ham `url` bo'sh bo'ladi. Sahifa bu ikkisini
 * farqlashi kerak — birinchisida kutamiz, ikkinchisida aloqa
 * taklifini ko'rsatamiz.
 */
export function useDownload(): { info: DownloadInfo; loading: boolean } {
  const [info, setInfo] = useState<DownloadInfo>(EMPTY);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;

    fetch(`${env.apiBaseUrl}/api/v1/site/settings`)
      .then((r) => (r.ok ? r.json() : null))
      .then((json: { download?: Partial<DownloadInfo> } | null) => {
        if (!alive) return;
        if (json?.download) setInfo({ ...EMPTY, ...json.download });
        setLoading(false);
      })
      .catch(() => {
        // Server javob bermasa sahifa baribir ochiladi — tugma
        // o'rniga aloqa taklifi chiqadi.
        if (alive) setLoading(false);
      });

    return () => {
      alive = false;
    };
  }, []);

  return { info, loading };
}
