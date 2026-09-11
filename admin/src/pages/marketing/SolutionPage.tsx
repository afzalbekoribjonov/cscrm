import { Link } from 'react-router-dom';

import { Icon, type IconName } from '@/components/Icon';
import { OrderFlow } from '@/components/OrderFlow';
import { Reveal } from '@/components/Reveal';
import { branding } from '@/lib/branding';
import { trialDays } from '@/lib/plans';
import { useSeo } from '@/lib/seo';

/**
 * Soha sahifalari — bitta shablon, uchta mazmun.
 *
 * NEGA ALOHIDA SAHIFA: gilam yuvuvchi "gilam m² bo'yicha hisoblanadi"
 * deb qidiradi, kir yuvuvchi esa "kg bo'yicha". Bitta umumiy sahifa
 * ikkovining ham tilida gapira olmaydi — u "xizmat biznesi" degan
 * mavhum iborada qolib ketadi. Har biriga o'z sahifasi berilganda esa
 * odam o'zining kundalik muammosini o'qiydi.
 *
 * Mazmun O'YLAB TOPILGAN imkoniyat emas: har bir gap ilovada
 * haqiqatan bor narsaga tayanadi.
 */

export interface SolutionContent {
  slug: string;
  title: string;
  seoTitle: string;
  seoDescription: string;
  lead: string;
  /** Shu sohaning kundalik og'riqlari va tizim ularni qanday yopishi. */
  pains: { icon: IconName; problem: string; answer: string }[];
  /** Aynan shu soha uchun muhim bo'lgan imkoniyatlar. */
  highlights: string[];
}

export const SOLUTIONS: SolutionContent[] = [
  {
    slug: 'gilam-yuvish',
    title: 'Gilam yuvish bizneslari uchun',
    seoTitle: 'Gilam yuvish uchun CRM',
    seoDescription:
      'Gilam yuvish sexi uchun boshqaruv tizimi: m² bo\'yicha o\'lchash, olib kelish-eltib berish, qarzdorlar va kunlik hisobot.',
    lead: 'O\'lchash, yuvish, qadoqlash va yetgazish — har bir gilam qayerdaligi doim ko\'rinib turadi.',
    pains: [
      {
        icon: 'orders',
        problem: 'Gilam kimniki ekani chalkashadi',
        answer:
          'Har bir gilam buyurtma raqamiga bog\'lanadi. Sexdagi xodim telefonida kimning gilami, necha m² va qaysi bosqichda ekanini ko\'radi.',
      },
      {
        icon: 'money',
        problem: 'O\'lcham qo\'lda hisoblanadi va xato ketadi',
        answer:
          'Uzunlik va enini kiritasiz — m² va summa o\'zi hisoblanadi. Kim o\'lchaganini tizim eslab qoladi.',
      },
      {
        icon: 'truck',
        problem: 'Olib kelish va eltib berish yozilmay qoladi',
        answer:
          'Dastavchik o\'z ro\'yxatini ko\'radi: manzil, telefon, olinadigan summa. Topshirgach belgilaydi — siz darhol bilasiz.',
      },
      {
        icon: 'clock',
        problem: 'Qarz unutiladi',
        answer:
          'Qisman to\'langan buyurtma avtomatik qarzdorlar ro\'yxatiga tushadi va yopilmaguncha u yerdan chiqmaydi.',
      },
    ],
    highlights: [
      'm² bo\'yicha o\'lchash va narxlash',
      'Yuvish → qadoqlash → tayyor bosqichlari',
      'Qayta yuvishga qaytarish',
      'Kunlik yuvilgan hajm (m²) hisoboti',
      'Olib kelish va eltib berish marshruti',
    ],
  },
  {
    slug: 'kimyoviy-tozalash',
    title: 'Kimyoviy tozalash uchun',
    seoTitle: 'Kimyoviy tozalash uchun CRM',
    seoDescription:
      'Kimyoviy tozalash uchun boshqaruv tizimi: buyurtmalar, shoshilinch ishlar, xodim vakolatlari va moliya hisoboti.',
    lead: 'Har bir buyum alohida hisobda: qabuldan topshirishgacha yo\'qolmaydi va chalkashmaydi.',
    pains: [
      {
        icon: 'orders',
        problem: 'Buyum dona bo\'yicha yoziladi, daftarda esa chalkashadi',
        answer:
          'Har bir xizmat alohida qator: nomi, soni, narxi. Bitta buyurtmada nechta buyum bo\'lsa ham hammasi ko\'rinadi.',
      },
      {
        icon: 'clock',
        problem: 'Shoshilinch buyurtma unutiladi',
        answer:
          'Buyurtma qachon qabul qilingani va qaysi bosqichda ekani doim ko\'rinib turadi — eng eskisi ro\'yxatning tepasida.',
      },
      {
        icon: 'people',
        problem: 'Kim nima qilganini bilib bo\'lmaydi',
        answer:
          'Har bir o\'zgarish tarixda qoladi: kim qabul qildi, kim tozaladi, kim topshirdi.',
      },
      {
        icon: 'money',
        problem: 'Kun oxirida kassa to\'g\'ri kelmaydi',
        answer:
          'Naqd va karta alohida hisoblanadi. Chiqim ham yoziladi — kunlik natija o\'zi chiqadi.',
      },
    ],
    highlights: [
      'Dona bo\'yicha xizmat va narx',
      'Bo\'limlar bo\'yicha xodim vakolatlari',
      'Buyurtma tarixi — kim, qachon, nima',
      'Naqd va karta bo\'yicha kunlik hisobot',
      'Chiqimlarni yuritish',
    ],
  },
  {
    slug: 'kir-yuvish',
    title: 'Kir yuvish xizmatlari uchun',
    seoTitle: 'Kir yuvish uchun CRM',
    seoDescription:
      'Kir yuvish xizmati uchun boshqaruv tizimi: doimiy mijozlar, hajm bo\'yicha hisob, yetgazish va qarzdorlar.',
    lead: 'Doimiy mijozlar, takrorlanadigan buyurtmalar va kunlik hajm — hammasi bir joyda.',
    pains: [
      {
        icon: 'people',
        problem: 'Doimiy mijoz har safar qaytadan yoziladi',
        answer:
          'Mijoz bir marta kiritiladi. Keyingi safar ismini yozsangiz — telefoni va manzili o\'zi tortib olinadi.',
      },
      {
        icon: 'chart',
        problem: 'Kuniga qancha ish bajarilgani noma\'lum',
        answer:
          'Kunlik hajm ko\'rsatkichi: nechta buyurtma qabul qilindi, nechtasi yuvildi, nechtasi topshirildi.',
      },
      {
        icon: 'truck',
        problem: 'Yetgazish tartibsiz',
        answer:
          'Tayyor buyurtmalar yetgazish ro\'yxatiga o\'zi tushadi. Dastavchik manzil va olinadigan summani ko\'radi.',
      },
      {
        icon: 'offline',
        problem: 'Sexda internet yo\'q',
        answer:
          'Ilova internetsiz ham ishlaydi. Yozganingiz telefonda saqlanadi va aloqa tiklanganda o\'zi yuboriladi.',
      },
    ],
    highlights: [
      'Mijozlar bazasi va takroriy buyurtma',
      'Hajm va og\'irlik bo\'yicha narxlash',
      'Yetgazish ro\'yxati va to\'lov',
      'Qarzdorlar nazorati',
      'Internetsiz ishlash',
    ],
  },
];

