/**
 * Moslashuvchanlik tekshiruvi — FAQAT ISHLAB CHIQISH UCHUN.
 *
 * `npm run dev` → http://localhost:5173/responsive-qa.html
 * Faqat ba'zi sahifalar: `?q=kabinet` (manzilida shu so'z borlari).
 *
 * Har bir sahifa har bir kenglikda iframe'da ochiladi va tekshiriladi:
 *  * sahifa gorizontal aylanadimi (hujjat kengligi > oyna);
 *  * qaysi element oyna chetidan chiqib ketgan (o'zi aylanadigan
 *    konteyner ichidagilar hisobga olinmaydi — jadval kabi);
 *  * telefonda 32px dan past bosiladigan element (matn ichidagi
 *    havolalar hisobga olinmaydi);
 *  * asosiy kirish imkoniyati: `alt`siz rasm, nomsiz tugma/havola,
 *    yorliqsiz maydon, `h1` soni, takroriy `id` (375 va 1366 da).
 */

const WIDTHS = [320, 375, 768, 1024, 1366, 1920];

const PAGES: string[] = [
  '/',
  '/imkoniyatlar',
  '/narxlar',
  '/yuklab-olish',
  '/yordam',
  '/aloqa',
  '/gilam-yuvish',
  '/maxfiylik',
  '/oferta',
  '/yoq-sahifa',
  '/kirish',
  '/kabinet/kirish',
  '/admin-preview.html',
  '/admin-preview.html?yol=/admin/tenants',
  '/admin-preview.html?yol=/admin/tenants/t2',
  '/admin-preview.html?yol=/admin/tenants/t2%3Fbolim%3Dtolovlar',
  '/admin-preview.html?yol=/admin/tenants/t2%3Fbolim%3Dkirish',
  '/admin-preview.html?yol=/admin/tenants/t2%3Fbolim%3Dtarix',
  '/admin-preview.html?yol=/admin/payment-requests',
  '/admin-preview.html?yol=/admin/users',
  '/admin-preview.html?yol=/admin/audit',
  '/admin-preview.html?yol=/admin/access',
  '/admin-preview.html?yol=/admin/broadcasts',
  '/admin-preview.html?yol=/admin/plans',
  '/admin-preview.html?yol=/admin/settings',
  '/cabinet-preview.html',
  '/cabinet-preview.html?yol=/kabinet/obuna',
  '/cabinet-preview.html?yol=/kabinet/xodimlar',
  '/cabinet-preview.html?yol=/kabinet/xabarlar',
];

interface Finding {
  overflow: number;
  offenders: string[];
  smallTargets: string[];
  a11y: string[];
}

/** Elementning ekran o'quvchi eshitadigan nomi bormi (soddalashtirilgan). */
function hasName(el: Element, doc: Document): boolean {
  if ((el.getAttribute('aria-label') ?? '').trim()) return true;
  const by = el.getAttribute('aria-labelledby');
  if (by && by.split(/\s+/).some((id) => (doc.getElementById(id)?.textContent ?? '').trim())) return true;
  if ((el.getAttribute('title') ?? '').trim()) return true;
  if ((el.textContent ?? '').trim()) return true;
  return Array.from(el.querySelectorAll('img[alt], [role="img"][aria-label]')).some(
    (i) => (i.getAttribute('alt') ?? i.getAttribute('aria-label') ?? '').trim(),
  );
}

/** Asosiy kirish imkoniyati xatolari — axe o'rnini bosmaydi, lekin eng ko'p uchraydiganlarini ushlaydi. */
function a11y(win: Window): string[] {
  const doc = win.document;
  const out: string[] = [];
  const visible = (el: Element) => {
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && win.getComputedStyle(el).visibility !== 'hidden';
  };

  doc.querySelectorAll('img:not([alt])').forEach((el) => out.push(`alt yo'q: ${describe(el)}`));
  doc.querySelectorAll('button, a[href], [role="button"]').forEach((el) => {
    if (visible(el) && !hasName(el, doc)) out.push(`nomsiz: ${describe(el)}`);
  });
  doc.querySelectorAll('input:not([type="hidden"]), select, textarea').forEach((el) => {
    if (!visible(el)) return;
    const id = el.getAttribute('id');
    const labelled =
      el.closest('label') ||
      (id && doc.querySelector(`label[for="${CSS.escape(id)}"]`)) ||
      (el.getAttribute('aria-label') ?? '').trim() ||
      el.getAttribute('aria-labelledby');
    if (!labelled) out.push(`yorliqsiz maydon: ${describe(el)}`);
  });
  const h1 = Array.from(doc.querySelectorAll('h1')).filter(visible).length;
  if (h1 !== 1) out.push(`h1 soni: ${h1}`);
  const ids = new Map<string, number>();
  doc.querySelectorAll('[id]').forEach((el) => ids.set(el.id, (ids.get(el.id) ?? 0) + 1));
  for (const [id, n] of ids) if (n > 1) out.push(`takroriy id: ${id} ×${n}`);
  if (!doc.documentElement.lang) out.push('html lang yo\'q');
  return [...new Set(out)].slice(0, 8);
}

