const SECTIONS = [
  {
    title: 'Buyurtma yo\'li',
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
    items: [
      'PIN-kod bilan tez kirish',
      'Bo\'limlar bo\'yicha vakolat: xodim faqat o\'z bo\'limida ishlaydi',
      'Qo\'shimcha huquqlar: skidka, o\'lchash, hisobot, o\'chirish va boshqalar',
      'Har bir xodimning faolligi va bajargan ishi bo\'yicha hisobot',
    ],
  },
  {
    title: 'Moliya',
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
    <section className="container" style={{ paddingBlock: 56 }}>
      <header style={{ textAlign: 'center', marginBottom: 40 }}>
        <h1>Imkoniyatlar</h1>
        <p className="muted" style={{ fontSize: 18, maxWidth: 600, marginInline: 'auto' }}>
          Xizmat biznesining kundalik ishi uchun kerak bo'ladigan hamma narsa.
        </p>
      </header>

      <div
        style={{
          display: 'grid',
          gap: 18,
          gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
        }}
      >
        {SECTIONS.map((s) => (
          <article key={s.title} className="card">
            <h3>{s.title}</h3>
            <ul style={{ margin: 0, paddingInlineStart: 20 }}>
              {s.items.map((item) => (
                <li key={item} className="muted" style={{ fontSize: 15, marginBottom: 6 }}>
                  {item}
                </li>
              ))}
            </ul>
          </article>
        ))}
      </div>
    </section>
  );
}