export function SolutionPage({ content }: { content: SolutionContent }) {
  useSeo(content.seoTitle, content.seoDescription);

  return (
    <>
      <section className="section--tight">
        <div className="container" style={{ maxWidth: 880 }}>
          <div className="section-head">
            <span className="eyebrow">Yechim</span>
            <h1>{content.title}</h1>
            <p>{content.lead}</p>
          </div>

          <div
            style={{
              display: 'flex',
              gap: 12,
              justifyContent: 'center',
              flexWrap: 'wrap',
            }}
          >
            <Link className="btn btn--primary btn--lg" to="/yuklab-olish">
              <Icon name="download" size={19} />
              Ilovani yuklab olish
            </Link>
            <Link className="btn btn--ghost btn--lg" to="/narxlar">
              Narxlar
            </Link>
          </div>
          <p
            className="muted center"
            style={{ marginTop: 14, fontSize: '0.9rem' }}
          >
            {trialDays} kun bepul · Karta kerak emas
          </p>
        </div>
      </section>

      <section className="section band">
        <div className="container" style={{ maxWidth: 900 }}>
          <div className="section-head">
            <span className="eyebrow">Kundalik muammolar</span>
            <h2>Tanish holatlar</h2>
          </div>

          <div className="grid grid--2">
            {content.pains.map((p, i) => (
              <Reveal key={p.problem} delay={i * 60}>
                <article className="card" style={{ height: '100%' }}>
                  <span className="icon-box">
                    <Icon name={p.icon} />
                  </span>
                  <h3>{p.problem}</h3>
                  <p
                    className="muted"
                    style={{ margin: 0, fontSize: '0.95rem' }}
                  >
                    {p.answer}
                  </p>
                </article>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Qanday ishlaydi</span>
            <h2>Buyurtmaning yo&apos;li</h2>
          </div>
          <Reveal>
            <OrderFlow />
          </Reveal>
        </div>
      </section>

      <section className="section--tight">
        <div className="container" style={{ maxWidth: 720 }}>
          <article className="card">
            <h3>Shu soha uchun muhimi</h3>
            <ul className="check-list" style={{ marginTop: 12 }}>
              {content.highlights.map((h) => (
                <li key={h}>{h}</li>
              ))}
            </ul>
          </article>
        </div>
      </section>

      <section className="section--tight">
        <div className="container">
          <div className="cta">
            <h2>Sinab ko&apos;ring</h2>
            <p>
              {trialDays} kun bepul. Savolingiz bo&apos;lsa — yozing, birga
              sozlab beramiz.
            </p>
            <div
              style={{
                display: 'flex',
                gap: 12,
                justifyContent: 'center',
                flexWrap: 'wrap',
                marginTop: 22,
              }}
            >
              <Link className="btn btn--on-brand btn--lg" to="/yuklab-olish">
                Ilovani yuklab olish
              </Link>
              <a
                className="btn btn--outline-light btn--lg"
                href={branding.supportTelegram}
                rel="noreferrer noopener"
              >
                Savol berish
              </a>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
