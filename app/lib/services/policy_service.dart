import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/business_policies.dart';
import '../utils/offline_write.dart';
import 'tenant_scope.dart';

/// Biznesning "Ilova qonuniyatlari" — butun ilova uchun BITTA nusxa.
///
/// Jonli kuzatiladi: boshqaruvchi qoidani o'zgartirsa, xodimlarning
/// telefonida u darhol kuchga kiradi. Tugun kichik (bir necha maydon),
/// shuning uchun kuzatish trafikka deyarli ta'sir qilmaydi.
class PolicyCenter extends ValueNotifier<BusinessPolicies> {
  PolicyCenter._() : super(BusinessPolicies.defaults);

  static final PolicyCenter instance = PolicyCenter._();

  StreamSubscription<Object?>? _sub;

  /// Sozlamalar tuguni o'qildimi.
  ///
  /// `false` — baza qoidalari hali yangilanmagan (yangi tugun yopiq).
  /// Ilova bunday holatda ham ishlaydi: standart qoidalar bilan. Shu
  /// belgiga qarab yangi indeksga bog'liq so'rovlar (mijozni telefon
  /// bo'yicha topish) ham o'chirib qo'yiladi — indeksi yo'q so'rov
  /// butun buyurtmalar ro'yxatini yuklab yuborardi.
  final serverReady = ValueNotifier<bool>(false);

  void start() {
    final scope = TenantScope.maybeCurrent;
    if (scope == null) return;
    _sub?.cancel();
    _sub = scope.ref('settings/policies').onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        value = BusinessPolicies.fromMap(raw is Map ? raw : null);
        serverReady.value = true;
      },
      onError: (Object error) {
        // Qoidalar yangilanmagan bo'lsa — standart qiymatlar bilan
        // davom etamiz, ish to'xtamaydi.
        debugPrint('Ilova qonuniyatlari o\'qilmadi: $error');
        serverReady.value = false;
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    value = BusinessPolicies.defaults;
    serverReady.value = false;
  }

  /// Faqat biznes egasi saqlay oladi (Database qoidalari ham shuni
  /// talab qiladi).
  Future<void> save(BusinessPolicies policies) async {
    final scope = TenantScope.current;
    try {
      await awaitOrFail(
        scope.ref('settings/policies').set(policies.toMap()),
        timeout: const Duration(seconds: 10),
      );
      value = policies;
    } on FirebaseException catch (e) {
      throw PolicySaveException(
        e.code == 'permission-denied'
            ? 'Qoidani saqlab bo\'lmadi. Tizim hali yangilanmagan — '
                'birozdan keyin qayta urinib ko\'ring.'
            : 'Qoidani saqlab bo\'lmadi. Internetni tekshirib, qayta '
                'urinib ko\'ring.',
      );
    } on TimeoutException {
      throw const PolicySaveException(
        'Internet aloqasi yo\'q. Qoida aloqa tiklanganda saqlanadi.',
      );
    }
  }
}

class PolicySaveException implements Exception {
  const PolicySaveException(this.message);
  final String message;

  @override
  String toString() => message;
}
