import { useEffect, useRef, useState, type KeyboardEvent } from 'react';

import { compactNumber, niceTicks, visibleLabelIndexes } from '@/components/ui/logic';

export interface BarDatum {
  /** O'q ostidagi qisqa yorliq ("12"). */
  label: string;
  /** Tooltip va jadvaldagi to'liq nom ("12-sentabr"). */
  fullLabel?: string;
  value: number;
}

/** Konteyner kengligini kuzatadi — chart haqiqiy pikselda chiziladi. */
function useWidth<T extends HTMLElement>() {
  const ref = useRef<T | null>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => {
      if (entry) setWidth(Math.round(entry.contentRect.width));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

/* Chizma o'lchamlari — dataviz qoidalari bo'yicha. */
const BAR_MAX = 24; // ustun hech qachon 24px dan qalin emas
const RADIUS = 4; // faqat ma'lumot uchida; asosi to'g'ri
const TOP_PAD = 10;
const X_AXIS = 26;
const LABEL_MIN_GAP = 46; // x yorliqlari orasidagi eng kam masofa

/** Uchi yumaloq, asosi to'g'ri ustun. */
function barPath(x: number, y: number, w: number, h: number): string {
  if (h <= 0) return '';
  const r = Math.min(RADIUS, w / 2, h);
  const base = y + h;
  return (
    `M${x},${base}V${y + r}Q${x},${y} ${x + r},${y}` +
    `H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${base}Z`
  );
}

/**
 * Ustunli chart — vaqt bo'yicha bitta ko'rsatkich (kunlik tushum,
 * haftalik ro'yxatdan o'tishlar).
 *
 * * SVG haqiqiy pikselda chiziladi (viewBox cho'zilmaydi): ustun
 *   qalinligi va matn o'lchami har ekranda bir xil;
 * * bitta qator — legend yo'q, nimani ko'rsatayotganini sarlavha aytadi;
 * * har bir ustun ustiga kelganda (yoki ←/→ bilan) qiymat chiqadi,
 *   ekran o'quvchi uni jonli hududdan eshitadi;
 * * qiymatlarning to'liq ro'yxati `ChartCard` ning jadval ko'rinishida.
 */
export function BarChart({
  data,
  format,
  formatAxis = compactNumber,
  height = 220,
  label,
  color = 'var(--chart-1)',
}: {
  data: BarDatum[];
  /** Tooltip qiymati: "1 250 000 so'm". */
  format: (value: number) => string;
  /** O'q qiymati — qisqa: "1,3 mln". */
  formatAxis?: (value: number) => string;
  height?: number;
  /** Chart nomi — ekran o'quvchi uchun. */
  label: string;
  color?: string;
}) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [active, setActive] = useState<number | null>(null);

  const max = Math.max(0, ...data.map((d) => d.value));
  const scale = niceTicks(max);
  const tickLabels = scale.ticks.map(formatAxis);

  // Chap maydon eng uzun o'q yozuviga qarab (taxminan 6.4px / belgi).
  const gutter = Math.min(76, Math.max(28, Math.max(...tickLabels.map((t) => t.length)) * 6.4 + 10));
  const plotW = Math.max(0, width - gutter);
  const plotH = height - TOP_PAD - X_AXIS;
  const band = data.length > 0 ? plotW / data.length : 0;
  const barW = Math.max(2, Math.min(BAR_MAX, band * 0.62));

  const y = (v: number) => TOP_PAD + plotH * (1 - v / scale.max);
  const cx = (i: number) => gutter + band * i + band / 2;

  const shownLabels = new Set(
    visibleLabelIndexes(data.length, Math.floor(plotW / LABEL_MIN_GAP)),
  );

  const onKeyDown = (e: KeyboardEvent<SVGSVGElement>) => {
    if (data.length === 0) return;
    const last = data.length - 1;
    const current = active ?? last;
    let next = current;
    if (e.key === 'ArrowRight') next = Math.min(last, current + 1);
    else if (e.key === 'ArrowLeft') next = Math.max(0, current - 1);
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = last;
    else return;
    e.preventDefault();
    setActive(next);
  };

  const activeDatum = active !== null ? data[active] : undefined;
  // Tooltip chetdan chiqib ketmasin.
  const tipX = active !== null ? Math.min(Math.max(cx(active), 70), Math.max(70, width - 70)) : 0;

  return (
    <div ref={ref} className="ui-chart" style={{ height }}>
      {width > 0 && (
        <svg
          className={`ui-chart__plot${active !== null ? ' has-active' : ''}`}
          width={width}
          height={height}
          role="group"
          aria-label={`${label}. Qiymatlarni ko'rish uchun chap va o'ng strelkalardan foydalaning.`}
          tabIndex={0}
          onKeyDown={onKeyDown}
          onFocus={() => setActive((a) => a ?? data.length - 1)}
          onBlur={() => setActive(null)}
          onPointerLeave={() => setActive(null)}
        >
          {/* To'r chiziqlari — ingichka, bir tekis, e'tiborni tortmaydi. */}
          {scale.ticks.map((t, i) => (
            <g key={t}>
              <line className="ui-chart__grid" x1={gutter} x2={width} y1={y(t)} y2={y(t)} />
              <text className="ui-chart__tick" x={gutter - 8} y={y(t)} dy="0.32em" textAnchor="end">
                {tickLabels[i]}
              </text>
            </g>
          ))}

          {data.map((d, i) => {
            const top = y(d.value);
            const h = TOP_PAD + plotH - top;
            return (
              <g key={i}>
                <path
                  className={`ui-chart__bar${active === i ? ' is-active' : ''}`}
                  d={barPath(cx(i) - barW / 2, top, barW, h)}
                  fill={color}
                />
                {shownLabels.has(i) && (
                  <text
                    className="ui-chart__tick"
                    x={cx(i)}
                    y={height - 8}
                    textAnchor="middle"
                  >
                    {d.label}
                  </text>
                )}
                {/* Bosiladigan maydon ustundan KATTA — butun tasma balandligi. */}
                <rect
                  x={gutter + band * i}
                  y={TOP_PAD}
                  width={band}
                  height={plotH}
                  fill="transparent"
                  onPointerEnter={() => setActive(i)}
                  onPointerDown={() => setActive(i)}
                />
              </g>
            );
          })}
        </svg>
      )}

      {activeDatum && active !== null && (
        <div className="ui-chart__tip" style={{ left: tipX, top: Math.max(y(activeDatum.value), 40) }}>
          <span className="ui-chart__tip-value">{format(activeDatum.value)}</span>
          <span className="ui-chart__tip-label">{activeDatum.fullLabel ?? activeDatum.label}</span>
        </div>
      )}

      <div className="ui-sr-only" aria-live="polite">
        {activeDatum ? `${activeDatum.fullLabel ?? activeDatum.label}: ${format(activeDatum.value)}` : ''}
      </div>
    </div>
  );
}
