import { branding } from '@/lib/branding';

export function ContactPage() {
  return (
    <section className="container" style={{ paddingBlock: 56, maxWidth: 640 }}>
      <h1>Aloqa</h1>
      <p className="muted" style={{ fontSize: 18 }}>
        Savolingiz bormi yoki tizimni ko'rmoqchimisiz? Bog'laning — javob
        beramiz.
      </p>

      <div className="card" style={{ marginTop: 24, lineHeight: 2.2 }}>
        <div>
          <strong>Telefon:</strong>{' '}
          <a href={`tel:${branding.supportPhone.replace(/\s/g, '')}`}>
            {branding.supportPhone}
          </a>
        </div>
        <div>
          <strong>Telegram:</strong>{' '}
          <a href={branding.supportTelegram} rel="noreferrer noopener">
            {branding.supportTelegram.replace('https://', '')}
          </a>
        </div>
        <div>
          <strong>E-pochta:</strong>{' '}
          <a href={`mailto:${branding.supportEmail}`}>{branding.supportEmail}</a>
        </div>
      </div>
    </section>
  );
}
