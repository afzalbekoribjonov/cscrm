import { Link } from 'react-router-dom';

import { AppMockup } from '@/components/AppMockup';
import { Icon, type IconName } from '@/components/Icon';
import { branding } from '@/lib/branding';
import { formatPrice, isPriceUnset, trialDays } from '@/lib/plans';
import { usePlans } from '@/lib/use-plans';

const FEATURES: { icon: IconName; title: string; text: string }[] = [
  {
    icon: 'orders',
    title: 'Buyurtmalarni boshqarish',
    text: 'Qabul qilishdan yetkazishgacha — har bir buyurtma qaysi bosqichda ekani doim ko\'rinib turadi.',
  },
  {
    icon: 'people',
    title: 'Xodimlar va vakolatlar',
    text: 'Har bir xodim faqat o\'z bo\'limida ishlaydi. Kim nima qilgani tarixda saqlanadi.',
  },
  {
    icon: 'money',
    title: 'Moliya va hisobot',
    text: 'Daromad, chiqim va qarzdorlar — kunlik, oylik va ixtiyoriy davr bo\'yicha.',
  },
  {
    icon: 'phone',
    title: 'Telefonda ishlaydi',
    text: 'Sexda, yo\'lda yoki mijoz oldida — hamma joyda, kompyuter oldiga borish shart emas.',
  },
  {
    icon: 'offline',
    title: 'Internetsiz ham',
    text: 'Aloqa uzilsa ish to\'xtamaydi. Yozganingiz saqlanadi va ulanish tiklanganda o\'zi yuboriladi.',
  },
  {
    icon: 'shield',
    title: 'Ma\'lumot xavfsizligi',
    text: 'Har bir biznesning ma\'lumoti butunlay alohida. Xodim PIN-kodi qurilmada emas, serverda tekshiriladi.',
  },
];

const STEPS = [
  {
    title: 'Buyurtmani qabul qiling',
    text: 'Mijoz, telefon raqami va xizmatlar. Olib kelish kerak bo\'lsa — dastavchikka topshiriladi.',
  },
  {
    title: 'Sex ishni bajaradi',
    text: 'Yuvish, qadoqlash, tayyor. Har bir xizmat alohida o\'lchanadi va narxlanadi.',
  },
  {
    title: 'Pulni yig\'ing',
    text: 'Yetkazishda naqd yoki karta. Qarz qolsa — qarzdorlar ro\'yxatida turadi va unutilmaydi.',
  },
];

const FAQ = [
  {
    q: 'Ilovadan foydalanish uchun kompyuter kerakmi?',
    a: 'Yo\'q. Butun tizim telefonda ishlaydi — xodimlar ham, boshqaruvchi ham. Kompyuter ixtiyoriy.',
  },
  {
    q: 'Internet uzilsa nima bo\'ladi?',
    a: 'Ish davom etadi. Yozgan ma\'lumotingiz telefonda saqlanadi va aloqa tiklanganda serverga o\'zi yuboriladi.',
  },
  {
    q: 'Xodimlarim boshqa bo\'limlarni ko\'ra oladimi?',
    a: 'Faqat siz ruxsat bergan bo\'limlarni. Masalan yuvishchi yetgazma bo\'limini ham, moliyani ham ko\'rmaydi.',
  },
  {
    q: 'Bir nechta xodim bir vaqtda ishlay oladimi?',
    a: 'Ha. Har biri o\'z telefonidan kiradi, o\'zgarishlar hammada darhol ko\'rinadi.',
  },
  {
    q: 'To\'lov qanday amalga oshiriladi?',
    a: 'Karta orqali o\'tkazma. Ilovada rekvizitlar ko\'rsatiladi, to\'lovni tasdiqlagach obuna darhol uzayadi.',
  },
  {
    q: 'Ma\'lumotlarim kimga ko\'rinadi?',
    a: 'Faqat sizga va siz qo\'shgan xodimlarga. Har bir biznesning ma\'lumoti alohida saqlanadi.',
  },
];

