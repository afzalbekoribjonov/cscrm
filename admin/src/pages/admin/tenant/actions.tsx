import { useState } from 'react';

import { ConfirmDialog, PromptDialog, useToast, type MenuItem } from '@/components/ui';
import { notifyBadgesChanged } from '@/lib/admin-events';
import type { ArchiveInfo, PaymentRequestRecord, TenantDetail, TenantSummary } from '@/lib/admin-types';
import { api } from '@/lib/api';
import { formatSom } from '@/lib/format';
import type { Plan } from '@/lib/plans';

import { ArchiveDialog, EditTenantDialog, LicenseDialog, PaymentDialog } from './dialogs';

/** Amal uchun kerakli eng kam ma'lumot (ro'yxat qatori ham, karta ham beradi). */
export interface TenantRef {
  tenantId: string;
  name: string;
  archive: ArchiveInfo | null;
  /** To'xtatilganmi — ro'yxatda `status.state === 'suspended'`. */
  suspended: boolean;
}

export function tenantRef(t: TenantSummary): TenantRef {
  return { tenantId: t.tenantId, name: t.name, archive: t.archive, suspended: t.status.state === 'suspended' };
}

type Kind =
  | 'edit'
  | 'pay'
  | 'license'
  | 'suspend'
  | 'unsuspend'
  | 'archive'
  | 'restore'
  | 'delete'
  | 'reject';

interface OpenState {
  kind: Kind;
  tenant: TenantRef;
  detail?: TenantDetail;
  request?: PaymentRequestRecord | null;
}

/**
 * Biznes ustidagi amallar — ro'yxatda ham, kartada ham BIR XIL oynalar.
 *
 * Oyna yopilganda ham oxirgi nishon saqlanadi (`last`) — aks holda
 * yopilish paytida oyna ichidagi matn bo'shab qolardi.
 *
 * `onChanged` — amal muvaffaqiyatli bo'lgach ma'lumotni qayta yuklash;
 * `onDeleted` — butunlay o'chirilgach (karta sahifasi ro'yxatga qaytadi).
 */
