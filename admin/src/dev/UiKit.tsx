/**
 * Dizayn tizimi vitrinasi — FAQAT ISHLAB CHIQISH UCHUN.
 *
 * `npm run dev` → http://localhost:5173/ui-kit.html
 *
 * Har bir komponent barcha holatlari bilan: yangi komponent qo'shilsa
 * yoki mavjudi o'zgarsa, shu yerda kun/tun rejimida va tor ekranda
 * tekshiriladi. Ma'lumotlar NAMUNA — prod yig'ilishiga kirmaydi.
 */
import { StrictMode, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import { BarChart } from '@/components/charts/BarChart';
import { MoneyInput } from '@/components/MoneyInput';
import { ThemeToggle } from '@/components/ThemeToggle';
import {
  Alert,
  Avatar,
  Badge,
  Button,
  Card,
  ChartCard,
  ChipGroup,
  Cluster,
  ConfirmDialog,
  DataTable,
  DescriptionList,
  EmptyState,
  Field,
  IconButton,
  Input,
  PageHeader,
  PromptDialog,
  SearchInput,
  Select,
  Skeleton,
  SkeletonText,
  Stack,
  StatCard,
  Tabs,
  Textarea,
  ToastProvider,
  Tooltip,
  compactNumber,
  deltaOf,
  useTable,
  useToast,
  type Column,
  type Tone,
} from '@/components/ui';
import { formatSom } from '@/lib/format';
import '@/styles/global.css';
import '@/styles/ui.css';

/* ------------------------------------------------------------------ */
/* Namunaviy ma'lumot (barqaror — skrinshotlar har safar bir xil)       */
/* ------------------------------------------------------------------ */

interface Row {
  id: string;
  name: string;
  phone: string;
  state: { label: string; tone: Tone };
  plan: string;
  daysLeft: number | null;
  createdAt: number;
}

const STATES: Row['state'][] = [
  { label: 'Faol', tone: 'success' },
  { label: 'Muddat yaqin', tone: 'warning' },
  { label: 'Bloklangan', tone: 'danger' },
  { label: 'Sinovda', tone: 'info' },
];
const NAMES = ['Toza Gilam', "G'olib Servis", 'Oq Parda', 'Nur Kimyoviy', 'Shabada', 'Bahor'];
const PLANS = ['1 oylik', '3 oylik', '1 yillik', 'Bir umrlik'];

const ROWS: Row[] = Array.from({ length: 27 }, (_, i) => ({
  id: `t${i}`,
  name: `${NAMES[i % NAMES.length]} ${i + 1}`,
  phone: `+998 90 ${String(100 + i * 7).padStart(3, '0')} ${String(10 + i).padStart(2, '0')} ${String(30 + i).padStart(2, '0')}`,
  state: STATES[i % STATES.length]!,
  plan: PLANS[i % PLANS.length]!,
  daysLeft: i % 4 === 3 ? null : ((i * 37) % 90) - 10,
  createdAt: Date.UTC(2026, 0, 1) + i * 5 * 86_400_000,
}));

const DAYS = Array.from({ length: 30 }, (_, i) => {
  const value = Math.round(900_000 + Math.sin(i / 3) * 420_000 + i * 22_000);
  return { label: String(i + 1), fullLabel: `${i + 1}-sentabr`, value: Math.max(0, value) };
});

/* ------------------------------------------------------------------ */

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section id={id} style={{ scrollMarginTop: 80 }}>
      <h2 style={{ fontSize: 'var(--fs-20)', margin: '0 0 var(--space-4)' }}>{title}</h2>
      {children}
    </section>
  );
}

function Tokens() {
  const tones: Tone[] = ['success', 'warning', 'danger', 'info', 'neutral'];
  const spaces = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16];
  return (
    <Stack gap={5}>
      <Cluster gap={3}>
        {tones.map((t) => (
          <div
            key={t}
            style={{
              padding: 'var(--space-3) var(--space-4)',
              borderRadius: 'var(--radius)',
              background: `var(--${t}-soft)`,
              color: `var(--${t}-ink)`,
              fontWeight: 700,
              fontSize: 'var(--fs-14)',
            }}
          >
            --{t}-ink
          </div>
        ))}
      </Cluster>
      <Cluster gap={2}>
        {spaces.map((s) => (
          <div key={s} style={{ display: 'grid', justifyItems: 'center', gap: 4, fontSize: 12 }}>
            <span
              style={{
                width: `var(--space-${s})`,
                height: `var(--space-${s})`,
                background: 'var(--brand)',
                borderRadius: 3,
              }}
            />
            <span className="muted">{s}</span>
          </div>
        ))}
      </Cluster>
      <Stack gap={1}>
        {[36, 30, 24, 20, 18, 16, 14, 13, 12].map((f) => (
          <span key={f} style={{ fontSize: `var(--fs-${f})`, lineHeight: 1.3 }}>
            {f}px — Buyurtmalar va tushum
          </span>
        ))}
      </Stack>
    </Stack>
  );
}

