import { StatusBar } from './charts/StatusBar';
import { TrendChart, type TrendPoint } from './charts/TrendChart';
import { formatNumber } from '@/lib/format';

/**
 * "Hisobotlar" bo'limi — ilovadagi hisobot ekranining sayt uchun
 * tayyorlangan ko'rinishi.
 *
 * Ma'lumot o'ylab topilgan (namuna), lekin shakli ilovadagi bilan bir
 * xil: haqiqiy mijoz ismlari va summalari saytda ko'rinmasligi kerak.
 */

/** So'nggi ikki hafta daromadi (namuna). */
const INCOME: TrendPoint[] = [
  { label: '1-sen', value: 1840000 },
  { label: '2-sen', value: 2120000 },
  { label: '3-sen', value: 1960000 },
  { label: '4-sen', value: 2480000 },
  { label: '5-sen', value: 2310000 },
  { label: '6-sen', value: 3040000 },
  { label: '7-sen', value: 2760000 },
  { label: '8-sen', value: 2180000 },
  { label: '9-sen', value: 2520000 },
  { label: '10-sen', value: 2890000 },
  { label: '11-sen', value: 2640000 },
  { label: '12-sen', value: 3180000 },
  { label: '13-sen', value: 3420000 },
  { label: '14-sen', value: 2840000 },
];

const STATUS = [
  { label: 'Qabul qilindi', value: 12, color: 'var(--chart-1)' },
  { label: 'Yuvishda', value: 26, color: 'var(--chart-2)' },
  { label: 'Qadoqlashda', value: 9, color: 'var(--chart-3)' },
  { label: 'Yetgazishda', value: 7, color: 'var(--chart-4)' },
];

/** Uzun summalarni qisqartiradi: 2 840 000 -> "2,84 mln". */
function short(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2).replace('.', ',')} mln`;
  return formatNumber(n);
}

export function ReportsPreview() {
  return (
    <div style={{ display: 'grid', gap: 14 }}>
      <div className="kpi-row">
        <StatTile
          label="Bugungi daromad"
          value={`${formatNumber(2840000)} so'm`}
          delta="18%"
          dir="up"
          good
        />
        <StatTile label="Faol buyurtma" value="54 ta" delta="6" dir="up" good />
        {/* Qarzdorlik KAMAYGAN — ya'ni o'q pastga, rang esa yashil.
            Yo'nalish va baho ikki boshqa narsa: qarz kamaysa bu yaxshi
            xabar, lekin ko'rsatkich baribir pastga tushgan. Ilgari
            bu yerda pastga tushish yuqoriga o'q bilan ko'rsatilgan
            edi — qarama-qarshi ishora. */}
        <StatTile
          label="Qarzdorlik"
          value={`${formatNumber(180000)} so'm`}
          delta="24%"
          dir="down"
          good
        />
      </div>

      <div className="chart-card">
        <div className="chart-card__head">
          <div>
            <h3 className="chart-card__title">Kunlik daromad</h3>
            <p className="chart-card__sub">So&apos;nggi 14 kun</p>
          </div>
        </div>
        <TrendChart points={INCOME} format={(v) => `${short(v)} so'm`} />
      </div>

      <div className="chart-card">
        <div className="chart-card__head">
          <div>
            <h3 className="chart-card__title">Buyurtmalar qayerda</h3>
            <p className="chart-card__sub">Hozirgi holat, 54 ta faol buyurtma</p>
          </div>
        </div>
        <StatusBar segments={STATUS} totalLabel="faol buyurtma" />
      </div>
    </div>
  );
}

/**
 * Ko'rsatkich plitkasi.
 *
 * `dir` — ko'rsatkich qayoqqa o'zgargani (o'q shakli).
 * `good` — bu o'zgarish yaxshimi (rang).
 *
 * Ikkovi ATAYLAB ajratilgan: qarzdorlik kamaysa o'q pastga tushadi,
 * lekin bu yaxshi xabar. Bitta bayroq bilan ifodalansa, ulardan biri
 * doim yolg'on chiqardi.
 */
function StatTile({
  label,
  value,
  delta,
  dir,
  good,
}: {
  label: string;
  value: string;
  delta: string;
  dir: 'up' | 'down';
  good: boolean;
}) {
  return (
    <div className="stat-tile">
      <div className="stat-tile__label">{label}</div>
      <div className="stat-tile__value">{value}</div>
      <span
        className={`stat-tile__delta stat-tile__delta--${good ? 'up' : 'down'}`}
      >
        {/* Rang yolg'iz ma'no tashimasin — o'q belgisi ham qo'yiladi. */}
        {dir === 'up' ? '▲' : '▼'} {delta}
      </span>
    </div>
  );
}
