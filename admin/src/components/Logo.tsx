/**
 * CS CRM logotipi — faqat matn, tasvirsiz.
 *
 * Mobil ilovadagi nusxasi: `app/lib/branding/logo.dart`. Ikkalasi bir xil
 * bo'lishi kerak: ranglar, nisbatlar va harflar orasidagi oraliq.
 *
 * NEGA FON QUYUQ KO'K. "CS" qizil, "CRM" oq. Qizil rang brendning
 * yorqin ko'ki (#0B5FFF) ustida O'QILMAYDI — kontrast atigi 1,57:1
 * (o'qilishi uchun kamida 3:1 kerak). Quyuqroq ko'k (#0B2E77) da esa
 * qizil 3,84:1, oq 12,56:1 ga chiqadi.
 *
 * Plashka HAR DOIM bor — oq fonda ham, qora fonda ham. Shu sababli
 * logotip saytda, ilovada va ilova ikonkasida bir xil ko'rinadi.
 */

const BADGE = '#0B2E77';
const CS = '#FF4D4D';

/** Kvadrat nishon: "CS" tepada, "CRM" pastda. */
export function Logo({ size = 44 }: { size?: number }) {
  return (
    <span
      aria-label="CS CRM"
      role="img"
      style={{
        display: 'inline-flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        width: size,
        height: size,
        flexShrink: 0,
        background: BADGE,
        borderRadius: size * 0.225,
        // Harflar logotipga o'xshashi uchun oraliq siqiladi va
        // qator balandligi harflarning o'ziga qisqartiriladi.
        lineHeight: 0.86,
        letterSpacing: '-0.035em',
        fontWeight: 900,
      }}
    >
      <span style={{ color: CS, fontSize: size * 0.34 }}>CS</span>
      <span style={{ color: '#fff', fontSize: size * 0.245 }}>CRM</span>
    </span>
  );
}

/** Gorizontal so'z belgisi: bitta qatorda "CS CRM". */
export function Wordmark({ size = 34 }: { size?: number }) {
  const fontSize = size * 0.46;

  return (
    <span
      aria-label="CS CRM"
      role="img"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        height: size,
        padding: `0 ${size * 0.3}px`,
        background: BADGE,
        borderRadius: size * 0.26,
        fontWeight: 900,
        fontSize,
        lineHeight: 1,
        letterSpacing: '-0.035em',
        whiteSpace: 'nowrap',
      }}
    >
      <span style={{ color: CS }}>CS</span>
      <span style={{ width: fontSize * 0.22, display: 'inline-block' }} />
      <span style={{ color: '#fff' }}>CRM</span>
    </span>
  );
}
