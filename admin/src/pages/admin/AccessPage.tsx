import { useEffect, useState } from 'react';

import {
  Alert,
  Avatar,
  Badge,
  Button,
  Card,
  Checkbox,
  Cluster,
  ConfirmDialog,
  DropdownMenu,
  EmptyState,
  Field,
  FormDialog,
  Input,
  List,
  ListItem,
  ListSkeleton,
  PageHeader,
  Select,
  Stack,
  Textarea,
  useToast,
} from '@/components/ui';
import type { AccessOverview, AdminMember, AdminRole } from '@/lib/admin-types';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { formatRelative } from '@/lib/dates';
import { PERMISSION_GROUPS, PERMISSION_LABELS, togglePermission, type Permission } from '@/lib/permissions';
import { useApi } from '@/lib/use-api';

/* ------------------------------------------------------------------ */
/* Rol tahriri                                                         */
/* ------------------------------------------------------------------ */

function RoleDialog({
  open,
  onClose,
  role,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  /** `null` — yangi rol. */
  role: AdminRole | null;
  onSaved: () => void;
}) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [perms, setPerms] = useState<Permission[]>([]);
  const [nameError, setNameError] = useState<string>();

  useEffect(() => {
    if (!open) return;
    setName(role?.name ?? '');
    setDescription(role?.description ?? '');
    setPerms(role?.permissions ?? []);
    setNameError(undefined);
  }, [open, role]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="shield"
      size="lg"
      title={role ? 'Rolni tahrirlash' : 'Yangi rol'}
      description={role && role.memberCount > 0 ? `O'zgarish shu roldagi ${role.memberCount} ta xodimga darhol ta'sir qiladi.` : undefined}
      submitLabel={role ? 'Saqlash' : 'Yaratish'}
      validate={() => {
        const ok = name.trim().length >= 2;
        setNameError(ok ? undefined : 'Rol nomini kiriting (kamida 2 ta belgi).');
        return ok;
      }}
      onSubmit={async () => {
        const body = { name: name.trim(), description: description.trim() || null, permissions: perms };
        if (role) await api.patch(`/api/v1/admin/access/roles/${role.id}`, body);
        else await api.post('/api/v1/admin/access/roles', body);
        onSaved();
      }}
    >
      <Field label="Nomi" required error={nameError} hint="Masalan: Operator, Yordam xizmati, Buxgalter.">
        <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={60} />
      </Field>
      <Field label="Tavsif" optional>
        <Textarea value={description} onChange={(e) => setDescription(e.target.value)} maxLength={300} rows={2} />
      </Field>
      <div className="ui-perm-grid">
        {PERMISSION_GROUPS.map((group) => (
          <fieldset key={group.title} className="ui-fieldset">
            <legend>{group.title}</legend>
            {group.items.map((p) => (
              <Checkbox
                key={p}
                label={PERMISSION_LABELS[p]}
                checked={perms.includes(p)}
                onChange={(on) => setPerms((list) => togglePermission(list, p, on))}
              />
            ))}
          </fieldset>
        ))}
      </div>
      <p className="ui-note">
        Panel xodimlari va rollarini boshqarish faqat bosh administratorda — uni rolga berib bo'lmaydi.
        Bog'liq vakolatlar o'zi belgilanadi (masalan, tahrirlash uchun ko'rish ham kerak).
      </p>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* Xodim qo'shish / rolini o'zgartirish                                */
/* ------------------------------------------------------------------ */

function MemberDialog({
  open,
  onClose,
  roles,
  member,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  roles: AdminRole[];
  /** `null` — yangi xodim. */
  member: AdminMember | null;
  onSaved: (result: { email: string; temporaryPassword?: string }) => void;
}) {
  const [email, setEmail] = useState('');
  const [roleId, setRoleId] = useState('');
  const [errors, setErrors] = useState<{ email?: string; role?: string }>({});

  useEffect(() => {
    if (!open) return;
    setEmail(member?.email ?? '');
    setRoleId(member?.roleId ?? roles[0]?.id ?? '');
    setErrors({});
  }, [open, member, roles]);

  return (
    <FormDialog
      open={open}
      onClose={onClose}
      icon="people"
      title={member ? 'Rolni o\'zgartirish' : 'Xodim qo\'shish'}
      description={member?.email}
      submitLabel={member ? 'Saqlash' : 'Qo\'shish'}
      validate={() => {
        const e: typeof errors = {};
        if (!member && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email.trim())) e.email = 'Email manzilini to\'g\'ri kiriting.';
        if (!roleId) e.role = 'Rolni tanlang.';
        setErrors(e);
        return Object.keys(e).length === 0;
      }}
      onSubmit={async () => {
        if (member) {
          await api.patch(`/api/v1/admin/access/members/${member.uid}`, { roleId });
          onSaved({ email: member.email });
        } else {
          const r = await api.post<{ temporaryPassword?: string }>('/api/v1/admin/access/members', {
            email: email.trim(),
            roleId,
          });
          onSaved({ email: email.trim().toLowerCase(), ...(r.temporaryPassword ? { temporaryPassword: r.temporaryPassword } : {}) });
        }
      }}
    >
      {!member && (
        <Field
          label="Email"
          required
          error={errors.email}
          hint="Hisob bo'lmasa yaratiladi va vaqtinchalik parol beriladi. Biznes egasining ilova logini ishlatilmaydi."
        >
          <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="off" />
        </Field>
      )}
      <Field label="Rol" required error={errors.role}>
        <Select value={roleId} onChange={(e) => setRoleId(e.target.value)}>
          {roles.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </Select>
      </Field>
    </FormDialog>
  );
}

/* ------------------------------------------------------------------ */
/* Sahifa                                                              */
/* ------------------------------------------------------------------ */

type Dialog =
  | { kind: 'role'; role: AdminRole | null }
  | { kind: 'deleteRole'; role: AdminRole }
  | { kind: 'member'; member: AdminMember | null }
  | { kind: 'removeMember'; member: AdminMember };

/**
 * Panel xodimlari va rollar — kim panelga kira oladi va nima qila oladi.
 *
 * Faqat bosh administrator (server sozlamasidagi) ko'radi. Bosh
 * administratorni panel orqali olib tashlab ham, cheklab ham bo'lmaydi.
 */
export function AccessPage() {
  const { user } = useAuth();
  const toast = useToast();
  const { data, error, loading, refreshing, reload } = useApi(
    '/api/v1/admin/access',
    (json) => json as AccessOverview,
  );
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [lastDialog, setLastDialog] = useState<Dialog | null>(null);
  const [issued, setIssued] = useState<{ email: string; password: string } | null>(null);

  const open = (d: Dialog) => {
    setDialog(d);
    setLastDialog(d);
  };
  const close = () => setDialog(null);

  if (error && !data) {
    return (
      <>
        <PageHeader title="Panel xodimlari" />
        <Alert
          tone="danger"
          title="Ma'lumotni yuklab bo'lmadi"
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

  const roles = data?.roles ?? [];
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      toast.success('Parol nusxalandi');
    } catch {
      toast.error('Nusxalab bo\'lmadi', 'Matnni qo\'lda belgilab oling.');
    }
  };

  return (
    <>
      <PageHeader
        title="Panel xodimlari"
        description="Kim boshqaruv paneliga kira oladi va nima qila oladi."
        actions={
          <Button variant="outline" size="sm" icon="refresh" loading={refreshing} onClick={reload}>
            Yangilash
          </Button>
        }
      />

      <Stack gap={5}>
        {issued && (
          <Alert
            tone="success"
            title={`${issued.email} uchun hisob yaratildi`}
            live
            action={
              <Cluster gap={2}>
                <Button variant="outline" size="sm" icon="copy" onClick={() => void copy(issued.password)}>
                  Nusxalash
                </Button>
                <Button variant="plain" size="sm" onClick={() => setIssued(null)}>
                  Yashirish
                </Button>
              </Cluster>
            }
          >
            Vaqtinchalik parol: <code className="ui-code ui-code--lg">{issued.password}</code>
            <br />
            Xodimga xavfsiz yo'l bilan yetkazing — u birinchi kirishdan keyin parolini o'zgartirsin (menyu pastidagi
            qulf belgisi). Bu parol faqat hozir ko'rinadi.
          </Alert>
        )}

        <div className="ui-split">
          <Card
            title="Xodimlar"
            actions={
              <Button
                size="sm"
                icon="plus"
                disabled={roles.length === 0}
                onClick={() => open({ kind: 'member', member: null })}
              >
                Xodim qo'shish
              </Button>
            }
          >
            {loading || !data ? (
              <ListSkeleton rows={3} />
            ) : (
              <List label="Panel xodimlari">
                {data.superAdmins.map((s) => (
                  <ListItem
                    key={s.uid}
                    leading={<Avatar name={s.email ?? 'A'} />}
                    title={s.email ?? 'Bosh administrator'}
                    meta={s.lastSignInAt ? `Oxirgi kirish: ${formatRelative(s.lastSignInAt)}` : 'Hali kirmagan'}
                    trailing={<Badge tone="brand">Bosh administrator</Badge>}
                  />
                ))}
                {data.members.map((m) => (
                  <ListItem
                    key={m.uid}
                    leading={<Avatar name={m.email} />}
                    title={m.email}
                    meta={[
                      m.roleName ?? 'Roli o\'chirilgan — vakolati yo\'q',
                      m.lastSignInAt ? `oxirgi kirish: ${formatRelative(m.lastSignInAt)}` : 'hali kirmagan',
                    ].join(' · ')}
                    trailing={
                      <Cluster gap={1}>
                        {m.disabled && <Badge tone="danger">Bloklangan</Badge>}
                        <DropdownMenu
                          label={`${m.email} — amallar`}
                          items={[
                            {
                              id: 'role',
                              label: 'Rolni o\'zgartirish',
                              icon: 'shield',
                              disabled: roles.length === 0,
                              onSelect: () => open({ kind: 'member', member: m }),
                            },
                            {
                              id: 'remove',
                              label: 'Paneldan chiqarish',
                              icon: 'logout',
                              tone: 'danger',
                              disabled: m.uid === user?.uid,
                              onSelect: () => open({ kind: 'removeMember', member: m }),
                            },
                          ]}
                        />
                      </Cluster>
                    }
                  />
                ))}
              </List>
            )}
            {data && data.members.length === 0 && (
              <div className="ui-card-note">
                <p className="ui-note">
                  {roles.length === 0
                    ? 'Xodim qo\'shish uchun avval rol yarating — rol uning nimalarga kira olishini belgilaydi.'
                    : 'Hozircha panelda faqat siz. Xodim qo\'shsangiz, u faqat roli bergan bo\'limlarni ko\'radi.'}
                </p>
              </div>
            )}
          </Card>

          <Card
            title="Rollar"
            actions={
              <Button size="sm" variant="secondary" icon="plus" onClick={() => open({ kind: 'role', role: null })}>
                Rol yaratish
              </Button>
            }
          >
            {loading || !data ? (
              <ListSkeleton rows={2} />
            ) : roles.length === 0 ? (
              <EmptyState
                icon="shield"
                title="Hali rol yo'q"
                description="Rol — vakolatlar to'plami: masalan, «Operator» to'lovlarni tasdiqlaydi, lekin biznesni o'chira olmaydi."
                compact
              />
            ) : (
              <List label="Rollar">
                {roles.map((r) => (
                  <ListItem
                    key={r.id}
                    leading={<Avatar name={r.name} square />}
                    title={r.name}
                    meta={[
                      `${r.permissions.length} ta vakolat`,
                      `${r.memberCount} ta xodim`,
                      ...(r.description ? [r.description] : []),
                    ].join(' · ')}
                    trailing={
                      <DropdownMenu
                        label={`${r.name} — amallar`}
                        items={[
                          { id: 'edit', label: 'Tahrirlash', icon: 'edit', onSelect: () => open({ kind: 'role', role: r }) },
                          {
                            id: 'delete',
                            label: r.memberCount > 0 ? 'O\'chirish (avval xodimlarni o\'tkazing)' : 'O\'chirish',
                            icon: 'trash',
                            tone: 'danger',
                            disabled: r.memberCount > 0,
                            onSelect: () => open({ kind: 'deleteRole', role: r }),
                          },
                        ]}
                      />
                    }
                  />
                ))}
              </List>
            )}
          </Card>
        </div>
      </Stack>

      <RoleDialog
        open={dialog?.kind === 'role'}
        onClose={close}
        role={lastDialog?.kind === 'role' ? lastDialog.role : null}
        onSaved={() => {
          toast.success(lastDialog?.kind === 'role' && lastDialog.role ? 'Rol saqlandi' : 'Rol yaratildi');
          reload();
        }}
      />
      <MemberDialog
        open={dialog?.kind === 'member'}
        onClose={close}
        roles={roles}
        member={lastDialog?.kind === 'member' ? lastDialog.member : null}
        onSaved={(r) => {
          if (r.temporaryPassword) setIssued({ email: r.email, password: r.temporaryPassword });
          toast.success(lastDialog?.kind === 'member' && lastDialog.member ? 'Rol o\'zgartirildi' : 'Xodim qo\'shildi', r.email);
          reload();
        }}
      />
      <ConfirmDialog
        open={dialog?.kind === 'deleteRole'}
        onClose={close}
        tone="danger"
        icon="trash"
        title="Rolni o'chirish"
        description={lastDialog?.kind === 'deleteRole' ? lastDialog.role.name : undefined}
        consequences={['Rol va uning vakolatlar ro\'yxati o\'chiriladi. Bu rolda xodim yo\'q.']}
        confirmLabel="O'chirish"
        onConfirm={async () => {
          if (lastDialog?.kind !== 'deleteRole') return;
          await api.del(`/api/v1/admin/access/roles/${lastDialog.role.id}`);
          toast.success('Rol o\'chirildi');
          reload();
        }}
      />
      <ConfirmDialog
        open={dialog?.kind === 'removeMember'}
        onClose={close}
        tone="danger"
        icon="logout"
        title="Paneldan chiqarish"
        description={lastDialog?.kind === 'removeMember' ? lastDialog.member.email : undefined}
        consequences={[
          'Panelga kirish huquqi darhol olinadi, ochiq seanslari yopiladi.',
          'Hisobning o\'zi o\'chirilmaydi — kerak bo\'lsa qayta qo\'shish mumkin.',
          'Uning amallari jurnalda saqlanib qoladi.',
        ]}
        confirmLabel="Chiqarish"
        onConfirm={async () => {
          if (lastDialog?.kind !== 'removeMember') return;
          await api.del(`/api/v1/admin/access/members/${lastDialog.member.uid}`);
          toast.success('Xodim paneldan chiqarildi', lastDialog.member.email);
          reload();
        }}
      />
    </>
  );
}
