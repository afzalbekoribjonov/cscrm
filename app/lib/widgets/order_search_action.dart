import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order.dart';
import '../models/staff_access.dart';
import '../models/work_section.dart';
import '../theme/app_colors.dart';
import '../utils/phone.dart';
import 'order_card.dart';

/// AppBar'ga qo'yiladigan qidiruv tugmasi - buyurtma ID raqami yoki mijoz
/// telefon raqami bo'yicha tezda topib, natija(lar)ni qisqa karta sifatida
/// ko'rsatadi (bosilsa to'liq ma'lumot ochiladi). Qidiruv allaqachon
/// qurilmada mavjud "orders" ro'yxati ustida ishlaydi - natija bir zumda
/// chiqadi.
class OrderSearchAction extends StatelessWidget {
  const OrderSearchAction({
    super.key,
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    this.section,
  });

  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;
  final WorkSection? section;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Qidiruv',
      icon: const Icon(Icons.search_rounded),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _OrderSearchSheet(
          orders: orders,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          access: access,
          section: section,
        ),
      ),
    );
  }
}

class _OrderSearchSheet extends StatefulWidget {
  const _OrderSearchSheet({
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    this.section,
  });

  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;
  final WorkSection? section;

  @override
  State<_OrderSearchSheet> createState() => _OrderSearchSheetState();
}

class _OrderSearchSheetState extends State<_OrderSearchSheet> {
  final _ctrl = TextEditingController();
  int _mode = 0; // 0 = ID, 1 = Telefon
  List<Order> _results = const [];
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setMode(int mode) {
    setState(() {
      _mode = mode;
      _ctrl.clear();
      _results = const [];
      _searched = false;
    });
  }

  void _search(String value) {
    setState(() {
      _searched = value.trim().isNotEmpty;
      if (_mode == 0) {
        final id = int.tryParse(value.trim());
        _results = id == null
            ? const []
            : widget.orders.where((o) => o.id == id).toList();
      } else {
        // Foydalanuvchi "+998" bilan yozsa ham, yozmasa ham, mahalliy
        // raqamning istalgan qismidan qidira olishi uchun to'g'ridan-to'g'ri
        // raqamlar bo'yicha (kanonizatsiyasiz) qidiriladi.
        final digits = digitsOnly(value);
        _results = digits.length < 5
            ? const []
            : widget.orders
                .where((o) => digitsOnly(o.customerPhone).contains(digits))
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: context.colorBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text('Buyurtmani qidirish', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.colorSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      label: 'ID raqami',
                      selected: _mode == 0,
                      onTap: () => _setMode(0),
                    ),
                  ),
                  Expanded(
                    child: _ModeTab(
                      label: 'Telefon',
                      selected: _mode == 1,
                      onTap: () => _setMode(1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  _mode == 0 ? TextInputType.number : TextInputType.phone,
              inputFormatters: _mode == 0
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              onChanged: _search,
              decoration: InputDecoration(
                labelText: _mode == 0 ? 'Buyurtma ID raqami' : 'Telefon raqami',
                hintText: _mode == 0 ? 'Masalan: 42' : '90 123 45 67',
                prefixText: _mode == 0 ? '#' : null,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_searched && _results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Hech narsa topilmadi',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    for (final order in _results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderCard(
                          order: order,
                          currentUserId: widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          access: widget.access,
                          section: widget.section,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? AppColors.primary : context.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}
