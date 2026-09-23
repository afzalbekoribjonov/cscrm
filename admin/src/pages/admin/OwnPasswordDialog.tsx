import { useEffect, useState } from 'react';
import { EmailAuthProvider, reauthenticateWithCredential, updatePassword } from 'firebase/auth';

import { Field, FormDialog, Input } from '@/components/ui';
import { firebaseAuth } from '@/lib/firebase';

const MIN_LENGTH = 8;

function message(err: unknown): string {
  const code = (err as { code?: string }).code ?? '';
  if (code === 'auth/invalid-credential' || code === 'auth/wrong-password') return 'Hozirgi parol noto\'g\'ri.';
  if (code === 'auth/too-many-requests') return 'Juda ko\'p urinish. Bir necha daqiqadan so\'ng qayta urining.';
  if (code === 'auth/weak-password') return 'Parol juda oddiy. Uzunroq va murakkabroq parol tanlang.';
  if (code === 'auth/network-request-failed') return 'Internet aloqasini tekshiring.';
  return 'Parolni almashtirib bo\'lmadi. Qayta urinib ko\'ring.';
}

/**
 * Panel foydalanuvchisi o'z parolini almashtiradi.
 *
 * Yangi xodimga vaqtinchalik parol beriladi — birinchi kirishdan keyin
 * uni shu yerda o'zgartiradi. Hozirgi parol so'raladi: ochiq qolgan
 * kompyuterdan boshqa odam parolni almashtirib qo'ya olmasin.
 */
export function OwnPasswordDialog({
  open,
  onClose,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [repeat, setRepeat] = useState('');
  const [errors, setErrors] = useState<{ current?: string; next?: string; repeat?: string }>({});

  useEffect(() => {
    if (!open) return;
    setCurrent('');
    setNext('');
    setRepeat('');
    setErrors({});
  }, [open]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="lock"
      title="Parolni almashtirish"
      submitLabel="Almashtirish"
      size="sm"
      validate={() => {
        const e: typeof errors = {};
        if (!current) e.current = 'Hozirgi parolni kiriting.';
        if (next.length < MIN_LENGTH) e.next = `Yangi parol kamida ${MIN_LENGTH} ta belgi bo'lsin.`;
        else if (next === current) e.next = 'Yangi parol hozirgisidan farq qilsin.';
        if (repeat !== next) e.repeat = 'Parollar bir xil emas.';
        setErrors(e);
        return Object.keys(e).length === 0;
      }}
      onSubmit={async () => {
        const user = firebaseAuth().currentUser;
        if (!user?.email) throw new Error('Qaytadan tizimga kiring.');
        try {
          await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, current));
          await updatePassword(user, next);
        } catch (err) {
          throw new Error(message(err));
        }
        onDone();
      }}
    >
      <Field label="Hozirgi parol" required error={errors.current}>
        <Input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" />
      </Field>
      <Field label="Yangi parol" required error={errors.next} hint={`Kamida ${MIN_LENGTH} ta belgi.`}>
        <Input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" />
      </Field>
      <Field label="Yangi parolni takrorlang" required error={errors.repeat}>
        <Input type="password" value={repeat} onChange={(e) => setRepeat(e.target.value)} autoComplete="new-password" />
      </Field>
    </FormDialog>
  );
}
