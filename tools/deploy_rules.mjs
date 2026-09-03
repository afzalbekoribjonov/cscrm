/**
 * Realtime Database qoidalarini joylaydi.
 *
 * Nega alohida skript: `firebase deploy` Google hisobiga kirishni talab
 * qiladi, bizda esa service account bor. REST endpoint o'sha ishni
 * bajaradi, faqat bitta farqi bor - u IZOHLARNI qabul qilmaydi.
 *
 * `database.rules.json` da `"//"` kalitlari ataylab ko'p: qoidaning
 * NEGA shundayligi o'sha yerda yozilgan va u yo'qolmasligi kerak.
 * Shu sabab izohlar faylda qoladi, yuborishdan oldin esa nusxadan
 * olib tashlanadi.
 *
 * Ishlatish (backend/.env dagi kalit bilan):
 *   node tools/deploy_rules.mjs
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { GoogleAuth } from '../backend/node_modules/google-auth-library/build/src/index.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

function readEnv() {
  const text = readFileSync(join(root, 'backend/.env'), 'utf8');
  return Object.fromEntries(
    text
      .split('\n')
      .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
      .map((l) => {
        const i = l.indexOf('=');
        return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
      }),
  );
}

/** `"//"` izoh kalitlarini rekursiv olib tashlaydi. */
function stripComments(node) {
  if (Array.isArray(node)) return node.map(stripComments);
  if (node === null || typeof node !== 'object') return node;

  const out = {};
  for (const [key, value] of Object.entries(node)) {
    if (key === '//') continue;
    out[key] = stripComments(value);
  }
  return out;
}

const env = readEnv();
if (!env.FIREBASE_SERVICE_ACCOUNT || !env.FIREBASE_DATABASE_URL) {
  console.error('backend/.env da FIREBASE_SERVICE_ACCOUNT yoki DATABASE_URL yo\'q');
  process.exit(1);
}

const sa = JSON.parse(
  Buffer.from(env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8'),
);

const source = JSON.parse(
  readFileSync(join(root, 'firebase/database.rules.json'), 'utf8'),
);
const payload = stripComments(source);

if (!payload.rules) {
  console.error('qoidalar faylida `rules` yo\'q');
  process.exit(1);
}

const auth = new GoogleAuth({
  credentials: sa,
  scopes: [
    'https://www.googleapis.com/auth/firebase.database',
    'https://www.googleapis.com/auth/userinfo.email',
  ],
});

const token = await auth.getAccessToken();
const url = `${env.FIREBASE_DATABASE_URL.replace(/\/+$/, '')}/.settings/rules.json`;

const res = await fetch(url, {
  method: 'PUT',
  headers: {
    authorization: `Bearer ${token}`,
    'content-type': 'application/json',
  },
  body: JSON.stringify(payload),
});

const body = await res.text();

if (!res.ok) {
  console.error(`Joylashtirib bo'lmadi (${res.status}):`, body);
  process.exit(1);
}

// Indekslar tuzatilganini ko'rsatamiz - ular bo'lmasa so'rovlar
// butun tugunni o'qib, keyin filtrlaydi.
const indexes = [];
const walk = (node, path) => {
  if (node === null || typeof node !== 'object') return;
  for (const [key, value] of Object.entries(node)) {
    if (key === '.indexOn') indexes.push(`${path || '/'} -> ${value.join(', ')}`);
    else walk(value, `${path}/${key}`);
  }
};
walk(payload.rules, '');

console.log(`Qoidalar joylandi (${sa.project_id}).`);
console.log(`Indekslar (${indexes.length}):`);
for (const line of indexes) console.log('  ' + line);
