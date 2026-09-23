import { useEffect, useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';

import { Logo } from '@/components/Logo';
import { Alert, Button, Field, Input, Stack } from '@/components/ui';
import { branding } from '@/lib/branding';
import { isFirebaseConfigured } from '@/lib/env';
import { ownerAuthErrorMessage, useOwnerAuth } from '@/lib/owner-auth';

/**
 * Biznes egasining kabinetga kirishi — ilovadagi login va parol bilan.
 *
 * Parolni unutgan ega — yordam xizmatiga murojaat qiladi (parolni
 * faqat CSCRM jamoasi yangilay oladi; eski parolni hech kim ko'rmaydi).
 */
export function CabinetLogin() {
  const { user, profile, notOwner, ready, signIn, signOutNow } = useOwnerAuth();
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    document.title = 'Kabinetga kirish — CSCRM';
  }, []);

  if (ready && profile) return <Navigate to="/kabinet" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!login.trim() || !password) {
      setError('Login va parolni kiriting.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await signIn(login, password);
    } catch (err) {
      setError(ownerAuthErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="cab-auth">
      <div className="cab-auth__card">
        <div className="cab-auth__head">
          <Logo size={52} />
          <h1>Biznes kabineti</h1>
          <p className="ui-note">Ilovadagi login va parolingiz bilan kiring.</p>
        </div>

        {!isFirebaseConfigured() ? (
          <Alert tone="warning">Kirish vaqtincha ishlamayapti. Birozdan so'ng qayta urinib ko'ring.</Alert>
        ) : ready && user && notOwner ? (
          <Stack gap={3}>
            <Alert tone="warning" title="Bu hisob biznes egasiniki emas">
              Kabinetga faqat biznes egasi kira oladi. Xodimlar ilovadan telefon raqami va PIN bilan kiradi.
            </Alert>
            <Button variant="secondary" block onClick={() => void signOutNow()}>
              Boshqa hisob bilan kirish
            </Button>
          </Stack>
        ) : (
          <form onSubmit={onSubmit} noValidate>
            <Stack gap={4}>
              <Field label="Login">
                <Input
                  value={login}
                  onChange={(e) => setLogin(e.target.value)}
                  autoComplete="username"
                  autoCapitalize="off"
                  spellCheck={false}
                  inputMode="text"
                />
              </Field>
              <Field label="Parol">
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                />
              </Field>
              {error && (
                <Alert tone="danger" live>
                  {error}
                </Alert>
              )}
              <Button type="submit" block loading={busy || (!ready && Boolean(user))}>
                Kirish
              </Button>
            </Stack>
          </form>
        )}

        <p className="cab-auth__help ui-note">
          Parolni unutdingizmi? Yordam xizmatiga yozing:{' '}
          <a href={branding.supportTelegram} target="_blank" rel="noreferrer">
            Telegram
          </a>{' '}
          yoki {branding.supportPhone}.
        </p>
        <Link to="/" className="cab-auth__back">
          ← Bosh sahifa
        </Link>
      </div>
    </div>
  );
}