export function useTenantActions({
  plans,
  onChanged,
  onDeleted,
}: {
  plans: Plan[];
  onChanged: () => void;
  onDeleted?: () => void;
}) {
  const toast = useToast();
  const [kind, setKind] = useState<Kind | null>(null);
  const [last, setLast] = useState<OpenState | null>(null);

  const open = (next: OpenState) => {
    setLast(next);
    setKind(next.kind);
  };
  const close = () => setKind(null);

  const done = (title: string, description?: string) => {
    toast.success(title, description);
    onChanged();
  };

  /** Ro'yxat qatori va karta menyusidagi amallar. */
  function menuItems(tenant: TenantRef, opts: { detail?: TenantDetail; openLink?: () => void } = {}): MenuItem[] {
    const items: MenuItem[] = [];
    const archived = tenant.archive !== null;

    if (opts.openLink) items.push({ id: 'open', label: 'Ochish', icon: 'external', onSelect: opts.openLink });

    if (!archived) {
      if (opts.detail) {
        const detail = opts.detail;
        items.push({ id: 'edit', label: 'Tahrirlash', icon: 'edit', onSelect: () => open({ kind: 'edit', tenant, detail }) });
      }
      items.push({
        id: 'pay',
        label: 'To\'lov qabul qilish',
        icon: 'card',
        disabled: plans.length === 0,
        onSelect: () => open({ kind: 'pay', tenant, request: null }),
      });
      if (opts.detail) {
        const detail = opts.detail;
        items.push({
          id: 'license',
          label: 'Obunani o\'zgartirish',
          icon: 'calendar',
          disabled: plans.length === 0,
          onSelect: () => open({ kind: 'license', tenant, detail }),
        });
      }
      items.push(
        tenant.suspended
          ? { id: 'unsuspend', label: 'Qayta ochish', icon: 'unlock', onSelect: () => open({ kind: 'unsuspend', tenant }) }
          : { id: 'suspend', label: 'To\'xtatish', icon: 'lock', onSelect: () => open({ kind: 'suspend', tenant }) },
      );
      items.push({ id: 'archive', label: 'Arxivlash', icon: 'archive', tone: 'danger', onSelect: () => open({ kind: 'archive', tenant }) });
    } else {
      items.push({ id: 'restore', label: 'Arxivdan qaytarish', icon: 'restore', onSelect: () => open({ kind: 'restore', tenant }) });
      items.push({ id: 'delete', label: 'Butunlay o\'chirish', icon: 'trash', tone: 'danger', onSelect: () => open({ kind: 'delete', tenant }) });
    }
    return items;
  }

  const t = last?.tenant;
  const base = t ? `/api/v1/admin/tenants/${t.tenantId}` : '';

  const dialogs = t ? (
    <>
      {last.detail && (
        <EditTenantDialog
          open={kind === 'edit'}
          onClose={close}
          tenant={last.detail}
          onSaved={(changed) =>
            changed.length > 0 ? done('Ma\'lumot saqlandi') : toast.info('O\'zgarish yo\'q', 'Hech narsa o\'zgartirilmadi.')
          }
        />
      )}

      <PaymentDialog
        open={kind === 'pay'}
        onClose={close}
        tenant={t}
        plans={plans}
        request={last.request ?? null}
        onDone={() => {
          notifyBadgesChanged();
          done('To\'lov tasdiqlandi', 'Obuna uzaytirildi, summa tushumga yozildi.');
        }}
      />

      {last.detail && (
        <LicenseDialog
          open={kind === 'license'}
          onClose={close}
          tenant={last.detail}
          plans={plans}
          onDone={() => done('Obuna o\'zgartirildi', 'Tushumga yozilmadi. Amal jurnalga tushdi.')}
        />
      )}

      <PromptDialog
        open={kind === 'suspend'}
        onClose={close}
        tone="danger"
        icon="lock"
        title="Biznesni to'xtatish"
        description={`${t.name} — egasi va xodimlari ilovada ishlay olmaydi. Ma'lumotlar saqlanadi.`}
        label="Sabab"
        hint="Mijozga ilovada shu matn ko'rsatiladi."
        placeholder="Masalan: to'lov bo'yicha kelishuv buzildi"
        submitLabel="To'xtatish"
        onSubmit={async (reason) => {
          await api.post(`${base}/suspend`, { suspended: true, reason });
          done('Biznes to\'xtatildi');
        }}
      />

      <ConfirmDialog
        open={kind === 'unsuspend'}
        onClose={close}
        icon="unlock"
        title="Biznesni qayta ochish"
        description={t.name}
        consequences={[
          'Egasi va xodimlari ilovada yana ishlay oladi.',
          'Obuna muddati o\'tgan bo\'lsa, ilova to\'lov qabul qilinmaguncha yopiq qoladi.',
        ]}
        confirmLabel="Qayta ochish"
        onConfirm={async () => {
          await api.post(`${base}/suspend`, { suspended: false });
          done('Biznes qayta ochildi');
        }}
      />

      <ArchiveDialog
        open={kind === 'archive'}
        onClose={close}
        tenant={t}
        onDone={() => done('Biznes arxivlandi', '30 kundan keyin butunlay o\'chiriladi.')}
      />

      <ConfirmDialog
        open={kind === 'restore'}
        onClose={close}
        icon="restore"
        title="Arxivdan qaytarish"
        description={t.name}
        consequences={[
          'Biznes arxivlashdan oldingi holatiga qaytadi va o\'chirilish bekor qilinadi.',
          'Obuna muddati o\'tgan bo\'lsa, ilova to\'lov qabul qilinmaguncha yopiq qoladi.',
        ]}
        confirmLabel="Qaytarish"
        onConfirm={async () => {
          await api.post(`${base}/restore`, {});
          done('Biznes arxivdan qaytarildi');
        }}
      />

      <ConfirmDialog
        open={kind === 'delete'}
        onClose={close}
        tone="danger"
        icon="trash"
        title="Butunlay o'chirish"
        description={t.name}
        consequences={[
          'Biznes, xodimlar, buyurtmalar, mijozlar va boshqa barcha ma\'lumotlar o\'chiriladi.',
          'Egasi va xodimlar tizimga kira olmaydi.',
          'Tasdiqlangan to\'lovlar tushum hisoboti uchun saqlanib qoladi.',
          'Bu amalni ortga qaytarib bo\'lmaydi.',
        ]}
        requireText={t.name}
        confirmLabel="Butunlay o'chirish"
        onConfirm={async () => {
          await api.del(base, { confirmName: t.name });
          toast.success('Biznes butunlay o\'chirildi', t.name);
          (onDeleted ?? onChanged)();
        }}
      />

      {last.request && (
        <PromptDialog
          open={kind === 'reject'}
          onClose={close}
          tone="danger"
          icon="close"
          title="So'rovni rad etish"
          description={`${t.name} — ${last.request.planName}, ${formatSom(last.request.amount)}`}
          label="Sabab"
          hint="Mijozga ilovada shu matn ko'rsatiladi."
          placeholder="Masalan: to'lov kartaga tushmagan"
          submitLabel="Rad etish"
          onSubmit={async (reason) => {
            await api.post(`${base}/payment-requests/${last.request!.id}/reject`, { reason });
            notifyBadgesChanged();
            done('So\'rov rad etildi', 'Mijoz sababni ilovada ko\'radi.');
          }}
        />
      )}
    </>
  ) : null;

  return {
    dialogs,
    menuItems,
    /** To'lov oynasini ochish (so'rov asosida yoki qo'lda). */
    openPayment: (tenant: TenantRef, request: PaymentRequestRecord | null = null) =>
      open({ kind: 'pay', tenant, request }),
    openReject: (tenant: TenantRef, request: PaymentRequestRecord) => open({ kind: 'reject', tenant, request }),
    openLicense: (tenant: TenantRef, detail: TenantDetail) => open({ kind: 'license', tenant, detail }),
    openEdit: (tenant: TenantRef, detail: TenantDetail) => open({ kind: 'edit', tenant, detail }),
    openRestore: (tenant: TenantRef) => open({ kind: 'restore', tenant }),
    openDelete: (tenant: TenantRef) => open({ kind: 'delete', tenant }),
    openUnsuspend: (tenant: TenantRef) => open({ kind: 'unsuspend', tenant }),
  };
}
