/**
 * Test fayllarini topib, Node'ning o'z test runner'ida ishga tushiradi.
 *
 * Nega alohida skript: `node --test "src/**\/*.test.ts"` Windows'da
 * ishlamaydi (npm buyruqni cmd.exe orqali chaqiradi, u glob'ni yoymaydi),
 * Node 20 esa `--test <papka>` bilan `.ts` fayllarni topmaydi. Shu sabab
 * ro'yxatni o'zimiz yig'amiz - natija har ikkala platformada bir xil.
 */
import { spawn } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(root, 'src');

function collect(dir) {
  const found = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      found.push(...collect(full));
    } else if (entry.name.endsWith('.test.ts')) {
      found.push(full);
    }
  }
  return found;
}

const files = collect(srcDir).map((f) => relative(root, f));

if (files.length === 0) {
  console.log('[test] test fayllari topilmadi');
  process.exit(0);
}

console.log(`[test] ${files.length} ta fayl:`);
for (const f of files) console.log(`  ${f}`);

// Testlar sof funksiyalarni tekshiradi va Firebase'ga ULANMAYDI, lekin
// `config/env.ts` modul yuklanishida sozlamalarni tekshiradi va yetishmasa
// process'ni to'xtatadi. Shu sabab soxta qiymatlarni shu yerda beramiz -
// ishlab chiquvchi test uchun alohida .env tayyorlashi shart emas.
const testEnv = {
  NODE_ENV: 'test',
  PORT: '8080',
  FIREBASE_SERVICE_ACCOUNT: '{"type":"service_account"}',
  FIREBASE_DATABASE_URL: 'https://test-default-rtdb.firebaseio.com',
  LICENSE_SIGNING_SECRET: 'test-only-secret-at-least-32-bytes-long-0000',
  SUPER_ADMIN_UIDS: '',
};

const child = spawn(
  process.execPath,
  ['--import', 'tsx', '--test', '--test-reporter=spec', ...files],
  { cwd: root, stdio: 'inherit', env: { ...testEnv, ...process.env } },
);
child.on('exit', (code) => process.exit(code ?? 1));
