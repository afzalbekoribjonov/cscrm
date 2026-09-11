export type StatusSegment = { label: string; value: number; color: string };

type StatusBarProps = {
  segments: StatusSegment[];
  /** Barcha bo'laklar yig'indisining nomi — masalan "faol buyurtma". */
  totalLabel: string;
};

/**
 * Butunning bo'laklari — bitta gorizontal yig'ma ustun.
 *
 * NEGA DOIRA (donut) EMAS: doirada bo'laklarning kattaligini burchak
 * bo'yicha chamalash kerak, odam buni yomon uddalaydi. Bir chiziqqa
 * tizilgan bo'laklar esa uzunligi bilan taqqoslanadi — bu ancha aniq
 * va joyni ham kamroq egallaydi.
 *
 * Har bir bo'lakda raqam YOZILADI (sig'sa — ichida). Bu shunchaki
 * bezak emas: yorug' rejimda ba'zi ranglar oq fon bilan kontrasti
 * pastroq, matn esa rangni ko'rmaydigan yoki ajrata olmaydigan
 * foydalanuvchi uchun ikkinchi, ishonchli belgi bo'lib xizmat qiladi.
 */
export function StatusBar({ segments, totalLabel }: StatusBarProps) {
  const total = segments.reduce((sum, s) => sum + s.value, 0) || 1;

  return (
    <div>
      <div
        className="stack-bar"
        role="img"
        aria-label={`${total} ${totalLabel}: ${segments
          .map((s) => `${s.label} ${s.value}`)
          .join(', ')}`}
      >
        {segments.map((s) => {
          const share = (s.value / total) * 100;
          return (
            <div
              key={s.label}
              className="stack-bar__seg"
              style={{ width: `${share}%`, background: s.color }}
            >
              {/* Raqam faqat SIG'SA yoziladi. Tor bo'lakka tiqilgan
                  matn qirqilib, yarim harf bo'lib ko'rinardi — u holda
                  raqam pastdagi izohlar qatorida qoladi. */}
              {share >= 12 && s.value}
            </div>
          );
        })}
      </div>

      <div className="chart-legend">
        {segments.map((s) => (
          <span key={s.label} className="chart-legend__item">
            <span
              className="chart-legend__swatch"
              style={{ background: s.color }}
            />
            {s.label}
            <span className="chart-legend__value">{s.value}</span>
          </span>
        ))}
      </div>
    </div>
  );
}
