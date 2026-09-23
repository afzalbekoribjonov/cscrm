import type { ReactNode } from 'react';

import type { IconName } from '../Icon';
import { Button } from './Button';
import { Dialog } from './Dialog';
import { Alert } from './Feedback';
import { Stack } from './Layout';
import { useSubmission } from './submission';

/**
 * Maydonli oyna — tahrirlash, to'lov qabul qilish va h.k.
 *
 * * Enter bilan yuboriladi (`<form>`);
 * * `validate` xato qaytarsa so'rov yuborilmaydi (maydon xatolari
 *   ota komponentda `Field error` orqali ko'rsatiladi);
 * * yuborish paytida oyna yopilmaydi va tugma ikkinchi marta ishlamaydi;
 * * server xatosi oyna ichida chiqadi, kiritilgan ma'lumot saqlanadi.
 */
export function FormDialog({
  open,
  onClose,
  title,
  description,
  icon,
  tone = 'primary',
  size = 'md',
  submitLabel = 'Saqlash',
  cancelLabel = 'Bekor qilish',
  onSubmit,
  validate,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  description?: ReactNode;
  icon?: IconName;
  tone?: 'primary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  submitLabel?: string;
  cancelLabel?: string;
  /** Xato tashlasa oyna ochiq qoladi va xato ko'rsatiladi. */
  onSubmit: () => Promise<void> | void;
  /** `false` — yuborilmaydi (maydon xatolari allaqachon ko'rsatilgan). */
  validate?: () => boolean;
  children: ReactNode;
}) {
  const { busy, error, run } = useSubmission(open);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      dismissible={!busy}
      title={title}
      description={description}
      icon={icon}
      tone={tone === 'danger' ? 'danger' : 'default'}
      size={size}
      onSubmit={() => {
        if (validate && !validate()) return;
        void run(onSubmit, onClose);
      }}
      footer={
        <>
          <Button variant="plain" onClick={onClose} disabled={busy}>
            {cancelLabel}
          </Button>
          <Button type="submit" variant={tone === 'danger' ? 'danger' : 'primary'} loading={busy}>
            {submitLabel}
          </Button>
        </>
      }
    >
      <Stack gap={4}>
        {children}
        {error && (
          <Alert tone="danger" live>
            {error}
          </Alert>
        )}
      </Stack>
    </Dialog>
  );
}
