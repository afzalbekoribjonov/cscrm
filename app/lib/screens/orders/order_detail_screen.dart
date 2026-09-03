import 'package:flutter/material.dart';

import '../../models/item_status.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/order_item.dart';
import '../../models/order_status.dart';
import '../../models/product.dart';
import '../../models/staff_access.dart';
import '../../models/staff_permission.dart';
import '../../models/work_section.dart';
import '../../services/location_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/edit_order_sheet.dart';
import '../../widgets/order_card.dart' show dayBadgeColor, dayBadgeText;
import '../../widgets/payment_dialog.dart';
import '../../widgets/phone_link.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/stream_error_view.dart';
import '../new_order/cart_line.dart';
import '../new_order/product_picker_sheet.dart';
import 'widgets/comment_bubble.dart';
import 'widgets/edit_item_sheet.dart';
import 'widgets/order_action_cards.dart';
import 'widgets/order_history_view.dart';
import 'widgets/order_item_card.dart';
import 'widgets/order_sheets.dart';
import 'widgets/order_view_common.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    this.section,
  });

  final int orderId;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  /// Buyurtma qaysi bo'limdan ochilgani. null bo'lsa (masalan boshqaruv
  /// paneli yoki hisobot ekranidan) - faqat ko'rish rejimi (admin bundan
  /// mustasno, unga barcha amallar ochiq).
  final WorkSection? section;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _service = OrderService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, mahalliy
  // setState() yangi Stream obyekti hosil qilib, ekranni "waiting" holatiga
  // qaytarib yuborardi.
  late final _orderStream = _service.streamOrder(widget.orderId);

  /// Tarix ALOHIDA oqimda — u endi buyurtma tugunida emas.
  ///
  /// Shu sabab ro'yxat ekranlari tarixni umuman yuklamaydi; u faqat shu
  /// karta ochilganda so'raladi.
  late final _historyStream = _service.streamOrderHistory(widget.orderId);

  /// Tarix hali kelmagan bo'lsa bo'sh — karta baribir ochiladi.
  List<OrderHistoryEntry> _history = const [];
  bool _commentsOpen = false;
  bool _historyOpen = false;
  final _commentCtrl = TextEditingController();
  bool _sendingComment = false;
  bool _busy = false;

  /// Admin qilgan o'zgarish tarixda "Admin" deb ko'rinadi.
  String get _byName =>
      widget.access.isAdmin ? 'Admin' : widget.currentUserName;

  bool get _isAdmin => widget.access.isAdmin;

  /// Yuvish bo'limidagi ishlar (xizmat qo'shish, o'lchash, qadoqlashga
  /// o'tkazish) shu bo'limdan turibgina bajariladi.
  bool get _canWashHere =>
      widget.access.canActIn(widget.section, WorkSection.yuvish);

  bool get _canPackageHere =>
      widget.access.canActIn(widget.section, WorkSection.qadoqlash);

  bool get _canTransportHere =>
      widget.access.canActIn(widget.section, WorkSection.yetgazma);

  /// Buyurtma ma'lumotlari va xizmatlarini o'zgartirish: buyurtma sexda
  /// bo'lsa Yuvish vakolati bilan, olib kelinayotgan bo'lsa Yetgazma
  /// vakolati bilan.
  bool _canManage(Order order) {
    if (_isAdmin) return true;
    if (order.status.isInWorkshop) return _canWashHere;
    if (order.status == OrderStatus.olibKelish) return _canTransportHere;
    return false;
  }

  /// Xizmat hajmini o'lchash/narxini o'zgartirish - bo'lim vakolatidan
  /// tashqari alohida "O'lchash va narx" huquqi ham talab qilinadi.
  bool _canMeasure(Order order) =>
      _canManage(order) && widget.access.can(StaffPermission.measure);

  /// Mijoz ma'lumotlarini (ism, telefon, manzil, muddat) tahrirlash.
  bool _canEditDetails(Order order) =>
      _canManage(order) && widget.access.can(StaffPermission.editOrder);

  bool get _canDelete => widget.access.can(StaffPermission.deleteOrder);

  bool get _canSeePhone => widget.access.can(StaffPermission.viewPhone);

  /// Izoh yozish vakolati. O'qish hammaga ochiq - faqat yozish cheklanadi.
  bool get _canComment => widget.access.can(StaffPermission.comment);

  /// Xizmat turini almashtirish va xizmatni o'chirish vakolati.
  bool get _canManageItems => widget.access.can(StaffPermission.manageItems);

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEdit(Order order) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditOrderSheet(order: order),
    );
  }

  Future<void> _confirmDelete(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buyurtmani o\'chirish'),
        content: Text(
          '${order.code} (${order.customerName}) butunlay o\'chiriladi. '
          'Bu amalni ortga qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteOrder(order.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _sendComment(Order order) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await _service.addComment(
        orderId: order.id,
        text: text,
        authorId: widget.currentUserId,
        authorName: _byName,
      );
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  /// Buyurtmani qabul qilish. Topshirish sanasi shu bosqichda majburiy -
  /// hali belgilanmagan bo'lsa avval kalendar ochiladi.
  Future<void> _acceptPickup(Order order) async {
    var deadline = order.deadline == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(order.deadline!);
    if (deadline == null) {
      deadline = await _pickDeadline();
      // Kalendar ochiq turganda ekran yopilgan bo'lishi mumkin.
      if (deadline == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      if (order.deadline == null) {
        await _service.setDeadline(
          orderId: order.id,
          deadline: deadline,
          byEmployeeId: widget.currentUserId,
          byName: _byName,
        );
      }
      await _service.advanceStatus(
        order: order,
        toStatus: OrderStatus.yuvishda,
        byEmployeeId: widget.currentUserId,
        byName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DateTime?> _pickDeadline() async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day + 1),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Topshirish sanasini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
  }

  Future<void> _saveGps(Order order) async {
    setState(() => _busy = true);
    try {
      final position = await LocationService().getCurrentLocation();
      await _service.savePickupLocation(
        orderId: order.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS manzil saqlandi')),
        );
      }
    } on LocationFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDirections(Order order) async {
    if (!order.hasPickupLocation) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('GPS ma\'lumotlari saqlanmagan'),
          content: const Text(
            'Bu buyurtma olib kelinayotganda GPS manzil saqlanmagan, '
            'shu sabab xaritada yo\'nalish ko\'rsatib bo\'lmaydi. '
            'Mijozning manzili va telefon raqamidan foydalaning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Yopish'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      await LocationService()
          .openDirections(order.pickupLat!, order.pickupLng!);
    } on LocationFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deliver(Order order) async {
    final result = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaymentDialog(
        orderTotal: order.totalPrice,
        allowDiscount: widget.access.can(StaffPermission.discount),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.markDelivered(
        order: order,
        paymentMethod: result.method,
        paymentAmount: result.amount,
        shortfallIsDiscount: result.shortfallIsDiscount,
        byEmployeeId: widget.currentUserId,
        byName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advanceItem(Order order, OrderItem item, ItemStatus to) async {
    setState(() => _busy = true);
    try {
      await _service.updateItemStatus(
        order: order,
        item: item,
        toStatus: to,
        byEmployeeId: widget.currentUserId,
        byName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rewash(Order order, OrderItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => RewashReasonDialog(productName: item.productName),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.updateItemStatus(
        order: order,
        item: item,
        toStatus: ItemStatus.qaytaYuvildi,
        rewashReason: reason,
        byEmployeeId: widget.currentUserId,
        byName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItemComment(Order order, OrderItem item, String text) async {
    if (text.trim().isEmpty) return;
    await _service.addItemComment(
      orderId: order.id,
      itemKey: item.key,
      text: text,
      authorId: widget.currentUserId,
      authorName: _byName,
    );
  }

  Future<void> _addProducts(Order order) async {
    final cart = await showModalBottomSheet<List<CartLine>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ProductPickerSheet(),
    );
    if (cart == null || cart.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.addItemsToOrder(
        orderId: order.id,
        items: expandCartToDrafts(cart),
        createdBy: widget.currentUserId,
        createdByName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editItem(Order order, OrderItem item) async {
    setState(() => _busy = true);
    Product? product;
    try {
      product = await ProductService().getProduct(item.productId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xizmat topilmadi, o\'lchab bo\'lmadi.')),
      );
      return;
    }
    final result = await showModalBottomSheet<ItemEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditItemSheet(
        product: product!,
        currentHajm: item.hajm,
        currentPrice: item.price,
        // Xizmat turini almashtirish alohida vakolat talab qiladi.
        canChangeProduct: _canManageItems,
      ),
    );
    if (result == null || !mounted) return;
    await _service.updateItemMeasurement(
      order: order,
      item: item,
      hajm: result.hajm,
      price: result.price,
      unit: result.unit,
      quantity: result.quantity,
      newProductId:
          result.productId == item.productId ? null : result.productId,
      newProductName:
          result.productName == item.productName ? null : result.productName,
      byEmployeeId: widget.currentUserId,
      byName: _byName,
    );
  }

  Future<void> _deleteItem(Order order, OrderItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xizmatni o\'chirish'),
        content: Text(
          '"${item.productName}" buyurtmadan butunlay o\'chiriladi va '
          'umumiy narx qayta hisoblanadi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.deleteItem(
        order: order,
        item: item,
        byEmployeeId: widget.currentUserId,
        byName: _byName,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tarix oqimi buyurtma oqimidan MUSTAQIL: tarix kelmasa ham karta
    // ochilaveradi, faqat tarix bo'limi bo'sh turadi.
    return StreamBuilder<List<OrderHistoryEntry>>(
      stream: _historyStream,
      builder: (context, historySnap) {
        _history = historySnap.data ?? const [];
        return _buildWithOrder(context);
      },
    );
  }

  Widget _buildWithOrder(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Buyurtma #${widget.orderId}')),
            body: StreamErrorView(error: snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text('Buyurtma #${widget.orderId}')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final order = snapshot.data;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Buyurtma #${widget.orderId}')),
            body: const Center(child: Text('Bu buyurtma o\'chirilgan')),
          );
        }
        return _buildBody(context, order);
      },
    );
  }

  Widget _buildBody(BuildContext context, Order order) {
    final theme = Theme.of(context);
    final dayText = dayBadgeText(order);
    final canManage = _canManage(order);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.code),
        actions: [
          if (_canEditDetails(order))
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEdit(order),
            ),
          if (_canDelete)
            IconButton(
              tooltip: 'O\'chirish',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              onPressed: () => _confirmDelete(order),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 24 + bottomInset),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    PhoneLink(
                      phone: order.customerPhone,
                      style: theme.textTheme.bodyMedium,
                      iconSize: 16,
                      masked: !_canSeePhone,
                    ),
                    if (order.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: context.colorTextSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(order.address,
                                  style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 9),
                    const Divider(height: 1),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(Icons.event_rounded,
                            size: 16, color: dayBadgeColor(context, order)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.deadline == null
                                ? 'Muddat belgilanmagan'
                                : 'Topshirish: ${orderDateFormat.format(DateTime.fromMillisecondsSinceEpoch(order.deadline!))}'
                                    '${dayText != null ? ' ($dayText)' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: dayBadgeColor(context, order),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Yaratdi: ${order.createdByName} · ${orderTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(order.createdAt))}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (order.pickedUpAt != null)
                      Text(
                        'Olib kelindi: ${orderTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(order.pickedUpAt!))}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (order.readyAt != null)
                      Text(
                        'Sex ishi tugadi: ${orderTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(order.readyAt!))}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (order.deliveredAt != null)
                      Text(
                        'Yetgazildi: ${orderTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(order.deliveredAt!))}'
                        '${order.paymentMethod != null ? ' · ${order.paymentMethod} · ${order.paymentAmount?.toStringAsFixed(0)} so\'m' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (order.totalPrice > 0) ...[
                      const SizedBox(height: 9),
                      const Divider(height: 1),
                      const SizedBox(height: 9),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Jami',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${order.totalPrice.toStringAsFixed(0)} so\'m',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (order.status == OrderStatus.olibKelish &&
                _canTransportHere) ...[
              const SizedBox(height: 12),
              PickupActionCard(
                hasGps: order.hasPickupLocation,
                busy: _busy,
                onSaveGps: () => _saveGps(order),
                onAccept: () => _acceptPickup(order),
              ),
            ],
            if (order.status == OrderStatus.yetgazishgaTayyor &&
                _canTransportHere) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: compactButtonStyle,
                  onPressed: () => _openDirections(order),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Yo\'lga chiqish'),
                ),
              ),
              const SizedBox(height: 8),
              TransportActionCard(
                label: 'Barcha xizmatlar tayyor, yetgazish kutilmoqda.',
                buttonLabel: 'Yetgazildi',
                busy: _busy,
                onPressed: () => _deliver(order),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Xizmatlar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    )),
                const Spacer(),
                if (canManage)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _addProducts(order),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Xizmat qo\'shish'),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Xizmat qo\'shilmagan',
                    style: theme.textTheme.bodyMedium),
              )
            else
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OrderItemCard(
                    key: ValueKey(item.key),
                    item: item,
                    inWorkshop: order.status.isInWorkshop,
                    canWash: _canWashHere,
                    canPackage: _canPackageHere,
                    canMeasure: _canMeasure(order),
                    canRewash: _canPackageHere &&
                        widget.access.can(StaffPermission.rewash),
                    canComment: _canComment,
                    canDelete: canManage && _canManageItems,
                    itemHistory: _history
                        .where(
                            (h) => h.belongsToItem(item.key, item.productName))
                        .toList(),
                    onDelete: () => _deleteItem(order, item),
                    onAdvance: (to) => _advanceItem(order, item, to),
                    onRewash: () => _rewash(order, item),
                    onEdit: () => _editItem(order, item),
                    onAddComment: (text) => _addItemComment(order, item, text),
                  ),
                ),
            const SizedBox(height: 4),
            DropdownSection(
              icon: Icons.mode_comment_outlined,
              label: order.comments.isEmpty
                  ? 'Izoh qoldirish'
                  : '${order.comments.length} ta izoh',
              open: _commentsOpen,
              onToggle: () => setState(() => _commentsOpen = !_commentsOpen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final comment in order.comments)
                    CommentBubble(
                      authorName: comment.authorName,
                      text: comment.text,
                      createdAt: comment.createdAt,
                    ),
                  if (_canComment)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(order),
                            decoration: const InputDecoration(
                              hintText: 'Izoh yozing...',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: _sendingComment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          onPressed: _sendingComment
                              ? null
                              : () => _sendComment(order),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            DropdownSection(
              icon: Icons.history_rounded,
              label: _history.isEmpty
                  ? 'Tarix yo\'q'
                  : '${_history.length} ta o\'zgarish tarixi',
              open: _historyOpen,
              onToggle: () => setState(() => _historyOpen = !_historyOpen),
              child: HistoryTimeline(entries: _history),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bo'lim amallari uchun ixcham tugma o'lchami - ekranda kamroq joy egallaydi.
