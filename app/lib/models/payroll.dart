import 'package:flutter/material.dart';

import '../utils/unit_amounts.dart';
import 'calculation_method.dart';
import 'measure_unit.dart';
import 'product.dart';

// ===========================================================================
// MAOSH — MA'LUMOT MODELI
//
// Uch qism, uchta alohida tugunda (ruxsatlari har xil):
//
//  * `payroll_rates`   — ishbayi narxlari va ulushlar. HAMMA A'ZO o'qiydi:
//    ish bajarilgan PAYTDA xodimning telefoni shu narx bilan hisoblaydi.
//    Shuning uchun narx o'zgarsa, u faqat SHUNDAN KEYINGI ishga ta'sir
//    qiladi — o'tgan kunlar qayta hisoblanmaydi.
//  * `payroll_staff`   — har bir xodimning maosh turi va oyligi. FAQAT EGA.
//  * `payroll_payments`— avans va oylik to'lovlari. FAQAT EGA.
//
// Bajarilgan ish esa `work_days/{yyyymmdd}/{xodim}` da kunlik YIG'INDI
// sifatida saqlanadi (`ServerValue.increment`) — oylik hisob uchun bir
// oylik tarixni yuklash shart emas, 30 ta kichik yozuv yetadi.
// ===========================================================================

/// Xodimning maosh turi.
enum SalaryType {
  piece('piece', 'Ishbayi', 'Faqat bajargan ishiga qarab'),
  fixed('fixed', 'Qat\'iy oylik', 'Har oy belgilangan summa'),
  mixed('mixed', 'Qat\'iy + ishbayi', 'Oylik ustiga bajargan ishi');

