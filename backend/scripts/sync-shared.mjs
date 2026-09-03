/**
 * `shared/` papkasidagi yagona-manba fayllarni backend `src/data/` ga
 * ko'chiradi.
 *
 * Nega ko'chirma kerak: TypeScript `rootDir: "src"` chegarasidan tashqaridagi
 * faylni import qilishga ruxsat bermaydi, `dist/` ga ham chiqarmaydi. Shu
 * sabab build va dev'dan OLDIN nusxa olinadi (`predev` / `prebuild`).
 * `src/data/` git'ga tushmaydi - manba doim `shared/`.
 */
import { copyFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..');
const outDir = join(here, '..', 'src', 'data');

const FILES = ['plans.json'];

mkdirSync(outDir, { recursive: true });
for (const file of FILES) {
  const from = join(repoRoot, 'shared', file);
  const to = join(outDir, file);
  copyFileSync(from, to);
  console.log(`[sync-shared] ${file} -> src/data/${file}`);
}
