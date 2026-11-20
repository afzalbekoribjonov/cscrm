import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/payroll.dart';
import 'payroll_center.dart';
import 'tenant_scope.dart';

/// Bir nechta ish hisobi o'zgarishini BITTA yozuvga yig'adi.
///
/// Sof Dart — Firebase'siz sinovdan o'tadi. Bir yo'lga bir necha marta
/// qo'shilsa (masalan dispetcher va dastavchik bir odam), qiymatlar
/// jamlanadi: bitta yozuvda bir kalit ikki marta bo'lolmaydi.
class LedgerBatch {
  final _inc = <String, double>{};
  final _names = <String, String>{};

  static String _base(String day, String employeeId) =>
      'work_days/$day/$employeeId';

  bool _valid(String day, String employeeId) =>
      day.length == 8 &&
      employeeId.isNotEmpty &&
      !employeeId.contains(RegExp(r'[.#$\[\]/]'));

  void _add(String day, String employeeId, String field, double delta) {
    if (!_valid(day, employeeId) || delta == 0 || !delta.isFinite) return;
    final path = '${_base(day, employeeId)}/$field';
    final next = (_inc[path] ?? 0) + delta;
    if (next == 0) {
      _inc.remove(path);
    } else {
      _inc[path] = next;
    }
  }

  /// Xodim ismi kun yozuvida ham turadi — xodim keyin o'chirilsa ham
  /// hisobotda "kim" ekani ko'rinib tursin. Kalit: kun yozuvining yo'li.
  void _name(String day, String employeeId, String name) {
    final n = name.trim();
    if (!_valid(day, employeeId) || n.isEmpty) return;
    _names[_base(day, employeeId)] = n.length > 120 ? n.substring(0, 120) : n;
  }

  /// Xizmat yuvildi (qadoqlashga o'tdi).
  void wash(ItemCredit c) {
    _name(c.day, c.by, c.name);
    _add(c.day, c.by, 'washN', 1);
    if (c.unit != null) _add(c.day, c.by, 'wash/${c.unit!.key}', c.quantity);
    _add(c.day, c.by, 'washPay', c.pay);
  }

  /// Xizmat qadoqlandi (tayyor bo'ldi).
  void pack(ItemCredit c) {
    _name(c.day, c.by, c.name);
    _add(c.day, c.by, 'packN', 1);
    if (c.unit != null) _add(c.day, c.by, 'pack/${c.unit!.key}', c.quantity);
    _add(c.day, c.by, 'packPay', c.pay);
  }

  /// Yuvish kvitansiyasi o'lcham tuzatilgani sababli o'zgardi: eskisi
  /// ayiriladi, yangisi qo'shiladi (soni o'zgarmaydi).
  void reviseWash(ItemCredit before, ItemCredit after) {
    if (before.unit != null) {
      _add(before.day, before.by, 'wash/${before.unit!.key}', -before.quantity);
    }
    _add(before.day, before.by, 'washPay', -before.pay);
    _name(after.day, after.by, after.name);
    if (after.unit != null) {
      _add(after.day, after.by, 'wash/${after.unit!.key}', after.quantity);
    }
    _add(after.day, after.by, 'washPay', after.pay);
  }

  /// Yuvgan xizmati qayta yuvishga qaytdi — [day] (bugun) ga ushlanma.
  void rewash(String day, ItemCredit washed) {
    _name(day, washed.by, washed.name);
    _add(day, washed.by, 'rewashN', 1);
    _add(day, washed.by, 'rewashPay', washed.pay);
  }

  /// Topshirish (oxirgi yoki bo'lib): xizmatlar summasi va ulush.
  void deliver(String day, String employeeId, String name,
      {required double sum, required double pay}) {
    _name(day, employeeId, name);
    _add(day, employeeId, 'deliverN', 1);
    _add(day, employeeId, 'deliverSum', sum);
    _add(day, employeeId, 'deliverPay', pay);
  }

  /// Buyurtma yaratildi (qat'iy rejimda — ulush ham).
  void create(String day, String employeeId, String name, {double pay = 0}) {
    _name(day, employeeId, name);
    _add(day, employeeId, 'createN', 1);
    _add(day, employeeId, 'createPay', pay);
  }

