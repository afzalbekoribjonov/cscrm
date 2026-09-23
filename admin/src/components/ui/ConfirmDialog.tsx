import { useEffect, useRef, useState, type ReactNode } from 'react';

import type { IconName } from '../Icon';
import { Button } from './Button';
import { Dialog } from './Dialog';
import { Alert } from './Feedback';
import { Field } from './Field';
import { Input, Textarea } from './Input';
import { Stack } from './Layout';
import { matchesConfirmation } from './logic';
import { useSubmission } from './submission';

/**
 * Tasdiqlash oynasi — muhim yoki qaytarib bo'lmaydigan amallar uchun.
 *
 * * `consequences` — nima bo'lishini aniq aytadi (umumiy "Ishonchingiz
 *   komilmi?" emas);
 * * `requireText` — eng xavfli amallar (biznesni o'chirish) uchun:
 *   foydalanuvchi nomni qo'lda yozmaguncha tugma ochilmaydi. Bu
 *   "avtomatik Enter" dan va noto'g'ri qatorni bosib yuborishdan himoya;
 * * xavfli oynada fokus "Bekor qilish" ga tushadi — tasodifiy Enter
 *   hech narsani o'chirmaydi.
 *
 * `onConfirm` xato tashlasa, oyna yopilmaydi va xato ichida ko'rinadi.
 */
export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  description,
  consequences,
  children,
  confirmLabel = 'Tasdiqlash',
  cancelLabel = 'Bekor qilish',
  tone = 'primary',
  icon,
  requireText,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void> | void;
  title: ReactNode;
  description?: ReactNode;
  consequences?: ReactNode[];
  children?: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: 'primary' | 'danger';
  icon?: IconName;
  /** Tasdiqlash uchun qo'lda yozilishi kerak bo'lgan matn (masalan, biznes nomi). */
  requireText?: string;
}) {
  const { busy, error, run } = useSubmission(open);
  const [typed, setTyped] = useState('');
  const cancelRef = useRef<HTMLButtonElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) setTyped('');
  }, [open]);

  const matched = !requireText || matchesConfirmation(typed, requireText);
  const danger = tone === 'danger';

  return (
    <Dialog
      open={open}
      onClose={onClose}
      dismissible={!busy}
      title={title}
      description={description}
      icon={icon ?? (danger ? 'alert' : undefined)}
      tone={danger ? 'danger' : 'default'}
      size="sm"
      initialFocusRef={requireText ? inputRef : danger ? cancelRef : undefined}
      onSubmit={() => {
        if (matched) void run(onConfirm, onClose);
      }}
      footer={
        <>
          <Button ref={cancelRef} variant="plain" onClick={onClose} disabled={busy}>
            {cancelLabel}
          </Button>
          <Button
            type="submit"
            variant={danger ? 'danger' : 'primary'}
            loading={busy}
            disabled={!matched}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      {(consequences?.length || children || requireText || error) && (
        <Stack gap={4}>
          {consequences && consequences.length > 0 && (
            <ul className="ui-consequences">
              {consequences.map((c, i) => (
                <li key={i}>{c}</li>
              ))}
            </ul>
          )}
          {children}
          {requireText && (
            <Field
              label={
                <>
                  Tasdiqlash uchun <strong>{requireText}</strong> deb yozing
                </>
              }
            >
              <Input
                ref={inputRef}
                value={typed}
                onChange={(e) => setTyped(e.target.value)}
                autoComplete="off"
                autoCapitalize="off"
                spellCheck={false}
                disabled={busy}
              />
            </Field>
          )}
          {error && (
            <Alert tone="danger" live>
              {error}
            </Alert>
          )}
        </Stack>
      )}
    </Dialog>
  );
}

/**
 * Sabab so'raydigan oyna — rad etish, to'xtatish kabi amallar uchun.
 *
 * Brauzerning `window.prompt` i o'rniga: u bezatilmaydi, telefonda
 * noqulay, uzunlik chegarasi va xato ko'rsatib bo'lmaydi.
 */
export function PromptDialog({
  open,
  onClose,
  onSubmit,
  title,
  description,
  label,
  hint,
  placeholder,
  submitLabel = 'Saqlash',
  cancelLabel = 'Bekor qilish',
  tone = 'primary',
  icon,
  maxLength = 300,
  multiline = true,
  initialValue = '',
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (value: string) => Promise<void> | void;
  title: ReactNode;
  description?: ReactNode;
  label: string;
  hint?: ReactNode;
  placeholder?: string;
  submitLabel?: string;
  cancelLabel?: string;
  tone?: 'primary' | 'danger';
  icon?: IconName;
  maxLength?: number;
  multiline?: boolean;
  initialValue?: string;
}) {
  const { busy, error, run } = useSubmission(open);
  const [value, setValue] = useState(initialValue);
  const [touched, setTouched] = useState(false);

  useEffect(() => {
    if (open) {
      setValue(initialValue);
      setTouched(false);
    }
  }, [open, initialValue]);

  const trimmed = value.trim();
  const invalid = trimmed.length === 0;
  const danger = tone === 'danger';

  const control = {
    value,
    maxLength,
    placeholder,
    disabled: busy,
    onChange: (e: { target: { value: string } }) => setValue(e.target.value),
    onBlur: () => setTouched(true),
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      dismissible={!busy}
      title={title}
      description={description}
      icon={icon}
      tone={danger ? 'danger' : 'default'}
      size="sm"
      onSubmit={() => {
        setTouched(true);
        if (!invalid) void run(() => onSubmit(trimmed), onClose);
      }}
      footer={
        <>
          <Button variant="plain" onClick={onClose} disabled={busy}>
            {cancelLabel}
          </Button>
          <Button type="submit" variant={danger ? 'danger' : 'primary'} loading={busy}>
            {submitLabel}
          </Button>
        </>
      }
    >
      <Stack gap={4}>
        <Field
          label={label}
          required
          hint={hint ?? `${value.length} / ${maxLength}`}
          error={touched && invalid ? 'Bu maydonni to\'ldiring.' : undefined}
        >
          {multiline ? <Textarea rows={3} {...control} /> : <Input {...control} />}
        </Field>
        {error && (
          <Alert tone="danger" live>
            {error}
          </Alert>
        )}
      </Stack>
    </Dialog>
  );
}
