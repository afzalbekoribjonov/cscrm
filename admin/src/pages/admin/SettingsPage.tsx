import { useCallback, useEffect, useState } from 'react';

import { api } from '@/lib/api';

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

interface SiteSettings {
  downloadUrl: string;
  version: string;
  sizeMb: number;
  note: string;
  updatedAt: number;
}

/**
 * Sayt sozlamalari — hozircha ilovani yuklab olish havolasi.
 *
 * NEGA PANELDA: yangi APK chiqqanda havola o'zgaradi. Agar u kodda
 * tursa, ilovani yangilash uchun har safar saytni qayta yig'ib, qayta
 * joylash kerak bo'lardi. Endi bu yerdan almashtiriladi va sayt darhol
 * yangisini beradi.
 */
export function SettingsPage() {
  const [saved, setSaved] = useState<SiteSettings | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [url, setUrl] = useState('');
  const [version, setVersion] = useState('');
  const [sizeMb, setSizeMb] = useState('');
  const [note, setNote] = useState('');

  /** Serverdagi qiymatlarni maydonlarga ko'chiradi. */
  const apply = useCallback((s: SiteSettings) => {
    setSaved(s);
    setUrl(s.downloadUrl);
    setVersion(s.version);
    setSizeMb(s.sizeMb > 0 ? String(s.sizeMb) : '');
    setNote(s.note);
  }, []);

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ settings: SiteSettings }>(
        '/api/v1/admin/site-settings',
      );
      apply(r.settings);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, [apply]);

  useEffect(() => {
    load();
  }, [load]);

  async function save() {
    setBusy(true);
    setDone(null);
    try {
      const r = await api.put<{ settings: SiteSettings }>(
        '/api/v1/admin/site-settings',
        {
          downloadUrl: url.trim(),
          version: version.trim(),
          sizeMb: Number(sizeMb) || 0,
          note: note.trim(),
        },
      );
      apply(r.settings);
      setDone('Saqlandi. Saytda darhol ko\'rinadi.');
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  if (error && !saved) return <p style={{ color: 'var(--danger)' }}>{error}</p>;
  if (!saved) return <p className="muted">Yuklanmoqda…</p>;

  const changed =
    url.trim() !== saved.downloadUrl ||
    version.trim() !== saved.version ||
    (Number(sizeMb) || 0) !== saved.sizeMb ||
    note.trim() !== saved.note;

  return (
    <>
      <div className="page-title">
        <h1>Sozlamalar</h1>
      </div>

      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}
      {done && <p style={{ color: 'var(--success)' }}>{done}</p>}

      <section className="card" style={{ maxWidth: 640 }}>
        <h3 style={{ marginTop: 0 }}>Ilovani yuklab olish</h3>
        <p className="muted" style={{ fontSize: '0.94rem' }}>
          Yangi APK chiqqanda shu havolani almashtiring — sayt darhol
          yangisini beradi, qayta joylash shart emas.
        </p>

        <label style={{ display: 'block', marginBottom: 14 }}>
          <strong>Havola</strong>
          <input
            style={fieldStyle}
            type="url"
            inputMode="url"
            placeholder="https://…"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
          />
          <span
            className="muted"
            style={{ fontSize: '0.82rem', display: 'block', marginTop: 4 }}
          >
            Google Drive, Telegram kanali yoki Play Store — to&apos;g&apos;ridan-to&apos;g&apos;ri
            yuklanadigan havola bo&apos;lsin. Bo&apos;sh qoldirilsa, saytda
            tugma o&apos;rniga aloqa taklifi chiqadi.
          </span>
        </label>

        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <label style={{ flex: '1 1 140px' }}>
            <strong>Versiya</strong>
            <input
              style={fieldStyle}
              placeholder="1.4.0"
              value={version}
              onChange={(e) => setVersion(e.target.value)}
            />
          </label>

          <label style={{ flex: '1 1 140px' }}>
            <strong>Hajmi (MB)</strong>
            <input
              style={fieldStyle}
              inputMode="decimal"
              placeholder="54.5"
              value={sizeMb}
              onChange={(e) => setSizeMb(e.target.value)}
            />
          </label>
        </div>

        <label style={{ display: 'block', margin: '14px 0 18px' }}>
          <strong>Izoh</strong>
          <input
            style={fieldStyle}
            placeholder="Nima yangilandi — ixtiyoriy"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
        </label>

        <button
          type="button"
          className="btn btn--primary"
          disabled={busy || !changed}
          onClick={save}
        >
          {busy ? 'Saqlanmoqda…' : 'Saqlash'}
        </button>

        {saved.updatedAt > 0 && (
          <p className="muted" style={{ fontSize: '0.82rem', marginTop: 12 }}>
            Oxirgi o&apos;zgarish:{' '}
            {new Date(saved.updatedAt).toLocaleString('uz-UZ')}
          </p>
        )}
      </section>
    </>
  );
}
