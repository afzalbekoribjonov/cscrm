import 'dart:async';

import 'package:flutter/foundation.dart';

import 'license_service.dart';

/// Obuna holatini butun ilova bo'ylab bitta joyda saqlaydi.
///
/// Ikki joyda kerak bo'ladi va ular bir-biridan uzoq:
///  * [LicenseGate] — bloklangan bo'lsa ish ekranlari o'rniga to'lov
///    ekranini ko'rsatadi
///  * `HomeShell` — muddat tugashiga oz qolganda tepada eslatma chizadi
///
/// Ikkalasi ham bir xil holatni ko'rishi va bir xil vaqtda yangilanishi
/// kerak, shuning uchun holat shu yerda — har biri o'zi so'rasa, server
/// ikki barobar ko'p so'rov olardi va ular bir-biriga mos kelmasligi
/// mumkin edi.
class LicenseController extends ValueNotifier<LicenseResolution?> {
  LicenseController._() : super(null);

  static final LicenseController instance = LicenseController._();

  final _service = LicenseService();

  String? _tenantId;
  Timer? _timer;
  var _refreshing = false;

  /// Hozir tekshirilyaptimi — tugmada aylanma ko'rsatish uchun.
  bool get isRefreshing => _refreshing;

  /// Kirish muvaffaqiyatli bo'lgach chaqiriladi.
  void start(String tenantId) {
    _tenantId = tenantId;
    unawaited(refresh());

    // Davriy tekshiruv. Javob 6 soat yaroqli, lekin to'lov tasdiqlangach
    // ilova buni tezroq bilishi kerak — shuning uchun tez-tez so'raymiz.
    // So'rov juda arzon (bitta kichik JSON).
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(refresh()),
    );
  }

  /// Chiqishda chaqiriladi.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _tenantId = null;
    value = null;
    await _service.clearCache();
  }

  /// Holatni qayta so'raydi. "Tekshirish" tugmasi ham shuni chaqiradi.
  Future<void> refresh() async {
    final tenantId = _tenantId;
    if (tenantId == null || _refreshing) return;

    _refreshing = true;
    notifyListeners();
    try {
      value = await _service.resolve(tenantId: tenantId);
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
