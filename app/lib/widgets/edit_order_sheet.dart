import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';
import '../utils/phone.dart';
import 'required_label.dart';

final _editDeadlineFormat = DateFormat('dd.MM.yyyy');

/// Buyurtmaning asosiy ma'lumotlarini (mahsulotlar, holat va tarixdan
/// tashqari) tahrirlash oynasi - istalgan bo'limdagi buyurtma kartasidan
/// ochiladi.
class EditOrderSheet extends StatefulWidget {
  const EditOrderSheet({super.key, required this.order});

  final Order order;

  @override
  State<EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<EditOrderSheet> {
  late final _nameCtrl = TextEditingController(text: widget.order.customerName);
  late final _phoneCtrl = TextEditingController(
    text: formatPhoneForDisplay(widget.order.customerPhone),
  );
  late final _addressCtrl = TextEditingController(text: widget.order.address);
  late DeliveryType _deliveryType = widget.order.deliveryType;
  late DateTime? _deadline = widget.order.deadline == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.order.deadline!);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Topshirish sanasini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || !isCompletePhone(_phoneCtrl.text)) {
      setState(
          () => _error = 'Ism-familiya va to\'liq telefon raqamini kiriting');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await OrderService().updateOrderDetails(
        orderId: widget.order.id,
        customerName: _nameCtrl.text,
        customerPhone: _phoneCtrl.text,
        address: _addressCtrl.text,
        deadline: _deadline,
        deliveryType: _deliveryType,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Saqlab bo\'lmadi. Qayta urining.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.order.code} ni tahrirlash',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
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
                hintText: '90 123 45 67 yoki +998 90 123 45 67',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressCtrl,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Manzil'),
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
                      : _editDeadlineFormat.format(_deadline!),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<DeliveryType>(
              segments: DeliveryType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                  .toList(),
              selected: {_deliveryType},
              onSelectionChanged: (s) =>
                  setState(() => _deliveryType = s.first),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
