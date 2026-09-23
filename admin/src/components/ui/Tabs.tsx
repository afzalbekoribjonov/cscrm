import { useId, useRef, type KeyboardEvent, type ReactNode } from 'react';

export interface TabItem<T extends string> {
  id: T;
  label: string;
  /** Yorliq yonidagi son (masalan, to'lovlar soni). */
  count?: number;
}

/**
 * Yorliqlar — bitta sahifada bir nechta bo'lim.
 *
 * WAI-ARIA "tabs" namunasi: ← → bilan yorliqlar orasida yuriladi,
 * Home / End — birinchi / oxirgi. Faqat faol yorliq Tab navbatida —
 * aks holda Tab bilan har bir yorliqdan birma-bir o'tishga to'g'ri
 * kelardi.
 *
 * Qaysi yorliq ochiqligini ota komponent boshqaradi — uni URL'da
 * saqlash mumkin (sahifa yangilanganda yo'qolmaydi).
 */
export function Tabs<T extends string>({
  items,
  value,
  onChange,
  label,
  children,
}: {
  items: TabItem<T>[];
  value: T;
  onChange: (id: T) => void;
  /** Guruh nomi — ekran o'quvchi uchun. */
  label: string;
  /** Faol yorliqning tarkibi. */
  children: ReactNode;
}) {
  const base = useId();
  const tabs = useRef(new Map<T, HTMLButtonElement>());

  const tabId = (id: T) => `${base}-tab-${id}`;
  const panelId = `${base}-panel`;

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    const index = items.findIndex((t) => t.id === value);
    let next = index;
    if (e.key === 'ArrowRight') next = (index + 1) % items.length;
    else if (e.key === 'ArrowLeft') next = (index - 1 + items.length) % items.length;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = items.length - 1;
    else return;

    e.preventDefault();
    const target = items[next];
    if (!target) return;
    onChange(target.id);
    tabs.current.get(target.id)?.focus();
  };

  return (
    <div className="ui-tabs">
      <div role="tablist" aria-label={label} className="ui-tabs__list" onKeyDown={onKeyDown}>
        {items.map((item) => {
          const selected = item.id === value;
          return (
            <button
              key={item.id}
              ref={(el) => {
                if (el) tabs.current.set(item.id, el);
                else tabs.current.delete(item.id);
              }}
              type="button"
              role="tab"
              id={tabId(item.id)}
              aria-selected={selected}
              aria-controls={panelId}
              tabIndex={selected ? 0 : -1}
              className="ui-tabs__tab"
              onClick={() => onChange(item.id)}
            >
              {item.label}
              {item.count !== undefined && <span className="ui-tabs__count">{item.count}</span>}
            </button>
          );
        })}
      </div>
      <div
        role="tabpanel"
        id={panelId}
        aria-labelledby={tabId(value)}
        tabIndex={0}
        className="ui-tabs__panel"
      >
        {children}
      </div>
    </div>
  );
}