function Buttons() {
  const [loading, setLoading] = useState(false);
  return (
    <Stack gap={4}>
      <Cluster>
        <Button>Asosiy</Button>
        <Button variant="secondary">Ikkinchi darajali</Button>
        <Button variant="outline" icon="plus">
          Chegarali
        </Button>
        <Button variant="plain">Bekor qilish</Button>
        <Button variant="danger" icon="trash">
          O'chirish
        </Button>
        <Button variant="danger-outline" icon="archive">
          Arxivlash
        </Button>
      </Cluster>
      <Cluster>
        <Button size="sm">Kichik</Button>
        <Button size="md">O'rta</Button>
        <Button size="lg">Katta</Button>
        <Button disabled>O'chirilgan</Button>
        <Button
          loading={loading}
          onClick={() => {
            setLoading(true);
            window.setTimeout(() => setLoading(false), 1500);
          }}
        >
          Saqlash (yuklanish)
        </Button>
      </Cluster>
      <Cluster>
        <IconButton icon="edit" label="Tahrirlash" />
        <IconButton icon="refresh" label="Yangilash" outline />
        <IconButton icon="trash" label="O'chirish" size="sm" />
        <Tooltip content="Maslahat matni">
          <Button variant="outline" size="sm">
            Ustiga olib boring
          </Button>
        </Tooltip>
      </Cluster>
    </Stack>
  );
}

function Forms() {
  const [name, setName] = useState('');
  const [touched, setTouched] = useState(false);
  const [price, setPrice] = useState('1790000');
  const [q, setQ] = useState('');
  return (
    <div className="grid grid--2">
      <Card title="Biznes ma'lumotlari" description="Majburiy maydonlar yulduzcha bilan.">
        <Stack gap={4}>
          <Field
            label="Biznes nomi"
            required
            error={touched && !name.trim() ? 'Biznes nomini kiriting.' : undefined}
          >
            <Input value={name} onChange={(e) => setName(e.target.value)} onBlur={() => setTouched(true)} />
          </Field>
          <Field label="Telefon" hint="Mijozlar shu raqam bilan bog'lanadi.">
            <Input type="tel" inputMode="tel" placeholder="+998 90 123 45 67" />
          </Field>
          <Field label="Manzil" optional>
            <Textarea placeholder="Shahar, ko'cha, mo'ljal" />
          </Field>
        </Stack>
      </Card>
      <Card title="Obuna">
        <Stack gap={4}>
          <Field label="Reja" required>
            <Select defaultValue="y1">
              <option value="m1">1 oylik</option>
              <option value="m3">3 oylik</option>
              <option value="y1">1 yillik</option>
            </Select>
          </Field>
          <Field label="Summa (so'm)" hint="Uchtalab ajratiladi.">
            <MoneyInput value={price} onChange={setPrice} />
          </Field>
          <Field label="Tugash sanasi">
            <Input type="date" defaultValue="2026-12-31" />
          </Field>
          <Field label="Qidiruv">
            <SearchInput value={q} onChange={setQ} placeholder="Nom yoki telefon" shortcut />
          </Field>
          <Field label="O'chirilgan maydon">
            <Input value="O'zgartirib bo'lmaydi" disabled readOnly />
          </Field>
        </Stack>
      </Card>
    </div>
  );
}

function Stats() {
  const up = deltaOf(12_400_000, 10_100_000);
  const down = deltaOf(3, 7);
  const bad = deltaOf(9, 4);
  return (
    <Stack gap={4}>
      <div className="ui-stat-grid">
        <StatCard
          label="30 kunlik tushum"
          value={`${compactNumber(12_400_000)} so'm`}
          icon="money"
          delta={{ ...up, period: 'oldingi 30 kunga nisbatan' }}
        />
        <StatCard label="Faol bizneslar" value="128" icon="building" hint="jami 146 tadan" />
        <StatCard
          label="Bloklangan"
          value="3"
          icon="lock"
          delta={{ ...down, goodWhen: 'down', period: 'o\'tgan haftaga' }}
        />
        <StatCard
          label="To'lov so'rovlari"
          value="9"
          icon="card"
          href="#"
          delta={{ ...bad, goodWhen: 'down', period: 'kechagiga' }}
        />
      </div>
      <div className="ui-stat-grid">
        <StatCard label="Yuklanmoqda" value="" loading />
        <StatCard label="Oldingi davr 0" value="5" delta={{ ...deltaOf(5, 0), period: 'o\'tgan oyga' }} />
        <StatCard label="O'zgarishsiz" value="42" delta={{ ...deltaOf(42, 42), period: 'o\'tgan oyga' }} />
        <StatCard label="Uzun qiymat" value={`${compactNumber(1_234_567_890)} so'm`} />
      </div>
    </Stack>
  );
}

