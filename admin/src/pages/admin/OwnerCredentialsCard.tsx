import { useCallback, useEffect, useState } from 'react';

import { api } from '@/lib/api';
import type { OwnerCredentials } from '@/lib/admin-types';

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
 * Biznes egasining kirish ma'lumotlari.
 *
 * Mijoz "login-parolimni unutdim" deb murojaat qilganda ishlatiladi.
 *
 * PAROLNI KO'RSATIB BO'LMAYDI — Firebase faqat hash saqlaydi, ochiq
 * matn hech qayerda yo'q. Shuning uchun login AYTIB beriladi, parol
 * esa yangisi QO'YIB beriladi.
 */
export function OwnerCredentialsCard({ tenantId }: { tenantId: string }) {
  const [creds, setCreds] = useState<OwnerCredentials | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);

  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ credentials: OwnerCredentials }>(
        `/api/v1/admin/tenants/${tenantId}/credentials`,
      );
      setCreds(r.credentials);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    }
  }, [tenantId]);

  useEffect(() => {
    load();
  }, [load]);

  async function submit() {
    const body: { login?: string; password?: string } = {};
    if (login.trim()) body.login = login.trim();
    if (password) body.password = password;
    if (!body.login && !body.password) return;

    const what = [body.login && 'login', body.password && 'parol']
      .filter(Boolean)
      .join(' va ');
    if (!window.confirm(`Egasining ${what}i o'zgartirilsinmi?`)) return;

    setBusy(true);
    setDone(null);
    try {
      const r = await api.post<{
        changed: string[];
        credentials: OwnerCredentials;
      }>(`/api/v1/admin/tenants/${tenantId}/credentials`, body);
      setCreds(r.credentials);
      setLogin('');
      setPassword('');
      setDone(`O'zgartirildi: ${r.changed.join(', ')}.`);
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Xatolik');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card">
      <h3>Kirish ma'lumotlari</h3>

      {error && (
        <p style={{ color: 'var(--danger)', fontSize: 14 }}>{error}</p>
      )}

      {creds === null ? (
        <p className="muted" style={{ margin: 0 }}>Yuklanmoqda…</p>
      ) : (
        <>
          <Row label="Login" value={creds.login ?? '—'} mono />
          <Row
            label="Oxirgi kirish"
            value={
              creds.lastSignInAt
                ? new Date(creds.lastSignInAt).toLocaleString('uz-UZ')
                : 'hech qachon'
            }
          />

          <p className="muted" style={{ fontSize: 13.5, marginTop: 12 }}>
            Parolni ko'rsatib bo'lmaydi — Firebase faqat hash saqlaydi.
            Mijoz parolini unutgan bo'lsa, bu yerdan yangisini qo'ying va
            unga telefon orqali ayting.
          </p>

          <label style={{ display: 'block', marginBottom: 10 }}>
            <span className="muted" style={{ fontSize: 13 }}>
              Yangi login (ixtiyoriy)
            </span>
            <input
              type="text"
              value={login}
              onChange={(e) => setLogin(e.target.value)}
              placeholder={creds.login ?? 'yangi_login'}
              autoComplete="off"
              style={fieldStyle}
            />
          </label>

          <label style={{ display: 'block', marginBottom: 12 }}>
            <span className="muted" style={{ fontSize: 13 }}>
              Yangi parol (ixtiyoriy, kamida 6 belgi)
            </span>
            <input
              type="text"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="yangi parol"
              autoComplete="off"
              style={fieldStyle}
            />
          </label>

          <button
            className="btn btn--primary"
            style={{ width: '100%' }}
            disabled={busy || (!login.trim() && !password)}
            onClick={submit}
          >
            {busy ? 'Bajarilmoqda…' : 'O\'zgartirish'}
          </button>

          {done && (
            <p
              style={{
                color: 'var(--success)',
                fontSize: 13.5,
                marginBottom: 0,
              }}
            >
              {done} Parol almashtirilgan bo'lsa, egasi tizimdan
              chiqariladi va yangi parol bilan qayta kiradi.
            </p>
          )}
        </>
      )}
    </section>
  );
}

function Row({
  label,
  value,
  mono,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div
      style={{
        display: 'flex',
        gap: 12,
        justifyContent: 'space-between',
        padding: '7px 0',
        borderBottom: '1px solid var(--border)',
        fontSize: 14,
      }}
    >
      <span className="muted">{label}</span>
      <span
        style={{
          textAlign: 'end',
          fontFamily: mono ? 'ui-monospace, monospace' : undefined,
          fontWeight: mono ? 700 : undefined,
        }}
      >
        {value}
      </span>
    </div>
  );
}
