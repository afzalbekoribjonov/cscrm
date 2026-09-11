import { Link } from 'react-router-dom';

import { AppDemo } from '@/components/AppDemo';
import { Icon, type IconName } from '@/components/Icon';
import { OrderFlow } from '@/components/OrderFlow';
import { ReportsPreview } from '@/components/ReportsPreview';
import { Reveal } from '@/components/Reveal';
import { SavingsCalculator } from '@/components/SavingsCalculator';
import { branding } from '@/lib/branding';
import { formatPrice, isPriceUnset, monthlyPrice, trialDays } from '@/lib/plans';
import { useSeo } from '@/lib/seo';
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

/* Ishonch qatori ATAYLAB "500+ mijoz" kabi raqamlardan iborat emas:
   bunday raqamni tekshirib bo'lmaydi va u to'g'ri bo'lmasa keyin
   o'zimizga qarshi ishlaydi. Bu yerdagi hamma narsa — mahsulotning
   o'zi haqidagi tekshirsa bo'ladigan fakt. */
const TRUST: { num: string; label: string }[] = [
  { num: `${trialDays} kun`, label: 'bepul sinov' },
  { num: 'Cheksiz', label: 'xodim va buyurtma' },
  { num: 'Internetsiz', label: 'ham ishlaydi' },
  { num: '3 soha', label: 'uchun moslangan' },
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
    a: 'Karta orqali o\'tkazma. Rekvizitlarni Telegram yoki telefon orqali beramiz, to\'lov tasdiqlangach obuna darhol uzayadi.',
  },
  {
    q: 'Ma\'lumotlarim kimga ko\'rinadi?',
    a: 'Faqat sizga va siz qo\'shgan xodimlarga. Har bir biznesning ma\'lumoti alohida saqlanadi.',
  },
];