function Feedback() {
  const toast = useToast();
  return (
    <Stack gap={4}>
      <Alert tone="warning" title="3 ta to'lov so'rovi kutilmoqda" action={<Button size="sm" variant="outline">Ko'rish</Button>}>
        Mijozlar to'lov qilganini aytdi — tasdiqlash kerak.
      </Alert>
      <Alert tone="danger">Ma'lumotni yuklashda muammo yuz berdi.</Alert>
      <Alert tone="success">O'zgarishlar saqlandi.</Alert>
      <Alert tone="info" title="Maslahat">Jadvalni telefon ekranida kartalar ko'rinishida ko'rasiz.</Alert>
      <Cluster>
        <Button variant="outline" size="sm" onClick={() => toast.success('O\'zgarishlar saqlandi')}>
          Toast: muvaffaqiyat
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => toast.error('Amalni bajarib bo\'lmadi', 'Internetni tekshirib, qayta urinib ko\'ring.')}
        >
          Toast: xato
        </Button>
        <Button variant="outline" size="sm" onClick={() => toast.info('Obuna yangilandi')}>
          Toast: ma'lumot
        </Button>
      </Cluster>
      <div className="grid grid--2">
        <Card>
          <EmptyState
            icon="building"
            title="Bizneslar hali yo'q"
            description="Birinchi biznes ilovadan ro'yxatdan o'tgach shu yerda ko'rinadi."
          />
        </Card>
        <Card>
          <EmptyState
            title="Natija topilmadi"
            description="Qidiruv yoki filtrni o'zgartirib ko'ring."
            action={<Button variant="outline" size="sm">Filtrni tozalash</Button>}
          />
        </Card>
      </div>
      <Card title="Skelet">
        <Stack gap={3}>
          <Skeleton width="40%" height={20} />
          <SkeletonText lines={3} />
        </Stack>
      </Card>
    </Stack>
  );
}

