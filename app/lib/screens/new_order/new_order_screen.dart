import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/calculation_method.dart';
import '../../models/order_status.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone.dart';
import '../../widgets/employee_app_bar_title.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_action.dart';
import '../../widgets/required_label.dart';
import '../../widgets/theme_toggle_action.dart';
import 'cart_line.dart';
import 'product_picker_sheet.dart';

final _deadlineFormat = DateFormat('dd.MM.yyyy');

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  DeliveryType _deliveryType = DeliveryType.olibKelish;
  DateTime? _deadline;
  final List<CartLine> _cart = [];
  String? _error;
  bool _creating = false;

  bool get _canCreate => widget.access.has(WorkSection.yangi);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addProducts() async {
    final result = await showModalBottomSheet<List<CartLine>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ProductPickerSheet(),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _cart.addAll(result));
  }

  void _removeLine(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _resetForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _commentCtrl.clear();
    setState(() {
      _deliveryType = DeliveryType.olibKelish;
      _deadline = null;
      _cart.clear();
      _error = null;
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    // Ko'pincha ertangi kunga topshiriladi - shu sabab kalendar ochilganda
    // standart sifatida ertangi kun tanlangan holda ochiladi, bitta bosish
    // bilan tasdiqlash mumkin.
    final defaultDay = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? defaultDay,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Topshirish sanasini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || !isCompletePhone(_phoneCtrl.text)) {
      setState(
          () => _error = 'Ism-familiya va to\'liq telefon raqamini kiriting');
      return;
    }
    setState(() {
      _error = null;
      _creating = true;
    });
    try {
      final orderId = await OrderService().createOrder(
        customerName: _nameCtrl.text,
        customerPhone: _phoneCtrl.text,
        address: _addressCtrl.text,
        deadline: _deadline,
        deliveryType: _deliveryType,
        items: expandCartToDrafts(_cart),
        createdBy: widget.currentUserId,
        createdByName: widget.currentUserName,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Buyurtma #$orderId yaratildi')),
      );
    } on TimeoutException {
      // Buyurtma raqami serverdagi hisoblagichdan olinadi - internetsiz
      // yangi buyurtma ochib bo'lmaydi (boshqa amallar esa ishlayveradi).
      setState(() => _error =
          'Internet aloqasi yo\'q. Yangi buyurtma yaratish uchun aloqa '
              'kerak - qolgan ishlar aloqasiz ham davom etadi.');
    } catch (_) {
      setState(() => _error = 'Buyurtmani saqlab bo\'lmadi. Qayta urining.');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: EmployeeAppBarTitle(
          title: 'Yangi buyurtma',
          employeeName: widget.currentUserName,
        ),
        actions: [
          NotificationAction(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
          ),
          const ThemeToggleAction(),
          const LogoutAction(),
        ],
      ),
      body: !_canCreate
          ? _buildNoAccess(context)
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
                child: _buildForm(context, theme),
              ),
            ),
    );
  }

  /// Vakolat berilmagan xodim uchun - hech qanday forma ko'rsatilmaydi.
  Widget _buildNoAccess(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 40, color: context.colorTextSecondary),
            const SizedBox(height: 12),
            Text(
              'Buyurtma yaratish vakolati berilmagan',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(label: requiredLabel('Ism familiya')),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
          decoration: InputDecoration(
            label: requiredLabel('Telefon raqami'),
            hintText: '+998 90 123 45 67',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _addressCtrl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Manzil',
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _pickDeadline,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Topshirish sanasi',
              suffixIcon: _deadline == null
                  ? const Icon(Icons.calendar_month_rounded)
                  : IconButton(
                      tooltip: 'Tozalash',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    ),
            ),
            child: Text(
              _deadline == null
                  ? 'Sanani tanlang'
                  : _deadlineFormat.format(_deadline!),
              style: _deadline == null
                  ? TextStyle(color: theme.textTheme.bodySmall?.color)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _DeliveryToggle(
          value: _deliveryType,
          onChanged: (v) => setState(() => _deliveryType = v),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _commentCtrl,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Izoh',
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Text('Xizmatlar', style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: _addProducts,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Xizmat qo\'shish'),
            ),
          ],
        ),
        if (_cart.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Hali xizmat qo\'shilmagan',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ...List.generate(_cart.length, (i) {
            final line = _cart[i];
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                dense: true,
                title: Text(line.product.name),
                subtitle: Text(line.product.method == CalculationMethod.dona
                    ? 'Soni: ${line.quantity}'
                    : 'Soni: ${line.quantity} · hajmi keyinroq kiritiladi'),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _removeLine(i),
                ),
              ),
            );
          }),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _creating ? null : _submit,
          child: _creating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Buyurtma yaratish'),
        ),
      ],
    );
  }
}

class _DeliveryToggle extends StatelessWidget {
  const _DeliveryToggle({required this.value, required this.onChanged});

  final DeliveryType value;
  final ValueChanged<DeliveryType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DeliveryType.values.map((type) {
        final selected = value == type;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type == DeliveryType.values.first ? 8 : 0,
              left: type == DeliveryType.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : context.colorSurfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : context.colorTextSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
