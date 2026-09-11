import { Icon } from '@/components/Icon';
import { Reveal } from '@/components/Reveal';
import { branding } from '@/lib/branding';
import { trialDays } from '@/lib/plans';
import { useSeo } from '@/lib/seo';
import { useDownload } from '@/lib/use-download';

const STEPS = [
  {
    title: 'Faylni yuklab oling',
    text: 'Yuqoridagi tugmani bosing. Fayl telefoningizning "Yuklanmalar" papkasiga tushadi.',
  },
  {
    title: 'O\'rnatishga ruxsat bering',
    text: 'Android "Noma\'lum manbadan o\'rnatish" haqida so\'raydi — bu oddiy hol, chunki ilova hozircha Play Store\'da emas. Ruxsat bering.',
  },
  {
    title: 'Ilovani oching va ro\'yxatdan o\'ting',
    text: 'Biznes nomi, telefon raqamingiz va parol. Bir necha daqiqada tayyor.',
  },
  {
    title: 'Xodimlaringizni qo\'shing',
    text: 'Har biriga bo\'lim va PIN-kod belgilaysiz. Ular shu ilovani o\'z telefoniga o\'rnatib ishlaydi.',
  },
];

export function DownloadPage() {
  useSeo(
    'Ilovani yuklab olish',
    'CSCRM Android ilovasini yuklab oling va bir necha daqiqada ishga tushiring.',
  );

  const { info, loading } = useDownload();

  return (
    <>
      <section className="section--tight">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="section-head">
            <span className="eyebrow">Yuklab olish</span>
            <h1>CSCRM ilovasi</h1>
            <p>
              Android telefonlar uchun. {trialDays} kun bepul — karta kerak
              emas.
            </p>
          </div>

          <div
            className="card center"
            style={{ borderColor: 'var(--brand)', borderWidth: 2 }}
          >
            {loading ? (
              <p className="muted" style={{ margin: 0 }}>
                Manzil tekshirilmoqda…
              </p>
            ) : info.url ? (
              <>
                <a
                  className="btn btn--primary btn--lg"
                  href={info.url}
                  rel="noreferrer noopener"
                >
                  <Icon name="download" size={20} />
                  Android uchun yuklab olish
                </a>

                <p
                  className="muted"
                  style={{ margin: '14px 0 0', fontSize: '0.9rem' }}
                >
                  {[
                    info.version && `Versiya ${info.version}`,
                    info.sizeMb > 0 &&
                      `${String(info.sizeMb).replace('.', ',')} MB`,
                    'Android 7.0 va undan yuqori',
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </p>

                {info.note && (
                  <p style={{ margin: '10px 0 0', fontSize: '0.92rem' }}>
                    {info.note}
                  </p>
                )}
              </>
            ) : (
              /* Manzil hali kiritilmagan — bu holat foydalanuvchiga
                 "xatolik" bo'lib ko'rinmasligi kerak. Unga ishlaydigan
                 muqobil yo'l beriladi. */
              <>
                <h3 style={{ marginBottom: 8 }}>
                  Ilovani biz yuboramiz
                </h3>
                <p className="muted" style={{ margin: '0 0 18px' }}>
                  Telegram orqali yozing yoki qo&apos;ng&apos;iroq qiling —
                  o&apos;rnatish faylini darhol yuboramiz va sozlashda yordam
                  beramiz.
                </p>
                <div
                  style={{
                    display: 'flex',
                    gap: 10,
                    justifyContent: 'center',
                    flexWrap: 'wrap',
                  }}
                >
                  <a
                    className="btn btn--primary"
                    href={branding.supportTelegram}
                    rel="noreferrer noopener"
                  >
                    Telegram
                  </a>
                  <a
                    className="btn btn--ghost"
                    href={`tel:${branding.supportPhone.replace(/\s/g, '')}`}
                  >
                    {branding.supportPhone}
                  </a>
                </div>
              </>
            )}
          </div>
        </div>
      </section>

      <section className="section band">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="section-head">
            <span className="eyebrow">O&apos;rnatish</span>
            <h2>To&apos;rtta qadam</h2>
          </div>

          <div style={{ display: 'grid', gap: 12 }}>
            {STEPS.map((s, i) => (
              <Reveal key={s.title} delay={i * 70}>
                <article
                  className="card"
                  style={{ display: 'flex', gap: 16, alignItems: 'flex-start' }}
                >
                  <span className="step__num" style={{ marginBottom: 0 }}>
                    {i + 1}
                  </span>
                  <div>
                    <h3 style={{ marginBottom: 4 }}>{s.title}</h3>
                    <p
                      className="muted"
                      style={{ margin: 0, fontSize: '0.96rem' }}
                    >
                      {s.text}
                    </p>
                  </div>
                </article>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="section--tight">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="grid grid--2">
            <article className="card">
              <span className="icon-box">
                <Icon name="phone" />
              </span>
              <h3>Nima kerak</h3>
              <ul className="check-list">
                <li>Android 7.0 yoki undan yuqori</li>
                <li>Internet (birinchi kirishda majburiy)</li>
                <li>Har bir xodim uchun alohida telefon</li>
              </ul>
            </article>

            <article className="card">
              <span className="icon-box">
                <Icon name="help" />
              </span>
              <h3>Yordam kerakmi</h3>
              <p className="muted" style={{ fontSize: '0.96rem' }}>
                O&apos;rnatish yoki sozlashda qiynalsangiz — yozing.
                Qo&apos;ng&apos;iroq orqali birga sozlab beramiz.
              </p>
              <a
                className="btn btn--ghost"
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Telegram orqali yozish
              </a>
            </article>
          </div>

          <p
            className="muted center"
            style={{ marginTop: 24, fontSize: '0.88rem' }}
          >
            iPhone uchun versiya hozircha yo&apos;q. Kerak bo&apos;lsa
            bizga ayting — talab bo&apos;yicha rejalashtiramiz.
          </p>
        </div>
      </section>
    </>
  );
}
