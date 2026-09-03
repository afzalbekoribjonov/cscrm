import { fileURLToPath, URL } from 'node:url';

import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const sharedDir = fileURLToPath(new URL('../shared', import.meta.url));

export default defineConfig({
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
});
