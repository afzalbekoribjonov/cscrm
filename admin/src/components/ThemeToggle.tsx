import { Icon } from './Icon';
import { useTheme } from '@/lib/theme';

/**
 * Kun/tun tugmasi.
 *
 * Ikonka JORIY holatni emas, bosilganda NIMA BO'LISHINI ko'rsatadi:
 * kunduzgi rejimda oy tasviri turadi ("bosang tun bo'ladi"). Bu
 * tarqalgan tartib — teskarisi foydalanuvchini chalkashtiradi.
 */
export function ThemeToggle() {
  const { theme, toggle } = useTheme();
  const next = theme === 'dark' ? 'kunduzgi' : 'tungi';

  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={toggle}
      // Ko'zi ojiz foydalanuvchi uchun: ikonka o'zi hech nima
      // demaydi, shuning uchun harakat matn bilan aytiladi.
      aria-label={`${next} rejimga o'tish`}
      title={`${next} rejim`}
    >
      <Icon name={theme === 'dark' ? 'sun' : 'moon'} size={19} />
    </button>
  );
}
