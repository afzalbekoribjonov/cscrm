/**
 * `database.rules.json` MANBASI.
 *
 * Nega generator: "biznes a'zosi" sharti o'ndan ortiq joyda takrorlanadi.
 * JSON'da uni qo'lda nusxalash — bir joyda tuzatib, boshqasida unutish
 * degani. Bu yerda shartlar BIR MARTA yoziladi.
 *
 *   node firebase/rules.mjs           — JSON'ni qayta yozadi
 *   node firebase/rules.mjs --check   — JSON manba bilan mosligini tekshiradi
 *
 * JSON'ni QO'LDA TAHRIRLAMANG — o'zgarish shu faylda qilinadi.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const T = "root.child('tenants').child($tenantId)";
const EMP = `${T}.child('employees').child(auth.token.employeeId)`;

/** Biznes a'zosi: ega YOKI mavjud va bloklanmagan xodim. */
export const MEMBER =
  'auth != null && auth.token.tenantId === $tenantId && ' +
  `(auth.token.role === 'owner' || (${EMP}.exists() && ${EMP}.child('active').val() !== false))`;

export const OWNER =
  "auth != null && auth.token.tenantId === $tenantId && auth.token.role === 'owner'";

/** To'xtatilgan biznes o'qiy oladi, lekin yoza olmaydi. */
export const NOT_SUSPENDED = `${T}.child('license').child('suspended').val() !== true`;

const backendOnly = (note, extra = {}) => ({
  '//': note,
  '.read': false,
  '.write': false,
  ...extra,
});

