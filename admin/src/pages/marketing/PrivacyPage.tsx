import { branding } from '@/lib/branding';
import { useSeo } from '@/lib/seo';

/**
 * Maxfiylik siyosati.
 *
 * Play Store'ga ilova joylash uchun SHART: do'kon ilova qanday
 * ma'lumot yig'ishini ochiq aytilgan sahifani talab qiladi.
 *
 * Bu yerdagi har bir band ilovaning HAQIQATDA qiladigan ishiga
 * asoslangan. Umumiy shablon ko'chirib qo'yilmagan: bo'lmagan narsani
 * "yig'amiz" deb yozish ham, yig'ilayotganini yashirish ham noto'g'ri.
 */
export function PrivacyPage() {
  useSeo(
    'Maxfiylik siyosati',
    'CSCRM qanday ma\'lumotlarni yig\'adi, ularni qanday saqlaydi va kim ko\'ra oladi.',
  );

  return (
    <section className="section container prose">
      <span className="eyebrow">Huquqiy</span>
      <h1>Maxfiylik siyosati</h1>
      <p className="muted">Oxirgi yangilanish: 2026-yil 11-sentyabr</p>

      <h2>1. Kim ma&apos;lumotni qayta ishlaydi</h2>
      <p>
        {branding.fullName} xizmati (keyingi o&apos;rinlarda — CSCRM).
        Aloqa: <a href={`mailto:${branding.supportEmail}`}>{branding.supportEmail}</a>,{' '}
        <a href={branding.supportTelegram} rel="noreferrer noopener">
          Telegram
        </a>
        , {branding.supportPhone}.
      </p>

      <h2>2. Qanday ma&apos;lumot yig&apos;iladi</h2>
      <p>Ilova quyidagilarni saqlaydi:</p>
      <ul className="check-list">
        <li>
          <strong>Biznes haqida:</strong> nomi, telefon raqami, manzili,
          kirish uchun login.
        </li>
        <li>
          <strong>Xodimlar haqida:</strong> ismi, telefon raqami, vakolatlari.
          PIN-kod ochiq holda saqlanmaydi — faqat uning qaytarib bo&apos;lmaydigan
          kriptografik izi (hash) saqlanadi.
        </li>
        <li>
          <strong>Mijozlar haqida:</strong> ism, telefon raqami va manzil —
          bularni ilovaga <em>biznesning o&apos;zi</em> kiritadi.
        </li>
        <li>
          <strong>Buyurtmalar va to&apos;lovlar:</strong> xizmat turi, summa,
          bosqichlar va o&apos;zgarishlar tarixi.
        </li>
        <li>
          <strong>Qurilma belgisi:</strong> bildirishnoma yuborish uchun
          kerak bo&apos;ladigan texnik token. Unda shaxsiy ma&apos;lumot
          yo&apos;q va u ilovadan chiqilganda o&apos;chiriladi.
        </li>
      </ul>
      <p>
        Ilova joylashuvni kuzatmaydi, kontaktlar ro&apos;yxatini
        o&apos;qimaydi, rasm va fayllaringizga kirmaydi, reklama
        tarmoqlariga hech narsa uzatmaydi.
      </p>

      <h2>3. Nima uchun ishlatiladi</h2>
      <p>
        Faqat xizmatning o&apos;zi uchun: buyurtmalarni yuritish, xodimlarni
        aniqlash, hisobot chiqarish, obuna holatini tekshirish va texnik
        yordam ko&apos;rsatish. Boshqa maqsadda ishlatilmaydi.
      </p>

      <h2>4. Kim ko&apos;ra oladi</h2>
      <p>
        Har bir biznesning ma&apos;lumoti alohida saqlanadi va unga faqat
        o&apos;sha biznes egasi hamda u qo&apos;shgan xodimlar kira oladi.
        Xodim faqat o&apos;ziga ruxsat berilgan bo&apos;limni ko&apos;radi.
      </p>
      <p>
        CSCRM xodimlari sizning ma&apos;lumotingizga faqat siz texnik yordam
        so&apos;raganingizda va shu masalani hal qilish uchun zarur bo&apos;lgan
        hajmda murojaat qiladi.
      </p>
      <p>
        Ma&apos;lumot uchinchi shaxslarga sotilmaydi va berilmaydi. Yagona
        istisno — qonun talab qilgan hollarda vakolatli davlat organi
        so&apos;rovi.
      </p>
      <p>
        Telefon bilan server o&apos;rtasidagi aloqa shifrlangan (HTTPS)
        kanal orqali amalga oshiriladi.
      </p>

      <h2>5. Qancha vaqt saqlanadi</h2>
      <p>
        Hisobingiz faol bo&apos;lgan davrda va obuna tugaganidan keyin ham
        ma&apos;lumot saqlanib turadi — to&apos;lovni tiklaganingizda hammasi
        joyida bo&apos;lishi uchun. Butunlay o&apos;chirishni so&apos;rasangiz,
        murojaatdan keyin 30 kun ichida o&apos;chiramiz.
      </p>

      <h2>6. Sizning huquqlaringiz</h2>
      <ul className="check-list">
        <li>Qanday ma&apos;lumot saqlanayotganini so&apos;rash</li>
        <li>Noto&apos;g&apos;ri ma&apos;lumotni tuzatish</li>
        <li>Hisobingizni va undagi ma&apos;lumotni o&apos;chirishni talab qilish</li>
        <li>Ma&apos;lumotingiz nusxasini so&apos;rash</li>
      </ul>
      <p>
        Buning uchun yuqoridagi aloqa yo&apos;llaridan biri orqali murojaat
        qiling.
      </p>

      <h2>7. Mijozlaringiz ma&apos;lumoti haqida</h2>
      <p>
        Ilovaga o&apos;z mijozlaringizning ismi va telefon raqamini siz
        kiritasiz. Shu ma&apos;lumotni to&apos;plash va ishlatish qonuniyligi
        uchun javobgarlik biznesning o&apos;ziga tegishli. CSCRM bu
        ma&apos;lumotni faqat sizning topshirig&apos;ingiz asosida saqlaydi.
      </p>

      <h2>8. O&apos;zgarishlar</h2>
      <p>
        Siyosat o&apos;zgarsa, yangi matn shu sahifada e&apos;lon qilinadi va
        yuqoridagi sana yangilanadi. Muhim o&apos;zgarishlar haqida ilova
        ichidagi xabar orqali ham xabar beramiz.
      </p>
    </section>
  );
}
