import { Link } from 'react-router-dom';

import { Icon, type IconName } from '@/components/Icon';
import { branding } from '@/lib/branding';
import { trialDays } from '@/lib/plans';
import { useSeo } from '@/lib/seo';

/**
 * Yordam bo'limi.
 *
 * Ikki qism: BOSHLASH (ketma-ket qadamlar) va SAVOL-JAVOB (tartibsiz
 * savollar). Ular ataylab ajratilgan — birinchi marta o'rnatayotgan
 * odamga tartib kerak, keyin kelganga esa aniq bitta savolga javob.
 */

const GUIDES: {
  icon: IconName;
  title: string;
  steps: string[];
}[] = [
  {
    icon: 'download',
    title: 'Boshlash',
    steps: [
      'Ilovani yuklab oling va o\'rnating.',
      'Ro\'yxatdan o\'ting: biznes nomi, telefon raqam va parol.',
      `Sinov muddati o'zi yoqiladi — ${trialDays} kun barcha imkoniyatlar ochiq.`,
      'Mahsulot va xizmatlaringizni narxi bilan kiriting.',
    ],
  },
  {
    icon: 'people',
    title: 'Xodim qo\'shish',
    steps: [
      '«Xodimlar» bo\'limiga kiring va yangisini qo\'shing.',
      'Ism, telefon raqam va PIN-kod belgilang.',
      'Qaysi bo\'limlarda ishlashini tanlang — faqat o\'shalarni ko\'radi.',
      'Qo\'shimcha huquqlar (skidka, o\'chirish, hisobot) alohida beriladi.',
      'Xodim shu ilovani o\'z telefoniga o\'rnatib, telefon raqami va PIN bilan kiradi.',
    ],
  },
  {
    icon: 'orders',
    title: 'Birinchi buyurtma',
    steps: [
      'Mijoz ismi va telefon raqamini kiriting.',
      'Xizmatlarni tanlang, o\'lcham yoki sonini kiriting — summa o\'zi hisoblanadi.',
      'Oldindan to\'lov olsangiz, uni ham yozing.',
      'Buyurtma sexga o\'tadi va bosqichma-bosqich yuradi.',
    ],
  },
  {
    icon: 'money',
    title: 'Hisobotni o\'qish',
    steps: [
      'Yuqoridagi kalendardan davrni tanlang — kun, oy yoki ixtiyoriy oraliq.',
      'Daromad naqd va karta bo\'yicha alohida ko\'rsatiladi.',
      'Ko\'z belgisini bossangiz — qaysi buyurtmalardan yig\'ilgani chiqadi.',
      'Qarzdorlar alohida ro\'yxatda, to\'langanda o\'zi yopiladi.',
    ],
  },
];

const FAQ = [
  {
    q: 'Parolimni unutdim, nima qilay?',
    a: 'Bizga Telegram yoki telefon orqali yozing. Biznes egasi ekaningizni tekshirib, parolni yangilab beramiz.',
  },
  {
    q: 'Xodim PIN-kodini unutdi',
    a: 'Biznes egasi «Xodimlar» bo\'limidan uning PIN-kodini o\'zgartira oladi — bizga murojaat qilish shart emas.',
  },
  {
    q: 'Telefonim almashdi, ma\'lumotlarim qayerda?',
    a: 'Ma\'lumot telefonda emas, serverda saqlanadi. Yangi telefonga ilovani o\'rnatib, o\'sha login bilan kirsangiz — hammasi joyida.',
  },
  {
    q: 'Xato buyurtma kiritdim, o\'chira olamanmi?',
    a: 'Ha, agar sizda o\'chirish huquqi bo\'lsa. O\'chirilgani tarixda qoladi — kim o\'chirgani ko\'rinadi.',
  },
  {
    q: 'Bir nechta filialim bor, ularni birga yuritsam bo\'ladimi?',
    a: 'Hozircha har bir filial alohida biznes sifatida yuritiladi. Filiallarni bitta hisobda birlashtirish ustida ishlanmoqda — sizga kerak bo\'lsa ayting, bu navbatni tezlashtiradi.',
  },
  {
    q: 'Ma\'lumotlarimni yuklab olsam bo\'ladimi?',
    a: 'Hozircha ilova ichida hisobot ko\'rinishida. Alohida fayl (Excel) ko\'rinishida yuklab olish rejalashtirilgan.',
  },
  {
    q: 'Bildirishnomalar kelmayapti',
    a: 'Telefon sozlamalarida CSCRM uchun bildirishnomaga ruxsat berilganini tekshiring. Android 13 va undan yuqorisida bu ruxsat alohida so\'raladi.',
  },
];

export function HelpPage() {
  useSeo(
    'Yordam',
    'CSCRM bilan ishlashni boshlash: o\'rnatish, xodim qo\'shish, birinchi buyurtma va hisobotlar.',
  );

  return (
    <>
      <section className="section--tight">
        <div className="container" style={{ maxWidth: 880 }}>
          <div className="section-head">
            <span className="eyebrow">Yordam</span>
            <h1>Qanday boshlash kerak</h1>
            <p>
              Qisqa qo&apos;llanmalar va ko&apos;p so&apos;raladigan savollar.
              Javob topilmasa — yozing, javob beramiz.
            </p>
          </div>

          <div className="grid grid--2">
            {GUIDES.map((g) => (
              <article key={g.title} className="card" style={{ height: '100%' }}>
                <span className="icon-box">
                  <Icon name={g.icon} />
                </span>
                <h3>{g.title}</h3>
                <ol style={{ margin: 0, paddingInlineStart: 20 }}>
                  {g.steps.map((s) => (
                    <li
                      key={s}
                      className="muted"
                      style={{
                        fontSize: '0.93rem',
                        marginBottom: 7,
                        listStyle: 'decimal',
                      }}
                    >
                      {s}
                    </li>
                  ))}
                </ol>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section band">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="section-head">
            <span className="eyebrow">Savol-javob</span>
            <h2>Tez-tez so&apos;raladi</h2>
          </div>

          {FAQ.map((item) => (
            <details key={item.q} className="faq">
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="section--tight">
        <div className="container" style={{ maxWidth: 720 }}>
          <article
            className="card center"
            style={{ borderColor: 'var(--brand)' }}
          >
            <span className="icon-box" style={{ marginInline: 'auto' }}>
              <Icon name="help" />
            </span>
            <h3>Javob topilmadimi?</h3>
            <p className="muted" style={{ fontSize: '0.96rem' }}>
              Telegram orqali yozing — odatda bir necha daqiqada javob
              beramiz.
            </p>
            <div
              style={{
                display: 'flex',
                gap: 10,
                justifyContent: 'center',
                flexWrap: 'wrap',
                marginTop: 6,
              }}
            >
              <a
                className="btn btn--primary"
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Telegram
              </a>
              <Link className="btn btn--ghost" to="/aloqa">
                Boshqa aloqa yo&apos;llari
              </Link>
            </div>
          </article>
        </div>
      </section>
    </>
  );
}