function describe(el: Element): string {
  const cls = typeof el.className === 'string' ? el.className.trim().split(/\s+/).slice(0, 2).join('.') : '';
  const text = (el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 30);
  return `${el.tagName.toLowerCase()}${cls ? `.${cls}` : ''}${text ? ` «${text}»` : ''}`;
}

/** Element o'zi aylanadigan/kesiladigan konteyner ichidami. */
function insideScroller(el: Element, win: Window): boolean {
  for (let p = el.parentElement; p && p !== win.document.body; p = p.parentElement) {
    const ox = win.getComputedStyle(p).overflowX;
    if (ox === 'auto' || ox === 'scroll' || ox === 'hidden' || ox === 'clip') return true;
  }
  return false;
}

function inspect(win: Window, width: number): Finding {
  const doc = win.document;
  const overflow = doc.documentElement.scrollWidth - doc.documentElement.clientWidth;
  const offenders: string[] = [];
  const smallTargets: string[] = [];

  for (const el of Array.from(doc.body.querySelectorAll('*'))) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;
    const style = win.getComputedStyle(el);
    if (style.visibility === 'hidden' || style.position === 'fixed') continue;
    if (el.closest('.ui-sr-only, .skip-link, [aria-hidden="true"]')) continue;
    if (r.right > width + 1 && !insideScroller(el, win)) offenders.push(`${describe(el)} → ${Math.round(r.right)}px`);

    if (width <= 480 && el.matches('button, [role="button"], input, select, textarea, a.btn, a.ui-btn, .ui-nav__link')) {
      if (r.height < 32 && !el.closest('p, li > a:only-child')) smallTargets.push(`${describe(el)} (${Math.round(r.height)}px)`);
    }
  }
  // Ichma-ich elementlar bir xil sabab bilan takrorlanmasin.
  return {
    overflow,
    offenders: [...new Set(offenders)].slice(0, 6),
    smallTargets: [...new Set(smallTargets)].slice(0, 6),
    // Kirish imkoniyati kenglikka bog'liq emas — ikki kenglikda yetarli.
    a11y: width === 375 || width === 1366 ? a11y(win) : [],
  };
}

function load(src: string, width: number): Promise<HTMLIFrameElement> {
  return new Promise((resolve) => {
    const frame = document.createElement('iframe');
    frame.style.width = `${width}px`;
    frame.style.height = '900px';
    frame.style.border = '0';
    frame.onload = () => setTimeout(() => resolve(frame), 1500);
    frame.src = src;
    document.getElementById('stage')!.appendChild(frame);
  });
}

async function run() {
  const filter = new URLSearchParams(location.search).get('q');
  const pages = filter ? PAGES.filter((p) => p.includes(filter)) : PAGES;
  const out = document.getElementById('out')!;
  const progress = document.getElementById('progress')!;
  let problems = 0;
  let done = 0;

  for (const page of pages) {
    for (const width of WIDTHS) {
      progress.textContent = `${++done} / ${pages.length * WIDTHS.length}: ${page} @ ${width}`;
      const frame = await load(page, width);
      const f = inspect(frame.contentWindow!, width);
      frame.remove();
      const bad = f.overflow > 1 || f.offenders.length > 0 || f.smallTargets.length > 0 || f.a11y.length > 0;
      if (!bad) continue;
      problems++;
      const row = document.createElement('tr');
      row.innerHTML = `<td>${page}</td><td>${width}</td><td class="bad"></td>`;
      row.lastElementChild!.textContent = [
        f.overflow > 1 ? `gorizontal aylanadi: +${f.overflow}px` : '',
        f.offenders.length ? `chetdan chiqqan: ${f.offenders.join('; ')}` : '',
        f.smallTargets.length ? `kichik bosish nuqtasi: ${f.smallTargets.join('; ')}` : '',
        f.a11y.length ? `a11y: ${f.a11y.join('; ')}` : '',
      ]
        .filter(Boolean)
        .join(' | ');
      out.appendChild(row);
    }
  }
  progress.textContent = problems === 0 ? `TAYYOR: muammo topilmadi (${done} ta tekshiruv).` : `TAYYOR: ${problems} ta muammoli holat (${done} ta tekshiruv).`;
  progress.className = problems === 0 ? 'ok' : 'bad';
}

void run();
