import { useId, useState } from 'react';

export type TrendPoint = { label: string; value: number };

type TrendChartProps = {
  points: TrendPoint[];
  /** Qiymatni odam o'qiydigan ko'rinishga o'tkazadi (masalan "1,2 mln"). */
  format: (value: number) => string;
  /** Chiziq rangi — CSS o'zgaruvchisi nomi. */
  color?: string;
  height?: number;
};

/* SVG ichki koordinata tizimi. Chart kengligi ekranga moslashadi, bu
   raqamlar esa o'zgarmaydi — nisbatlar shu to'rda hisoblanadi. */
const W = 600;
const PAD_TOP = 12;
const PAD_BOTTOM = 6;

/**
 * Vaqt bo'yicha o'zgarish — bitta qatorli chiziq va uning ostidagi
 * yengil to'ldirish.
 *
 * Bitta qator uchun ATAYLAB kategoriya ranglari ishlatilmaydi va
 * izohlar (legend) ham chizilmaydi: sarlavha nimani ko'rsatayotganini
 * aytib turibdi, ikkinchi rang esa "bu boshqa narsa" degan yolg'on
 * ishorani berardi.
 *
 * Matn SVG ICHIDA emas, ostidagi HTML'da: SVG kengayganda ichidagi
 * harflar ham cho'ziladi va turli ekranda turli o'lchamda chiqadi.
 */
export function TrendChart({
  points,
  format,
  color = 'var(--chart-1)',
  height = 190,
}: TrendChartProps) {
  const gradientId = useId();
  const [hover, setHover] = useState<number | null>(null);

  const H = height;
  const values = points.map((p) => p.value);
  const max = Math.max(...values);
  // Pastki chegara noldan emas, eng kichik qiymatdan sal pastdan
  // boshlanadi — aks holda o'zgarish tekis chiziqday ko'rinib qolardi.
  const min = Math.min(...values);
  const lo = Math.max(0, min - (max - min) * 0.6);
  const span = max - lo || 1;

  const x = (i: number) => (i / (points.length - 1)) * W;
  const y = (v: number) =>
    PAD_TOP + (1 - (v - lo) / span) * (H - PAD_TOP - PAD_BOTTOM);

  const line = points.map((p, i) => `${i ? 'L' : 'M'}${x(i)},${y(p.value)}`).join(' ');
  const area = `${line} L${W},${H} L0,${H} Z`;

  const last = points.length - 1;
  const active = hover ?? last;
  // `active` har doim [0, last] oralig'ida, lekin TypeScript buni
  // isbotlay olmaydi — indeks bo'yicha o'qish uning uchun doim
  // "bo'lmasligi ham mumkin". Bir joyda hal qilinadi, pastda esa
  // toza qiymat ishlatiladi.
  const activePoint = points[active] ?? points[last]!;

  /** Sichqoncha (yoki barmoq) qaysi kunning ustida turganini topadi. */
  function onMove(e: React.PointerEvent<HTMLDivElement>) {
    const box = e.currentTarget.getBoundingClientRect();
    const ratio = (e.clientX - box.left) / box.width;
    const i = Math.round(ratio * last);
    setHover(Math.min(last, Math.max(0, i)));
  }

  return (
    <div>
      <div
        className="chart-plot"
        style={{ height }}
        onPointerMove={onMove}
        onPointerLeave={() => setHover(null)}
      >
        <svg
          viewBox={`0 0 ${W} ${H}`}
          preserveAspectRatio="none"
          // Balandlik CSS orqali QAT'IY beriladi.
          //
          // `height` atributi yetarli emas: umumiy uslublarda
          // `svg { height: auto }` turadi va u atributni bosib
          // ketadi — SVG o'z nisbatini saqlab, konteynerdan
          // balandroq chiziladi. Natijada SVG ichidagi Y va ustidagi
          // HTML elementlarning Y'i bir-biriga to'g'ri kelmay
          // qoladi: belgi doirasi chiziqdan ajralib turadi.
          style={{ display: 'block', width: '100%', height: `${H}px` }}
          role="img"
          aria-label={`Kunlik daromad, ${points.length} kun. Eng yuqori: ${format(max)}.`}
        >
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity="0.22" />
              <stop offset="100%" stopColor={color} stopOpacity="0" />
            </linearGradient>
          </defs>

          {/* To'r chiziqlari — uzuq-yuluq EMAS, yaxlit va fondan bir
              pog'ona quyuqroq. Uzuq chiziq "chegara" degan ma'noni
              beradi, bu yerda esa u shunchaki o'lchov. */}
          {[0.25, 0.5, 0.75].map((t) => (
            <line
              key={t}
              x1="0"
              x2={W}
              y1={PAD_TOP + t * (H - PAD_TOP - PAD_BOTTOM)}
              y2={PAD_TOP + t * (H - PAD_TOP - PAD_BOTTOM)}
              stroke="var(--chart-grid)"
              strokeWidth="1"
              vectorEffect="non-scaling-stroke"
            />
          ))}

          <path d={area} fill={`url(#${gradientId})`} />
          <path
            d={line}
            fill="none"
            stroke={color}
            strokeWidth="2"
            strokeLinejoin="round"
            strokeLinecap="round"
            // Busiz chiziq SVG kengayganda yo'g'onlashib ketardi:
            // `preserveAspectRatio="none"` koordinatalar bilan birga
            // chiziq qalinligini ham cho'zadi.
            vectorEffect="non-scaling-stroke"
          />

          {hover !== null && (
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={PAD_TOP}
              y2={H}
              stroke="var(--border-strong)"
              strokeWidth="1"
              vectorEffect="non-scaling-stroke"
            />
          )}

        </svg>

        {/* Belgi doirasi SVG ICHIDA emas, ustidagi HTML'da.
            Sababi: `preserveAspectRatio="none"` SVG'ni faqat eniga
            cho'zadi — ichidagi doira ham cho'zilib, ovalga aylanardi.
            HTML elementi esa qanday bo'lsa shunday qoladi.
            Oq halqa — chiziq ustida turganda unga qo'shilib
            ketmasligi uchun. */}
        <span
          style={{
            position: 'absolute',
            left: `${(active / last) * 100}%`,
            top: `${y(activePoint.value)}px`,
            width: 10,
            height: 10,
            marginLeft: -5,
            marginTop: -5,
            borderRadius: '50%',
            background: color,
            boxShadow: '0 0 0 2px var(--surface)',
            pointerEvents: 'none',
          }}
        />

        {/* Izoh qutisi markazi belgida turadi, lekin chekkalarda u
            chartdan chiqib ketardi — shuning uchun chetga yaqinlashgan
            joyda o'rni cheklab qo'yiladi. */}
        <div
          className="chart-tip"
          style={{
            left: `${Math.min(88, Math.max(12, (active / last) * 100))}%`,
            top: `${y(activePoint.value)}px`,
          }}
        >
          <div className="chart-tip__label">{activePoint.label}</div>
          <div className="chart-tip__value">{format(activePoint.value)}</div>
        </div>
      </div>

      <div className="chart-axis">
        <span>{points[0]?.label}</span>
        <span>{points[Math.floor(last / 2)]?.label}</span>
        <span>{points[last]?.label}</span>
      </div>
    </div>
  );
}
