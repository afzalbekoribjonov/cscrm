import { useEffect } from 'react';

import { branding } from './branding';

/**
 * Sahifa sarlavhasi va tavsifi.
 *
 * Sayt bitta HTML fayldan iborat (SPA) — ya'ni `index.html` dagi
 * `<title>` barcha sahifalar uchun bir xil bo'lib qolardi. Bu ikki
 * joyda ziyon: brauzer yorlig'ida va Google natijasida har bir sahifa
 * bir xil nom bilan chiqardi.
 *
 * Bu ilgak sahifa ochilganda teglarni almashtiradi va sahifadan
 * chiqilganda hech narsa qilmaydi — keyingi sahifa o'zinikini qo'yadi.
 */
export function useSeo(title: string, description?: string): void {
  useEffect(() => {
    document.title = `${title} — ${branding.name}`;

    if (description) {
      setMeta('name', 'description', description);
      setMeta('property', 'og:description', description);
    }
    setMeta('property', 'og:title', title);
    setMeta('property', 'og:url', window.location.href);
    setCanonical(window.location.href);
  }, [title, description]);
}

function setMeta(attr: 'name' | 'property', key: string, value: string): void {
  let el = document.head.querySelector<HTMLMetaElement>(`meta[${attr}="${key}"]`);
  if (!el) {
    el = document.createElement('meta');
    el.setAttribute(attr, key);
    document.head.appendChild(el);
  }
  el.content = value;
}

function setCanonical(href: string): void {
  let el = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]');
  if (!el) {
    el = document.createElement('link');
    el.rel = 'canonical';
    document.head.appendChild(el);
  }
  // Qidiruv tizimi uchun manzil bitta bo'lishi kerak — so'rov
  // parametrlari (utm_source va h.k.) nusxa sahifa yasab qo'ymasin.
  el.href = href.split('?')[0]?.split('#')[0] ?? href;
}
