import { useCallback, useEffect, useState } from 'react';

import { api } from '@/lib/api';
import { formatDateTime } from '@/lib/admin-types';

type BroadcastKind = 'yangilik' | 'eslatma' | 'taklif';

interface Broadcast {
  id: string;
  title: string;
  body: string;
  kind: BroadcastKind;
  createdAt: number;
  expiresAt: number | null;
}

const KINDS: { id: BroadcastKind; label: string; color: string }[] = [
  { id: 'yangilik', label: 'Yangilik', color: 'var(--brand)' },
  { id: 'eslatma', label: 'Eslatma', color: 'var(--warning)' },
  { id: 'taklif', label: 'Taklif', color: 'var(--success)' },
];

const fieldStyle: React.CSSProperties = {
  width: '100%',
  marginTop: 4,
  padding: '10px 12px',
  borderRadius: 'var(--radius)',
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  font: 'inherit',
};

/**
 * Barcha bizneslarga xabar yuborish.
 *
 * Xabar BARCHA mijozlarning ilovasida darhol ko'rinadi — shuning uchun
 * yuborishdan oldin tasdiq so'raladi va oldindan ko'rish beriladi.
 */
export function BroadcastsPage() {
  const [list, setList] = useState<Broadcast[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [kind, setKind] = useState<BroadcastKind>('yangilik');
  const [days, setDays] = useState('');

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ broadcasts: Broadcast[] }>(
        '/api/v1/admin/broadcasts',
      );
      setList(r.broadcasts);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function send() {
    if (!title.trim() || !body.trim()) return;
    if (
      !window.confirm(
        'Bu xabar BARCHA bizneslarning ilovasida ko\'rinadi.\n\n' +
          `"${title.trim()}"\n\nYuborilsinmi?`,
      )
    ) {
      return;
    }

    setBusy(true);
    try {
      const n = Number(days);
      await api.post('/api/v1/admin/broadcasts', {
        title: title.trim(),
        body: body.trim(),
        kind,
        ...(n > 0
          ? { expiresAt: Date.now() + n * 24 * 60 * 60 * 1000 }
          : {}),
      });
      setTitle('');
      setBody('');
      setDays('');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  async function remove(b: Broadcast) {
    if (!window.confirm(`"${b.title}" o'chirilsinmi?`)) return;
    setBusy(true);
    try {
      await api.del(`/api/v1/admin/broadcasts/${b.id}`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="page-title">
        <h1>Xabarlar</h1>
        <span className="muted">Barcha bizneslarga</span>
      </div>

      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}

      <div
        style={{
          display: 'grid',
          gap: 18,
          gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          alignItems: 'start',
        }}
      >
        <section className="card">
          <h3>Yangi xabar</h3>
          <p className="muted" style={{ fontSize: 13.5 }}>
            Xabar barcha mijozlarning ilovasida, qo'ng'iroq ostidagi
            "Xabarlar" bo'limida ko'rinadi.
          </p>

          <label style={{ display: 'block', marginBottom: 10 }}>
            <span className="muted" style={{ fontSize: 13 }}>Turi</span>
            <div className="chips" style={{ marginTop: 6 }}>
              {KINDS.map((k) => (
                <button
                  key={k.id}
                  type="button"
                  className={`chip${kind === k.id ? ' is-active' : ''}`}
                  onClick={() => setKind(k.id)}
                >
                  {k.label}
                </button>
              ))}
            </div>
          </label>

          <label style={{ display: 'block', marginBottom: 10 }}>
            <span className="muted" style={{ fontSize: 13 }}>Sarlavha</span>
            <input
              type="text"
              value={title}
              maxLength={120}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Masalan: Yangi imkoniyat qo'shildi"
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'block', marginBottom: 10 }}>
            <span className="muted" style={{ fontSize: 13 }}>Matn</span>
            <textarea
              value={body}
              maxLength={2000}
              rows={5}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Xabar matni…"
              style={{ ...fieldStyle, resize: 'vertical' }}
            />
          </label>

          <label style={{ display: 'block', marginBottom: 14 }}>
            <span className="muted" style={{ fontSize: 13 }}>
              Necha kun ko'rinsin (bo'sh — muddatsiz)
            </span>
            <input
              type="number"
              min={1}
              value={days}
              onChange={(e) => setDays(e.target.value)}
              placeholder="masalan: 14"
              style={fieldStyle}
            />
          </label>

          <button
            className="btn btn--primary"
            style={{ width: '100%' }}
            disabled={busy || !title.trim() || !body.trim()}
            onClick={send}
          >
            {busy ? 'Yuborilmoqda…' : 'Barchaga yuborish'}
          </button>
        </section>

        <section className="card">
          <h3>Yuborilganlar</h3>
          {list === null ? (
            <p className="muted" style={{ margin: 0 }}>Yuklanmoqda…</p>
          ) : list.length === 0 ? (
            <p className="muted" style={{ margin: 0 }}>
              Hali xabar yuborilmagan.
            </p>
          ) : (
            <div style={{ display: 'grid', gap: 10 }}>
              {list.map((b) => {
                const k = KINDS.find((x) => x.id === b.kind) ?? KINDS[0]!;
                const expired =
                  b.expiresAt !== null && b.expiresAt < Date.now();
                return (
                  <div
                    key={b.id}
                    style={{
                      border: '1px solid var(--border)',
                      borderRadius: 'var(--radius)',
                      padding: 12,
                      opacity: expired ? 0.55 : 1,
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        gap: 8,
                        alignItems: 'center',
                        flexWrap: 'wrap',
                      }}
                    >
                      <span
                        className="badge"
                        style={{
                          color: k.color,
                          background: `color-mix(in srgb, ${k.color} 15%, transparent)`,
                        }}
                      >
                        {k.label}
                      </span>
                      {expired && (
                        <span className="muted" style={{ fontSize: 12 }}>
                          muddati o'tgan
                        </span>
                      )}
                      <span
                        className="muted"
                        style={{ fontSize: 12, marginInlineStart: 'auto' }}
                      >
                        {formatDateTime(b.createdAt)}
                      </span>
                    </div>
                    <strong style={{ display: 'block', marginTop: 6 }}>
                      {b.title}
                    </strong>
                    <p
                      className="muted"
                      style={{ margin: '4px 0 8px', fontSize: 14 }}
                    >
                      {b.body}
                    </p>
                    <button
                      className="btn btn--ghost"
                      style={{
                        padding: '6px 12px',
                        fontSize: 13,
                        color: 'var(--danger)',
                      }}
                      disabled={busy}
                      onClick={() => remove(b)}
                    >
                      O'chirish
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      </div>
    </>
  );
}
