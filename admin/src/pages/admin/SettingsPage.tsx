import { useEffect, useState } from 'react';

import {
  Alert,
  Button,
  Card,
  Cluster,
  Field,
  Input,
  PageHeader,
  SkeletonText,
  Stack,
  useToast,
} from '@/components/ui';
import { api } from '@/lib/api';
import { formatDateTime } from '@/lib/admin-types';
import { useApi } from '@/lib/use-api';

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
  const toast = useToast();
  const { data: saved, error, loading, reload } = useApi(
    '/api/v1/admin/site-settings',
    (json) => (json as { settings: SiteSettings }).settings,
    { staleMs: Number.POSITIVE_INFINITY },
  );

  const [url, setUrl] = useState('');
  const [version, setVersion] = useState('');
  const [sizeMb, setSizeMb] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [urlError, setUrlError] = useState<string>();

  /** Serverdagi qiymatlarni maydonlarga ko'chiradi. */
  useEffect(() => {
    if (!saved) return;
    setUrl(saved.downloadUrl);
    setVersion(saved.version);
    setSizeMb(saved.sizeMb > 0 ? String(saved.sizeMb) : '');
    setNote(saved.note);
  }, [saved]);

  if (error && !saved) {
    return (
      <>
        <PageHeader title="Sozlamalar" />
        <Alert
          tone="danger"
          title="Sozlamalarni yuklab bo'lmadi"
          action={
            <Button variant="outline" size="sm" icon="refresh" onClick={reload}>
              Qayta urinish
            </Button>
          }
        >
          {error}
        </Alert>
      </>
    );
  }

  const changed =
    saved !== null &&
    (url.trim() !== saved.downloadUrl ||
      version.trim() !== saved.version ||
      (Number(sizeMb) || 0) !== saved.sizeMb ||
      note.trim() !== saved.note);

  const save = async () => {
    const u = url.trim();
    // Server qoidasi bilan bir xil: faqat http(s) manzil.
    if (u && !/^https?:\/\/\S+$/i.test(u)) {
      setUrlError('Havola https:// bilan boshlansin.');
      return;
    }
    setUrlError(undefined);
    setBusy(true);
    setSaveError(null);
    try {
      await api.put('/api/v1/admin/site-settings', {
        downloadUrl: u,
        version: version.trim(),
        sizeMb: Number(sizeMb) || 0,
        note: note.trim(),
      });
      toast.success('Saqlandi', 'Saytda darhol ko\'rinadi.');
      reload();
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : 'Saqlab bo\'lmadi.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader title="Sozlamalar" description="Websaytning panel orqali boshqariladigan qismlari." />

      <div style={{ maxWidth: 680 }}>
        <Card
          title="Ilovani yuklab olish"
          description="Yangi APK chiqqanda shu havolani almashtiring — sayt darhol yangisini beradi, qayta joylash shart emas."
          footer={
            saved && saved.updatedAt > 0 ? (
              <span className="ui-note">Oxirgi o'zgarish: {formatDateTime(saved.updatedAt)}</span>
            ) : undefined
          }
        >
          {loading || !saved ? (
            <SkeletonText lines={5} />
          ) : (
            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (changed && !busy) void save();
              }}
            >
              <Stack gap={4}>
                <Field
                  label="Havola"
                  optional
                  error={urlError}
                  hint="To'g'ridan-to'g'ri yuklanadigan havola (Google Drive, Telegram, Play Store). Bo'sh bo'lsa, saytda tugma o'rniga aloqa taklifi chiqadi."
                >
                  <Input
                    type="url"
                    inputMode="url"
                    placeholder="https://…"
                    value={url}
                    onChange={(e) => {
                      setUrl(e.target.value);
                      setUrlError(undefined);
                    }}
                  />
                </Field>
                <div className="ui-grid" style={{ ['--min' as string]: '180px' }}>
                  <Field label="Versiya" optional>
                    <Input placeholder="1.4.0" value={version} onChange={(e) => setVersion(e.target.value)} />
                  </Field>
                  <Field label="Hajmi (MB)" optional>
                    <Input inputMode="decimal" placeholder="54.5" value={sizeMb} onChange={(e) => setSizeMb(e.target.value)} />
                  </Field>
                </div>
                <Field label="Izoh" optional hint="Nima yangilandi — saytda versiya yonida ko'rinadi.">
                  <Input value={note} onChange={(e) => setNote(e.target.value)} maxLength={200} />
                </Field>
                {saveError && (
                  <Alert tone="danger" live>
                    {saveError}
                  </Alert>
                )}
                <Cluster gap={2}>
                  <Button type="submit" loading={busy} disabled={!changed}>
                    Saqlash
                  </Button>
                  {changed && (
                    <Button
                      variant="plain"
                      onClick={() => {
                        setUrl(saved.downloadUrl);
                        setVersion(saved.version);
                        setSizeMb(saved.sizeMb > 0 ? String(saved.sizeMb) : '');
                        setNote(saved.note);
                        setUrlError(undefined);
                      }}
                    >
                      Bekor qilish
                    </Button>
                  )}
                </Cluster>
              </Stack>
            </form>
          )}
        </Card>
      </div>
    </>
  );
}
