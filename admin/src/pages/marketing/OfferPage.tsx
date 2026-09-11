import { Link } from 'react-router-dom';

import { branding } from '@/lib/branding';
import { trialDays, warnBeforeDays } from '@/lib/plans';
import { useSeo } from '@/lib/seo';

/**
 * Ommaviy oferta — xizmatdan foydalanish shartlari.
 *
 * To'lov qabul qilish uchun kerak: shartlar qayerdadir yozilgan
 * bo'lishi va foydalanuvchi ularni ko'ra olishi lozim.
 *
 * Muddatlar (sinov kunlari, ogohlantirish kunlari) matnga QO'LDA
 * yozilmaydi — ular `shared/plans.json` dan olinadi. Aks holda fayl
 * o'zgarganda hujjatdagi va'da haqiqatdan ajralib qolardi.
 */
export function OfferPage() {
  useSeo(
    'Ommaviy oferta',
    'CSCRM xizmatidan foydalanish shartlari: obuna, to\'lov, javobgarlik va bekor qilish tartibi.',
  );

  return (
    <section className="section container prose">
      <span className="eyebrow">Huquqiy</span>
      <h1>Ommaviy oferta</h1>
      <p className="muted">Oxirgi yangilanish: 2026-yil 11-sentyabr</p>

      <p>
        Ushbu hujjat {branding.fullName} xizmatidan foydalanish shartlarini
        belgilaydi. Ilovadan foydalanishni boshlash — quyidagi shartlarga
        rozilik bildirish demakdir.
      </p>

      <h2>1. Xizmatning mohiyati</h2>
      <p>
        CSCRM — xizmat ko&apos;rsatuvchi bizneslar (gilam yuvish, kimyoviy
        tozalash, kir yuvish va shunga o&apos;xshash) uchun buyurtma, xodim
        va moliya hisobini yuritish dasturi. Xizmat obuna asosida
        beriladi.
      </p>

      <h2>2. Sinov muddati</h2>
      <p>
        Ro&apos;yxatdan o&apos;tgan har bir biznes {trialDays} kun davomida
        barcha imkoniyatlardan bepul foydalanadi. Sinov muddati uchun karta
        ma&apos;lumoti so&apos;ralmaydi va u <strong>o&apos;zi pulli obunaga
        aylanmaydi</strong>.
      </p>

      <h2>3. Obuna va to&apos;lov</h2>
      <ul className="check-list">
        <li>
          Rejalar va joriy narxlar <Link to="/narxlar">narxlar sahifasida</Link>{' '}
          ko&apos;rsatilgan.
        </li>
        <li>
          To&apos;lov oldindan, tanlangan muddat uchun to&apos;liq amalga
          oshiriladi.
        </li>
        <li>
          To&apos;lov usuli — karta orqali o&apos;tkazma. Rekvizitlar
          Telegram yoki telefon orqali beriladi.
        </li>
        <li>
          To&apos;lov tasdiqlangach obuna muddati darhol uzaytiriladi.
        </li>
        <li>
          Obuna <strong>o&apos;zi yangilanmaydi</strong>: har bir keyingi
          muddat uchun to&apos;lovni siz o&apos;zingiz amalga oshirasiz.
        </li>
      </ul>

      <h2>4. Muddat tugagandan keyin</h2>
      <p>
        Obuna muddati tugagan zahoti ilova vaqtincha bloklanadi —{' '}
        <strong>qo&apos;shimcha vaqt berilmaydi</strong>. Muddat
        tugashidan {warnBeforeDays.join(', ')} kun oldin ogohlantirish
        ko&apos;rsatiladi.
      </p>
      <p>
        Bloklanish <strong>ma&apos;lumotlaringizga tegmaydi</strong>: ular
        o&apos;chirilmaydi va to&apos;lov qilganingizdan keyin hammasi
        joyida qoladi.
      </p>

      <h2>5. Narx o&apos;zgarishi</h2>
      <p>
        Narxni o&apos;zgartirish huquqini saqlab qolamiz. Yangi narx faqat
        keyingi to&apos;lovga tegishli bo&apos;ladi — allaqachon
        to&apos;langan muddat qayta hisoblanmaydi.
      </p>

      <h2>6. Pulni qaytarish</h2>
      <p>
        Xizmat bizning aybimiz bilan uzoq muddat ishlamay qolsa,
        foydalanilmagan kunlar uchun to&apos;lovni qaytaramiz yoki obuna
        muddatini shuncha kunga uzaytiramiz — tanlov sizniki. Fikringiz
        o&apos;zgargani sababli to&apos;lov qaytarilmaydi; aynan shuning
        uchun {trialDays} kunlik bepul sinov beriladi.
      </p>

      <h2>7. Foydalanuvchining majburiyatlari</h2>
      <ul className="check-list">
        <li>
          Kirish ma&apos;lumotlarini (login, parol, PIN-kod) sir tutish.
        </li>
        <li>
          Xizmatdan qonunga zid maqsadda foydalanmaslik.
        </li>
        <li>
          Ilovaning ishlashiga xalaqit beradigan harakatlar qilmaslik.
        </li>
        <li>
          Mijozlar ma&apos;lumotini to&apos;plash qonuniyligini
          ta&apos;minlash.
        </li>
      </ul>

      <h2>8. Javobgarlik chegarasi</h2>
      <p>
        Xizmat internetga, bulut infratuzilmasiga va mobil aloqa
        operatorlariga tayanadi. Bizga bog&apos;liq bo&apos;lmagan
        uzilishlar uchun javobgar emasmiz, lekin ularni imkon qadar tez
        bartaraf etishga harakat qilamiz.
      </p>
      <p>
        Javobgarligimizning umumiy chegarasi — oxirgi 12 oy ichida
        to&apos;langan obuna summasi.
      </p>

      <h2>9. Ma&apos;lumot xavfsizligi</h2>
      <p>
        Ma&apos;lumotlar qanday saqlanishi va kim ko&apos;ra olishi{' '}
        <Link to="/maxfiylik">maxfiylik siyosatida</Link> batafsil
        yozilgan.
      </p>

      <h2>10. Xizmatni to&apos;xtatish</h2>
      <p>
        Foydalanuvchi xohlagan paytda foydalanishni to&apos;xtatishi
        mumkin — buning uchun shunchaki keyingi to&apos;lovni amalga
        oshirmaslik yetarli.
      </p>
      <p>
        Biz esa ushbu shartlar qo&apos;pol buzilgan hollarda xizmatni
        to&apos;xtatishimiz mumkin. Bunday holatda sabab yozma ravishda
        bildiriladi va foydalanilmagan kunlar uchun to&apos;lov
        qaytariladi.
      </p>

      <h2>11. Aloqa</h2>
      <p>
        {branding.supportPhone} ·{' '}
        <a href={`mailto:${branding.supportEmail}`}>{branding.supportEmail}</a>{' '}
        ·{' '}
        <a href={branding.supportTelegram} rel="noreferrer noopener">
          Telegram
        </a>
      </p>
    </section>
  );
}
