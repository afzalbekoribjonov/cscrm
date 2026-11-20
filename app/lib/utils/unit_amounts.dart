import '../models/measure_unit.dart';
import 'money.dart';

/// O'lchov birligi bo'yicha yig'indi: "145 m² · 50 m · 3 kg · 6 dona ·
/// 4 kichik · 8 katta".
///
/// [Volume] (team_stats) dan farqi: kichik va katta o'lchamlar "dona"ga
/// QO'SHILMAYDI — ular alohida so'z bilan yoziladi (foydalanuvchi
/// tanlovi, 2026-11-20): yangi xodim ham "4 kichik" ni darhol tushunadi.
class UnitAmounts {
  UnitAmounts();

  /// Tartib — ko'rsatkichlar shu ketma-ketlikda chiqadi.
  static const order = [
    MeasureUnit.m2,
    MeasureUnit.metr,
    MeasureUnit.kg,
    MeasureUnit.dona,
    MeasureUnit.kichik,
    MeasureUnit.katta,
  ];

  final Map<MeasureUnit, double> _byUnit = {};

  void add(MeasureUnit? unit, double quantity) {
    if (unit == null || quantity == 0 || quantity.isNaN) return;
    final next = (_byUnit[unit] ?? 0) + quantity;
    // Kasr qoldig'i (0,000001) "0" deb chiqmasin.
    if (next.abs() < 1e-6) {
      _byUnit.remove(unit);
    } else {
      _byUnit[unit] = next;
    }
  }

  void addAll(UnitAmounts other) {
    for (final e in other._byUnit.entries) {
      add(e.key, e.value);
    }
  }

  double of(MeasureUnit unit) => _byUnit[unit] ?? 0;

  bool get isEmpty => entries.isEmpty;

  /// Musbat qiymatlar, [order] tartibida.
  List<(MeasureUnit, double)> get entries => [
        for (final u in order)
          if ((_byUnit[u] ?? 0) > 0) (u, _byUnit[u]!),
      ];

  /// "145 m² · 50 m · 4 kichik" — bo'sh bo'lsa [empty]. Son va birlik
  /// orasida UZILMAYDIGAN bo'sh joy: "145" bilan "m²" ikki qatorga
  /// bo'linib ketmaydi.
  String label({String separator = ' · ', String empty = ''}) {
    final parts = [for (final (u, q) in entries) amountWithUnit(q, u)];
    return parts.isEmpty ? empty : parts.join(separator);
  }

  /// Firebase'dagi `{m2: 12.5, kichik: 2}` ko'rinishidan.
  factory UnitAmounts.fromMap(Object? raw) {
    final out = UnitAmounts();
    if (raw is Map) {
      for (final e in raw.entries) {
        final unit = MeasureUnit.fromKey('${e.key}');
        final v = e.value;
        if (unit != null && v is num) out.add(unit, v.toDouble());
      }
    }
    return out;
  }
}

/// Ko'rsatkichdagi birlik so'zi. Kichik/katta — o'z nomi bilan
/// ([MeasureUnit.short] ularda "dona").
String unitWord(MeasureUnit unit) => switch (unit) {
      MeasureUnit.m2 => 'm²',
      MeasureUnit.metr => 'm',
      MeasureUnit.kg => 'kg',
      MeasureUnit.dona => 'dona',
      MeasureUnit.kichik => 'kichik',
      MeasureUnit.katta => 'katta',
    };

/// "145 m²", "4 kichik" — uzilmaydigan bo'sh joy bilan.
String amountWithUnit(double quantity, MeasureUnit unit) =>
    '${formatAmount(quantity)}$moneyGroupSeparator${unitWord(unit)}';

/// "12", "12,5", "1 250" — ortiqcha nolsiz, minglik uzilmaydigan
/// bo'shliq bilan (pul summalari bilan bir xil).
String formatAmount(double v) {
  final rounded = (v * 10).round() / 10;
  final whole = rounded.truncate();
  final frac = ((rounded - whole).abs() * 10).round();
  final digits = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(moneyGroupSeparator);
    buf.write(digits[i]);
  }
  final sign = rounded < 0 ? '−' : '';
  return frac == 0 ? '$sign$buf' : '$sign$buf,$frac';
}
