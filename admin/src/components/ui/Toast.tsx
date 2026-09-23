import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';

import { Icon, type IconName } from '../Icon';
import { IconButton } from './IconButton';
import { cx } from './logic';

type ToastTone = 'success' | 'danger' | 'warning' | 'info';

interface ToastItem {
  id: number;
  tone: ToastTone;
  title: string;
  description?: string;
}

interface ToastApi {
  success: (title: string, description?: string) => void;
  error: (title: string, description?: string) => void;
  warning: (title: string, description?: string) => void;
  info: (title: string, description?: string) => void;
}

const ICONS: Record<ToastTone, IconName> = {
  success: 'check',
  danger: 'error',
  warning: 'alert',
  info: 'info',
};

/**
 * Qancha turadi. Xato uzoqroq: uni o'qib, nima qilishni o'ylash kerak.
 * Muvaffaqiyat qisqa: "Saqlandi" ni tushunish uchun bir soniya yetadi.
 */
const DURATION: Record<ToastTone, number> = {
  success: 4000,
  info: 5000,
  warning: 7000,
  danger: 8000,
};

/** Bir vaqtda ko'rinadigan eng ko'p soni — qolgani eskisini siqib chiqaradi. */
const MAX_VISIBLE = 3;

const Ctx = createContext<ToastApi | null>(null);

/**
 * Amal natijasi haqida qisqa xabar ("O'zgarishlar saqlandi").
 *
 *   const toast = useToast();
 *   toast.success('Obuna yangilandi');
 */
export function useToast(): ToastApi {
  const api = useContext(Ctx);
  if (!api) throw new Error('useToast faqat <ToastProvider> ichida ishlaydi');
  return api;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const nextId = useRef(1);

  const dismiss = useCallback((id: number) => {
    setItems((list) => list.filter((t) => t.id !== id));
  }, []);

  const push = useCallback((tone: ToastTone, title: string, description?: string) => {
    const id = nextId.current++;
    setItems((list) => [...list, { id, tone, title, description }].slice(-MAX_VISIBLE));
  }, []);

  const api = useMemo<ToastApi>(
    () => ({
      success: (t, d) => push('success', t, d),
      error: (t, d) => push('danger', t, d),
      warning: (t, d) => push('warning', t, d),
      info: (t, d) => push('info', t, d),
    }),
    [push],
  );

  return (
    <Ctx.Provider value={api}>
      {children}
      {createPortal(
        // Hudud DOIM sahifada turadi: ekran o'quvchi faqat oldindan
        // mavjud "jonli" hududdagi o'zgarishni e'lon qiladi.
        <div className="ui-toaster" aria-live="polite" aria-relevant="additions">
          {items.map((t) => (
            <Toast key={t.id} item={t} onDismiss={() => dismiss(t.id)} />
          ))}
        </div>,
        document.body,
      )}
    </Ctx.Provider>
  );
}

function Toast({ item, onDismiss }: { item: ToastItem; onDismiss: () => void }) {
  const [paused, setPaused] = useState(false);
  const remaining = useRef(DURATION[item.tone]);
  const started = useRef(0);

  // Sichqoncha ustida yoki fokusda bo'lsa vaqt to'xtaydi — o'qib
  // ulgurmasdan yo'qolib qolmasin.
  useEffect(() => {
    if (paused) return;
    started.current = Date.now();
    const timer = window.setTimeout(onDismiss, remaining.current);
    return () => {
      window.clearTimeout(timer);
      remaining.current -= Date.now() - started.current;
    };
  }, [paused, onDismiss]);

  return (
    <div
      className={cx('ui-toast', `ui-toast--${item.tone}`)}
      role={item.tone === 'danger' ? 'alert' : 'status'}
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={() => setPaused(false)}
    >
      <span className="ui-toast__icon" aria-hidden="true">
        <Icon name={ICONS[item.tone]} size={18} />
      </span>
      <div className="ui-toast__body">
        <p className="ui-toast__title">{item.title}</p>
        {item.description && <p className="ui-toast__desc">{item.description}</p>}
      </div>
      <IconButton icon="close" label="Yopish" size="sm" noTooltip onClick={onDismiss} />
    </div>
  );
}