  /// Yaratilgan buyurtma o'chirildi — yozilgan ulush qaytariladi.
  void uncreate(CreateCredit c) {
    _add(c.day, c.by, 'createN', -1);
    _add(c.day, c.by, 'createPay', -c.pay);
  }

  /// Foiz rejimi: yaratgan buyurtmasi topshirildi.
  void dispatch(String day, String employeeId, String name,
      {required double sum, required double pay}) {
    _name(day, employeeId, name);
    _add(day, employeeId, 'dispatchN', 1);
    _add(day, employeeId, 'dispatchSum', sum);
    _add(day, employeeId, 'dispatchPay', pay);
  }

  bool get isEmpty => _inc.isEmpty;

  /// Sinov uchun: yo'l → qo'shiladigan qiymat.
  Map<String, double> get increments => Map.unmodifiable(_inc);

  /// Ism yoziladigan yo'llar — faqat haqiqiy o'zgarish bo'lgan kun
  /// yozuvlari uchun (bo'sh yozuv faqat ism bilan yaratilmasin).
  Map<String, String> get names => {
        for (final e in _names.entries)
          if (_inc.keys.any((k) => k.startsWith('${e.key}/')))
            '${e.key}/name': e.value,
      };

  /// Firebase `update` uchun.
  Map<String, Object?> toUpdate() => {
        for (final e in _inc.entries) e.key: ServerValue.increment(e.value),
        ...names,
      };
}

/// Qayta yuvish ogohlantirishi.
class WarningDraft {
  const WarningDraft({
    required this.employeeId,
    required this.orderId,
    required this.itemKey,
    required this.productName,
    required this.reason,
    required this.byId,
    required this.byName,
    this.deduction = 0,
  });

  final String employeeId;
  final int orderId;
  final String itemKey;
  final String productName;
  final String reason;
  final String byId;
  final String byName;
  final double deduction;

  /// Baza qoidalaridagi uzunlik chegaralari — uzun sabab yozilsa ham
  /// ogohlantirish rad etilmasin (qisqartiriladi).
  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  Map<String, Object?> toMap() => {
        'at': ServerValue.timestamp,
        'orderId': orderId,
        'itemKey': _clip(itemKey, 32),
        'productName': _clip(productName, 200),
        if (reason.isNotEmpty) 'reason': _clip(reason.trim(), 500),
        'byId': _clip(byId, 128),
        'byName': _clip(byName.isEmpty ? 'Xodim' : byName, 120),
        if (deduction > 0) 'deduction': deduction,
      };
}

/// Ish hisobi va ogohlantirishlarni bazaga yozadi.
///
/// "YUBOR VA KUTMA": buyurtma bilan ishlayotgan ekran bu yozuvni
/// kutmaydi. Internet bo'lmasa Firebase uni navbatda saqlaydi.
/// Xatolik foydalanuvchiga KO'RSATILMAYDI — bu xodimning ishi emas,
/// buyurtma baribir to'g'ri saqlangan; xato faqat jurnalga yoziladi.
class WorkLedger {
  WorkLedger({TenantScope? scope, PayrollCenter? center})
      : _scope = scope,
        _center = center ?? PayrollCenter.instance;

  final TenantScope? _scope;
  final PayrollCenter _center;

  TenantScope? get _target => _scope ?? TenantScope.maybeCurrent;

  /// Qoidalar yangilangan va maosh tugunlari ochiq.
  bool get enabled => _center.ready.value && _target != null;

  PayrollRates get rates => _center.value;

  void commit(LedgerBatch batch) {
    final scope = _target;
    if (!enabled || scope == null || batch.isEmpty) return;
    unawaited(scope.root.update(batch.toUpdate()).catchError((Object e) {
      debugPrint('Ish hisobi yozilmadi: $e');
    }));
  }

  void warn(WarningDraft draft) {
    final scope = _target;
    if (!enabled || scope == null) return;
    if (draft.employeeId.isEmpty || draft.employeeId == draft.byId) return;
    unawaited(scope
        .ref('warnings/${draft.employeeId}')
        .push()
        .set(draft.toMap())
        .catchError((Object e) {
      debugPrint('Ogohlantirish yozilmadi: $e');
    }));
  }
}
