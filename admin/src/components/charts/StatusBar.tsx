import { useLayoutEffect, useRef, useState } from 'react';

export type StatusSegment = { label: string; value: number; color: string };

type StatusBarProps = {
  segments: StatusSegment[];
  /** Barcha bo'laklar yig'indisining nomi — masalan "faol buyurtma". */
  totalLabel: string;
};

const INK = '#0b1524';
const WHITE = '#ffffff';

/** `rgb(…)` / `color(srgb …)` → nisbiy yorqinlik (WCAG). */
function luminance(css: string): number | null {
  let rgb: number[] | null = null;
  const m1 = css.match(/rgba?\(([^)]+)\)/);
  if (m1) rgb = m1[1]!.split(/[ ,/]+/).filter(Boolean).slice(0, 3).map((v) => Number(v) / 255);
  const m2 = css.match(/color\(srgb ([^)]+)\)/);
  if (!rgb && m2) rgb = m2[1]!.split(/[ /]+/).filter(Boolean).slice(0, 3).map(Number);
  if (!rgb || rgb.some((v) => !Number.isFinite(v))) return null;
  const [r, g, b] = rgb.map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)) as [number, number, number];
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** Fon ustida qaysi matn rangi aniqroq o'qiladi. */
export function inkFor(background: string): string {
  const l = luminance(background);
  if (l === null) return WHITE;
  const withWhite = 1.05 / (l + 0.05);
  const withInk = (l + 0.05) / (luminance('rgb(11, 21, 36)')! + 0.05);
  return withInk > withWhite ? INK : WHITE;
}

/**
 * Butunning bo'laklari — bitta gorizontal yig'ma ustun.
 *
 * NEGA DOIRA (donut) EMAS: doirada bo'laklarning kattaligini burchak
 * bo'yicha chamalash kerak, odam buni yomon uddalaydi. Bir chiziqqa
 * tizilgan bo'laklar esa uzunligi bilan taqqoslanadi — bu ancha aniq
 * va joyni ham kamroq egallaydi.
 *
 * Raqam bo'lak ichida faqat SIG'SA yoziladi; aks holda u pastdagi
 * izohlar qatorida qoladi (qirqilgan yarim raqam yozilmaydi).
 *
 * Ichki matn rangi bo'lakning HAQIQIY fonidan hisoblanadi (oq yoki
 * to'q — qaysi biri aniqroq): sariq yoki yashil bo'lak ustida oq matn
 * 2–3:1 berib, o'qilmasdi. Rang CSS o'zgaruvchisidan kelgani uchun
 * hisob chizilgandan keyin, brauzer bergan rangdan qilinadi — tun
 * rejimida ham to'g'ri.
 */
export function StatusBar({ segments, totalLabel }: StatusBarProps) {
  const total = segments.reduce((sum, s) => sum + s.value, 0);
  const safeTotal = total || 1;
  const refs = useRef<(HTMLDivElement | null)[]>([]);
  const [inks, setInks] = useState<string[]>([]);

  useLayoutEffect(() => {
    const update = () =>
      setInks(refs.current.map((el) => (el ? inkFor(getComputedStyle(el).backgroundColor) : WHITE)));
    update();
    // Rejim almashganda ranglar o'zgaradi — qayta hisoblaymiz.
    const mo = new MutationObserver(update);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    return () => mo.disconnect();
  }, [segments]);

  return (
    <div>
      <div
        className="stack-bar"
        role="img"
        aria-label={`${total} ${totalLabel}: ${segments
          .map((s) => `${s.label} ${s.value}`)
          .join(', ')}`}
      >
        {segments
          .filter((s) => s.value > 0)
          .map((s, i) => {
            const share = (s.value / safeTotal) * 100;
            return (
              <div
                key={s.label}
                ref={(el) => {
                  refs.current[i] = el;
                }}
                className="stack-bar__seg"
                style={{ width: `${share}%`, background: s.color, color: inks[i] ?? WHITE }}
              >
                {share >= 12 && s.value}
              </div>
            );
          })}
      </div>

      <div className="chart-legend">
        {segments.map((s) => (
          <span key={s.label} className="chart-legend__item">
            <span className="chart-legend__swatch" style={{ background: s.color }} />
            {s.label}
            <span className="chart-legend__value">{s.value}</span>
          </span>
        ))}
      </div>
    </div>
  );
}
