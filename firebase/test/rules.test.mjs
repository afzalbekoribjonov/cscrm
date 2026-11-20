/**
 * Baza qoidalari sinovi — Firebase EMULATORIDA, jonli bazaga tegmasdan.
 *
 * Ishga tushirish (`firebase/` papkasidan, Java 11+ kerak):
 *   npm install
 *   npm test
 *
 * Qoidalar to'g'ridan-to'g'ri MANBADAN (`rules.mjs`) olinadi.
 *
 * "ilova:" holatlari — ilovaning haqiqiy yozuv va o'qish yo'llari
 * (order_service.dart, expense_service.dart, product_service.dart,
 * employee_service.dart, home_shell.dart). Qoidani o'zgartirganda ular
 * o'tishi SHART: mijozlar qo'lidagi ilova eski versiyada qolishi mumkin.
 *
 * Hujum holatlari (X1, X3...) — docs/KAMCHILIKLAR.md dagi
 * "2026-09-23 xavfsizlik auditi" bandlari. 2026-09-23 da ular avvalgi
 * qoidalarda haqiqatan O'TISHI emulatorda tasdiqlangan.
 */
import { after, before, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import { rules, stripComments } from '../rules.mjs';

const TS = { '.sv': 'timestamp' };

/** Ilova saqlaydigan to'liq qonuniyatlar (BusinessPolicies.toMap). */
const POLICIES = {
  deadlineDays: 3,
  deadlineRequired: true,
  addressRequired: false,
  pickupGpsRequired: false,
  debtAllowed: true,
  measureBeforeWash: false,
  measureBeforePackaging: true,
  rewashReasonRequired: true,
  partialHandoverEnabled: true,
  warehouseEnabled: true,
  warehouseDays: 15,
};

const SEED = {
  tenants: {
    t1: {
      profile: { name: 'Biznes 1', ownerUid: 'owner1', createdAt: 1 },
      license: { planId: 'm1', kind: 'subscription', startedAt: 1, expiresAt: 9e12 },
      members: { owner1: true },
      employees: {
        e1: { firstName: 'Ali', lastName: '', phone: '998901112233', active: true, pinHash: 'ESKI_JOYDAGI_HASH' },
        e2: { firstName: 'Vali', lastName: '', phone: '998901112234', active: false },
        // Eski yozuv — `active` maydoni umuman yo'q.
        e3: { firstName: 'Eski', lastName: '', phone: '998901112235' },
      },
      products: { p1: { name: 'Gilam', price: 10000 } },
      counters: { orderId: 2 },
      orders: {
        1: { id: 1, status: 'qabul', active: true, createdAt: 1, items: { i1: { price: 1000 } } },
        2: { id: 2, status: 'qabul', active: true, createdAt: 2 },
      },
      order_history: { h1: { orderId: 1, type: 'created', at: 1 } },
      expenses: { x1: { amount: 5000, spentAt: 1 } },
      payments: { pay1: { amount: 1 } },
      payment_requests: { r1: { status: 'pending' } },
      payroll_rates: { products: { p1: { wash: 1500, pack: 500 } }, courierPct: 5, dispatcherMode: 'percent', dispatcherValue: 2 },
      payroll_staff: { e1: { type: 'mixed', monthly: 3000000, pieces: { wash: true } } },
      payroll_payments: { pp1: { employeeId: 'e1', amount: 500000, kind: 'advance', month: '2026-11', at: 1 } },
      work_days: { 20261120: { e1: { name: 'Ali', washN: 2, washPay: 18000, wash: { m2: 12 } } } },
      warnings: { e1: { w1: { at: 1, orderId: 1, itemKey: 'i1', productName: 'Gilam', reason: "Dog'", byId: 'e3', byName: 'Eski' } } },
    },
    t2: {
      profile: { name: 'Biznes 2', ownerUid: 'owner2', createdAt: 1 },
      license: { planId: 'm1', kind: 'subscription', startedAt: 1, expiresAt: 9e12 },
      members: { owner2: true },
      orders: { 1: { id: 1, status: 'qabul', active: true, createdAt: 1 } },
    },
    t3: {
      profile: { name: "To'xtatilgan", ownerUid: 'owner3', createdAt: 1 },
      license: { planId: 'm1', kind: 'subscription', startedAt: 1, expiresAt: 9e12, suspended: true },
      members: { owner3: true },
      employees: { e1: { firstName: 'S', lastName: '', phone: '998901112239', active: true } },
      counters: { orderId: 1 },
      orders: { 1: { id: 1, status: 'qabul', active: true, createdAt: 1 } },
    },
  },
  broadcasts: { b1: { title: 'Yangilik', body: 'x', createdAt: 1, createdBy: 'SUPER_ADMIN_UID' } },
  employee_secrets: { t1: { e1: { pinHash: 'YANGI_JOYDAGI_HASH' } } },
  tenant_archive: { t3: { archivedAt: 1, purgeAfter: 2, reason: 'x' } },
  admin_audit: { a1: { at: 1, action: 'tenant.update', tenantId: 't1', actor: { uid: 'admin', email: 'a@b.c' } } },
  admin_roles: { r1: { name: 'Operator', permissions: ['tenants.read'], createdAt: 1, createdBy: 'admin' } },
  admin_members: { panel1: { email: 'op@cscrm.uz', roleId: 'r1', addedAt: 1, addedBy: 'admin' } },
};

// --- Kim nomidan ---
const owner = (env, t = 't1', uid = 'owner1') =>
  env.authenticatedContext(uid, { tenantId: t, role: 'owner' }).database();
const staff = (env, e, t = 't1') =>
  env
    .authenticatedContext(`staff_${t}_${e}`, { tenantId: t, role: 'staff', employeeId: e })
    .database();
const anon = (env) => env.unauthenticatedContext().database();

const read = (db, path) => db.ref(path).once('value');

/** Tranzaksiya: birinchi chaqiruv mahalliy `null` bilan keladi — ilova kabi. */
const increment = (db, path) =>
  db.ref(path).transaction((cur) => {
    if (cur === null) return 1;
    if (typeof cur === 'string') return (Number.parseInt(cur, 10) || 0) + 1;
    return cur + 1;
  }).then((r) => {
    if (!r.committed) throw new Error('tranzaksiya bajarilmadi');
    return r;
  });

/**
 * [nom, bajariladigan amal, kutilma] — kutilma: 'ok' | 'rad'.
 */
const CASES = [
  // ================= QONUNIY: ilova qiladigan ishlar =================
  ['ilova: xodim faol buyurtmalarni so\'raydi (indeksli so\'rov)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders').orderByChild('active').equalTo(true).once('value'), 'ok'],
  ['ilova: xodim yangi buyurtma yaratadi (buyurtma + tarix, bitta yozuvda)',
    (e) => staff(e, 'e1').ref('tenants/t1').update({
      'orders/3': { id: 3, status: 'qabul', active: true, createdAt: TS, createdBy: 'e1' },
      'order_history/hNew': { orderId: 3, type: 'created', at: TS, byEmployeeId: 'e1' },
    }), 'ok'],
  ['ilova: holatni o\'zgartirish (maydonlar + tarix, bitta yozuvda)',
    (e) => staff(e, 'e1').ref('tenants/t1').update({
      'orders/1/status': 'yuvishda',
      'orders/1/washStartedAt': TS,
      'order_history/hNew2': { orderId: 1, type: 'status_changed', at: TS },
    }), 'ok'],
  ['ilova: buyurtma raqami hisoblagichi (tranzaksiya)',
    (e) => increment(staff(e, 'e1'), 'tenants/t1/counters/orderId'), 'ok'],
  ['ilova: buyurtma tranzaksiyasi (o\'lchash, narx)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1').transaction((cur) =>
      cur === null ? cur : { ...cur, totalPrice: 7000 }), 'ok'],
  ['ilova: tarixga alohida yozuv (yangi kalit)',
    (e) => staff(e, 'e1').ref('tenants/t1/order_history/hNew3').set({ orderId: 1, type: 'item_updated', at: TS }), 'ok'],
  ['ilova: buyurtmaga izoh',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1/comments').push({ text: 'salom', at: TS }), 'ok'],
  ['ilova: xizmatga izoh',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1/items/i1/comments').push({ text: 'dog\'', at: TS }), 'ok'],
  ['ilova: bitta buyurtmani o\'chirish',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/2').remove(), 'ok'],
  ['ilova: chiqim qo\'shish',
    (e) => staff(e, 'e1').ref('tenants/t1/expenses').push({ amount: 100, spentAt: TS }), 'ok'],
  ['ilova: chiqimni tahrirlash',
    (e) => staff(e, 'e1').ref('tenants/t1/expenses/x1').update({ amount: 200 }), 'ok'],
  ['ilova: chiqimni o\'chirish',
    (e) => staff(e, 'e1').ref('tenants/t1/expenses/x1').remove(), 'ok'],
  ['ilova: ega xizmat turi qo\'shadi',
    (e) => owner(e).ref('tenants/t1/products').push({ name: 'Parda', price: 5000 }), 'ok'],
  ['ilova: ega xizmat turini tahrirlaydi va o\'chiradi',
    (e) => owner(e).ref('tenants/t1/products/p1').update({ price: 12000 })
      .then(() => owner(e).ref('tenants/t1/products/p1').remove()), 'ok'],

  // --- 2026-11: ilova qonuniyatlari, bo'lib topshirish, mijozni topish ---
  ['ilova: xodim "Ilova qonuniyatlari"ni o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/settings/policies'), 'ok'],
  ['ilova: ega qonuniyatlarni saqlaydi',
    (e) => owner(e).ref('tenants/t1/settings/policies').set(POLICIES), 'ok'],
  ['ilova: mijozni telefon bo\'yicha topish (indeksli, bitta yozuv)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders').orderByChild('customerPhone')
      .equalTo('998901234567').limitToLast(1).once('value'), 'ok'],
  ['ilova: "Yuvish" tugmasi — xizmat holati va vaqt (tranzaksiya)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1').transaction((cur) =>
      cur === null ? cur : { ...cur, items: { i1: { price: 1000, status: 'yuvilmoqda', washStartedAt: Date.now() } } }), 'ok'],
  ['ilova: bo\'lib topshirish — handedAt va oldindan to\'lov (tranzaksiya)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1').transaction((cur) =>
      cur === null ? cur : {
        ...cur,
        prepaidAmount: 1000,
        items: { i1: { price: 1000, status: 'tayyor', handedAt: Date.now(), handedBy: 'e1' } },
      }), 'ok'],
  ['hujum: xodim qonuniyatlarni o\'zgartira olmaydi',
    (e) => staff(e, 'e1').ref('tenants/t1/settings/policies').set(POLICIES), 'rad'],
  ['hujum: qonuniyatga chegaradan tashqari qiymat',
    (e) => owner(e).ref('tenants/t1/settings/policies').set({ ...POLICIES, warehouseDays: 1000 }), 'rad'],
  ['hujum: qonuniyatga noma\'lum kalit',
    (e) => owner(e).ref('tenants/t1/settings/policies').set({ ...POLICIES, admin: true }), 'rad'],
  ['hujum: sozlamalar ichida boshqa tugun',
    (e) => owner(e).ref('tenants/t1/settings/boshqa').set({ x: 1 }), 'rad'],
  ['hujum: boshqa biznes sozlamalarini o\'qish',
    (e) => read(owner(e, 't2', 'owner2'), 'tenants/t1/settings'), 'rad'],
  ['hujum: to\'xtatilgan biznes egasi qonuniyat yoza olmaydi',
    (e) => owner(e, 't3', 'owner3').ref('tenants/t3/settings/policies').set(POLICIES), 'rad'],
  ['ilova: ega xodimni bloklaydi',
    (e) => owner(e).ref('tenants/t1/employees/e1').update({ active: false }), 'ok'],
  ['ilova: ega xodim vakolatini o\'zgartiradi',
    (e) => owner(e).ref('tenants/t1/employees/e1').update({ 'sections/yuvish': true }), 'ok'],
  ['ilova: xodim xodimlar ro\'yxatini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/employees'), 'ok'],
  ['ilova: xodim litsenziya, profil, to\'lovlar, so\'rovlarni o\'qiydi',
    (e) => Promise.all(['license', 'profile', 'payments', 'payment_requests', 'members', 'counters', 'products']
      .map((n) => read(staff(e, 'e1'), `tenants/t1/${n}`))), 'ok'],
  ['ilova: ega biznes nomini o\'qiydi',
    (e) => read(owner(e), 'tenants/t1/profile/name'), 'ok'],
  ['ilova: eski yozuvli xodim (active maydoni yo\'q) ishlaydi',
    (e) => read(staff(e, 'e3'), 'tenants/t1/orders')
      .then(() => staff(e, 'e3').ref('tenants/t1/orders/1/status').set('yuvishda')), 'ok'],
  ['ilova: BLOKLANGAN xodim o\'z yozuvini o\'qiy oladi (toza chiqarish uchun)',
    (e) => read(staff(e, 'e2'), 'tenants/t1/employees/e2'), 'ok'],
  ['ilova: O\'CHIRILGAN xodim o\'z (yo\'q) yozuvini o\'qiy oladi — null ko\'radi',
    (e) => read(staff(e, 'gone'), 'tenants/t1/employees/gone'), 'ok'],
  ['ilova: eski matnli hisoblagichni tranzaksiya tuzatadi',
    async (e) => {
      await e.withSecurityRulesDisabled((c) => c.database().ref('tenants/t1/counters/orderId').set('7'));
      const r = await increment(staff(e, 'e1'), 'tenants/t1/counters/orderId');
      if (r.snapshot.val() !== 8) throw new Error(`kutilgan 8, keldi ${r.snapshot.val()}`);
    }, 'ok'],
  ['ilova: to\'xtatilgan biznes ma\'lumotini O\'QIY oladi',
    (e) => read(staff(e, 'e1', 't3'), 'tenants/t3/orders'), 'ok'],

  // --- 2026-11-20: MAOSH ---
  ['ilova: xodim ishbayi narxlarini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/payroll_rates'), 'ok'],
  ['ilova: ega narxlarni saqlaydi',
    (e) => owner(e).ref('tenants/t1/payroll_rates').set({
      products: { p1: { wash: 2000, pack: 700 }, p2: { washSmall: 5000, washLarge: 9000, packSmall: 1000, packLarge: 2000 } },
      courierPct: 5, dispatcherMode: 'fixed', dispatcherValue: 3000, updatedAt: TS,
    }), 'ok'],
  ['ilova: xodim ish hisobini yozadi (increment, bir necha xodim, bitta yozuvda)',
    (e) => staff(e, 'e1').ref('tenants/t1').update({
      'work_days/20261121/e1/washN': { '.sv': { increment: 1 } },
      'work_days/20261121/e1/wash/m2': { '.sv': { increment: 6.5 } },
      'work_days/20261121/e1/washPay': { '.sv': { increment: 9750 } },
      'work_days/20261121/e1/name': 'Ali',
      'work_days/20261121/e3/rewashN': { '.sv': { increment: 1 } },
      'work_days/20261121/e3/rewashPay': { '.sv': { increment: 9000 } },
    }), 'ok'],
  ['ilova: o\'chirilgan buyurtma ulushini qaytarish (manfiy increment)',
    (e) => staff(e, 'e1').ref('tenants/t1').update({
      'work_days/20261120/e1/createN': { '.sv': { increment: -1 } },
      'work_days/20261120/e1/createPay': { '.sv': { increment: -3000 } },
    }), 'ok'],
  ['ilova: ega oy ish hisobini o\'qiydi (kalit oralig\'i)',
    (e) => owner(e).ref('tenants/t1/work_days').orderByKey().startAt('20261101').endAt('20261130').once('value'), 'ok'],
  ['ilova: ega xodim maoshini sozlaydi',
    (e) => owner(e).ref('tenants/t1/payroll_staff/e1').set({
      type: 'mixed', monthly: 3000000, pieces: { wash: true, pack: false, courier: true, dispatch: false }, updatedAt: TS,
    }), 'ok'],
  ['ilova: ega avans yozadi va oy to\'lovlarini so\'raydi',
    (e) => owner(e).ref('tenants/t1/payroll_payments').push({
      employeeId: 'e1', amount: 200000, kind: 'advance', month: '2026-11', at: TS, note: 'Avans', byName: 'Boshqaruvchi',
    }).then(() => owner(e).ref('tenants/t1/payroll_payments').orderByChild('month').equalTo('2026-11').once('value')), 'ok'],
  ['ilova: ega to\'lovni o\'chiradi',
    (e) => owner(e).ref('tenants/t1/payroll_payments/pp1').remove(), 'ok'],
  ['ilova: qayta yuvishga qaytargan xodim yuvgan xodimga ogohlantirish yozadi',
    (e) => staff(e, 'e3').ref('tenants/t1/warnings/e1').push({
      at: TS, orderId: 1, itemKey: '1', productName: 'Gilam', reason: "Dog' qolgan", byId: 'e3', byName: 'Eski', deduction: 9000,
    }), 'ok'],
  ['ilova: xodim o\'z ogohlantirishlarini o\'qiydi (oxirgilari)',
    (e) => staff(e, 'e1').ref('tenants/t1/warnings/e1').orderByChild('at').limitToLast(30).once('value'), 'ok'],
  ['ilova: xodim ogohlantirishni "tanishdim" deb belgilaydi',
    (e) => staff(e, 'e1').ref('tenants/t1/warnings/e1/w1/seenAt').set(TS), 'ok'],
  ['ilova: ega ogohlantirishlarni o\'qiydi va o\'chiradi',
    (e) => read(owner(e), 'tenants/t1/warnings')
      .then(() => owner(e).ref('tenants/t1/warnings/e1/w1').remove()), 'ok'],
  ['ilova: xizmat va buyurtmadagi maosh kvitansiyalari (tranzaksiya)',
    (e) => staff(e, 'e1').ref('tenants/t1/orders/1').transaction((cur) =>
      cur === null ? cur : {
        ...cur,
        createCredit: { by: 'e1', day: '20261120', pay: 0, mode: 'percent' },
        items: { i1: { price: 1000, status: 'qadoqlashda', washCredit: { by: 'e1', name: 'Ali', day: '20261120', pay: 9000, unit: 'm2', qty: 6 } } },
      }), 'ok'],
  ['hujum: xodim ishbayi narxini o\'zgartiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/payroll_rates/products/p1/wash').set(999999), 'rad'],
  ['hujum: dastavchik ulushi 50% dan oshadi',
    (e) => owner(e).ref('tenants/t1/payroll_rates').set({ courierPct: 500 }), 'rad'],
  ['hujum: narxlarga noma\'lum kalit',
    (e) => owner(e).ref('tenants/t1/payroll_rates').set({ courierPct: 5, bonus: 1 }), 'rad'],
  ['hujum: xodim boshqalarning oyligini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/payroll_staff'), 'rad'],
  ['hujum: xodim o\'z oyligini o\'zgartiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/payroll_staff/e1/monthly').set(99000000), 'rad'],
  ['hujum: xodim to\'lovlar ro\'yxatini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/payroll_payments'), 'rad'],
  ['hujum: xodim o\'ziga to\'lov yozib qo\'yadi',
    (e) => staff(e, 'e1').ref('tenants/t1/payroll_payments').push({ employeeId: 'e1', amount: 1, kind: 'advance', month: '2026-11', at: 1 }), 'rad'],
  ['hujum: manfiy to\'lov',
    (e) => owner(e).ref('tenants/t1/payroll_payments').push({ employeeId: 'e1', amount: -5, kind: 'advance', month: '2026-11', at: 1 }), 'rad'],
  ['hujum: to\'lov oyi noto\'g\'ri ko\'rinishda',
    (e) => owner(e).ref('tenants/t1/payroll_payments').push({ employeeId: 'e1', amount: 5, kind: 'advance', month: 'noyabr', at: 1 }), 'rad'],
  ['hujum: xodim boshqalarning ish hisobini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'tenants/t1/work_days'), 'rad'],
  ['hujum: ish hisobiga noma\'lum maydon',
    (e) => staff(e, 'e1').ref('tenants/t1/work_days/20261121/e1/bonus').set(1000000), 'rad'],
  ['hujum: ish hisobiga matn',
    (e) => staff(e, 'e1').ref('tenants/t1/work_days/20261121/e1/washPay').set('ko\'p'), 'rad'],
  ['hujum: ish hisobida noto\'g\'ri kun kaliti',
    (e) => staff(e, 'e1').ref('tenants/t1/work_days/bugun/e1/washN').set(1), 'rad'],
  ['hujum: ish hisobida noma\'lum o\'lchov birligi',
    (e) => staff(e, 'e1').ref('tenants/t1/work_days/20261121/e1/wash/tonna').set(1), 'rad'],
  ['hujum: BLOKLANGAN xodim ish hisobiga yozadi',
    (e) => staff(e, 'e2').ref('tenants/t1/work_days/20261121/e2/washN').set(5), 'rad'],
  ['hujum: to\'xtatilgan biznes xodimi ish hisobiga yozadi',
    (e) => staff(e, 'e1', 't3').ref('tenants/t3/work_days/20261121/e1/washN').set(5), 'rad'],
  ['hujum: boshqa biznes egasi ish hisobini o\'qiydi',
    (e) => read(owner(e, 't2', 'owner2'), 'tenants/t1/work_days'), 'rad'],
  ['hujum: xodim boshqa xodimning ogohlantirishlarini o\'qiydi',
    (e) => read(staff(e, 'e3'), 'tenants/t1/warnings/e1'), 'rad'],
  ['hujum: xodim ogohlantirish matnini o\'zgartiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/warnings/e1/w1/reason').set('yo\'q'), 'rad'],
  ['hujum: xodim o\'z ogohlantirishini o\'chiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/warnings/e1/w1').remove(), 'rad'],
  ['hujum: boshqa xodimning ogohlantirishini "tanishdim" qiladi',
    (e) => staff(e, 'e3').ref('tenants/t1/warnings/e1/w1/seenAt').set(TS), 'rad'],
  ['hujum: bo\'sh ogohlantirish (majburiy maydonlarsiz)',
    (e) => staff(e, 'e3').ref('tenants/t1/warnings/e1').push({ reason: 'x' }), 'rad'],

  // ================= HUJUMLAR =================
  ['X1: ega profilidagi ownerUid ni o\'zgartiradi',
    (e) => owner(e).ref('tenants/t1/profile/ownerUid').set('SUPER_ADMIN_UID'), 'rad'],
  ['X1: ega profilni butunlay qayta yozadi',
    (e) => owner(e).ref('tenants/t1/profile').set({ name: 'x', ownerUid: 'SUPER_ADMIN_UID', createdAt: 1 }), 'rad'],
  ['X1: ega ownerUid ni o\'chiradi',
    (e) => owner(e).ref('tenants/t1/profile/ownerUid').remove(), 'rad'],
  ['X1: xodim xabarlardan admin UID\'ini o\'qiydi',
    (e) => read(staff(e, 'e1'), 'broadcasts'), 'rad'],
  ['X3: xodim BARCHA buyurtmalarni o\'chiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/orders').remove(), 'rad'],
  ['X3: xodim buyurtmalar ro\'yxatini bo\'sh obyekt bilan almashtiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/orders').set({ 1: { id: 1 } }), 'rad'],
  ['X3: xodim BUTUN tarixni o\'chiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/order_history').remove(), 'rad'],
  ['X3: xodim tarixdagi yozuvni o\'chiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/order_history/h1').remove(), 'rad'],
  ['X3: xodim tarixdagi yozuvni soxtalashtiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/order_history/h1/byEmployeeId').set('boshqasi'), 'rad'],
  ['X3: ega ham tarixni o\'chira olmaydi',
    (e) => owner(e).ref('tenants/t1/order_history/h1').remove(), 'rad'],
  ['X3: xodim BARCHA chiqimlarni o\'chiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/expenses').remove(), 'rad'],
  ['X3: hisoblagichni orqaga surish (mavjud buyurtma ustidan yozish uchun)',
    (e) => staff(e, 'e1').ref('tenants/t1/counters/orderId').set(1), 'rad'],
  ['X3: hisoblagichni o\'chirish',
    (e) => staff(e, 'e1').ref('tenants/t1/counters/orderId').remove(), 'rad'],
  ['X3: hisoblagichga matn yozish',
    (e) => staff(e, 'e1').ref('tenants/t1/counters/orderId').set('abc'), 'rad'],
  ['X3: butun hisoblagichlar tugunini o\'chirish',
    (e) => staff(e, 'e1').ref('tenants/t1/counters').remove(), 'rad'],
  ['X4: BLOKLANGAN xodim buyurtmalarni o\'qiydi',
    (e) => read(staff(e, 'e2'), 'tenants/t1/orders'), 'rad'],
  ['X4: BLOKLANGAN xodim buyurtmani o\'zgartiradi',
    (e) => staff(e, 'e2').ref('tenants/t1/orders/1/status').set('yetgazildi'), 'rad'],
  ['X4: O\'CHIRILGAN xodim mijozlar ma\'lumotini o\'qiydi',
    (e) => read(staff(e, 'gone'), 'tenants/t1/orders'), 'rad'],
  ['X6: to\'xtatilgan biznes xodimi buyurtma yozadi',
    (e) => staff(e, 'e1', 't3').ref('tenants/t3/orders/1/status').set('yuvishda'), 'rad'],
  ['X6: to\'xtatilgan biznes egasi xizmat qo\'shadi',
    (e) => owner(e, 't3', 'owner3').ref('tenants/t3/products').push({ name: 'x' }), 'rad'],
  ['X11 (qoldiq): xodim yozuvidagi ESKI hash o\'qiladi — .read:false ishlamaydi, yechim ko\'chirish',
    (e) => read(staff(e, 'e3'), 'tenants/t1/employees/e1/pinHash'), 'ok'],
  ['X11: yopiq tugundagi hashni xodim o\'qiy olmaydi',
    (e) => read(staff(e, 'e1'), 'employee_secrets/t1/e1'), 'rad'],
  ['X11: yopiq tugundagi hashni ega ham o\'qiy olmaydi',
    (e) => read(owner(e), 'employee_secrets/t1'), 'rad'],

  // ================= AVVAL HAM YOPIQ BO'LGANLAR (regressiya) =================
  ['boshqa biznes egasi t1 buyurtmalarini o\'qiydi',
    (e) => read(owner(e, 't2', 'owner2'), 'tenants/t1/orders'), 'rad'],
  ['boshqa biznes egasi t1 ga buyurtma yozadi',
    (e) => owner(e, 't2', 'owner2').ref('tenants/t1/orders/9').set({ id: 9 }), 'rad'],
  ['ega amallar jurnalini o\'qiy olmaydi',
    (e) => read(owner(e), 'admin_audit'), 'rad'],
  ['ega o\'z biznesining jurnal yozuvini ham o\'qiy olmaydi',
    (e) => read(owner(e), 'admin_audit/a1'), 'rad'],
  ['ega jurnalga soxta yozuv qo\'sha olmaydi',
    (e) => owner(e).ref('admin_audit').push({ at: 1, action: 'x' }), 'rad'],
  ['arxiv ma\'lumotini hech kim o\'qiy olmaydi',
    (e) => read(owner(e, 't3', 'owner3'), 'tenant_archive/t3'), 'rad'],
  ['ega o\'z biznesini arxivdan chiqara olmaydi',
    (e) => owner(e, 't3', 'owner3').ref('tenant_archive/t3').remove(), 'rad'],
  ['ega o\'zini panel xodimi qilib yoza olmaydi',
    (e) => owner(e).ref('admin_members/owner1').set({ email: 'x@y.uz', roleId: 'r1', addedAt: 1, addedBy: 'owner1' }), 'rad'],
  ['ega rolga vakolat qo\'sha olmaydi',
    (e) => owner(e).ref('admin_roles/r1/permissions/1').set('tenants.delete'), 'rad'],
  ['panel xodimi ham rollar ro\'yxatini to\'g\'ridan-to\'g\'ri o\'qiy olmaydi',
    (e) => read(e.authenticatedContext('panel1').database(), 'admin_roles'), 'rad'],
  ['kirmagan foydalanuvchi buyurtmalarni o\'qiydi',
    (e) => read(anon(e), 'tenants/t1/orders'), 'rad'],
  ['xodim litsenziyani uzaytiradi',
    (e) => staff(e, 'e1').ref('tenants/t1/license/expiresAt').set(9e13), 'rad'],
  ['ega to\'lov yozuvini soxtalashtiradi',
    (e) => owner(e).ref('tenants/t1/payments/fake').set({ amount: 1 }), 'rad'],
  ['xodim xodim qo\'shadi (faqat ega)',
    (e) => staff(e, 'e1').ref('tenants/t1/employees/e9').set({ firstName: 'x', active: true }), 'rad'],
  ['xodim xizmat narxini o\'zgartiradi (faqat ega)',
    (e) => staff(e, 'e1').ref('tenants/t1/products/p1/price').set(1), 'rad'],
  ['noma\'lum tugunga yozish',
    (e) => owner(e).ref('tenants/t1/boshqa').set({ a: 1 }), 'rad'],
];

describe('baza qoidalari', () => {
  let env;

  before(async () => {
    // `emulators:exec` emulator manzilini shu o'zgaruvchida beradi. Windows
    // ba'zan 9000-portni o'zi band qilib qo'yadi (Hyper-V) — shunda
    // emulator boshqa portda ishga tushiriladi va sinov o'sha portga ulanadi.
    const [host, port] = (process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000').split(':');
    env = await initializeTestEnvironment({
      projectId: 'demo-cscrm',
      database: {
        host,
        port: Number(port),
        rules: JSON.stringify(stripComments(rules)),
      },
    });
  });

  after(async () => {
    await env?.cleanup();
  });

  for (const [name, run, expected] of CASES) {
    it(`[${expected === 'ok' ? 'o\'tadi' : 'rad'}] ${name}`, async () => {
      await env.clearDatabase();
      await env.withSecurityRulesDisabled((c) => c.database().ref().set(SEED));
      const p = Promise.resolve().then(() => run(env));
      if (expected === 'ok') await assertSucceeds(p);
      else await assertFails(p);
    });
  }
});