function TableDemo() {
  const toast = useToast();
  const [filter, setFilter] = useState<'all' | 'active' | 'blocked'>('all');
  const [mode, setMode] = useState<'normal' | 'loading' | 'empty' | 'refreshing'>('normal');
  const [confirm, setConfirm] = useState<Row | null>(null);

  const filtered = useMemo(
    () =>
      ROWS.filter((r) =>
        filter === 'all' ? true : filter === 'active' ? r.state.tone === 'success' : r.state.tone === 'danger',
      ),
    [filter],
  );

  const columns: Column<Row>[] = [
    {
      key: 'name',
      header: 'Biznes',
      primary: true,
      sortValue: (r) => r.name,
      cell: (r) => (
        <Cluster gap={3}>
          <Avatar name={r.name} square />
          <span className="ui-table__primary">
            {r.name}
            <span className="ui-table__sub">{r.phone}</span>
          </span>
        </Cluster>
      ),
    },
    { key: 'state', header: 'Holat', cell: (r) => <Badge tone={r.state.tone} dot>{r.state.label}</Badge>, sortValue: (r) => r.state.label },
    { key: 'plan', header: 'Reja', cell: (r) => r.plan, hideOnMobile: true },
    {
      key: 'days',
      header: 'Qolgan kun',
      align: 'end',
      numeric: true,
      sortValue: (r) => r.daysLeft,
      cell: (r) => (r.daysLeft === null ? <span className="muted">Cheksiz</span> : r.daysLeft),
    },
  ];

  const rows = mode === 'loading' ? null : mode === 'empty' ? [] : filtered;
  const table = useTable({ rows, columns, pageSize: 10, initialSort: { key: 'name', dir: 'asc' } });

  return (
    <Stack gap={4}>
      <Cluster justify="between">
        <ChipGroup
          label="Holat bo'yicha filtr"
          value={filter}
          onChange={setFilter}
          options={[
            { id: 'all', label: 'Hammasi', count: ROWS.length },
            { id: 'active', label: 'Faol', count: ROWS.filter((r) => r.state.tone === 'success').length },
            { id: 'blocked', label: 'Bloklangan', count: ROWS.filter((r) => r.state.tone === 'danger').length },
          ]}
        />
        <Select aria-label="Jadval holati" value={mode} onChange={(e) => setMode(e.target.value as typeof mode)} style={{ width: 200 }}>
          <option value="normal">Oddiy</option>
          <option value="loading">Birinchi yuklanish</option>
          <option value="refreshing">Qayta yuklanish</option>
          <option value="empty">Bo'sh</option>
        </Select>
      </Cluster>
      <DataTable
        caption="Bizneslar (namuna)"
        columns={columns}
        rows={table.slice?.rows ?? null}
        rowKey={(r) => r.id}
        sort={table.sort}
        onSortChange={table.setSort}
        refreshing={mode === 'refreshing'}
        empty={<EmptyState compact title="Natija topilmadi" description="Filtrni o'zgartirib ko'ring." />}
        rowActions={(r) => [
          { id: 'open', label: 'Ochish', icon: 'external', onSelect: () => toast.info(r.name) },
          { id: 'edit', label: 'Tahrirlash', icon: 'edit', onSelect: () => toast.info('Tahrirlash') },
          { id: 'archive', label: 'Arxivlash', icon: 'archive', tone: 'danger', onSelect: () => setConfirm(r) },
        ]}
        pagination={table.slice ? { slice: table.slice, onPageChange: table.setPage } : undefined}
      />
      <ConfirmDialog
        open={confirm !== null}
        onClose={() => setConfirm(null)}
        tone="danger"
        icon="archive"
        title="Biznesni arxivlash"
        description={confirm ? `"${confirm.name}" arxivga o'tkaziladi.` : undefined}
        consequences={[
          'Biznes egasi va xodimlari ilovaga kira olmaydi.',
          'Ma\'lumotlar 30 kun saqlanadi — shu vaqt ichida qaytarish mumkin.',
          '30 kundan keyin biznes butunlay o\'chiriladi.',
        ]}
        confirmLabel="Arxivlash"
        requireText={confirm?.name}
        onConfirm={async () => {
          await new Promise((r) => setTimeout(r, 900));
          toast.success('Biznes arxivlandi');
        }}
      />
    </Stack>
  );
}

function Dialogs() {
  const [open, setOpen] = useState<'confirm' | 'fail' | 'prompt' | null>(null);
  const toast = useToast();
  return (
    <>
      <Cluster>
        <Button variant="outline" onClick={() => setOpen('confirm')}>
          Tasdiqlash oynasi
        </Button>
        <Button variant="outline" onClick={() => setOpen('fail')}>
          Xato bilan tugaydigan amal
        </Button>
        <Button variant="outline" onClick={() => setOpen('prompt')}>
          Sabab so'rash
        </Button>
      </Cluster>
      <ConfirmDialog
        open={open === 'confirm'}
        onClose={() => setOpen(null)}
        title="To'lovni tasdiqlash"
        description="Obuna 1 yilga uzaytiriladi va tushumga yoziladi."
        confirmLabel="Tasdiqlash"
        onConfirm={async () => {
          await new Promise((r) => setTimeout(r, 800));
          toast.success('To\'lov tasdiqlandi');
        }}
      />
      <ConfirmDialog
        open={open === 'fail'}
        onClose={() => setOpen(null)}
        title="Obunani yangilash"
        onConfirm={async () => {
          await new Promise((r) => setTimeout(r, 600));
          throw new Error('Aloqa o\'rnatilmadi. Internetni tekshirib, qayta urinib ko\'ring.');
        }}
      />
      <PromptDialog
        open={open === 'prompt'}
        onClose={() => setOpen(null)}
        tone="danger"
        icon="lock"
        title="Hisobni to'xtatish"
        description="Sabab mijozga ko'rsatiladi."
        label="To'xtatish sababi"
        placeholder="Masalan: to'lov muddati o'tgan"
        submitLabel="To'xtatish"
        onSubmit={async (reason) => {
          await new Promise((r) => setTimeout(r, 600));
          toast.success('Hisob to\'xtatildi', reason);
        }}
      />
    </>
  );
}

