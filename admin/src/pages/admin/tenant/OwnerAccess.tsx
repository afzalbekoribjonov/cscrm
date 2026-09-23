import { useState } from 'react';

import {
  Alert,
  Badge,
  Button,
  Card,
  Cluster,
  DescriptionList,
  IconButton,
  SkeletonText,
  Stack,
  useToast,
} from '@/components/ui';
import type { OwnerCredentials } from '@/lib/admin-types';
import { formatRelative } from '@/lib/dates';
import { useApi } from '@/lib/use-api';

import { LoginDialog, PasswordDialog } from './dialogs';

async function copy(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/**
 * Biznes egasining kirish ma'lumotlari.
 *
 * Mijoz "login-parolimni unutdim" deb murojaat qilganda ishlatiladi:
 * login AYTIB beriladi, parol esa yangisi QO'YIB beriladi — eski
 * parolni hech kim (shu jumladan, biz ham) ko'ra olmaydi.
 *
 * Yangi parol faqat qo'yilgan zahoti bir marta ko'rinadi: sahifa
 * yangilansa yo'qoladi, hech qayerda saqlanmaydi.
 */
export function OwnerAccess({ tenantId, archived }: { tenantId: string; archived: boolean }) {
  const toast = useToast();
  const { data, error, loading, reload } = useApi(
    `/api/v1/admin/tenants/${tenantId}/credentials`,
    (json) => (json as { credentials: OwnerCredentials }).credentials,
  );
  const [dialog, setDialog] = useState<'login' | 'password' | null>(null);
  const [issued, setIssued] = useState<string | null>(null);

  const copyAndSay = async (text: string, what: string) => {
    if (await copy(text)) toast.success(`${what} nusxalandi`);
    else toast.error('Nusxalab bo\'lmadi', 'Matnni qo\'lda belgilab oling.');
  };

  const lastSignIn = data?.lastSignInAt ? Date.parse(data.lastSignInAt) : NaN;

  return (
    <Stack gap={4}>
      <Card
        title="Egasining kirish ma'lumotlari"
        description="Mijoz loginini unutgan bo'lsa — aytib bering. Parolni unutgan bo'lsa — yangisini qo'ying."
      >
        {loading ? (
          <SkeletonText lines={3} />
        ) : error && !data ? (
          <Alert
            tone="danger"
            action={
              <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
                Qayta urinish
              </Button>
            }
          >
            {error}
          </Alert>
        ) : data ? (
          <Stack gap={4}>
            <DescriptionList
              items={[
                {
                  label: 'Login',
                  value: data.login ? (
                    <Cluster gap={1}>
                      <code className="ui-code">{data.login}</code>
                      <IconButton
                        icon="copy"
                        size="sm"
                        label="Loginni nusxalash"
                        onClick={() => void copyAndSay(data.login!, 'Login')}
                      />
                    </Cluster>
                  ) : (
                    <span className="ui-muted">Login o'rnatilmagan</span>
                  ),
                },
                {
                  label: 'Oxirgi kirish',
                  value: Number.isFinite(lastSignIn) ? formatRelative(lastSignIn) : 'Hali kirmagan',
                },
                ...(data.disabled
                  ? [{ label: 'Holat', value: <Badge tone="danger">Kirish o'chirilgan</Badge> }]
                  : []),
              ]}
            />
            <p className="ui-note">
              Parolni ko'rib bo'lmaydi — u shifrlangan holda saqlanadi. Yangi parol qo'yilganda egasi
              barcha qurilmalardan chiqariladi.
            </p>
            <Cluster gap={2}>
              <Button variant="secondary" icon="edit" disabled={archived} onClick={() => setDialog('login')}>
                Loginni almashtirish
              </Button>
              <Button variant="secondary" icon="lock" disabled={archived} onClick={() => setDialog('password')}>
                Yangi parol qo'yish
              </Button>
            </Cluster>
            {archived && <p className="ui-note">Arxivdagi biznesning kirish ma'lumotlarini o'zgartirib bo'lmaydi.</p>}
          </Stack>
        ) : null}
      </Card>

      {issued && (
        <Alert
          tone="success"
          title="Yangi parol o'rnatildi"
          live
          action={
            <Cluster gap={2}>
              <Button variant="outline" size="sm" icon="copy" onClick={() => void copyAndSay(issued, 'Parol')}>
                Nusxalash
              </Button>
              <Button variant="plain" size="sm" onClick={() => setIssued(null)}>
                Yashirish
              </Button>
            </Cluster>
          }
        >
          <code className="ui-code ui-code--lg">{issued}</code>
          <br />
          Mijozga telefon orqali ayting. Bu parol faqat hozir ko'rinadi.
        </Alert>
      )}

      <LoginDialog
        open={dialog === 'login'}
        onClose={() => setDialog(null)}
        tenantId={tenantId}
        currentLogin={data?.login ?? null}
        onDone={() => {
          toast.success('Login almashtirildi', 'Mijozga yangi loginni ayting.');
          reload();
        }}
      />
      <PasswordDialog
        open={dialog === 'password'}
        onClose={() => setDialog(null)}
        tenantId={tenantId}
        onDone={(password) => {
          setIssued(password);
          reload();
        }}
      />
    </Stack>
  );
}
