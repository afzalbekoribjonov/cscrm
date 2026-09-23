import { readFileSync } from 'node:fs';

import { describe, expect, it } from 'vitest';

import { SOLUTIONS } from '@/pages/marketing/SolutionPage';

import { branding } from './branding';

const read = (rel: string) => readFileSync(new URL(rel, import.meta.url), 'utf8');

/**
 * sitemap.xml qo'lda yoziladi — yangi sahifa qo'shilib, xaritaga
 * yozilmay qolsa, Google uni kech topadi. Bu sinov ikkalasini solishtiradi.
 */
describe('sitemap.xml va robots.txt', () => {
  const app = read('../App.tsx');
  const sitemap = read('../../public/sitemap.xml');
  const robots = read('../../public/robots.txt');

  it('xaritada aynan marketing sahifalari bor', () => {
    const routes = [...app.matchAll(/<Route path="([a-z-]+)"/g)].map((m) => `/${m[1]}`);
    const expected = ['/', ...routes, ...SOLUTIONS.map((s) => `/${s.slug}`)];
    const locs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]!);

    expect(locs.every((l) => l.startsWith(branding.websiteUrl))).toBe(true);
    expect(new Set(locs.map((l) => l.slice(branding.websiteUrl.length)))).toEqual(new Set(expected));
  });

  it('panel va kirish indekslanmaydi, xarita ko\'rsatilgan', () => {
    expect(robots).toMatch(/^Disallow: \/admin$/m);
    expect(robots).toMatch(/^Disallow: \/kirish$/m);
    expect(robots).toContain(`Sitemap: ${branding.websiteUrl}/sitemap.xml`);
    expect(sitemap).not.toMatch(/\/admin|\/kirish/);
  });
});
