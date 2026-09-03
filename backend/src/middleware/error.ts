import type { NextFunction, Request, Response } from 'express';

import { env } from '../config/env.js';

/** Mijozga ko'rsatish mumkin bo'lgan, kutilgan xatolik. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code = 'error',
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static badRequest(msg: string, details?: unknown) {
    return new ApiError(400, msg, 'bad_request', details);
  }
  static unauthorized(msg = 'Avtorizatsiya talab qilinadi') {
    return new ApiError(401, msg, 'unauthorized');
  }
  static forbidden(msg = 'Ruxsat yo\'q') {
    return new ApiError(403, msg, 'forbidden');
  }
  static notFound(msg = 'Topilmadi') {
    return new ApiError(404, msg, 'not_found');
  }
}

export function notFoundHandler(req: Request, _res: Response, next: NextFunction) {
  next(ApiError.notFound(`Yo'l topilmadi: ${req.method} ${req.originalUrl}`));
}

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _next: NextFunction,
) {
  const isApi = err instanceof ApiError;
  const status = isApi ? err.status : 500;

  // 5xx - bu bizning xatomiz, to'liq log qilamiz. 4xx - kutilgan, shovqin
  // qilmaymiz.
  if (status >= 500) {
    req.log?.error({ err }, 'so\'rov bajarilmadi');
  }

  res.status(status).json({
    ok: false,
    error: {
      code: isApi ? err.code : 'internal',
      message: isApi
        ? err.message
        : 'Serverda kutilmagan xatolik. Keyinroq urinib ko\'ring.',
      ...(isApi && err.details ? { details: err.details } : {}),
      // Stack faqat ishlab chiqishda - prod'da ichki tuzilma oshkor bo'lmasin.
      ...(!env.isProd && !isApi && err instanceof Error
        ? { stack: err.stack }
        : {}),
    },
  });
}

/**
 * Async route handler'larni o'raydi - `throw` qilingan xatolik Express'ning
 * error middleware'iga yetib borishi uchun (Express 4 async'ni o'zi
 * ushlamaydi).
 */
export function asyncRoute<T extends Request>(
  fn: (req: T, res: Response, next: NextFunction) => Promise<unknown>,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req as T, res, next).catch(next);
  };
}
