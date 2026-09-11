import { Icon, type IconName } from './Icon';

/**
 * Buyurtmaning yo'li — qabuldan pulgacha.
 *
 * Oddiy kartalar o'rniga bog'langan diagramma: bosqichlar orasidagi
 * strelka "bu ketma-ketlik" degan ma'noni beradi, alohida kartalar esa
 * "bu ro'yxat" deb o'qilardi. Ikkovining farqi muhim — tizim aynan
 * shu tartib ustiga qurilgan.
 */

const NODES: { icon: IconName; title: string; text: string }[] = [
  {
    icon: 'orders',
    title: 'Qabul',
    text: 'Mijoz, xizmatlar, o\'lcham va narx. Kerak bo\'lsa — olib kelish.',
  },
  {
    icon: 'sparkle',
    title: 'Yuvish',
    text: 'Sex ishni oladi. Har bir xizmat alohida o\'lchanadi.',
  },
  {
    icon: 'box',
    title: 'Qadoqlash',
    text: 'Tayyor buyurtma qadoqlanadi va yetgazishga o\'tadi.',
  },
  {
    icon: 'truck',
    title: 'Yetgazish',
    text: 'Dastavchik marshrutini ko\'radi, mijozga topshiradi.',
  },
  {
    icon: 'money',
    title: 'To\'lov',
    text: 'Naqd yoki karta. Qarz qolsa — ro\'yxatda turadi, unutilmaydi.',
  },
];

export function OrderFlow() {
  return (
    <ol className="flow">
      {NODES.map((n) => (
        <li key={n.title} className="flow__node">
          <span className="flow__icon">
            <Icon name={n.icon} size={19} />
          </span>
          <h3>{n.title}</h3>
          <p>{n.text}</p>
        </li>
      ))}
    </ol>
  );
}
