/**
 * CSCRM nishoni — mobil ilovadagi vektor nishon bilan bir xil geometriya
 * (app/lib/branding/logo.dart va tools/generate_icons.py).
 */
export function Logo({ size = 40 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 512 512"
      role="img"
      aria-label="CSCRM"
      style={{ flexShrink: 0 }}
    >
      <defs>
        <linearGradient id="cscrm-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#0B5FFF" />
          <stop offset="1" stopColor="#00C2FF" />
        </linearGradient>
        <mask id="cscrm-cut">
          <rect width="512" height="512" fill="#fff" />
          <path
            d="M223 315l10-25 25-10-25-10-10-25-10 25-25 10 25 10z"
            fill="#000"
          />
          <path
            d="M310 243l6-15 15-6-15-6-6-15-6 15-15 6 15 6z"
            fill="#000"
          />
        </mask>
      </defs>
      <rect width="512" height="512" rx="115" fill="url(#cscrm-bg)" />
      <path
        d="M256 108c58 74 88 122 88 158a88 88 0 1 1-176 0c0-36 30-84 88-158z"
        fill="#fff"
        mask="url(#cscrm-cut)"
      />
    </svg>
  );
}

export function Wordmark({ size = 36 }: { size?: number }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 10,
        fontWeight: 800,
        fontSize: size * 0.5,
        letterSpacing: '0.02em',
        color: 'var(--text)',
      }}
    >
      <Logo size={size} />
      CSCRM
    </span>
  );
}