export function LandingPage() {
  // Narxlar sahifasiga ishora uchun eng ommabop reja - joriy narxi bilan.
  const { plans } = usePlans();
  const highlight = plans.find((p) => p.highlight);

  return (
    <>
      {/* ---------------- Hero ---------------- */}
      <section className="hero">
        <div className="container hero__inner">
          <div className="hero__text">
            <span className="pill">
              Gilam yuvish · Kimyoviy tozalash · Kir yuvish
            </span>

            <h1 style={{ marginTop: 18 }}>
              Xizmat biznesingizni{' '}
              <span className="text-gradient">bitta tizimdan</span> boshqaring
            </h1>

            <p className="hero__lead">
              Buyurtma qabul qilishdan pul yig'ishgacha. Daftar va telefon
              qo'ng'iroqlari o'rniga — aniq, tartibli va har doim
              qo'lingizda.
            </p>

            <div className="hero__actions">
              <Link className="btn btn--primary btn--lg" to="/narxlar">
                {trialDays} kun bepul sinab ko'rish
              </Link>
              <Link className="btn btn--ghost btn--lg" to="/imkoniyatlar">
                Imkoniyatlar
              </Link>
            </div>

            <p className="muted" style={{ marginTop: 16, fontSize: '0.9rem' }}>
              Karta kerak emas · Bir necha daqiqada ishga tushadi
            </p>
          </div>

          <AppMockup />
        </div>
      </section>

      {/* ---------------- Qanday ishlaydi ---------------- */}
      <section className="section--tight">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Qanday ishlaydi</span>
            <h2>Uchta qadam, tanish tartib</h2>
            <p>
              Tizim sizning ishingizni o'zgartirmaydi — shunchaki uni
              tartibga soladi.
            </p>
          </div>

          <div className="grid grid--3">
            {STEPS.map((step, i) => (
              <article key={step.title} className="card step">
                <span className="step__num">{i + 1}</span>
                <h3>{step.title}</h3>
                <p className="muted" style={{ margin: 0, fontSize: '0.96rem' }}>
                  {step.text}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------- Imkoniyatlar ---------------- */}
      <section className="section">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Imkoniyatlar</span>
            <h2>Kundalik ish uchun kerak bo'ladigan hamma narsa</h2>
          </div>

          <div className="grid grid--3">
            {FEATURES.map((f) => (
              <article key={f.title} className="card card--hover">
                <span className="icon-box">
                  <Icon name={f.icon} />
                </span>
                <h3>{f.title}</h3>
                <p className="muted" style={{ margin: 0, fontSize: '0.96rem' }}>
                  {f.text}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------- Narx haqida qisqacha ---------------- */}
      {highlight && !isPriceUnset(highlight) && (
        <section className="section--tight">
          <div className="container">
            <div
              className="card"
              style={{
                display: 'flex',
                gap: 24,
                flexWrap: 'wrap',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <div style={{ minWidth: 240, flex: '1 1 280px' }}>
                <span className="eyebrow">Narxlar</span>
                <h3 style={{ marginBottom: 6 }}>
                  {highlight.name} — {formatPrice(highlight)}
                </h3>
                <p className="muted" style={{ margin: 0, fontSize: '0.96rem' }}>
                  Eng ko'p tanlanadigan reja. Yashirin to'lov yo'q,
                  xohlagan paytda o'zgartirasiz.
                </p>
              </div>
              <Link className="btn btn--primary btn--lg" to="/narxlar">
                Barcha rejalar
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ---------------- Savol-javob ---------------- */}
      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="section-head">
            <span className="eyebrow">Savol-javob</span>
            <h2>Ko'p so'raladigan savollar</h2>
          </div>

          {FAQ.map((item) => (
            <details key={item.q} className="faq">
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}
        </div>
      </section>

      {/* ---------------- Yakuniy chaqiruv ---------------- */}
      <section className="section--tight">
        <div className="container">
          <div className="cta">
            <h2>Bugundan boshlang</h2>
            <p>
              {trialDays} kun bepul. Yoqsa — obuna bo'lasiz, yoqmasa hech
              narsa to'lamaysiz.
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
              <Link className="btn btn--on-brand btn--lg" to="/narxlar">
                Narxlarni ko'rish
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
