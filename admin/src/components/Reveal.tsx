import { useEffect, useRef, useState, type ReactNode } from 'react';

type RevealProps = {
  children: ReactNode;
  /** Kechikish (ms) — yonma-yon kartalar navbat bilan paydo bo'lsin. */
  delay?: number;
  className?: string;
};

/**
 * Ekranga kirganda yumshoq paydo bo'ladigan blok.
 *
 * MUHIM QARORI: element boshida KO'RINADIGAN holatda chiziladi va
 * "ko'rinmas" holatga faqat JavaScript o'zi qo'ya oladi (`is-armed`).
 *
 * Sababi: agar ko'rinmaslik CSS'da yozilganda, JavaScript ishlamagan
 * yoki `IntersectionObserver` bo'lmagan brauzerda butun sahifa bo'sh
 * qolardi. Animatsiya — bezak, mazmun esa asosiy narsa; bezak
 * ishlamasa mazmun yo'qolmasligi kerak.
 */
export function Reveal({ children, delay = 0, className }: RevealProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [state, setState] = useState<'idle' | 'armed' | 'in'>('idle');

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // Harakat foydalanuvchini bezovta qilsa (vestibulyar sezgirlik) —
    // animatsiya umuman yoqilmaydi.
    const reduced = window.matchMedia?.(
      '(prefers-reduced-motion: reduce)',
    ).matches;
    if (reduced || typeof IntersectionObserver === 'undefined') return;

    setState('armed');

    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          // Bir marta ko'ringach kuzatish to'xtaydi: qayta skroll
          // qilganda blok yana yo'qolib-paydo bo'lsa, bu bezovta qiladi.
          io.disconnect();
          window.setTimeout(() => setState('in'), delay);
        }
      },
      // Blok to'liq kirishini kutmaymiz — uchdan biri ko'ringanda
      // boshlanadi, shunda animatsiya skroll bilan bir maromda ketadi.
      { threshold: 0.15, rootMargin: '0px 0px -40px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [delay]);

  const classes = ['reveal'];
  if (state === 'armed') classes.push('is-armed');
  if (state === 'in') classes.push('is-in');
  if (className) classes.push(className);

  return (
    <div ref={ref} className={classes.join(' ')}>
      {children}
    </div>
  );
}