function Charts() {
  const [state, setState] = useState<'ready' | 'loading' | 'error' | 'empty'>('ready');
  return (
    <Stack gap={4}>
      <ChipGroup
        label="Chart holati"
        value={state}
        onChange={setState}
        options={[
          { id: 'ready', label: 'Ma\'lumot' },
          { id: 'loading', label: 'Yuklanish' },
          { id: 'error', label: 'Xato' },
          { id: 'empty', label: 'Bo\'sh' },
        ]}
      />
      <ChartCard
        title="Kunlik tushum"
        description="Sentabr, 30 kun (namuna)"
        status={state}
        onRetry={() => setState('ready')}
        table={{
          columns: ['Kun', 'Tushum'],
          rows: DAYS.map((d) => [d.fullLabel, formatSom(d.value)]),
        }}
      >
        <BarChart data={DAYS} format={formatSom} label="Kunlik tushum, sentabr" />
      </ChartCard>
    </Stack>
  );
}

function TabsDemo() {
  const [tab, setTab] = useState<'overview' | 'subscription' | 'payments' | 'history'>('overview');
  return (
    <Card>
      <Tabs
        label="Biznes bo'limlari"
        value={tab}
        onChange={setTab}
        items={[
          { id: 'overview', label: 'Umumiy' },
          { id: 'subscription', label: 'Obuna' },
          { id: 'payments', label: 'To\'lovlar', count: 4 },
          { id: 'history', label: 'Tarix' },
        ]}
      >
        {tab === 'overview' ? (
          <DescriptionList
            items={[
              { label: 'Telefon', value: '+998 90 123 45 67' },
              { label: "Ro'yxatdan o'tgan", value: '12.03.2026' },
              { label: 'Xodimlar', value: '6' },
              { label: 'Manzil', value: 'Farg\'ona sh., Beshariq yo\'li, "Ishonch" do\'koni oldi' },
            ]}
          />
        ) : (
          <p className="muted" style={{ margin: 0 }}>
            "{tab}" bo'limi tarkibi.
          </p>
        )}
      </Tabs>
    </Card>
  );
}

const SECTIONS = [
  ['tokens', 'Tokenlar'],
  ['buttons', 'Tugmalar'],
  ['forms', 'Formalar'],
  ['badges', 'Nishonlar va avatar'],
  ['stats', "Ko'rsatkich kartalari"],
  ['feedback', 'Xabarlar va holatlar'],
  ['tabs', 'Yorliqlar'],
  ['table', 'Jadval'],
  ['dialogs', 'Oynalar'],
  ['charts', 'Chart'],
] as const;

function UiKit() {
  return (
    <div className="container" style={{ paddingBlock: 'var(--space-8)', maxWidth: 1080 }}>
      <PageHeader
        title="Dizayn tizimi"
        description="CSCRM komponentlari — barcha holatlari bilan. Faqat ishlab chiqish uchun."
        actions={<ThemeToggle />}
      />
      <nav aria-label="Bo'limlar" style={{ marginBottom: 'var(--space-8)' }}>
        <Cluster gap={2}>
          {SECTIONS.map(([id, label]) => (
            <a key={id} href={`#${id}`} className="chip">
              {label}
            </a>
          ))}
        </Cluster>
      </nav>
      <Stack gap={12}>
        <Section id="tokens" title="Tokenlar"><Tokens /></Section>
        <Section id="buttons" title="Tugmalar"><Buttons /></Section>
        <Section id="forms" title="Formalar"><Forms /></Section>
        <Section id="badges" title="Nishonlar va avatar">
          <Cluster gap={3}>
            <Badge>Neytral</Badge>
            <Badge tone="brand">Yangi</Badge>
            <Badge tone="info" dot>Sinovda</Badge>
            <Badge tone="success" dot>Faol</Badge>
            <Badge tone="warning" dot>Muddat yaqin</Badge>
            <Badge tone="danger" dot>Bloklangan</Badge>
            <Badge tone="danger" icon="lock">To'xtatilgan</Badge>
            {NAMES.map((n) => <Avatar key={n} name={n} />)}
          </Cluster>
        </Section>
        <Section id="stats" title="Ko'rsatkich kartalari"><Stats /></Section>
        <Section id="feedback" title="Xabarlar va holatlar"><Feedback /></Section>
        <Section id="tabs" title="Yorliqlar"><TabsDemo /></Section>
        <Section id="table" title="Jadval"><TableDemo /></Section>
        <Section id="dialogs" title="Oynalar"><Dialogs /></Section>
        <Section id="charts" title="Chart"><Charts /></Section>
      </Stack>
    </div>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <ToastProvider>
        <UiKit />
      </ToastProvider>
    </BrowserRouter>
  </StrictMode>,
);
