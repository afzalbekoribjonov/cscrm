import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/payroll.dart';
import 'tenant_scope.dart';

/// Ishbayi narxlari va ulushlar — butun ilova uchun BITTA nusxa.
///
/// Xodimning telefoni ish bajarilgan PAYTDA shu narxlar bilan hisoblaydi
/// (qarang: [WorkLedger]). Tugun kichik va jonli kuzatiladi: boshqaruvchi
/// narxni o'zgartirsa, keyingi ishdan boshlab yangi narx qo'llanadi.
class PayrollCenter extends ValueNotifier<PayrollRates> {
  PayrollCenter._() : super(PayrollRates.empty);

  static final PayrollCenter instance = PayrollCenter._();

  StreamSubscription<Object?>? _sub;

  /// Maosh tugunlari o'qildimi.
  ///
  /// `false` — baza qoidalari hali yangilanmagan (yangi tugunlar yopiq).
  /// Bunday holatda ish hisobi UMUMAN yozilmaydi: aks holda keyinroq
  /// (qoidalar yangilangach) qaytarib olinadigan yozuvlar "yo'q joydan"
  /// ayirilib, manfiy son chiqib qolardi.
  final ready = ValueNotifier<bool>(false);

  void start() {
    final scope = TenantScope.maybeCurrent;
    if (scope == null) return;
    _sub?.cancel();
    _sub = scope.ref('payroll_rates').onValue.listen(
      (event) {
        value = PayrollRates.fromMap(event.snapshot.value);
        ready.value = true;
      },
      onError: (Object error) {
        debugPrint('Maosh narxlari o\'qilmadi: $error');
        ready.value = false;
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    value = PayrollRates.empty;
    ready.value = false;
  }

  /// Faqat sinov uchun.
  @visibleForTesting
  void debugSet(PayrollRates rates, {bool isReady = true}) {
    value = rates;
    ready.value = isReady;
  }
}
