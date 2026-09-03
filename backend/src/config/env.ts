import 'dotenv/config';
import { z } from 'zod';

/**
 * Server sozlamalari. Ishga tushishda BIR MARTA tekshiriladi - noto'g'ri
 * sozlama bilan server umuman ko'tarilmaydi (kech qolib, ish vaqtida
 * `undefined` bo'lib chiqishidan ko'ra shu yaxshi).
 */
const schema = z.object({
  NODE_ENV: z
    .enum(['development', 'production', 'test'])
    .default('development'),

  // Render `PORT` ni o'zi beradi - qattiq yozmaymiz.
  PORT: z.coerce.number().int().positive().default(8080),

  /** Vergul bilan ajratilgan ruxsat etilgan origin'lar (admin websayt). */
  CORS_ORIGINS: z.string().default('http://localhost:5173'),

  // --- Firebase Admin SDK ---
  /** Service account JSON, bitta qatorga siqilgan holda. */
  FIREBASE_SERVICE_ACCOUNT: z.string().min(2),
  FIREBASE_DATABASE_URL: z.string().url(),

  /**
   * Litsenziya imzosi uchun maxfiy kalit (HMAC-SHA256, base64 yoki hex).
   * Kamida 32 bayt bo'lishi shart - qisqa kalit imzoni zaif qiladi.
   */
  LICENSE_SIGNING_SECRET: z.string().min(32),

  /** Super-admin panelga kirish uchun ruxsat etilgan Firebase UID'lar. */
  SUPER_ADMIN_UIDS: z.string().default(''),

  // --- To'lov ma'lumotlari (ilovadagi to'lov ekranida ko'rsatiladi) ---
  // To'lov usuli: qo'lda karta o'tkazma. Bu qiymatlar kodda emas,
  // sozlamada turadi - karta almashsa, ilovani qayta yig'ish shart emas.
  /**
   * Kartalar - vergul bilan. Turi (Humo/Uzcard) RAQAMDAN aniqlanadi,
   * shuning uchun bu yerda yorliq yozilmaydi.
   *   PAYMENT_CARDS=9860 1234 5678 9012, 5614 1234 5678 9012
   */
  PAYMENT_CARDS: z.string().default(''),
  PAYMENT_CARD_HOLDER: z.string().default(''),
  PAYMENT_PHONE: z.string().default(''),
  PAYMENT_EMAIL: z.string().default(''),
  PAYMENT_TELEGRAM: z.string().default(''),
  /** To'lov qanday tasdiqlanishi haqida qisqa izoh. */
  PAYMENT_NOTE: z
    .string()
    .default(
      'To\'lovni amalga oshirgach chekni yuboring — hisobingiz 1 soat ichida faollashtiriladi.',
    ),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((i) => `  - ${i.path.join('.') || '(root)'}: ${i.message}`)
    .join('\n');
  // eslint-disable-next-line no-console
  console.error(
    `\n[cscrm] Sozlamalar noto'g'ri. .env faylini tekshiring ` +
      `(namuna: .env.example):\n${issues}\n`,
  );
  process.exit(1);
}

const raw = parsed.data;

export const env = {
  ...raw,
  isProd: raw.NODE_ENV === 'production',
  corsOrigins: raw.CORS_ORIGINS.split(',')
    .map((o) => o.trim())
    .filter(Boolean),
  superAdminUids: new Set(
    raw.SUPER_ADMIN_UIDS.split(',')
      .map((u) => u.trim())
      .filter(Boolean),
  ),
} as const;

export type Env = typeof env;
