/**
 * Ikonkalar to'plami.
 *
 * Emoji ATAYLAB ishlatilmaydi: u har qurilmada boshqacha chiziladi
 * (Windows, Android va iPhone'da uch xil ko'rinish), rangini brendga
 * moslab bo'lmaydi va o'lchami matn bilan birga sakraydi. SVG esa
 * hamma joyda bir xil va joriy rangni oladi.
 */

type IconProps = {
  name: IconName;
  size?: number;
  strokeWidth?: number;
};

export type IconName =
  | 'orders'
  | 'people'
  | 'money'
  | 'phone'
  | 'bell'
  | 'shield'
  | 'clock'
  | 'chart'
  | 'check'
  | 'offline'
  | 'menu'
  | 'close';

/** Har bir ikonka — 24x24 to'rda, faqat chiziqlar (stroke). */
const PATHS: Record<IconName, React.ReactNode> = {
  orders: (
    <>
      <path d="M8 4h8a2 2 0 0 1 2 2v13a1 1 0 0 1-1.5.9L12 18l-4.5 1.9A1 1 0 0 1 6 19V6a2 2 0 0 1 2-2Z" />
      <path d="M9 9h6M9 13h4" />
    </>
  ),
  people: (
    <>
      <circle cx="9" cy="8" r="3" />
      <path d="M3 20a6 6 0 0 1 12 0" />
      <path d="M16 6.5a3 3 0 0 1 0 5.8M17 20a6 6 0 0 0-1.6-4" />
    </>
  ),
  money: (
    <>
      <rect x="2.5" y="6" width="19" height="12" rx="2.5" />
      <circle cx="12" cy="12" r="2.6" />
      <path d="M6 10v4M18 10v4" />
    </>
  ),
  phone: (
    <>
      <rect x="6.5" y="2.5" width="11" height="19" rx="2.5" />
      <path d="M10.5 18.5h3" />
    </>
  ),
  bell: (
    <>
      <path d="M18 15V10a6 6 0 1 0-12 0v5l-1.5 2.5h15L18 15Z" />
      <path d="M10 19.5a2 2 0 0 0 4 0" />
    </>
  ),
  shield: (
    <>
      <path d="M12 2.5 4.5 5.5v6c0 4.6 3.1 8.5 7.5 10 4.4-1.5 7.5-5.4 7.5-10v-6L12 2.5Z" />
      <path d="m9 12 2.2 2.2L15.5 10" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5.2l3.2 2" />
    </>
  ),
  chart: (
    <>
      <path d="M3.5 20.5h17" />
      <path d="M7 20.5V13M12 20.5V6.5M17 20.5v-5" />
    </>
  ),
  check: <path d="m5 12.5 4.5 4.5L19 7.5" />,
  offline: (
    <>
      <path d="M5 12.5a9.5 9.5 0 0 1 14 0" />
      <path d="M8.5 16a5 5 0 0 1 7 0" />
      <circle cx="12" cy="19.5" r="0.6" fill="currentColor" />
      <path d="M3 3l18 18" />
    </>
  ),
  menu: <path d="M4 7h16M4 12h16M4 17h16" />,
  close: <path d="M6 6l12 12M18 6 6 18" />,
};

export function Icon({ name, size = 22, strokeWidth = 1.8 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {PATHS[name]}
    </svg>
  );
}