  const SalaryType(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;

  bool get hasFixed => this != piece;
  bool get hasPiece => this != fixed;

  static SalaryType? fromKey(String? key) {
    for (final t in SalaryType.values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// Ishbayi turlari — xodimga qaysilari hisoblanishi.
enum PieceKind {
  wash('wash', 'Yuvish', Icons.local_laundry_service_rounded),
  pack('pack', 'Qadoqlash', Icons.inventory_2_rounded),
  courier('courier', 'Yetkazish', Icons.local_shipping_rounded),
  dispatch('dispatch', 'Dispetcherlik', Icons.support_agent_rounded);

  const PieceKind(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static PieceKind? fromKey(String? key) {
    for (final k in PieceKind.values) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// Dispetcher ulushi qanday hisoblanadi.
enum DispatcherMode {
  /// Yaratgan buyurtmasi TOPSHIRILGANDA, uning yakuniy narxidan foiz.
  percent('percent', 'Foiz (%)'),

  /// Har bir yaratilgan buyurtma uchun qat'iy summa — yaratilgan kuni.
  fixed('fixed', 'Har buyurtmaga');

  const DispatcherMode(this.key, this.label);

  final String key;
  final String label;

  static DispatcherMode fromKey(String? key) =>
      key == fixed.key ? fixed : percent;
}

double _num(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;

/// Bitta xizmat turining ishbayi narxlari (o'lchov birligi uchun).
///
/// Kichik/Katta usulidagi xizmatda narx o'lchamga qarab alohida.
class ProductRate {
  const ProductRate({
    this.wash = 0,
    this.pack = 0,
    this.washSmall = 0,
    this.washLarge = 0,
    this.packSmall = 0,
    this.packLarge = 0,
  });

  factory ProductRate.fromMap(Object? raw) {
    if (raw is! Map) return const ProductRate();
    return ProductRate(
      wash: _num(raw['wash']),
      pack: _num(raw['pack']),
      washSmall: _num(raw['washSmall']),
      washLarge: _num(raw['washLarge']),
      packSmall: _num(raw['packSmall']),
      packLarge: _num(raw['packLarge']),
    );
  }

  final double wash;
  final double pack;
  final double washSmall;
  final double washLarge;
  final double packSmall;
  final double packLarge;

  bool get isEmpty =>
      wash == 0 &&
      pack == 0 &&
      washSmall == 0 &&
      washLarge == 0 &&
      packSmall == 0 &&
      packLarge == 0;

  /// Bitta birlik uchun narx — o'lchamga qarab.
  double washFor(MeasureUnit? unit) => switch (unit) {
        MeasureUnit.kichik => washSmall,
        MeasureUnit.katta => washLarge,
        _ => wash,
      };

  double packFor(MeasureUnit? unit) => switch (unit) {
        MeasureUnit.kichik => packSmall,
        MeasureUnit.katta => packLarge,
        _ => pack,
      };

  Map<String, Object?> toMap() => {
        if (wash > 0) 'wash': wash,
        if (pack > 0) 'pack': pack,
        if (washSmall > 0) 'washSmall': washSmall,
        if (washLarge > 0) 'washLarge': washLarge,
        if (packSmall > 0) 'packSmall': packSmall,
        if (packLarge > 0) 'packLarge': packLarge,
      };
}

/// Ishbayi narxlari va ulushlar — "Maosh sozlamasi".
class PayrollRates {
  const PayrollRates({
    this.products = const {},
    this.courierPct = 0,
    this.dispatcherMode = DispatcherMode.percent,
    this.dispatcherValue = 0,
  });

  static const empty = PayrollRates();

  /// Ulush foizining yuqori chegarasi — tasodifan "50" o'rniga "500"
  /// yozilib, biznes zarariga ishlab qolmasligi uchun.
  static const maxPercent = 50.0;

  factory PayrollRates.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    final products = <String, ProductRate>{};
    final rawProducts = raw['products'];
    if (rawProducts is Map) {
      for (final e in rawProducts.entries) {
        final rate = ProductRate.fromMap(e.value);
        if (!rate.isEmpty) products['${e.key}'] = rate;
      }
    }
    return PayrollRates(
      products: products,
      courierPct: _num(raw['courierPct']).clamp(0, maxPercent).toDouble(),
      dispatcherMode: DispatcherMode.fromKey(raw['dispatcherMode'] as String?),
      dispatcherValue: _num(raw['dispatcherValue']).clamp(0, 1e9).toDouble(),
    );
  }

  final Map<String, ProductRate> products;

  /// Dastavchik: topshirgan xizmatlari summasidan foiz.
  final double courierPct;

  final DispatcherMode dispatcherMode;

  /// Foiz (percent) yoki so'm (fixed).
  final double dispatcherValue;

  ProductRate rateOf(String productId) =>
      products[productId] ?? const ProductRate();

  /// Yuvilgan xizmat uchun ishbayi.
  double washPay(String productId, MeasureUnit? unit, double quantity) =>
      _round(rateOf(productId).washFor(unit) * _qty(unit, quantity));

  double packPay(String productId, MeasureUnit? unit, double quantity) =>
      _round(rateOf(productId).packFor(unit) * _qty(unit, quantity));

  double courierPay(double sum) => _round(sum * courierPct / 100);

  /// Foiz rejimida — topshirilgan buyurtma narxidan.
  double dispatchPercentPay(double total) =>
      dispatcherMode == DispatcherMode.percent
          ? _round(total * dispatcherValue / 100)
          : 0;

  /// Qat'iy rejimda — har bir yaratilgan buyurtma uchun.
  double get dispatchFixedPay =>
      dispatcherMode == DispatcherMode.fixed ? dispatcherValue : 0;

  /// O'lchanmagan xizmat (miqdor 0) — 0 so'm. Dona va kichik/katta
  /// xizmatlarda miqdor doim 1 (o'lchash formasi shunday yozadi).
  static double _qty(MeasureUnit? unit, double quantity) =>
      unit != null && quantity > 0 && quantity.isFinite ? quantity : 0;

  /// Tiyin qoldig'i bo'lmasin — so'mgacha yaxlitlanadi.
  static double _round(double v) => v.isFinite ? v.roundToDouble() : 0;

  bool get isConfigured =>
      products.isNotEmpty || courierPct > 0 || dispatcherValue > 0;

  PayrollRates copyWith({
    Map<String, ProductRate>? products,
    double? courierPct,
    DispatcherMode? dispatcherMode,
    double? dispatcherValue,
  }) =>
      PayrollRates(
        products: products ?? this.products,
        courierPct: courierPct ?? this.courierPct,
        dispatcherMode: dispatcherMode ?? this.dispatcherMode,
        dispatcherValue: dispatcherValue ?? this.dispatcherValue,
      );

  Map<String, Object?> toMap() => {
        'products': {
          for (final e in products.entries)
            if (!e.value.isEmpty) e.key: e.value.toMap(),
        },
        'courierPct': courierPct,
        'dispatcherMode': dispatcherMode.key,
        'dispatcherValue': dispatcherValue,
      };
}

/// Mahsulot uchun narx yorlig'i birligi: "m²", "kg", "dona".
String rateUnitLabel(Product product) => switch (product.method) {
      CalculationMethod.m2 => 'm²',
      CalculationMethod.metr => 'm',
      CalculationMethod.kg => 'kg',
      CalculationMethod.dona => 'dona',
      CalculationMethod.kichikKatta => 'dona',
    };

/// Bitta xodimning maosh sozlamasi.
class StaffPay {
  const StaffPay({
    required this.type,
    this.monthly = 0,
    this.pieces = const {},
  });

  factory StaffPay.fromMap(Object? raw) {
    if (raw is! Map) return const StaffPay(type: SalaryType.piece);
    final pieces = <PieceKind>{};
    final rawPieces = raw['pieces'];
    if (rawPieces is Map) {
      for (final e in rawPieces.entries) {
        final kind = PieceKind.fromKey('${e.key}');
        if (kind != null && e.value == true) pieces.add(kind);
      }
    }
    return StaffPay(
      type: SalaryType.fromKey(raw['type'] as String?) ?? SalaryType.piece,
      monthly: _num(raw['monthly']),
      pieces: pieces,
    );
  }

  final SalaryType type;

  /// Qat'iy oylik (so'm, oyiga).
  final double monthly;

  /// Ishbayi hisoblanadigan ish turlari.
  final Set<PieceKind> pieces;

  double get fixedMonthly => type.hasFixed ? monthly : 0;

  Set<PieceKind> get activePieces => type.hasPiece ? pieces : const {};

  Map<String, Object?> toMap() => {
        'type': type.key,
        'monthly': type.hasFixed ? monthly : 0,
        'pieces': {for (final k in PieceKind.values) k.key: pieces.contains(k)},
      };
}

/// Avans yoki oylik to'lovi.
enum PaymentKind {
  advance('advance', 'Avans'),
  salary('salary', 'Oylik');

  const PaymentKind(this.key, this.label);
  final String key;
  final String label;

  static PaymentKind fromKey(String? key) =>
      key == salary.key ? salary : advance;
}

class PayrollPayment {
  const PayrollPayment({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.kind,
    required this.month,
    required this.at,
    this.note = '',
    this.byName = '',
  });

  factory PayrollPayment.fromMap(String id, Map<dynamic, dynamic> map) =>
      PayrollPayment(
        id: id,
        employeeId: map['employeeId'] as String? ?? '',
        amount: _num(map['amount']),
        kind: PaymentKind.fromKey(map['kind'] as String?),
        month: map['month'] as String? ?? '',
        at: (map['at'] as num?)?.toInt() ?? 0,
        note: map['note'] as String? ?? '',
        byName: map['byName'] as String? ?? '',
      );

  final String id;
  final String employeeId;
  final double amount;
  final PaymentKind kind;

  /// Qaysi oy hisobidan: "2026-11".
  final String month;
  final int at;
  final String note;
  final String byName;
}

/// Bitta xodimning BIR KUNLIK (yoki bir necha kunlik yig'indi) ishi.
class WorkTally {
  WorkTally({this.name = ''});

  factory WorkTally.fromMap(Object? raw) {
    final w = WorkTally();
    if (raw is! Map) return w;
    w.name = raw['name'] as String? ?? '';
    w.wash.addAll(UnitAmounts.fromMap(raw['wash']));
    w.washN = _num(raw['washN']).round();
    w.washPay = _num(raw['washPay']);
    w.pack.addAll(UnitAmounts.fromMap(raw['pack']));
    w.packN = _num(raw['packN']).round();
    w.packPay = _num(raw['packPay']);
    w.deliverN = _num(raw['deliverN']).round();
    w.deliverSum = _num(raw['deliverSum']);
    w.deliverPay = _num(raw['deliverPay']);
    w.createN = _num(raw['createN']).round();
    w.createPay = _num(raw['createPay']);
    w.dispatchN = _num(raw['dispatchN']).round();
    w.dispatchSum = _num(raw['dispatchSum']);
    w.dispatchPay = _num(raw['dispatchPay']);
    w.rewashN = _num(raw['rewashN']).round();
    w.rewashPay = _num(raw['rewashPay']);
    return w;
  }

  String name;

  final wash = UnitAmounts();
  var washN = 0;
  var washPay = 0.0;

  final pack = UnitAmounts();
  var packN = 0;
  var packPay = 0.0;

  /// Topshirishlar (oxirgi va bo'lib) — soni, xizmatlar summasi, ulush.
  var deliverN = 0;
  var deliverSum = 0.0;
  var deliverPay = 0.0;

  /// Qabul qilingan (yaratilgan) buyurtmalar; qat'iy rejimdagi ulush.
  var createN = 0;
  var createPay = 0.0;

  /// Foiz rejimi: yaratgan buyurtmasi topshirilganda.
  var dispatchN = 0;
  var dispatchSum = 0.0;
  var dispatchPay = 0.0;

  /// Yuvgan xizmati qayta yuvishga qaytdi — soni va ushlab qolingan summa.
  var rewashN = 0;
  var rewashPay = 0.0;

  bool get isEmpty =>
      washN == 0 &&
      packN == 0 &&
      deliverN == 0 &&
      createN == 0 &&
      dispatchN == 0 &&
      rewashN == 0;

  void addAll(WorkTally o) {
    if (name.isEmpty) name = o.name;
    wash.addAll(o.wash);
    washN += o.washN;
    washPay += o.washPay;
    pack.addAll(o.pack);
    packN += o.packN;
    packPay += o.packPay;
    deliverN += o.deliverN;
    deliverSum += o.deliverSum;
    deliverPay += o.deliverPay;
    createN += o.createN;
    createPay += o.createPay;
    dispatchN += o.dispatchN;
    dispatchSum += o.dispatchSum;
    dispatchPay += o.dispatchPay;
    rewashN += o.rewashN;
    rewashPay += o.rewashPay;
  }

  /// Ishbayi daromad — faqat xodimga belgilangan ish turlari bo'yicha.
  /// Qayta yuvish ushlanmasi yuvish yoqilgan bo'lsa ayiriladi.
  double piecePay(Set<PieceKind> kinds) {
    var total = 0.0;
    if (kinds.contains(PieceKind.wash)) total += washPay - rewashPay;
    if (kinds.contains(PieceKind.pack)) total += packPay;
    if (kinds.contains(PieceKind.courier)) total += deliverPay;
    if (kinds.contains(PieceKind.dispatch)) total += createPay + dispatchPay;
    return total;
  }

  /// Barcha ish turlari bo'yicha (maosh sozlanmagan xodim uchun ham
  /// "bugun qancha ishladi" ni ko'rsatish).
  double get allPiecePay => piecePay(PieceKind.values.toSet());
}

/// Xodimning bir oylik hisob-kitobi.
class MonthPayroll {
  const MonthPayroll({
    required this.employeeId,
    required this.name,
    required this.pay,
    required this.work,
    required this.payments,
  });

  final String employeeId;
  final String name;
  final StaffPay? pay;
  final WorkTally work;
  final List<PayrollPayment> payments;

  bool get configured => pay != null;

  double get fixed => pay?.fixedMonthly ?? 0;
  double get piece => pay == null ? 0 : work.piecePay(pay!.activePieces);
  double get accrued => fixed + piece;
  double get paid => payments.fold(0, (s, p) => s + p.amount);
  double get advances => payments
      .where((p) => p.kind == PaymentKind.advance)
      .fold(0, (s, p) => s + p.amount);
  double get remaining => accrued - paid;
}

/// "2026-11" — oy kaliti.
String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// "20261120" — kun kaliti (qurilma vaqti bo'yicha).
String dayKey(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// Kun kalitidan sana.
DateTime? dayFromKey(String key) {
  if (key.length != 8) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(4, 6));
  final d = int.tryParse(key.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Xizmatga yozilgan ishbayi "kvitansiyasi" — kim, qaysi kuni, qancha.
///
/// Xizmatning o'zida saqlanadi (`washCredit` / `packCredit`). Nega:
///  * qayta yuvishga qaytganda AYNAN o'sha xodimdan, AYNAN o'sha summa
///    ushlab qolinadi — keyin narx o'zgargan bo'lsa ham;
///  * o'lcham keyin tuzatilsa, farq to'g'ri kunga qo'shiladi/ayiriladi;
///  * bir kvitansiya ikki marta qaytarilmaydi (qaytarilgach o'chiriladi).
class ItemCredit {
  const ItemCredit({
    required this.by,
    required this.name,
    required this.day,
    required this.pay,
    this.unit,
    this.quantity = 0,
  });

  static ItemCredit? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final by = raw['by'] as String? ?? '';
    final day = raw['day'] as String? ?? '';
    if (by.isEmpty || day.length != 8) return null;
    final pay = raw['pay'];
    final qty = raw['qty'];
    return ItemCredit(
      by: by,
      name: raw['name'] as String? ?? '',
      day: day,
      pay: pay is num ? pay.toDouble() : 0,
      unit: MeasureUnit.fromKey(raw['unit'] as String?),
      quantity: qty is num ? qty.toDouble() : 0,
    );
  }

  final String by;
  final String name;

  /// Ish yozilgan kun ("20261120") — qaytarishda shu kunga tegiladi.
  final String day;
  final double pay;
  final MeasureUnit? unit;
  final double quantity;

  Map<String, Object?> toMap() => {
        'by': by,
        'name': name,
        'day': day,
        'pay': pay,
        if (unit != null) 'unit': unit!.key,
        if (quantity > 0) 'qty': quantity,
      };
}

/// Buyurtma yaratilganda dispetcherga yozilgan ulush.
class CreateCredit {
  const CreateCredit({
    required this.by,
    required this.day,
    required this.pay,
    required this.mode,
  });

  static CreateCredit? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final by = raw['by'] as String? ?? '';
    final day = raw['day'] as String? ?? '';
    if (by.isEmpty || day.length != 8) return null;
    final pay = raw['pay'];
    return CreateCredit(
      by: by,
      day: day,
      pay: pay is num ? pay.toDouble() : 0,
      mode: DispatcherMode.fromKey(raw['mode'] as String?),
    );
  }

  final String by;
  final String day;
  final double pay;
  final DispatcherMode mode;

  Map<String, Object?> toMap() =>
      {'by': by, 'day': day, 'pay': pay, 'mode': mode.key};
}
