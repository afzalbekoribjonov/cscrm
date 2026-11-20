import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../utils/firebase_map.dart';
import 'sound_service.dart';
import 'tenant_scope.dart';

/// Qayta yuvish ogohlantirishi — xodim yuvgan xizmat qayta yuvishga
/// qaytarilganda unga yoziladi.
class WorkWarning {
  const WorkWarning({
    required this.id,
    required this.at,
    required this.orderId,
    required this.productName,
    required this.reason,
    required this.byName,
    this.deduction = 0,
    this.seenAt,
  });

  factory WorkWarning.fromMap(String id, Map<dynamic, dynamic> map) =>
      WorkWarning(
        id: id,
        at: (map['at'] as num?)?.toInt() ?? 0,
        orderId: (map['orderId'] as num?)?.toInt() ?? 0,
        productName: map['productName'] as String? ?? '',
        reason: map['reason'] as String? ?? '',
        byName: map['byName'] as String? ?? '',
        deduction: (map['deduction'] as num?)?.toDouble() ?? 0,
        seenAt: (map['seenAt'] as num?)?.toInt(),
      );

  final String id;
  final int at;
  final int orderId;
  final String productName;
  final String reason;
  final String byName;

  /// Ishbayidan ushlab qolingan summa.
  final double deduction;

  /// Xodim "Tanishdim" bosgan payt.
  final int? seenAt;

  bool get isSeen => seenAt != null;
}

/// Xodimning o'z ogohlantirishlari (oxirgi 30 tasi) — jonli.
///
/// Faqat XODIM uchun ishga tushadi: boshqaruvchi xizmatni o'zi qayta
/// yuvishga qaytaradi va ogohlantirish olmaydi.
class WarningCenter extends ValueNotifier<List<WorkWarning>> {
  WarningCenter._() : super(const []);

  static final WarningCenter instance = WarningCenter._();

  StreamSubscription<Object?>? _sub;
  String? _employeeId;
  var _loaded = false;

  int get unseenCount => value.where((w) => !w.isSeen).length;

  void start(String employeeId) {
    final scope = TenantScope.maybeCurrent;
    if (scope == null || employeeId.isEmpty) return;
    if (_employeeId == employeeId && _sub != null) return;
    _sub?.cancel();
    _employeeId = employeeId;
    _loaded = false;
    _sub = scope
        .ref('warnings/$employeeId')
        .orderByChild('at')
        .limitToLast(30)
        .onValue
        .listen(
      (event) {
        final raw = asFirebaseMap(event.snapshot.value);
        final list = <WorkWarning>[
          for (final e in raw.entries)
            if (e.value is Map) WorkWarning.fromMap(e.key, e.value as Map),
        ]..sort((a, b) => b.at.compareTo(a.at));
        final before = unseenCount;
        value = list;
        // Yangi ogohlantirish kelganda — ovoz (birinchi yuklanishda emas).
        if (_loaded && unseenCount > before) {
          SoundService.instance.playNotification();
        }
        _loaded = true;
      },
      onError: (Object e) {
        // Qoidalar hali yangilanmagan bo'lsa — ogohlantirish yo'q, xolos.
        debugPrint('Ogohlantirishlar o\'qilmadi: $e');
        value = const [];
      },
    );
  }

  /// "Tanishdim" — barcha ko'rilmaganlar belgilanadi.
  Future<void> acknowledgeAll() async {
    final scope = TenantScope.maybeCurrent;
    final id = _employeeId;
    if (scope == null || id == null) return;
    final unseen = value.where((w) => !w.isSeen).toList();
    if (unseen.isEmpty) return;
    // Bir necha yozuv BITTA so'rovda. Kutilmaydi: internet bo'lmasa
    // Firebase uni navbatda saqlaydi, belgi esa darhol ko'rinadi.
    unawaited(scope.ref('warnings/$id').update({
      for (final w in unseen) '${w.id}/seenAt': ServerValue.timestamp,
    }).catchError((Object e) {
      debugPrint('Ogohlantirish belgilanmadi: $e');
    }));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _employeeId = null;
    _loaded = false;
    value = const [];
  }
}
