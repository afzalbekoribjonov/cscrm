/**
 * Ilova ko'rinishining sxematik maketi.
 *
 * Nega chizma, haqiqiy skrinshot emas: skrinshotda mijozning haqiqiy
 * buyurtmalari, ismlari va telefon raqamlari bo'ladi. Chizma esa hech
 * kimning ma'lumotini oshkor qilmaydi, har doim toza ko'rinadi va
 * mavzu (kunduzgi/tungi) bilan birga o'zgaradi.
 *
 * Barcha ranglar CSS o'zgaruvchilaridan olinadi — sayt mavzusi
 * almashsa, maket ham u bilan birga almashadi.
 */
export function AppMockup() {
  return (
    <div
      style={{
        position: 'relative',
        display: 'grid',
        placeItems: 'center',
        padding: '8px 0',
      }}
    >
      <svg
        viewBox="0 0 320 620"
        style={{
          width: '100%',
          maxWidth: 300,
          filter: 'drop-shadow(0 24px 48px rgb(13 22 38 / 0.22))',
        }}
        role="img"
        aria-label="CSCRM ilovasining ko'rinishi: yuvish bo'limi, ko'rsatkichlar va buyurtma kartalari"
      >
        {/* Telefon korpusi */}
        <rect
          x="4"
          y="4"
          width="312"
          height="612"
          rx="42"
          fill="var(--surface)"
          stroke="var(--border-strong)"
          strokeWidth="2"
        />
        {/* Ekran */}
        <rect x="14" y="14" width="292" height="592" rx="34" fill="var(--bg)" />

        {/* Yuqori panel */}
        <rect x="14" y="14" width="292" height="76" rx="34" fill="var(--brand)" />
        <rect x="14" y="60" width="292" height="30" fill="var(--brand)" />
        <text
          x="36"
          y="58"
          fill="#fff"
          fontSize="17"
          fontWeight="800"
          fontFamily="system-ui, sans-serif"
        >
          Yuvish
        </text>
        {/* Qo'ng'iroq */}
        <circle cx="248" cy="52" r="13" fill="rgb(255 255 255 / 0.18)" />
        <path
          d="M248 46.5a4.5 4.5 0 0 0-4.5 4.5v3l-1 1.7h11l-1-1.7v-3a4.5 4.5 0 0 0-4.5-4.5Z"
          fill="#fff"
        />
        <circle cx="254" cy="45" r="4" fill="var(--accent)" />
        {/* Chiqish */}
        <circle cx="280" cy="52" r="13" fill="rgb(255 255 255 / 0.18)" />

        {/* Ko'rsatkich kartalari — 2x2 */}
        {[
          { x: 26, y: 106, c: 'var(--brand)', w: 60 },
          { x: 166, y: 106, c: 'var(--danger)', w: 44 },
          { x: 26, y: 168, c: 'var(--warning)', w: 52 },
          { x: 166, y: 168, c: 'var(--brand-light)', w: 48 },
        ].map((s) => (
          <g key={`${s.x}-${s.y}`}>
            <rect
              x={s.x}
              y={s.y}
              width="128"
              height="52"
              rx="13"
              fill="var(--surface)"
              stroke="var(--border)"
            />
            <rect
              x={s.x + 11}
              y={s.y + 15}
              width="22"
              height="22"
              rx="7"
              fill={s.c}
              opacity="0.16"
            />
            <circle cx={s.x + 22} cy={s.y + 26} r="5" fill={s.c} />
            <rect
              x={s.x + 42}
              y={s.y + 14}
              width="34"
              height="10"
              rx="5"
              fill="var(--text)"
              opacity="0.82"
            />
            <rect
              x={s.x + 42}
              y={s.y + 30}
              width={s.w}
              height="7"
              rx="3.5"
              fill="var(--text-muted)"
              opacity="0.5"
            />
          </g>
        ))}

        {/* Buyurtma kartalari */}
        {[
          { y: 238, badge: 'var(--brand-light)', w: 96 },
          { y: 350, badge: 'var(--warning)', w: 120 },
          { y: 462, badge: 'var(--success)', w: 84 },
        ].map((card) => (
          <g key={card.y}>
            <rect
              x="26"
              y={card.y}
              width="268"
              height="98"
              rx="16"
              fill="var(--surface)"
              stroke="var(--border)"
            />
            {/* Buyurtma raqami */}
            <rect
              x="42"
              y={card.y + 18}
              width="42"
              height="20"
              rx="7"
              fill="var(--brand)"
              opacity="0.13"
            />
            <rect
              x="50"
              y={card.y + 25}
              width="26"
              height="7"
              rx="3.5"
              fill="var(--brand)"
            />
            {/* Mijoz ismi */}
            <rect
              x="94"
              y={card.y + 22}
              width={card.w}
              height="11"
              rx="5.5"
              fill="var(--text)"
              opacity="0.8"
            />
            {/* Holat belgisi */}
            <rect
              x="222"
              y={card.y + 18}
              width="56"
              height="20"
              rx="10"
              fill={card.badge}
              opacity="0.18"
            />
            <rect
              x="232"
              y={card.y + 25}
              width="36"
              height="6"
              rx="3"
              fill={card.badge}
            />
            {/* Xizmat qatorlari */}
            <rect
              x="42"
              y={card.y + 52}
              width="150"
              height="8"
              rx="4"
              fill="var(--text-muted)"
              opacity="0.4"
            />
            <rect
              x="42"
              y={card.y + 70}
              width="104"
              height="8"
              rx="4"
              fill="var(--text-muted)"
              opacity="0.28"
            />
            {/* Narx */}
            <rect
              x="222"
              y={card.y + 66}
              width="56"
              height="12"
              rx="6"
              fill="var(--success)"
              opacity="0.75"
            />
          </g>
        ))}

        {/* Pastki menyu */}
        <rect
          x="14"
          y="562"
          width="292"
          height="44"
          fill="var(--surface)"
          stroke="var(--border)"
        />
        {[52, 122, 192, 262].map((cx, i) => (
          <g key={cx}>
            <circle
              cx={cx}
              cy="578"
              r="8"
              fill={i === 1 ? 'var(--brand)' : 'var(--text-muted)'}
              opacity={i === 1 ? 1 : 0.35}
            />
            <rect
              x={cx - 14}
              y="592"
              width="28"
              height="5"
              rx="2.5"
              fill={i === 1 ? 'var(--brand)' : 'var(--text-muted)'}
              opacity={i === 1 ? 0.9 : 0.3}
            />
          </g>
        ))}
      </svg>
    </div>
  );
}
