import { fileURLToPath, URL } from 'node:url';

import react from '@vitejs/plugin-react';
import { defineConfig, loadEnv } from 'vite';

const sharedDir = fileURLToPath(new URL('../shared', import.meta.url));

/**
 * Firebase sozlamalari BUILD PAYTIDA bundlega kiradi.
 *
 * Ular yetishmasa Vite baribir muvaffaqiyatli yig'adi — sayt esa
 * ochiladi-yu, panelga kirishga urinilganda "Firebase sozlanmagan"
 * deydi. Ya'ni buzilganini faqat foydalanuvchi topadi.
 *
 * Shuning uchun yig'ishning o'zi TO'XTAYDI: xato joylashdan oldin,
 * build logida, aniq nomi bilan ko'rinsin.
 */
const REQUIRED_FOR_BUILD = [
  'VITE_FIREBASE_API_KEY',
  'VITE_FIREBASE_AUTH_DOMAIN',
  'VITE_FIREBASE_PROJECT_ID',
  'VITE_FIREBASE_DATABASE_URL',
  'VITE_FIREBASE_APP_ID',
];

export default defineConfig(({ command, mode }) => {
  // Qiymatlar `.env*` fayllaridan ham, muhit o'zgaruvchilaridan ham
  // olinadi — Render aynan ikkinchi yo'l bilan beradi.
  const env = loadEnv(mode, process.cwd(), 'VITE_');

  if (command === 'build') {
    const missing = REQUIRED_FOR_BUILD.filter((key) => !env[key]);
    if (missing.length > 0) {
      throw new Error(
        `\nFirebase sozlamalari yetishmayapti:\n` +
          missing.map((k) => `  - ${k}`).join('\n') +
          `\n\nMahalliy yig'ishda: admin/.env.local faylini to'ldiring ` +
          `(namuna: admin/.env.example).\n` +
          `Render'da: servis sozlamalarida Environment bo'limiga qo'shing.\n`,
      );
    }
  }

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
        // Narx rejalari yagona manbadan olinadi (shared/plans.json) —
        // websaytdagi narx va ilovadagi narx bir-biridan farq qila olmaydi.
        '@shared': sharedDir,
      },
    },
    server: {
      port: 5173,
      fs: {
        // Vite sukut bo'yicha root'dan tashqariga chiqmaydi; `shared/` ni
        // o'qishi uchun aniq ruxsat beramiz.
        allow: ['..'],
      },
    },
    build: {
      outDir: 'dist',
      sourcemap: true,
    },
  };
});
