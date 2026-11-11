import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/calculation_method.dart';
import '../../models/order.dart';
import '../../models/order_status.dart';
import '../../models/pending_order.dart';
import '../../services/order_service.dart';
import '../../services/order_sync_service.dart';
import '../../services/pending_order_store.dart';
import '../../services/policy_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../ui/uz_date_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/order_sections.dart';
import '../../utils/phone.dart';
import '../../utils/phone_input.dart';
import '../../utils/uz_dates.dart';
import 'cart_line.dart';
import 'product_picker_sheet.dart';

/// Yangi buyurtma sahifasi ("Yangi" bo'limidagi "+" tugmasidan).
///
/// TELEFON BIRINCHI: doimiy mijozning raqami kiritilishi bilan uning ismi,
/// manzili va (bor bo'lsa) GPS manzili oxirgi buyurtmasidan avtomatik
/// to'ldiriladi — xodim har safar qaytadan yozmaydi.
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.user, required this.sections});

  final AppUser user;

  /// Qurilmada allaqachon bor buyurtmalar — mijozni internetsiz ham
  /// darhol topish uchun.
  final OrderSections sections;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _phoneFocus = FocusNode();

  DeliveryType _deliveryType = DeliveryType.olibKelish;
  DateTime? _deadline;
  final List<CartLine> _cart = [];
  var _submitting = false;
  var _showErrors = false;

  // --- Doimiy mijoz ---
  Order? _customer;
  String _lookedUp = '';
  var _searching = false;
  String? _autoName;
  String? _autoAddress;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final days = PolicyCenter.instance.value.deadlineDays;
    if (days > 0) {
      _deadline = startOfDay(DateTime.now()).add(Duration(days: days));
    }
    _phoneCtrl.addListener(_onPhoneChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _phoneFocus.requestFocus());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _commentCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- mijozni topish

  void _onPhoneChanged() {
    final phone = normalizePhone(_phoneCtrl.text);
    if (phone.length != 12) {
      if (_customer != null || _lookedUp.isNotEmpty) _forgetCustomer();
      return;
    }
    if (phone != _lookedUp) unawaited(_lookup(phone));
  }

  Future<void> _lookup(String phone) async {
    _lookedUp = phone;
    // 1) Qurilmadagi buyurtmalardan — darhol, internetsiz.
    Order? best;
    for (final o in widget.sections.all) {
      if (normalizePhone(o.customerPhone) != phone) continue;
      if (best == null || o.createdAt > best.createdAt) best = o;
    }
    if (best != null) _apply(best);

    // 2) Bazadan — eski (topshirilgan) buyurtmalar uchun. Bitta yozuv
    //    so'raladi; indeks hali yo'q bo'lsa umuman so'ralmaydi.
    if (!PolicyCenter.instance.serverReady.value) return;
    setState(() => _searching = true);
    try {
      final remote = await OrderService()
          .lastOrderOfCustomer(phone, indexReady: true);
      if (!mounted || _lookedUp != phone) return;
      if (remote != null && (best == null || remote.createdAt > best.createdAt)) {
        _apply(remote);
      }
    } catch (_) {
      // Topilmasa — oddiy yangi mijoz kabi davom etiladi.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _apply(Order o) {
    setState(() {
      _customer = o;
      if (_nameCtrl.text.trim().isEmpty || _nameCtrl.text == _autoName) {
        _nameCtrl.text = o.customerName;
        _autoName = o.customerName;
      }
      if (_addressCtrl.text.trim().isEmpty || _addressCtrl.text == _autoAddress) {
        _addressCtrl.text = o.address;
        _autoAddress = o.address;
      }
      _lat = o.hasPickupLocation ? o.pickupLat : null;
      _lng = o.hasPickupLocation ? o.pickupLng : null;
    });
  }

  /// Raqam o'zgardi yoki "Boshqa mijoz" bosildi — avtomatik to'ldirilgan
  /// ma'lumot olib tashlanadi (qo'lda yozilgani qoladi).
  void _forgetCustomer() {
    setState(() {
      if (_nameCtrl.text == _autoName) _nameCtrl.clear();
      if (_addressCtrl.text == _autoAddress) _addressCtrl.clear();
      _customer = null;
      _autoName = null;
      _autoAddress = null;
      _lat = null;
      _lng = null;
      _lookedUp = '';
    });
  }

  // -------------------------------------------------------------- forma

  Future<void> _pickDeadline() async {
    final today = startOfDay(DateTime.now());
    final picked = await showUzDatePicker(
      context,
      title: 'Topshirish sanasi',
      initial: _deadline ?? today.add(const Duration(days: 1)),
      first: today,
      last: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _addProducts() async {
    final result = await showAppSheet<List<CartLine>>(
      context,
      (_) => const ProductPickerSheet(),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      for (final line in result) {
        final i = _cart.indexWhere((c) => c.product.id == line.product.id);
        if (i >= 0) {
          _cart[i] = _cart[i].copyWith(quantity: _cart[i].quantity + line.quantity);
        } else {
          _cart.add(line);
        }
      }
    });
  }

  String? get _phoneError => isCompletePhone(_phoneCtrl.text)
      ? null
      : 'Telefon raqamini to\'liq kiriting';
  String? get _nameError =>
      _nameCtrl.text.trim().isEmpty ? 'Mijoz ismini kiriting' : null;
  String? get _addressError =>
      PolicyCenter.instance.value.addressRequired &&
              _addressCtrl.text.trim().isEmpty
          ? 'Manzilni kiriting'
          : null;

  Future<void> _submit() async {
    if (_phoneError != null || _nameError != null || _addressError != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _submitting = true);
    try {
      // Buyurtma HAR DOIM avval qurilmadagi navbatga tushadi: internet
      // bo'lmasa ham yo'qolmaydi, raqam esa aloqa tiklangach olinadi.
      await OrderSyncService.instance.enqueue(PendingOrder(
        localId: PendingOrderStore.newLocalId(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        customerName: _nameCtrl.text.trim(),
        customerPhone: normalizePhone(_phoneCtrl.text),
        address: _addressCtrl.text.trim(),
        deadline: _deadline?.millisecondsSinceEpoch,
        deliveryType: _deliveryType,
        items: expandCartToDrafts(_cart),
        createdBy: widget.user.id,
        createdByName: widget.user.historyName,
        comment: _commentCtrl.text.trim(),
        pickupLat: _lat,
        pickupLng: _lng,
      ));
      if (!mounted) return;
      showResult(context, 'Buyurtma qabul qilindi');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        showResult(context, 'Buyurtmani saqlab bo\'lmadi. Qayta urinib ko\'ring.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------------------------------------------------- chizish

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policies = PolicyCenter.instance.value;
    final items = _cart.fold<int>(0, (s, l) => s + l.quantity);

    return Scaffold(
      appBar: AppBar(title: const Text('Yangi buyurtma')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(Gap.page, 10, Gap.page, 10),
          decoration: BoxDecoration(
            color: context.colorSurface,
            border: Border(top: BorderSide(color: context.colorBorder)),
          ),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(items == 0
                ? 'Buyurtmani saqlash'
                : 'Buyurtmani saqlash · $items ta xizmat'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 8, Gap.page, 24),
        children: [
          _Section(
            title: 'Mijoz',
            children: [
              TextField(
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: const [UzPhoneInputFormatter()],
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: AppFonts.tabular,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  labelText: t('Telefon raqami'),
                  prefixText: '+998 ',
                  hintText: '90 123 45 67',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  errorText: _showErrors && _phoneError != null
                      ? t(_phoneError!)
                      : null,
                ),
              ),
              if (_customer != null) ...[
                const SizedBox(height: 10),
                _CustomerCard(
                  order: _customer!,
                  hasGps: _lat != null,
                  onDismiss: _forgetCustomer,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Ism familiya'),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _showErrors && _nameError != null
                      ? t(_nameError!)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t(policies.addressRequired
                      ? 'Manzil'
                      : 'Manzil (ixtiyoriy)'),
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: _lat != null
                      ? Tooltip(
                          message: t('GPS manzil oldingi buyurtmadan olindi'),
                          child: Icon(Icons.my_location_rounded,
                              color: StageTone.success.ink(context)),
                        )
                      : null,
                  errorText: _showErrors && _addressError != null
                      ? t(_addressError!)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Buyurtma',
            children: [
              SegmentedButton<DeliveryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DeliveryType.olibKelish,
                    icon: Icon(Icons.moped_outlined),
                    label: Text('Olib kelish'),
                  ),
                  ButtonSegment(
                    value: DeliveryType.oziKeldi,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('O\'zi keldi'),
                  ),
                ],
                selected: {_deliveryType},
                onSelectionChanged: (s) =>
                    setState(() => _deliveryType = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _deliveryType == DeliveryType.olibKelish
                    ? 'Buyurtma avval "Yetgazma → Olib kelish"ga tushadi.'
                    : 'Buyurtma darhol sexga — "Yuvish" bo\'limiga tushadi.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _DeadlineField(
                deadline: _deadline,
                onPick: _pickDeadline,
                onClear: () => setState(() => _deadline = null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Xizmatlar',
            trailing: TextButton.icon(
              onPressed: _addProducts,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Qo\'shish'),
            ),
            children: [
              if (_cart.isEmpty)
                Text(
                  'Xizmatlarni hozir yoki keyinroq, sexda qo\'shish mumkin.',
                  style: theme.textTheme.bodySmall,
                )
              else
                for (var i = 0; i < _cart.length; i++)
                  _CartRow(
                    line: _cart[i],
                    onChanged: (q) => setState(() {
                      if (q <= 0) {
                        _cart.removeAt(i);
                      } else {
                        _cart[i] = _cart[i].copyWith(quantity: q);
                      }
                    }),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t('Izoh (ixtiyoriy)'),
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Doimiy mijoz topildi — oxirgi buyurtmasi haqida qisqa ma'lumot.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.order,
    required this.hasGps,
    required this.onDismiss,
  });

  final Order order;
  final bool hasGps;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = StageTone.success;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: tone.ink(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doimiy mijoz — ma\'lumotlar to\'ldirildi',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tone.ink(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Oxirgi buyurtma: ${order.code} · '
                  '${UzDates.date(UzDates.fromMillis(order.createdAt))}'
                  '${hasGps ? ' · GPS bor' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('Boshqa mijoz'),
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DeadlineField extends StatelessWidget {
  const _DeadlineField({
    required this.deadline,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? deadline;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = deadline;
    String? hint;
    if (d != null) {
      final days = startOfDay(d).difference(startOfDay(DateTime.now())).inDays;
      hint = days == 0
          ? 'bugun'
          : days == 1
              ? 'ertaga'
              : '$days kundan keyin';
    }
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t('Topshirish sanasi'),
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: d == null
              ? const Icon(Icons.expand_more_rounded)
              : IconButton(
                  tooltip: t('Tozalash'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          d == null
              ? 'Belgilanmagan'
              : '${UzDates.weekdays[d.weekday - 1]}, ${UzDates.date(d)} · $hint',
          style: d == null
              ? theme.textTheme.bodyLarge
                  ?.copyWith(color: context.colorTextTertiary)
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line, required this.onChanged});

  final CartLine line;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDona = line.product.method == CalculationMethod.dona;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconTile(icon: line.product.method.icon, tone: StageTone.brand, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.product.name, style: theme.textTheme.titleSmall),
                Text(
                  isDona
                      ? line.product.priceLabel
                      : '${line.product.priceLabel} · o\'lchami sexda',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _Stepper(value: line.quantity, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: t(value <= 1 ? 'Olib tashlash' : 'Kamaytirish'),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value - 1),
            icon: Icon(value <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                size: 20),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFeatures: AppFonts.tabular,
                  ),
            ),
          ),
          IconButton(
            tooltip: t('Ko\'paytirish'),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
