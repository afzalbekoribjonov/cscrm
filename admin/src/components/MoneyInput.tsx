import { useLayoutEffect, useRef, type CSSProperties } from 'react';

import { formatNumber } from '@/lib/format';

/** Eng uzun summa — 12 xona (999 milliard). */
const MAX_DIGITS = 12;

/**
 * Faqat raqamlarni qoldiradi va qiymatni bir ko'rinishga keltiradi.
 *
 * Boshidagi nollar olib tashlanadi. Busiz saqlangan qiymat ("05")
 * bilan ekrandagi ("5") bir-biridan farq qilib ketardi: `Number()`
 * nolni yo'qotadi, qiymat esa xom holda uzatilaveradi.
 */
function normalize(text: string): string {
  const digits = text.replace(/\D/g, '').slice(0, MAX_DIGITS);
  return digits.replace(/^0+(?=\d)/, '');
}

/**
 * Summa kiritish maydoni — raqamlarni uchtalab ajratib ko'rsatadi.
 *
 * NEGA `type="number"` EMAS. Brauzerning raqam maydoni qiymatni xom
 * holda ko'rsatadi: "537000". Olti xonadan boshlab bunday raqamni
 * o'qish qiyin — "537000" bilan "53700" ni bir qarashda ajratib
 * bo'lmaydi va narx belgilashda bu qimmatga tushadi.
 *
 * `inputMode="numeric"` telefonda baribir raqamli klaviaturani
 * ochadi, ya'ni hech narsa yo'qotilmaydi.
 */
export function MoneyInput({
  value,
  onChange,
  style,
  id,
  placeholder,
}: {
  /** Faqat raqamlardan iborat qiymat, masalan "537000". */
  value: string;
  onChange: (digits: string) => void;
  style?: CSSProperties;
  id?: string;
  placeholder?: string;
}) {
  const ref = useRef<HTMLInputElement>(null);

  /** Kursor qaysi raqamdan keyin turishi kerak. */
  const caretDigits = useRef<number | null>(null);

  // Kursorni qayta chizishdan KEYIN qo'yamiz.
  //
  // React maydon matnini almashtirganda kursorni oxiriga tashlaydi.
  // Busiz o'rtaga raqam yozib bo'lmasdi: har bir belgidan keyin
  // kursor oxirga sakrardi.
  useLayoutEffect(() => {
    const input = ref.current;
    const digits = caretDigits.current;
    if (!input || digits === null) return;
    caretDigits.current = null;

    const text = input.value;
    let seen = 0;
    let offset = text.length;
    for (let i = 0; i < text.length; i++) {
      if (seen === digits) {
        offset = i;
        break;
      }
      const ch = text[i] ?? '';
      if (ch >= '0' && ch <= '9') seen++;
    }
    input.setSelectionRange(offset, offset);
  });

  return (
    <input
      id={id}
      ref={ref}
      type="text"
      inputMode="numeric"
      placeholder={placeholder}
      value={value === '' ? '' : formatNumber(Number(value))}
      onChange={(e) => {
        const typed = e.target.value;
        const next = normalize(typed);

        // Kursor sanoqdagi raqamlar bo'yicha eslab qolinadi, belgi
        // o'rni bo'yicha emas: qayta chizilgandan keyin bo'sh joylar
        // boshqa joyga tushishi mumkin.
        const caret = e.target.selectionStart ?? typed.length;
        const before = typed.slice(0, caret).replace(/\D/g, '').length;

        // Chegaradan oshgan yoki tashlab yuborilgan nollar hisobga
        // olinadi, aks holda kursor bor-yo'q raqamdan keyin turardi.
        const dropped = typed.replace(/\D/g, '').length - next.length;
        caretDigits.current = Math.max(0, before - dropped);

        onChange(next);
      }}
      style={style}
    />
  );
}
