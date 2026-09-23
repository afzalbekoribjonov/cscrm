import type { MutableRefObject, Ref } from 'react';

/**
 * Bir nechta ref'ni bittaga birlashtiradi.
 *
 * Kerak bo'lgan joy: `Tooltip` tugmaga o'z ref'ini qo'yadi, lekin
 * tugmaning egasi ham unga ref bergan bo'lishi mumkin (menyu shu
 * orqali joyini hisoblaydi va fokusni qaytaradi). Biri ikkinchisini
 * almashtirib yubormasligi kerak.
 */
export function mergeRefs<T>(...refs: (Ref<T> | undefined)[]): (node: T | null) => void {
  return (node) => {
    for (const ref of refs) {
      if (!ref) continue;
      if (typeof ref === 'function') ref(node);
      else (ref as MutableRefObject<T | null>).current = node;
    }
  };
}
