import { Icon, type IconName } from '@/components/Icon';

const SECTIONS: { title: string; icon: IconName; items: string[] }[] = [
  {
    title: 'Buyurtma yo\'li',
    icon: 'orders',
    items: [
      'Olib kelish yoki mijoz o\'zi keltirishi — ikkalasi ham qo\'llab-quvvatlanadi',
      'Yuvish → qadoqlash → yetgazish bosqichlari, har biri alohida bo\'lim',
      'Har bir xizmatni alohida o\'lchash va narxlash',
      'Qayta yuvishga qaytarish',
      'Buyurtma tarixi — kim, qachon, nima o\'zgartirgani saqlanadi',
    ],
  },
  {
    title: 'Xodimlar',
    icon: 'people',
    items: [
      'PIN-kod bilan tez kirish',
      'Bo\'limlar bo\'yicha vakolat: xodim faqat o\'z bo\'limida ishlaydi',
      'Qo\'shimcha huquqlar: skidka, o\'lchash, hisobot, o\'chirish va boshqalar',
      'Har bir xodimning faolligi va bajargan ishi bo\'yicha hisobot',
    ],
  },
  {
    title: 'Moliya',
    icon: 'money',
    items: [
      'To\'lov qabul qilish: naqd, karta, qisman to\'lov',
      'Qarzdorlar ro\'yxati va qarzni yopish',
      'Chiqimlarni hisobga olish',
      'Daromad hisoboti — kunlik, oylik, ixtiyoriy davr',
    ],
  },
];

export function FeaturesPage() {
  return (
    <section className="section container">
      <header className="section-head">
        <span className="eyebrow">Imkoniyatlar</span>
        <h1>Kundalik ish uchun hamma narsa</h1>
        <p>
          Xizmat biznesining har kungi jarayoni — buyurtmadan pulgacha.
        </p>
      </header>

      <div className="grid grid--3">
        {SECTIONS.map((s) => (
          <article key={s.title} className="card">
            <span className="icon-box">
              <Icon name={s.icon} />
            </span>
            <h3>{s.title}</h3>
            <ul className="check-list">
              {s.items.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </article>
        ))}
      </div>
    </section>
  );
}
