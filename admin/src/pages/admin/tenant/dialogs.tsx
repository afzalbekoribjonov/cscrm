import { useEffect, useMemo, useState } from 'react';

import { MoneyInput } from '@/components/MoneyInput';
import {
  Alert,
  Button,
  Cluster,
  DescriptionList,
  Field,
  FormDialog,
  Input,
  Select,
  Textarea,
  matchesConfirmation,
} from '@/components/ui';
import { api } from '@/lib/api';
import { formatDate, type PaymentRequestRecord, type TenantDetail } from '@/lib/admin-types';
import { formatDay, fromDateInput, toDateInput } from '@/lib/dates';
import { formatSom } from '@/lib/format';
import type { Plan } from '@/lib/plans';

const DAY = 86_400_000;

/** Takrorlanmas kalit — javob yo'qolib qayta bosilsa ikkinchi to'lov yozilmasin. */
function newKey(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

/* ------------------------------------------------------------------ */
/* Tahrirlash                                                          */
/* ------------------------------------------------------------------ */

export function EditTenantDialog({
  open,
  onClose,
  tenant,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  tenant: Pick<TenantDetail, 'tenantId' | 'name' | 'phone' | 'address'>;
  onSaved: (changed: string[]) => void;
}) {
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [errors, setErrors] = useState<{ name?: string; phone?: string }>({});

  useEffect(() => {
    if (!open) return;
    setName(tenant.name);
    setPhone(tenant.phone ?? '');
    setAddress(tenant.address ?? '');
    setErrors({});
  }, [open, tenant]);

  const validate = () => {
    const next: typeof errors = {};
    if (name.trim().length < 2) next.name = 'Biznes nomini kiriting (kamida 2 ta belgi).';
    const digits = phone.replace(/\D/g, '');
    if (digits && !(digits.length === 12 && digits.startsWith('998')) && digits.length !== 9) {
      next.phone = 'Telefon raqamini to\'liq kiriting: +998 XX XXX XX XX.';
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      title="Biznes ma'lumotini tahrirlash"
      icon="edit"
      validate={validate}
      onSubmit={async () => {
        const r = await api.patch<{ changed: string[] }>(`/api/v1/admin/tenants/${tenant.tenantId}/profile`, {
          name: name.trim(),
          phone: phone.trim() || null,
          address: address.trim() || null,
        });
        onSaved(r.changed);
      }}
    >
      <Field label="Biznes nomi" required error={errors.name}>
        <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} autoComplete="organization" />
      </Field>
      <Field label="Telefon" optional error={errors.phone} hint="Biznes egasi bilan bog'lanish uchun.">
        <Input
          type="tel"
          inputMode="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          placeholder="+998 90 123 45 67"
          autoComplete="tel"
        />
      </Field>
      <Field label="Manzil" optional>
        <Textarea value={address} onChange={(e) => setAddress(e.target.value)} maxLength={300} rows={2} />
      </Field>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* To'lov qabul qilish                                                 */
/* ------------------------------------------------------------------ */

/**
 * To'lovni tasdiqlash — obunani uzaytiradi va TUSHUMGA yoziladi.
 *
 * Mijoz so'rovi asosida bo'lsa reja va summa so'rovdan olinadi
 * (qayta kiritishda xato qilish oson); so'rov shu bilan yopiladi.
 */
export function PaymentDialog({
  open,
  onClose,
  tenant,
  plans,
  request,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  tenant: { tenantId: string; name: string };
  plans: Plan[];
  request?: PaymentRequestRecord | null;
  onDone: () => void;
}) {
  const paid = useMemo(() => plans.filter((p) => p.kind !== 'trial'), [plans]);
  const [planId, setPlanId] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [key, setKey] = useState(newKey);
  const [planError, setPlanError] = useState<string>();

  useEffect(() => {
    if (!open) return;
    const initial = request?.planId ?? '';
    setPlanId(initial);
    const plan = paid.find((p) => p.id === initial);
    setAmount(request ? String(request.amount) : plan && plan.price > 0 ? String(plan.price) : '');
    setNote(request?.reference ? `O'tkazma: ${request.reference}` : '');
    setPlanError(undefined);
    setKey(newKey());
  }, [open, request, paid]);

  const plan = paid.find((p) => p.id === planId);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="card"
      title={request ? 'To\'lov so\'rovini tasdiqlash' : 'To\'lov qabul qilish'}
      description={tenant.name}
      submitLabel="To'lovni tasdiqlash"
      validate={() => {
        if (!planId) setPlanError('Rejani tanlang.');
        return Boolean(planId);
      }}
      onSubmit={async () => {
        await api.post(`/api/v1/admin/tenants/${tenant.tenantId}/confirm-payment`, {
          planId,
          amount: Number(amount) || 0,
          ...(note.trim() ? { note: note.trim() } : {}),
          ...(request ? { requestId: request.id } : { idempotencyKey: key }),
        });
        onDone();
      }}
    >
      <Field label="Reja" required error={planError}>
        <Select
          value={planId}
          onChange={(e) => {
            setPlanId(e.target.value);
            setPlanError(undefined);
            const p = paid.find((x) => x.id === e.target.value);
            if (!request) setAmount(p && p.price > 0 ? String(p.price) : '');
          }}
        >
          <option value="">— tanlang —</option>
          {paid.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name} — {formatSom(p.price)}
            </option>
          ))}
        </Select>
      </Field>
      <Field label="Olingan summa (so'm)" hint={plan ? `Reja narxi: ${formatSom(plan.price)}` : undefined}>
        <MoneyInput value={amount} onChange={setAmount} placeholder="0" />
      </Field>
      <Field label="Izoh" optional hint="Masalan, chek yoki o'tkazma raqami.">
        <Input value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} />
      </Field>
      <Alert tone="info">
        Obuna darhol uzayadi, summa tushumga yoziladi. Muddati hali tugamagan bo'lsa, yangi muddat
        mavjudining ustiga qo'shiladi.
      </Alert>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* Obunani to'lovsiz o'zgartirish                                      */
