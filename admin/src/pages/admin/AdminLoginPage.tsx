import { useEffect, useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';

import { Logo } from '@/components/Logo';
import { authErrorMessage, useAuth } from '@/lib/auth';
import { isFirebaseConfigured } from '@/lib/env';

/** Boshqaruv paneliga kirish sahifasi. */
export function AdminLoginPage() {
  const { user, access, ready, signIn, signOutNow } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const configured = isFirebaseConfigured();

  useEffect(() => {
    document.title = 'Panelga kirish — CSCRM';
  }, []);

  // Allaqachon kirgan va ruxsati bor — panelga.
  if (ready && user && access) return <Navigate to="/admin" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await signIn(email.trim(), password);
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ minHeight: '100dvh', display: 'grid', placeItems: 'center', padding: 20 }}>
      <div className="card" style={{ width: '100%', maxWidth: 400 }}>
        <div style={{ display: 'grid', placeItems: 'center', marginBottom: 20 }}>
          <Logo size={56} />
          <h1 style={{ margin: '14px 0 4px', fontSize: 22 }}>CSCRM boshqaruv</h1>
          <p className="muted" style={{ fontSize: 14, margin: 0 }}>
            Faqat CSCRM jamoasi uchun
          </p>
        </div>

        {!configured ? (
          <Notice tone="warning">
            <strong>Kirish vaqtincha ishlamayapti.</strong>
            {/* Sozlash bo'yicha ko'rsatma faqat ishlab chiqishda — prod'da
                tashrifchi ichki fayl nomlarini ko'rmasligi kerak. */}
            {import.meta.env.DEV && (
              <p style={{ margin: '8px 0 0' }}>
                <code>admin/.env.local</code> faylini <code>.env.example</code>{' '}
                asosida to'ldiring.
              </p>
            )}
          </Notice>
        ) : ready && user && !access ? (
          // Hisob haqiqiy, lekin ruxsat yo'q. Bu xatolik emas - shunchaki
          // bu hisob panel xodimlari orasida yo'q.
          //
          // Ruxsat qanday berilishi (sozlama nomi, UID) bu yerda
          // ATAYLAB aytilmaydi: bu sahifaga har qanday biznes egasi o'z
          // login-paroli bilan kira oladi va ichki tuzilmani bilishi
          // unga kerak emas.
          <Notice tone="danger">
            <strong>Bu hisobga boshqaruv paneliga kirish ruxsati berilmagan.</strong>
            <p style={{ margin: '8px 0 12px' }}>
              Biznesingizni boshqarish uchun CSCRM ilovasidan foydalaning.
            </p>
            <button
              className="btn btn--ghost"
              style={{ marginTop: 12, width: '100%' }}
              onClick={() => signOutNow()}
            >
              Boshqa hisob bilan kirish
            </button>
          </Notice>
        ) : (
          <form onSubmit={onSubmit}>
            <label style={{ display: 'block', marginBottom: 12 }}>
              <span className="muted" style={{ fontSize: 13 }}>E-pochta</span>
              <input
                type="email"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={inputStyle}
              />
            </label>

            <label style={{ display: 'block', marginBottom: 16 }}>
              <span className="muted" style={{ fontSize: 13 }}>Parol</span>
              <input
                type="password"
                required
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={inputStyle}
              />
            </label>

            {error && (
              <p style={{ color: 'var(--danger)', fontSize: 14, marginBottom: 12 }}>
                {error}
              </p>
            )}

            <button
              className="btn btn--primary"
              type="submit"
              disabled={busy}
              style={{ width: '100%' }}
            >
              {busy ? 'Kirilmoqda…' : 'Kirish'}
            </button>
          </form>
        )}

        <p style={{ marginTop: 20, marginBottom: 0, textAlign: 'center' }}>
          <Link to="/" style={{ fontSize: 14 }}>← Bosh sahifaga</Link>
        </p>
      </div>
    </div>
  );
}

const inputStyle: React.CSSProperties = {
  width: '100%',
  marginTop: 4,
  padding: '11px 13px',
  borderRadius: 'var(--radius)',
  border: '1px solid var(--border)',
  background: 'var(--surface-muted)',
  color: 'var(--text)',
  font: 'inherit',
};

function Notice({
  tone,
  children,
}: {
  tone: 'warning' | 'danger';
  children: React.ReactNode;
}) {
  const color = tone === 'warning' ? 'var(--warning)' : 'var(--danger)';
  return (
    <div
      style={{
        padding: 14,
        borderRadius: 'var(--radius)',
        background: `color-mix(in srgb, ${color} 12%, transparent)`,
        border: `1px solid color-mix(in srgb, ${color} 40%, transparent)`,
        fontSize: 14,
      }}
    >
      {children}
    </div>
  );
}
