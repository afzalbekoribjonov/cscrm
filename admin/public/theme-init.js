/*
 * REJIM SKRIPTI — React'dan OLDIN ishlashi SHART.
 *
 * Agar rejim React yuklangandan keyin qo'yilsa, sahifa bir lahza
 * standart (oq) ko'rinishda chizilib, keyin qoraga sakraydi.
 *
 * NEGA ALOHIDA FAYL. Avval bu kod `index.html` ichida (inline) edi.
 * Server esa Content-Security-Policy bilan faqat o'z fayllaridagi
 * skriptlarga ruxsat beradi (`script-src 'self'`) va inline skriptni
 * BLOKLAYDI. Natijada prod'da tanlangan tun rejimi har qayta yuklashda
 * yo'qolardi. CSP'ni yumshatish ('unsafe-inline') XSS himoyasini
 * butunlay o'chirib qo'yardi — shuning uchun kod faylga ko'chirildi.
 *
 * Standart — KUN rejimi. Operatsion tizim sozlamasiga ATAYLAB
 * qaralmaydi: tun rejimini foydalanuvchining o'zi tanlaydi.
 */
(function () {
  var t = 'light';
  try {
    if (localStorage.getItem('cscrm-theme') === 'dark') t = 'dark';
  } catch (e) {
    /* maxfiy oyna — standart qoladi */
  }
  document.documentElement.dataset.theme = t;
})();