/* ------------------------------------------------------------------ */

/**
 * Reja va muddatni QO'LDA o'zgartirish — TO'LOV EMAS.
 *
 * Xato tuzatish, sovg'a kunlar, boshqa yo'l bilan olingan to'lov.
 * Tushumga yozilmaydi; sabab majburiy va jurnalga tushadi.
 */
export function LicenseDialog({
  open,
  onClose,
  tenant,
  plans,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  tenant: TenantDetail;
  plans: Plan[];
  onDone: () => void;
}) {
  const [planId, setPlanId] = useState('');
  const [date, setDate] = useState('');
  const [reason, setReason] = useState('');
  const [errors, setErrors] = useState<{ date?: string; reason?: string }>({});

  const current = tenant.license;
  const plan = plans.find((p) => p.id === planId);
  const lifetime = plan?.kind === 'lifetime';

  useEffect(() => {
    if (!open) return;
    setPlanId(current.planId);
    setDate(toDateInput(current.kind === 'lifetime' ? current.nextAnnualFeeAt : current.expiresAt));
    setReason('');
    setErrors({});
  }, [open, current]);

  /** Tezkor: joriy muddatga (yoki o'tgan bo'lsa bugunga) N kun qo'shish. */
  const addDays = (days: number) => {
    const base = fromDateInput(date) ?? Date.now();
    setDate(toDateInput(Math.max(base, Date.now()) + days * DAY));
    setErrors((e) => ({ ...e, date: undefined }));
  };

  const at = fromDateInput(date);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="calendar"
      title="Obunani o'zgartirish"
      description={tenant.name}
      submitLabel="O'zgartirish"
      validate={() => {
        const next: typeof errors = {};
        if (at === null) next.date = 'Sanani tanlang.';
        if (reason.trim().length < 3) next.reason = 'Sababni yozing — u amallar jurnaliga tushadi.';
        setErrors(next);
        return Object.keys(next).length === 0;
      }}
      onSubmit={async () => {
        await api.put(`/api/v1/admin/tenants/${tenant.tenantId}/license`, {
          planId,
          ...(lifetime ? { nextAnnualFeeAt: at } : { expiresAt: at }),
          reason: reason.trim(),
        });
        onDone();
      }}
    >
      <Alert tone="warning" title="Bu to'lov emas">
        Tushumga yozilmaydi. Mijoz pul to'lagan bo'lsa — "To'lov qabul qilish" dan foydalaning.
      </Alert>
      <Field label="Reja" required>
        <Select value={planId} onChange={(e) => setPlanId(e.target.value)}>
          {plans.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </Select>
      </Field>
      <Field
        label={lifetime ? 'Keyingi yillik to\'lov sanasi' : 'Obuna tugash sanasi'}
        required
        error={errors.date}
        hint={at !== null ? `Shu kun oxirigacha amal qiladi: ${formatDay(at)}` : undefined}
      >
        <Input
          type="date"
          value={date}
          onChange={(e) => {
            setDate(e.target.value);
            setErrors((x) => ({ ...x, date: undefined }));
          }}
        />
      </Field>
      <Cluster gap={2}>
        {[7, 30, 90].map((d) => (
          <Button key={d} variant="secondary" size="sm" icon="plus" onClick={() => addDays(d)}>
            {d} kun
          </Button>
        ))}
      </Cluster>
      <Field label="Sabab" required error={errors.reason}>
        <Textarea
          value={reason}
          onChange={(e) => {
            setReason(e.target.value);
            setErrors((x) => ({ ...x, reason: undefined }));
          }}
          maxLength={300}
          rows={2}
          placeholder="Masalan: texnik nosozlik uchun kompensatsiya"
        />
      </Field>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* Arxivlash                                                           */
/* ------------------------------------------------------------------ */

/**
 * Arxivlash — eng jiddiy qaytariladigan amal. Sabab va biznes nomini
 * qo'lda yozish talab qilinadi.
 */
export function ArchiveDialog({
  open,
  onClose,
  tenant,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  tenant: { tenantId: string; name: string };
  onDone: () => void;
}) {
  const [reason, setReason] = useState('');
  const [typed, setTyped] = useState('');
  const [errors, setErrors] = useState<{ reason?: string; typed?: string }>({});

  useEffect(() => {
    if (!open) return;
    setReason('');
    setTyped('');
    setErrors({});
  }, [open]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      tone="danger"
      icon="archive"
      title="Biznesni arxivlash"
      description={tenant.name}
      submitLabel="Arxivlash"
      validate={() => {
        const next: typeof errors = {};
        if (reason.trim().length < 3) next.reason = 'Arxivlash sababini yozing.';
        if (!matchesConfirmation(typed, tenant.name)) next.typed = 'Biznes nomi mos kelmadi.';
        setErrors(next);
        return Object.keys(next).length === 0;
      }}
      onSubmit={async () => {
        await api.post(`/api/v1/admin/tenants/${tenant.tenantId}/archive`, { reason: reason.trim() });
        onDone();
      }}
    >
      <ul className="ui-consequences">
        <li>Biznes egasi va xodimlari ilovada ishlay olmaydi.</li>
        <li>Barcha ma'lumotlar 30 kun saqlanadi — shu vaqt ichida arxivdan qaytarish mumkin.</li>
        <li>30 kundan keyin biznes va uning ma'lumotlari butunlay o'chiriladi.</li>
      </ul>
      <Field label="Sabab" required error={errors.reason}>
        <Textarea value={reason} onChange={(e) => setReason(e.target.value)} maxLength={300} rows={2} />
      </Field>
      <Field
        label={
          <>
            Tasdiqlash uchun <strong>{tenant.name}</strong> deb yozing
          </>
        }
        error={errors.typed}
      >
        <Input value={typed} onChange={(e) => setTyped(e.target.value)} autoComplete="off" spellCheck={false} />
      </Field>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* Kirish ma'lumotlari                                                 */
/* ------------------------------------------------------------------ */

export function LoginDialog({
  open,
  onClose,
  tenantId,
  currentLogin,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  tenantId: string;
  currentLogin: string | null;
  onDone: () => void;
}) {
  const [login, setLogin] = useState('');
  const [error, setError] = useState<string>();
  const cleaned = cleanLogin(login);

  useEffect(() => {
    if (open) {
      setLogin('');
      setError(undefined);
    }
  }, [open]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="edit"
      title="Loginni almashtirish"
      submitLabel="Almashtirish"
      validate={() => {
        const ok = cleaned.length >= 3;
        setError(ok ? undefined : 'Login kamida 3 ta belgidan iborat bo\'lsin.');
        return ok;
      }}
      onSubmit={async () => {
        await api.post(`/api/v1/admin/tenants/${tenantId}/credentials`, { login: cleaned });
        onDone();
      }}
    >
      {currentLogin && (
        <DescriptionList items={[{ label: 'Hozirgi login', value: <code>{currentLogin}</code> }]} />
      )}
      <Field
        label="Yangi login"
        required
        error={error}
        hint={
          cleaned && cleaned !== login.trim()
            ? `Saqlanadi: ${cleaned}`
            : 'Lotin harflari, raqamlar, _ va - belgilari.'
        }
      >
        <Input
          value={login}
          onChange={(e) => setLogin(e.target.value)}
          autoComplete="off"
          autoCapitalize="off"
          spellCheck={false}
        />
      </Field>
    </FormDialog>
  );
}

/** Server qoidasi bilan bir xil: kichik harf, faqat a-z 0-9 _ -. */
export function cleanLogin(input: string): string {
  return input.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
}

/** O'qish oson, adashtiradigan belgilarsiz (0/O, 1/l yo'q) vaqtinchalik parol. */
function generatePassword(): string {
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  const bytes = new Uint32Array(10);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

/**
 * Yangi parol qo'yish. Eski parolni ko'rsatib bo'lmaydi — u hech
 * qayerda ochiq saqlanmaydi. Barcha qurilmalardagi seanslar yopiladi.
 */
export function PasswordDialog({
  open,
  onClose,
  tenantId,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  tenantId: string;
  onDone: (password: string) => void;
}) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string>();

  useEffect(() => {
    if (open) {
      setPassword(generatePassword());
      setError(undefined);
    }
  }, [open]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      tone="danger"
      icon="lock"
      title="Yangi parol qo'yish"
      submitLabel="Parolni almashtirish"
      validate={() => {
        const ok = password.length >= 6;
        setError(ok ? undefined : 'Parol kamida 6 ta belgidan iborat bo\'lsin.');
        return ok;
      }}
      onSubmit={async () => {
        await api.post(`/api/v1/admin/tenants/${tenantId}/credentials`, { password });
        onDone(password);
      }}
    >
      <Alert tone="warning">
        Egasi barcha qurilmalardan chiqariladi va yangi parol bilan kirishi kerak bo'ladi.
      </Alert>
      <Field label="Yangi parol" required error={error} hint="Parolni mijozga telefon orqali ayting.">
        <Cluster gap={2}>
          <div style={{ flex: 1, minWidth: 180 }}>
            <Input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="new-password"
              spellCheck={false}
            />
          </div>
          <Button variant="secondary" icon="refresh" onClick={() => setPassword(generatePassword())}>
            Boshqasi
          </Button>
        </Cluster>
      </Field>
    </FormDialog>
  );
}

/** Kichik yordamchi: "12-mart 2026 gacha" yozuvi. */
export function untilText(ms: number | null | undefined): string {
  return ms ? `${formatDate(ms)} gacha` : '—';
}
