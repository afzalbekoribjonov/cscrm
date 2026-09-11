import { Icon, type IconName } from '@/components/Icon';
import { branding } from '@/lib/branding';
import { useSeo } from '@/lib/seo';

const CHANNELS: {
  icon: IconName;
  label: string;
  value: string;
  href: string;
  hint: string;
}[] = [
  {
    icon: 'phone',
    label: 'Telefon',
    value: branding.supportPhone,
    href: `tel:${branding.supportPhone.replace(/\s/g, '')}`,
    hint: 'Ish kunlari, 9:00 — 19:00',
  },
  {
    icon: 'bell',
    label: 'Telegram',
    value: branding.supportTelegram.replace('https://', ''),
    href: branding.supportTelegram,
    hint: 'Eng tez javob shu yerda',
  },
  {
    icon: 'orders',
    label: 'E-pochta',
    value: branding.supportEmail,
    href: `mailto:${branding.supportEmail}`,
    hint: 'Batafsil savollar uchun',
  },
];

export function ContactPage() {
  useSeo(
    'Aloqa',
    'CSCRM bilan bog\'lanish: Telegram, telefon va e-pochta.',
  );

  return (
    <section className="section container">
      <header className="section-head">
        <span className="eyebrow">Aloqa</span>
        <h1>Savolingiz bormi?</h1>
        <p>
          Tizimni ko'rmoqchimisiz yoki biror narsa noaniqmi — yozing,
          javob beramiz.
        </p>
      </header>

      <div className="grid grid--3" style={{ maxWidth: 900, marginInline: 'auto' }}>
        {CHANNELS.map((c) => (
          <a
            key={c.label}
            className="card card--hover"
            href={c.href}
            rel="noreferrer noopener"
            style={{ textDecoration: 'none', color: 'inherit' }}
          >
            <span className="icon-box">
              <Icon name={c.icon} />
            </span>
            <h3 style={{ marginBottom: 2 }}>{c.label}</h3>
            <p
              style={{
                margin: '0 0 4px',
                fontWeight: 700,
                color: 'var(--brand)',
                wordBreak: 'break-word',
              }}
            >
              {c.value}
            </p>
            <p className="muted" style={{ margin: 0, fontSize: '0.9rem' }}>
              {c.hint}
            </p>
          </a>
        ))}
      </div>
    </section>
  );
}
