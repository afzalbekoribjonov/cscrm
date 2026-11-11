import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/business_policies.dart';
import '../../models/item_status.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/order_item.dart';
import '../../models/order_status.dart';
import '../../models/product.dart';
import '../../models/staff_permission.dart';
import '../../models/work_section.dart';
import '../../services/location_service.dart';
import '../../services/order_service.dart';
import '../../services/policy_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/action_menu.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../ui/uz_date_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/order_sections.dart';
import '../../utils/phone.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/edit_order_sheet.dart';
import '../../widgets/payment_dialog.dart';
import '../../widgets/phone_link.dart';
import '../../widgets/stage_visuals.dart';
import '../../widgets/stream_error_view.dart';
import '../new_order/cart_line.dart';
import '../new_order/product_picker_sheet.dart';
import 'widgets/comment_bubble.dart';
import 'widgets/edit_item_sheet.dart';
import 'widgets/handover_sheet.dart';
import 'widgets/order_history_view.dart';
import 'widgets/order_item_tile.dart';
import 'widgets/order_sheets.dart';

/// Buyurtmaning to'liq ko'rinishi. Jonli: boshqa xodim nimanidir
/// o'zgartirsa, ekran darhol yangilanadi.
///
/// Bo'limdan ochilganda FAQAT shu bo'limning xizmatlari to'liq
/// ko'rsatiladi va faqat shu bo'limning amallari ochiq. Boshqa
/// bo'limdagi xizmatlar pastda belgilar bilan.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.user,
    this.section,
    @visibleForTesting this.orderStream,
  });

  /// Faqat sinov/rasm uchun — bazasiz namunaviy buyurtma.
  final Stream<Order?>? orderStream;

  final int orderId;
  final AppUser user;

  /// Qaysi bo'limdan ochilgani. `null` — boshqaruvchi yoki qidiruvdan:
  /// barcha xizmatlar ko'rinadi.
  final WorkSection? section;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final _service = OrderService();
  late final _orderStream =
      widget.orderStream ?? _service.streamOrder(widget.orderId);

  /// Tarix faqat KERAK BO'LGANDA yuklanadi (tarix bo'limi ochilganda yoki
  /// xizmat tarixi so'ralganda). Ilgari har bir buyurtma ochilishi bilan
  /// yuklanardi — ko'pincha hech kim qaramasa ham.
  final _history = ValueNotifier<List<OrderHistoryEntry>?>(null);
  StreamSubscription<List<OrderHistoryEntry>>? _historySub;

  final _commentCtrl = TextEditingController();
  var _sendingComment = false;
  var _historyOpen = false;
  var _busy = false;

  AppUser get _user => widget.user;
  String get _byName => _user.historyName;
  BusinessPolicies get _policies => PolicyCenter.instance.value;

  @override
  void dispose() {
    _historySub?.cancel();
    _history.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _ensureHistory() {
    _historySub ??= _service.streamOrderHistory(widget.orderId).listen(
          (entries) => _history.value = entries,
          onError: (Object _) => _history.value = const [],
        );
  }

  // ------------------------------------------------------------ vakolatlar

  bool _canIn(WorkSection s) => _user.access.canActIn(widget.section, s);
  bool get _canWashHere => _canIn(WorkSection.yuvish);
  bool get _canPackageHere => _canIn(WorkSection.qadoqlash);
  bool get _canTransportHere =>
      _canIn(WorkSection.yetgazma) || _canIn(WorkSection.ombor);

  /// Buyurtma ma'lumoti va xizmatlarini o'zgartirish.
  ///
  /// Topshirilgan buyurtma YOPIQ — boshqaruvchiga ham: puli olingan va
  /// kunlik hisobotga kirgan, keyin o'zgarsa hisobot buzilardi.
  bool _canManage(Order order) {
    if (order.status.isClosed) return false;
    if (_user.isManager) return true;
    if (order.status.isInWorkshop) return _canWashHere;
    if (order.status == OrderStatus.olibKelish) return _canTransportHere;
    return false;
  }

  bool _canEditDetails(Order o) =>
      _canManage(o) && _user.access.can(StaffPermission.editOrder);
  bool _canDelete(Order o) =>
      !o.status.isClosed && _user.access.can(StaffPermission.deleteOrder);
  bool get _canSeePhone => _user.access.can(StaffPermission.viewPhone);
  bool get _canComment => _user.access.can(StaffPermission.comment);

  ItemPermissions _itemPermissions(Order order) => ItemPermissions(
        wash: _canWashHere && order.status.isInWorkshop,
        package: _canPackageHere,
        measure: _canManage(order) && _user.access.can(StaffPermission.measure),
        rewash: _user.access.can(StaffPermission.rewash),
        delete:
            _canManage(order) && _user.access.can(StaffPermission.manageItems),
        comment: _canComment,
        measureBeforeWash: _policies.measureBeforeWash,
        measureBeforePackaging: _policies.measureBeforePackaging,
      );

  // ---------------------------------------------------------------- amallar

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showResult(context, done);
    } on TimeoutException {
      if (mounted) {
        showResult(context,
            'Internet aloqasi yo\'q. Aloqa tiklanganda qayta urinib ko\'ring.',
            error: true);
      }
    } on LocationFailure catch (e) {
      if (mounted) showResult(context, e.message, error: true);
    } catch (e) {
      debugPrint('Buyurtma amali bajarilmadi: $e');
      if (mounted) {
        showResult(context, 'Amalni bajarib bo\'lmadi. Qayta urinib ko\'ring.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startWash(Order order, List<OrderItem> items) => _run(
        () => _service.startWash(
          order: order,
          items: items,
          byEmployeeId: _user.id,
          byName: _byName,
        ),
        done: items.length == 1
            ? '${items.first.productName} yuvishga olindi'
            : '${items.length} ta xizmat yuvishga olindi',
      );

  Future<void> _advanceItem(Order order, OrderItem item, ItemStatus to) => _run(
        () => _service.updateItemStatus(
          order: order,
          item: item,
          toStatus: to,
          byEmployeeId: _user.id,
          byName: _byName,
        ),
        done: to == ItemStatus.tayyor
            ? '${item.productName} tayyor'
            : '${item.productName} qadoqlashga o\'tdi',
      );

  Future<void> _rewash(Order order, OrderItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => RewashReasonDialog(
        productName: item.productName,
        reasonRequired: _policies.rewashReasonRequired,
      ),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _service.updateItemStatus(
        order: order,
        item: item,
        toStatus: ItemStatus.qaytaYuvildi,
        rewashReason: reason,
        byEmployeeId: _user.id,
        byName: _byName,
      ),
      done: '${item.productName} qayta yuvishga qaytarildi',
    );
  }

  Future<void> _measure(Order order, OrderItem item) async {
    Product? product;
    setState(() => _busy = true);
    try {
      product = await ProductService().getProduct(item.productId);
    } catch (_) {
      product = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (product == null) {
      showResult(context, 'Bu xizmat turi o\'chirilgan — o\'lchab bo\'lmadi.',
          error: true);
      return;
    }
    final result = await showAppSheet<ItemEditResult>(
      context,
      (_) => EditItemSheet(
        product: product!,
        currentHajm: item.hajm,
        currentPrice: item.price,
        canChangeProduct: _user.access.can(StaffPermission.manageItems),
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => _service.updateItemMeasurement(
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
        byEmployeeId: _user.id,
        byName: _byName,
      ),
      done: 'O\'lcham saqlandi',
    );
  }

  Future<void> _deleteItem(Order order, OrderItem item) async {
    final ok = await confirmAction(
      context,
      title: 'Xizmatni o\'chirish',
      message: '"${item.productName}" buyurtmadan o\'chiriladi va narx qayta '
          'hisoblanadi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _service.deleteItem(
        order: order,
        item: item,
        byEmployeeId: _user.id,
        byName: _byName,
      ),
      done: 'Xizmat o\'chirildi',
    );
  }

  Future<void> _addProducts(Order order) async {
    final cart = await showAppSheet<List<CartLine>>(
      context,
      (_) => const ProductPickerSheet(),
    );
    if (cart == null || cart.isEmpty || !mounted) return;
    await _run(
      () => _service.addItemsToOrder(
        orderId: order.id,
        items: expandCartToDrafts(cart),
        createdBy: _user.id,
        createdByName: _byName,
      ),
      done: 'Xizmat qo\'shildi',
    );
  }

  Future<void> _openComments(OrderItem item) => showAppSheet<void>(
        context,
        (_) => ItemCommentsSheet(
          title: item.productName,
          comments: item.comments,
          canWrite: _canComment,
          onSend: (text) => _service.addItemComment(
            orderId: widget.orderId,
            itemKey: item.key,
            text: text,
            authorId: _user.id,
            authorName: _byName,
          ),
        ),
      );

  Future<void> _openItemHistory(OrderItem item) {
    _ensureHistory();
    return showAppSheet<void>(
      context,
      (_) => ValueListenableBuilder<List<OrderHistoryEntry>?>(
        valueListenable: _history,
        builder: (context, entries, _) => entries == null
            ? const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()))
            : ItemHistorySheet(
                title: item.productName,
                entries: entries
                    .where((h) => h.belongsToItem(item.key, item.productName))
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _saveGps(Order order) => _run(() async {
        final position = await LocationService().getCurrentLocation();
        await _service.savePickupLocation(
          orderId: order.id,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }, done: 'Manzil GPS orqali saqlandi');

  Future<void> _acceptPickup(Order order) async {
    final p = _policies;
    DateTime? deadline;
    if (order.deadline == null) {
      if (p.deadlineDays > 0) {
        deadline =
            startOfDay(DateTime.now()).add(Duration(days: p.deadlineDays));
      } else if (p.deadlineRequired) {
        deadline = await showUzDatePicker(
          context,
          title: 'Topshirish sanasi',
          initial: startOfDay(DateTime.now()).add(const Duration(days: 1)),
          first: startOfDay(DateTime.now()),
          last: DateTime.now().add(const Duration(days: 365)),
        );
        if (deadline == null || !mounted) return;
      }
    }
    await _run(
      () => _service.advanceStatus(
        order: order,
        toStatus: OrderStatus.yuvishda,
        byEmployeeId: _user.id,
        byName: _byName,
        deadline: deadline,
      ),
      done: 'Buyurtma sexga qabul qilindi',
    );
  }

  Future<void> _deliver(Order order) async {
    final result = await showAppSheet<PaymentResult>(
      context,
      (_) => PaymentDialog(
        orderTotal: order.totalPrice,
        prepaid: order.prepaidAmount,
        allowDiscount: _user.access.can(StaffPermission.discount),
        allowDebt: _policies.debtAllowed,
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => _service.markDelivered(
        order: order,
        paymentMethod: result.method,
        paymentAmount: result.amount,
        shortfallIsDiscount: result.shortfallIsDiscount,
        byEmployeeId: _user.id,
        byName: _byName,
      ),
      done: 'Buyurtma topshirildi',
    );
  }

  Future<void> _handOver(Order order) async {
    final result = await showAppSheet<HandoverResult>(
      context,
      (_) => HandoverSheet(order: order),
    );
    if (result == null || !mounted) return;
    await _run(
      () => _service.handOverItems(
        order: order,
        items: result.items,
        amount: result.amount,
        method: result.method,
        byEmployeeId: _user.id,
        byName: _byName,
      ),
      done: '${result.items.length} ta xizmat topshirildi',
    );
  }

  Future<void> _openDirections(Order order) async {
    try {
      await LocationService()
          .openDirections(order.pickupLat!, order.pickupLng!);
    } on LocationFailure catch (e) {
      if (mounted) showResult(context, e.message, error: true);
    }
  }

  Future<void> _call(Order order) async {
    final digits = digitsOnly(order.customerPhone);
    if (digits.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: '+$digits'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(Order order) async {
    final ok = await confirmAction(
      context,
      title: 'Buyurtmani o\'chirish',
      message: '${order.code} (${order.customerName}) butunlay o\'chiriladi. '
          'Bu amalni ortga qaytarib bo\'lmaydi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
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
        authorId: _user.id,
        authorName: _byName,
      );
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  void _openMenu(Order order) {
    showActionMenu(
      context,
      title: order.code,
      groups: [
        MenuGroup(actions: [
          if (_canEditDetails(order))
            MenuAction(
              icon: Icons.edit_outlined,
              label: 'Ma\'lumotlarni tahrirlash',
              subtitle: 'Ism, telefon, manzil va muddat',
              onTap: () => showAppSheet<void>(
                  context, (_) => EditOrderSheet(order: order)),
            ),
          if (_canSeePhone && digitsOnly(order.customerPhone).isNotEmpty)
            MenuAction(
              icon: Icons.call_outlined,
              label: 'Qo\'ng\'iroq qilish',
              subtitle: formatPhoneForDisplay(order.customerPhone),
              tone: StageTone.success,
              onTap: () => _call(order),
            ),
          if (order.hasPickupLocation)
            MenuAction(
              icon: Icons.near_me_outlined,
              label: 'Xaritada yo\'l',
              subtitle: 'Mijoz manziliga yo\'nalish',
              tone: StageTone.info,
              onTap: () => _openDirections(order),
            ),
        ]),
        MenuGroup(actions: [
          if (_canDelete(order))
            MenuAction(
              icon: Icons.delete_outline_rounded,
              label: 'Buyurtmani o\'chirish',
              destructive: true,
              onTap: () => _confirmDelete(order),
            ),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------- chizish

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: _orderStream,
      builder: (context, snapshot) {
        final title = '№ ${widget.orderId}';
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: StreamErrorView(error: snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final order = snapshot.data;
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const EmptyState(
              icon: Icons.delete_sweep_outlined,
              title: 'Bu buyurtma o\'chirilgan',
            ),
          );
        }
        return ValueListenableBuilder<BusinessPolicies>(
          valueListenable: PolicyCenter.instance,
          builder: (context, _, __) => _buildBody(context, order),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, Order order) {
    final theme = Theme.of(context);
    final place = placeOf(order, _policies, DateTime.now());
    final perms = _itemPermissions(order);
    final section = widget.section;
    final mine = [
      for (final i in order.items)
        if (itemBelongsTo(i, section)) i,
    ];
    final others = [
      for (final i in order.items)
        if (!itemBelongsTo(i, section)) i,
    ];
    final awaitingWash = mine
        .where((i) => i.status.awaitsWash && !i.isHanded)
        .where((i) => !(_policies.measureBeforeWash && !i.hasNumericMeasure))
        .toList();
    final bottom = MediaQuery.of(context).padding.bottom;
    final canManage = _canManage(order);

    return Scaffold(
      appBar: AppBar(
        title: Text(order.code),
        actions: [
          MoreButton(onPressed: () => _openMenu(order)),
          const SizedBox(width: 4),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            ListView(
              padding:
                  EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 32 + bottom),
              children: [
                _HeaderCard(
                    order: order, place: place, canSeePhone: _canSeePhone),
                ..._actionPanel(order, place),
                const SizedBox(height: 20),
                SectionHeader(
                  title: section == null || section == WorkSection.yangi
                      ? 'Xizmatlar'
                      : '${section.label} bo\'limida',
                  subtitle: mine.isEmpty
                      ? null
                      : '${mine.length} ta xizmat'
                          '${order.items.length != mine.length ? ' · jami ${order.items.length}' : ''}',
                  actionLabel: canManage ? 'Qo\'shish' : null,
                  onAction: canManage ? () => _addProducts(order) : null,
                ),
                if (perms.wash && awaitingWash.length >= 2) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: StageTone.washing.fill,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _startWash(order, awaitingWash),
                    icon: const Icon(Icons.local_laundry_service_rounded),
                    label: Text('Hammasini yuvish (${awaitingWash.length})'),
                  ),
                  const SizedBox(height: 10),
                ],
                if (order.items.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        const IconTile(
                            icon: Icons.playlist_add_rounded,
                            tone: StageTone.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            canManage
                                ? 'Xizmat hali qo\'shilmagan. "Qo\'shish" '
                                    'orqali qo\'shing.'
                                : 'Xizmat hali qo\'shilmagan.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (mine.isEmpty)
                  AppCard(
                    child: Text(
                      'Bu bo\'limda hozir ish yo\'q — xizmatlar boshqa '
                      'bo\'limlarda.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: context.colorTextSecondary),
                    ),
                  ),
                for (final item in mine) ...[
                  OrderItemTile(
                    key: ValueKey(item.key),
                    item: item,
                    permissions: perms,
                    busy: _busy,
                    onWash: () => _startWash(order, [item]),
                    onAdvance: (to) => _advanceItem(order, item, to),
                    onRewash: () => _rewash(order, item),
                    onMeasure: () => _measure(order, item),
                    onDelete: () => _deleteItem(order, item),
                    onComments: () => _openComments(item),
                    onHistory: () => _openItemHistory(item),
                  ),
                  const SizedBox(height: 10),
                ],
                if (others.isNotEmpty) _OtherSectionsCard(items: others),
                const SizedBox(height: 18),
                _CommentsCard(
                  order: order,
                  canComment: _canComment,
                  controller: _commentCtrl,
                  sending: _sendingComment,
                  onSend: () => _sendComment(order),
                ),
                const SizedBox(height: 12),
                _HistoryCard(
                  open: _historyOpen,
                  history: _history,
                  onToggle: () {
                    _ensureHistory();
                    setState(() => _historyOpen = !_historyOpen);
                  },
                ),
              ],
            ),
            if (_busy)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  /// Buyurtma darajasidagi amallar: qabul qilish, topshirish, bo'lib
  /// topshirish. Faqat tegishli bo'limdan ochilganda.
  List<Widget> _actionPanel(Order order, OrderPlace place) {
    final out = <Widget>[];
    if (!_canTransportHere) return out;

    if (order.status == OrderStatus.olibKelish) {
      final gpsMissing =
          _policies.pickupGpsRequired && !order.hasPickupLocation;
      out.add(_ActionCard(
        tone: StageTone.pickup,
        icon: Icons.moped_rounded,
        title: 'Mijozdan olib kelish',
        message: order.hasPickupLocation
            ? 'Manzil GPS orqali saqlangan.'
            : gpsMissing
                ? 'Qabul qilishdan oldin GPS manzilni saqlang.'
                : 'Mijoz manzilida GPS manzilni saqlab qo\'ying — keyin '
                    'topshirishda yo\'l ko\'rsatiladi.',
        children: [
          if (!order.hasPickupLocation)
            OutlinedButton.icon(
              onPressed: () => _saveGps(order),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('GPS saqlash'),
            ),
          FilledButton.icon(
            onPressed: gpsMissing ? null : () => _acceptPickup(order),
            icon: const Icon(Icons.move_to_inbox_rounded),
            label: const Text('Qabul qilindi'),
          ),
        ],
      ));
    }

    if (place == OrderPlace.ready || place == OrderPlace.warehouse) {
      final warehouse = place == OrderPlace.warehouse;
      out.add(_ActionCard(
        tone: warehouse ? StageTone.warehouse : StageTone.ready,
        icon: warehouse ? Icons.warehouse_rounded : Icons.check_circle_rounded,
        title: warehouse ? 'Omborda turibdi' : 'Barcha xizmatlar tayyor',
        message: order.prepaidAmount > 0
            ? 'Qolgan to\'lov: ${formatSom(order.remainingDue)}'
            : order.totalPrice > 0
                ? 'To\'lov: ${formatSom(order.totalPrice)}'
                : 'Mijozga topshirish kutilmoqda.',
        children: [
          if (order.hasPickupLocation)
            OutlinedButton.icon(
              onPressed: () => _openDirections(order),
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Yo\'lga chiqish'),
            ),
          FilledButton.icon(
            onPressed: () => _deliver(order),
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Topshirish'),
          ),
        ],
      ));
    }

    if (place == OrderPlace.almostReady && _policies.partialHandoverEnabled) {
      final ready = order.readyToHandItems.length;
      final rest = order.unhandedItems.length - ready;
      out.add(_ActionCard(
        tone: StageTone.almost,
        icon: Icons.timelapse_rounded,
        title: '$ready ta xizmat tayyor',
        message: 'Qolgan $rest ta xizmat hali sexda. Tayyorlarini hozir '
            'topshirish mumkin.',
        children: [
          FilledButton.icon(
            style:
                FilledButton.styleFrom(backgroundColor: StageTone.almost.fill),
            onPressed: () => _handOver(order),
            icon: const Icon(Icons.call_split_rounded),
            label: const Text('Bo\'lib topshirish'),
          ),
        ],
      ));
    }

    return [
      for (final w in out) ...[const SizedBox(height: 12), w],
    ];
  }
}

// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.order,
    required this.place,
    required this.canSeePhone,
  });

  final Order order;
  final OrderPlace place;
  final bool canSeePhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = placeVisual(place);
    final badge = deadlineBadge(order);
    final created = UzDates.fromMillis(order.createdAt);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.customerName.isEmpty ? 'Mijoz' : order.customerName,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: 8),
              TonePill(label: visual.label, tone: visual.tone, icon: visual.icon),
            ],
          ),
          const SizedBox(height: 6),
          PhoneLink(
            phone: order.customerPhone,
            masked: !canSeePhone,
            iconSize: 16,
            style: theme.textTheme.bodyMedium,
          ),
          if (order.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined,
                    size: 17, color: context.colorTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child:
                      Text(order.address, style: theme.textTheme.bodyMedium),
                ),
                if (order.hasPickupLocation)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: TonePill(
                      label: 'GPS',
                      tone: StageTone.success,
                      icon: Icons.my_location_rounded,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 6),
          InfoRow(
            icon: Icons.event_outlined,
            label: 'Topshirish muddati',
            value: order.deadline == null
                ? 'Belgilanmagan'
                : '${UzDates.date(UzDates.fromMillis(order.deadline!))}'
                    '${badge != null ? ' · ${badge.label}' : ''}',
            valueColor: badge?.tone.ink(context),
          ),
          InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Qabul qildi',
            value:
                '${order.createdByName.isEmpty ? '—' : order.createdByName} · '
                '${UzDates.dateTime(created)}',
          ),
          if (order.pickedUpAt != null)
            InfoRow(
              icon: Icons.move_to_inbox_outlined,
              label: 'Olib kelindi',
              value: UzDates.dateTime(UzDates.fromMillis(order.pickedUpAt!)),
            ),
          if (order.readyAt != null)
            InfoRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Tayyor bo\'ldi',
              value: UzDates.dateTime(UzDates.fromMillis(order.readyAt!)),
            ),
          if (order.deliveredAt != null)
            InfoRow(
              icon: Icons.task_alt_rounded,
              label: 'Topshirildi',
              value:
                  '${UzDates.dateTime(UzDates.fromMillis(order.deliveredAt!))}'
                  '${order.delivered!.name.isNotEmpty ? ' · ${order.delivered!.name}' : ''}',
            ),
          if (order.totalPrice > 0 || order.status.isClosed) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: context.colorBorder),
            const SizedBox(height: 6),
            InfoRow(
              label: 'Jami',
              value: formatSom(order.totalPrice),
              emphasize: true,
            ),
            if (order.prepaidAmount > 0 && !order.status.isClosed)
              InfoRow(
                label: 'Oldindan to\'langan',
                value: formatSom(order.prepaidAmount),
                valueColor: StageTone.success.ink(context),
              ),
            if (order.status.isClosed) ...[
              InfoRow(
                label:
                    'To\'langan${order.paymentMethod != null ? ' (${order.paymentMethod})' : ''}',
                value: formatSom(order.paymentAmount ?? 0),
                valueColor: StageTone.success.ink(context),
              ),
              if (order.debtAmount > 0)
                InfoRow(
                  label: 'Qarz',
                  value: formatSom(order.debtAmount),
                  valueColor: StageTone.danger.ink(context),
                ),
              if (order.discountAmount > 0)
                InfoRow(label: 'Skidka', value: formatSom(order.discountAmount)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
  });

  final StageTone tone;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      color: tone.soft(context),
      borderColor: tone.fill.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: tone.ink(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: tone.ink(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Boshqa bo'limlardagi xizmatlar — faqat belgi va son. Ular boshqa
/// xodimning ishi: bu yerda batafsil ko'rsatilmaydi.
class _OtherSectionsCard extends StatelessWidget {
  const _OtherSectionsCard({required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    final counts = <ItemStage, int>{};
    for (final item in items) {
      final s = ItemStage.of(item);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      color: context.colorSurfaceMuted,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Boshqa bo\'limlarda',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.colorTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final stage in ItemStage.values)
                if (counts.containsKey(stage))
                  TonePill(
                    label:
                        '${counts[stage]} · ${stage.visual.label.toLowerCase()}',
                    tone: stage.visual.tone,
                    icon: stage.visual.icon,
                    dense: true,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.order,
    required this.canComment,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final Order order;
  final bool canComment;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (order.comments.isEmpty && !canComment) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined,
                  size: 18, color: context.colorTextSecondary),
              const SizedBox(width: 8),
              Text(
                order.comments.isEmpty
                    ? 'Izohlar'
                    : 'Izohlar · ${order.comments.length}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          if (order.comments.isNotEmpty) const SizedBox(height: 8),
          for (final c in order.comments)
            CommentBubble(
              authorName: c.authorName,
              text: c.text,
              createdAt: c.createdAt,
            ),
          if (canComment) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: t('Izoh yozing…'),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Yuborish'),
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded,
                          color: context.colorPrimaryInk),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.open,
    required this.history,
    required this.onToggle,
  });

  final bool open;
  final ValueNotifier<List<OrderHistoryEntry>?> history;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 18, color: context.colorTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('O\'zgarishlar tarixi',
                        style: theme.textTheme.titleSmall),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.colorTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ValueListenableBuilder<List<OrderHistoryEntry>?>(
                valueListenable: history,
                builder: (context, entries, _) => entries == null
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : HistoryTimeline(entries: entries),
              ),
            ),
        ],
      ),
    );
  }
}