export const rules = {
  '//': [
    "CSCRM Realtime Database xavfsizlik qoidalari — KO'P IJARACHILI.",
    "MANBA: firebase/rules.mjs — bu faylni qo'lda tahrirlamang.",
    '',
    "ASOSIY G'OYA: har bir biznes = bitta `tenant`. Foydalanuvchi FAQAT o'z",
    "tenant'ining ma'lumotini ko'radi (`auth.token.tenantId` — uni faqat",
    "backend (Admin SDK) qo'ya oladi).",
    '',
    "A'ZO = ega YOKI mavjud va bloklanmagan xodim. Token da'vosining o'zi",
    "yetarli emas: o'chirilgan xodimning telefonidagi token yangilanishda",
    "davom etadi. `active !== false` — eski yozuvlarda maydon bo'lmasligi mumkin.",
    '',
    "MEROS QOIDASI: ota tugunda berilgan ruxsat bolalarga o'tadi va bola",
    "darajasida BEKOR QILIB BO'LMAYDI. Shu sababli yozish ruxsati ro'yxat",
    'tugunida emas, har bir YOZUV darajasida (`$orderId` va h.k.) beriladi.',
    '',
    "TO'XTATILGAN BIZNES (`license/suspended`) o'qiy oladi, yoza olmaydi.",
    'Muddat tugashi bu yerda ATAYLAB tekshirilmaydi — uni server imzolagan',
    'javob orqali ilova hal qiladi.',
  ],

  rules: {
    '.read': false,
    '.write': false,

    super_admins: {
      $uid: { '.read': 'auth != null && auth.uid === $uid', '.write': false },
    },

    admin_logins: { $login: { '.read': false, '.write': false } },

    employee_phone_index: backendOnly(
      "Telefon -> tenant xaritasi. Ochiq bo'lsa, barcha xodim raqamlarini yig'ib olish mumkin bo'lardi.",
    ),

    employee_secrets: backendOnly(
      "Xodimlarning PIN hashlari. Avval xodim yozuvi ichida `.read: false` bilan turardi — lekin ota `employees` ochiq bo'lgani uchun bu ishlamasdi (meros qoidasi). Endi alohida, mijozga butunlay berk tugunda.",
    ),

    user_tenants: {
      $uid: { '.read': 'auth != null && auth.uid === $uid', '.write': false },
    },

    tenant_directory: backendOnly("Bizneslar ID'lari — super-admin paneli uchun."),

    pending_payments: backendOnly("Ko'rib chiqilmagan to'lov so'rovlari navbati.", {
      '.indexOn': ['tenantId'],
    }),

    broadcasts: backendOnly(
      "CSCRM xabarlari. Ilova ularni `/license/messages` orqali oladi — u yerda ichki maydonlar (yuborgan admin UID'i) olib tashlanadi. Ilova bu tugunni hech qachon to'g'ridan-to'g'ri o'qimagan.",
      { '.indexOn': ['createdAt'] },
    ),

    push_tokens: backendOnly('Qurilma FCM tokenlari.'),
    plan_prices: backendOnly('Reja narxlari. Ilova ularni `/license/plans` orqali oladi.'),
    site_settings: backendOnly('Websayt sozlamalari.'),
    payments_log: backendOnly("Tasdiqlangan to'lovlar — daromad statistikasi.", {
      '.indexOn': ['at'],
    }),

    tenants: {
      $tenantId: {
        profile: {
          '//': "Mijoz YOZA OLMAYDI. `ownerUid` ni mijoz o'zgartira olishi hisobni egallash zanjiriga yo'l ochardi. Ilova profilga hech qachon yozmagan; tahrirlash backend orqali.",
          '.read': MEMBER,
          '.write': false,
        },

        license: { '.read': MEMBER, '.write': false },
        members: { '.read': MEMBER, '.write': false },

        employees: {
          '.read': MEMBER,
          '.write': `${OWNER} && ${NOT_SUSPENDED}`,
          '.indexOn': ['phone', 'active'],
          $employeeId: {
            '//': "Xodim O'Z yozuvini bloklangan bo'lsa ham o'qiy oladi: ilova shu yozuvni kuzatib, `active: false` ni ko'rgach xodimni toza chiqarib yuboradi.",
            '.read':
              'auth != null && auth.token.tenantId === $tenantId && auth.token.employeeId === $employeeId',
          },
        },

        products: { '.read': MEMBER, '.write': `${OWNER} && ${NOT_SUSPENDED}` },

        counters: {
          '.read': MEMBER,
          $counter: {
            '//': "Faqat O'SADI va o'chirilmaydi — aks holda keyingi buyurtma mavjud buyurtma raqamini olib, uning ustidan yozilardi. `!data.isNumber()` — eski matnli qiymatni ilova o'zi tuzatadi.",
            '.write': `${MEMBER} && ${NOT_SUSPENDED} && newData.exists()`,
            '.validate':
              'newData.isNumber() && (!data.exists() || !data.isNumber() || newData.val() > data.val())',
          },
        },

        orders: {
          '//': "Yozish har bir BUYURTMA darajasida: butun ro'yxatni bitta so'rov bilan o'chirib bo'lmaydi.",
          '.read': MEMBER,
          '.indexOn': ['active', 'status', 'createdAt', 'deliveredAt', 'createdBy', 'debtAmount'],
          $orderId: { '.write': `${MEMBER} && ${NOT_SUSPENDED}` },
        },

        expenses: {
          '.read': MEMBER,
          '.indexOn': ['spentAt'],
          $expenseId: { '.write': `${MEMBER} && ${NOT_SUSPENDED}` },
        },

        order_history: {
          '//': "O'zgarishlar jurnali — FAQAT QO'SHILADI. Mavjud yozuvni o'zgartirib yoki o'chirib bo'lmaydi. Ilova har doim yangi (push) kalitga yozadi.",
          '.read': MEMBER,
          '.indexOn': ['orderId', 'at'],
          $entryId: { '.write': `${MEMBER} && ${NOT_SUSPENDED} && !data.exists()` },
        },

        payments: { '.read': MEMBER, '.write': false },
        payment_requests: { '.read': MEMBER, '.write': false },

        $other: { '.validate': false },
      },
    },
  },
};

const out = join(dirname(fileURLToPath(import.meta.url)), 'database.rules.json');
const json = `${JSON.stringify(rules, null, 2)}\n`;
const isMain = process.argv[1] === fileURLToPath(import.meta.url);

if (isMain && process.argv.includes('--check')) {
  const current = readFileSync(out, 'utf8').split('\r\n').join('\n');
  if (current !== json) {
    console.error('database.rules.json manbadan farq qiladi: node firebase/rules.mjs');
    process.exit(1);
  }
  console.log('database.rules.json — manba bilan mos');
} else if (isMain) {
  writeFileSync(out, json);
  console.log(`yozildi: ${out}`);
}
