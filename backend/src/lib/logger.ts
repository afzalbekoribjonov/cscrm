import type { LoggerOptions } from 'pino';

/**
 * Loglarga HECH QACHON tushmasligi kerak bo'lgan maydonlar.
 *
 * pino-http har bir so'rovning sarlavhalarini TO'LIQ yozadi, shu
 * jumladan `authorization: Bearer <token>`. Firebase ID tokeni bir soat
 * yaroqli: loglarni o'qiy olgan har kim shu vaqt ichida istalgan
 * foydalanuvchi — jumladan super-admin — nomidan so'rov yubora olardi.
 *
 * Yo'llar log YOZUVIGA nisbatan (`req` — pino-http qo'shadigan kalit),
 * Express so'roviga emas.
 */
export const REDACTED_PATHS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'res.headers["set-cookie"]',
];

export const REDACTED = '[yashirilgan]';

export function loggerOptions(isProd: boolean): LoggerOptions {
  return {
    level: isProd ? 'info' : 'debug',
    redact: { paths: REDACTED_PATHS, censor: REDACTED },
  };
}
