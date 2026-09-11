import { useState } from 'react';

import { formatNumber } from '@/lib/format';

/**
 * Taxminiy yo'qotish kalkulyatori.
 *
 * HALOLLIK HAQIDA. Bu hisob "CSCRM sizga shuncha pul olib keladi"
 * degan VA'DA EMAS va biz uni shunday ko'rsatmaymiz. Yo'qotish ulushi
 * — biz o'ylab topgan raqam emas, foydalanuvchining O'ZI qo'yadigan
 * taxmin: uchinchi slayder aynan shuning uchun bor. Har bir biznesda
 * bu ko'rsatkich boshqacha, shuning uchun uni qotirib qo'yish
 * to'g'ri bo'lmasdi.
 *
 * Natija ostidagi izohda ham shu ochiq aytiladi.
 */

const YEAR_PRICE = 1790000; // 1 yillik reja narxi, shared/plans.json

export function SavingsCalculator() {
  const [perDay, setPerDay] = useState(20);
  const [check, setCheck] = useState(180000);
  const [lossPct, setLossPct] = useState(3);

  const yearly = perDay * 365 * check;
  const loss = Math.round((yearly * lossPct) / 100);

  // Ikki ustunning balandligi kattarog'iga nisbatan hisoblanadi —
  // shunda taqqoslash ko'z bilan darhol o'qiladi.
  const scale = Math.max(loss, YEAR_PRICE);

  return (
    <div className="calc">
      <div>
        <Field
          label="Kuniga nechta buyurtma"
          value={`${perDay} ta`}
          min={3}
          max={120}
          step={1}
          current={perDay}
          onChange={setPerDay}
        />
        <Field
          label="O'rtacha buyurtma summasi"
          value={`${formatNumber(check)} so'm`}
          min={40000}
          max={600000}
          step={10000}
          current={check}
          onChange={setCheck}
        />
        <Field
          label="Yig'ilmay qoladigan ulush"
          value={`${lossPct}%`}
          min={0}
          max={10}
          step={1}
          current={lossPct}
          onChange={setLossPct}
          hint="Unutilgan qarz, yozilmay qolgan buyurtma, noto'g'ri hisoblangan o'lcham"
        />
      </div>

      <div className="calc__result">
        <div className="stat-tile__label">Yillik aylanma</div>
        <div style={{ fontWeight: 800, fontSize: '1.2rem', marginBottom: 18 }}>
          {formatNumber(yearly)} so&apos;m
        </div>

        <div className="stat-tile__label">Yiliga taxminan yo&apos;qoladi</div>
        <div className="calc__big">{formatNumber(loss)} so&apos;m</div>

        <div style={{ display: 'grid', gap: 12, marginTop: 22 }}>
          <CompareBar
            label="Taxminiy yillik yo'qotish"
            value={loss}
            scale={scale}
            color="var(--chart-2)"
          />
          <CompareBar
            label="CSCRM — 1 yillik reja"
            value={YEAR_PRICE}
            scale={scale}
            color="var(--chart-1)"
          />
        </div>

        <p className="calc__note">
          Bu <strong>taxminiy hisob</strong>, va&apos;da emas. Yo&apos;qotish
          ulushini siz o&apos;zingiz belgilaysiz — haqiqiy raqam har bir
          biznesda boshqacha bo&apos;ladi.
        </p>
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  min,
  max,
  step,
  current,
  onChange,
  hint,
}: {
  label: string;
  value: string;
  min: number;
  max: number;
  step: number;
  current: number;
  onChange: (n: number) => void;
  hint?: string;
}) {
  return (
    <div className="calc__field">
      <label>
        {label}
        <output>{value}</output>
      </label>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={current}
        onChange={(e) => onChange(Number(e.target.value))}
        // Slayderning o'zi faqat raqamni aytadi; nima haqidaligini
        // yonidagi yozuv aytadi, shuning uchun u bog'lanadi.
        aria-label={label}
        aria-valuetext={value}
      />
      {hint && (
        <p className="muted" style={{ fontSize: '0.8rem', margin: '2px 0 0' }}>
          {hint}
        </p>
      )}
    </div>
  );
}

/** Ikki summani yonma-yon taqqoslash uchun oddiy ustun. */
function CompareBar({
  label,
  value,
  scale,
  color,
}: {
  label: string;
  value: number;
  scale: number;
  color: string;
}) {
  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          gap: 10,
          fontSize: '0.84rem',
          marginBottom: 5,
        }}
      >
        <span className="muted">{label}</span>
        <strong style={{ fontVariantNumeric: 'tabular-nums' }}>
          {formatNumber(value)}
        </strong>
      </div>
      <div
        style={{
          height: 10,
          borderRadius: 5,
          background: 'var(--surface-muted)',
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            width: `${Math.max(2, (value / scale) * 100)}%`,
            height: '100%',
            borderRadius: 5,
            background: color,
            transition: 'width 0.25s ease',
          }}
        />
      </div>
    </div>
  );
}