export function LandingPage() {
  useSeo(
    'Xizmat biznesi uchun boshqaruv tizimi',
    'Gilam yuvish, kimyoviy tozalash va kir yuvish bizneslari uchun CRM: buyurtma, xodim, moliya va hisobot — hammasi telefonda.',
  );

  // Narxlar sahifasiga ishora uchun eng ommabop reja — joriy narxi bilan.
  const { plans } = usePlans();
  const highlight = plans.find((p) => p.highlight);

  return (
    <>
      {/* ---------------- Hero ---------------- */}
      <section className="hero">
        <div className="container hero__inner hero__inner--solo">
          <div className="hero__text">
            <span className="pill">
              <Icon name="sparkle" size={15} />
              Gilam yuvish · Kimyoviy tozalash · Kir yuvish
            </span>

            <h1 style={{ marginTop: 18 }}>
              Xizmat biznesingizni{' '}
              <span className="text-gradient">bitta tizimdan</span> boshqaring
            </h1>

            <p className="hero__lead">
              Buyurtma qabul qilishdan pul yig&apos;ishgacha. Daftar va telefon
              qo&apos;ng&apos;iroqlari o&apos;rniga — aniq, tartibli va har doim
              qo&apos;lingizda.
            </p>

            <div className="hero__actions">
              <Link className="btn btn--primary btn--lg" to="/yuklab-olish">
                <Icon name="download" size={19} />
                Ilovani yuklab olish
              </Link>
              <Link className="btn btn--ghost btn--lg" to="/narxlar">
                Narxlar
              </Link>
            </div>

            <p className="muted" style={{ marginTop: 16, fontSize: '0.9rem' }}>
              {trialDays} kun bepul · Karta kerak emas · Bir necha daqiqada ishga
              tushadi
            </p>
          </div>
        </div>
      </section>

      {/* Demo hero'dan ALOHIDA bo'lim: u o'zi ikki ustunli (telefon va
          tugmalar), hero ichiga qo'yilsa ikkalasi ham siqilib qolardi. */}
      <section className="section--tight" style={{ paddingTop: 0 }}>
        <div className="container">
          <AppDemo />
        </div>
      </section>

      <div className="container">
        <div className="trust">
          {TRUST.map((t) => (
            <div key={t.label} className="trust__item">
              <div className="trust__num">{t.num}</div>
              <div className="trust__label">{t.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* ---------------- Buyurtma yo'li ---------------- */}
      <section className="section--tight">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Qanday ishlaydi</span>
            <h2>Buyurtmaning yo&apos;li</h2>
            <p>
              Tizim sizning ishingizni o&apos;zgartirmaydi — shunchaki uni
              tartibga soladi.
            </p>
          </div>

          <Reveal>
            <OrderFlow />
          </Reveal>
        </div>
      </section>

      {/* ---------------- Hisobotlar ---------------- */}
      <section className="section band">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Hisobotlar</span>
            <h2>Biznesingiz raqamlarda</h2>
            <p>
              Kassani kechqurun sanab chiqish shart emas — daromad, qarzdorlik
              va buyurtmalar holati har doim oldingizda.
            </p>
          </div>

          <Reveal>
            <ReportsPreview />
          </Reveal>

          <p
            className="muted center"
            style={{ fontSize: '0.84rem', marginTop: 18 }}
          >
            Namuna ma&apos;lumot — haqiqiy mijoz va summalar ko&apos;rsatilmagan.
          </p>
        </div>
      </section>

      {/* ---------------- Imkoniyatlar ---------------- */}
      <section className="section">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Imkoniyatlar</span>
            <h2>Kundalik ish uchun kerak bo&apos;ladigan hamma narsa</h2>
          </div>

          <div className="grid grid--3">
            {FEATURES.map((f, i) => (
              <Reveal key={f.title} delay={i * 60}>
                <article className="card card--hover" style={{ height: '100%' }}>
                  <span className="icon-box">
                    <Icon name={f.icon} />
                  </span>
                  <h3>{f.title}</h3>
                  <p className="muted" style={{ margin: 0, fontSize: '0.96rem' }}>
                    {f.text}
                  </p>
                </article>
              </Reveal>
            ))}
          </div>

          <p className="center" style={{ marginTop: 28 }}>
            <Link className="btn btn--ghost" to="/imkoniyatlar">
              Batafsil ro&apos;yxat
              <Icon name="arrow-right" size={18} />
            </Link>
          </p>
        </div>
      </section>

      {/* ---------------- Kalkulyator ---------------- */}
      <section className="section band">
        <div className="container">
          <div className="section-head">
            <span className="eyebrow">Hisob-kitob</span>
            <h2>Tartibsizlik qancha turadi?</h2>
            <p>
              Slayderlarni o&apos;z biznesingizga moslang — quyidagi raqam
              o&apos;zi hisoblanadi.
            </p>
          </div>

          <Reveal>
            <SavingsCalculator />
          </Reveal>
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
                  Eng ko&apos;p tanlanadigan reja
                  {monthlyPrice(highlight) && `, ${monthlyPrice(highlight)}`}.
                  Yashirin to&apos;lov yo&apos;q.
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
            <h2>Ko&apos;p so&apos;raladigan savollar</h2>
          </div>

          {FAQ.map((item) => (
            <details key={item.q} className="faq">
              <summary>{item.q}</summary>
              <p>{item.a}</p>
            </details>
          ))}

          <p className="center" style={{ marginTop: 24 }}>
            <Link className="btn btn--ghost" to="/yordam">
              Yordam bo&apos;limi
              <Icon name="arrow-right" size={18} />
            </Link>
          </p>
        </div>
      </section>

      {/* ---------------- Yakuniy chaqiruv ---------------- */}
      <section className="section--tight">
        <div className="container">
          <div className="cta">
            <h2>Bugundan boshlang</h2>
            <p>
              {trialDays} kun bepul. Yoqsa — obuna bo&apos;lasiz, yoqmasa hech
              narsa to&apos;lamaysiz.
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
                <Icon name="download" size={19} />
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
