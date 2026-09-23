import assert from 'node:assert/strict';
import { Writable } from 'node:stream';
import { describe, it } from 'node:test';

import { pino } from 'pino';

import { REDACTED, loggerOptions } from './logger.js';

/** Log yozuvlarini xotiraga yig'adi. */
function capture() {
  const lines: string[] = [];
  const stream = new Writable({
    write(chunk, _enc, done) {
      lines.push(String(chunk));
      done();
    },
  });
  return { lines, stream };
}

describe('logger — maxfiy sarlavhalar', () => {
  it('kirish tokeni logga tushmaydi', () => {
    const { lines, stream } = capture();
    const log = pino(loggerOptions(true), stream);

    log.info(
      { req: { headers: { authorization: 'Bearer eyJhbGciOiJSUzI1NiJ9.secret' } } },
      'so\'rov',
    );

    const out = lines.join('');
    assert.ok(!out.includes('eyJhbGciOiJSUzI1NiJ9'), 'token matni qolmasligi kerak');
    assert.ok(out.includes(REDACTED));
  });

  it('cookie ham yashiriladi', () => {
    const { lines, stream } = capture();
    const log = pino(loggerOptions(true), stream);

    log.info({ req: { headers: { cookie: 'session=abc123' } } }, 'so\'rov');

    assert.ok(!lines.join('').includes('abc123'));
  });

  it('oddiy sarlavhalar o\'zgarmaydi — tahlil uchun kerak', () => {
    const { lines, stream } = capture();
    const log = pino(loggerOptions(true), stream);

    log.info({ req: { headers: { 'user-agent': 'Dart/3.6' } } }, 'so\'rov');

    assert.ok(lines.join('').includes('Dart/3.6'));
  });
});
