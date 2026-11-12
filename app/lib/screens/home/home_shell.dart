import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/live_sections.dart';
import '../../services/message_center.dart';
import '../../services/order_service.dart';
import '../../services/order_sync_service.dart';
import '../../services/policy_service.dart';
import '../../services/push_service.dart';
import '../../services/session_service.dart';
import '../../services/sound_service.dart';
import '../../ui/app_nav_bar.dart';
import '../../ui/sheets.dart';
import '../../utils/date_utils.dart';
import '../../utils/offline_write.dart';
import '../../utils/order_change_detector.dart';
import '../../utils/order_sections.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/stream_error_view.dart';
import '../../widgets/subscription_banner.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../delivery/yetgazma_screen.dart';
import '../new_order/today_orders_screen.dart';
import '../packaging/packaging_screen.dart';
import '../wash/wash_screen.dart';
import '../warehouse/warehouse_screen.dart';

/// Ilova qobig'i: pastki menyu va bo'limlar.
///
///  * Boshqaruvchida birinchi bo'lim — **Asosiy** (biznesning to'liq
///    holati). Ilova har ochilganda shu sahifadan boshlanadi.
///  * Xodimda — ish bo'limlari; ilova u vakolatli BIRINCHI bo'limda
///    ochiladi. Vakolati yo'q bo'lim menyuda qulf belgisi bilan turadi va
///    ichida "Sizda vakolat mavjud emas" ko'rinadi.
///  * "Omborxona" — "⋮" menyuda (qoidalarda o'chirilgan bo'lsa — yo'q).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final Session session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  OrderService _orderService = OrderService();

  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<Employee?>? _employeeSub;
  StreamSubscription<LateWriteFailure>? _writeFailureSub;
  Timer? _ticker;

  late AppUser _user = AppUser(
    id: widget.session.actorId,
    name: widget.session.displayName ?? '',
    access: widget.session.access,
    businessName: widget.session.tenantName ?? '',
  );

  List<Order> _orders = const [];
  OrderSections _sections = OrderSections.empty();
  List<Order> _todaysOrders = const [];
  Object? _ordersError;
  var _loaded = false;

  /// Tanlangan bo'lim (dashboard uchun `null`).
  WorkSection? _current;
  var _initialPicked = false;

  late final _changeDetector =
      OrderChangeDetector(currentActorId: widget.session.actorId);

  bool get _isManager => _user.isManager;

  @override
  void initState() {
    super.initState();
    // CSCRM xabarlari — qo'ng'iroq ustidagi raqam darhol to'g'ri bo'lsin.
    MessageCenter.instance.refresh();
    PushService.instance.start();
    OrderSyncService.instance.start();
    PolicyCenter.instance.start();
    PolicyCenter.instance.addListener(_recompute);
    _listenToOrders();
    _listenToEmployee();
    _listenToWriteFailures();
    // Vaqtga bog'liq ro'yxatlar (omborxonaga o'tish, muddat belgilari,
    // "bugun") vaqt o'tishi bilan o'zi yangilanadi.
    _ticker = Timer.periodic(const Duration(minutes: 10), (_) => _recompute());
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _employeeSub?.cancel();
    _writeFailureSub?.cancel();
    _ticker?.cancel();
    PolicyCenter.instance.removeListener(_recompute);
    super.dispose();
  }

  // ------------------------------------------------------------ buyurtmalar

  void _listenToOrders() {
    _ordersSub?.cancel();
    // Boshqaruvchiga bugun topshirilganlar ham kerak (bosh sahifadagi
    // bugungi tushum). Xodimga — faqat faol buyurtmalar: ortiqcha so'rov
    // yo'q.
    final stream = _isManager
        ? _orderService.streamOperational()
        : _orderService.streamActiveOrders();
    _ordersSub = stream.listen(
      (orders) {
        // Ovoz faqat BOSHQA odam qilgan o'zgarishda.
        if (_changeDetector.shouldNotify(orders)) {
          SoundService.instance.playNotification();
        }
        if (!mounted) return;
        _orders = orders;
        _ordersError = null;
        _loaded = true;
        _recompute();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _ordersError = error);
      },
    );
  }

  void _recompute() {
    if (!mounted) return;
    final now = DateTime.now();
    final dayStart = startOfDay(now).millisecondsSinceEpoch;
    setState(() {
      _sections = OrderSections.from(
        _orders,
        policies: PolicyCenter.instance.value,
        now: now,
      );
      _todaysOrders = _orders.where((o) => o.createdAt >= dayStart).toList();
    });
    // "⋮" menyudan ochiladigan sahifalar (Omborxona) ham jonli bo'lsin.
    LiveSections.instance.value = _sections;
  }

  void _retryOrdersStream() {
    setState(() {
      _orderService = OrderService();
      _ordersError = null;
      _loaded = false;
    });
    _changeDetector.reset();
    _listenToOrders();
  }

  // ------------------------------------------------------------ vakolatlar

  /// Xodim yozuvi jonli kuzatiladi: vakolat o'zgarsa darhol kuchga
  /// kiradi, bloklansa — tizimdan chiqariladi.
  void _listenToEmployee() {
    final employeeId = widget.session.employeeId;
    if (employeeId == null) return;

    _employeeSub = EmployeeService().streamEmployee(employeeId).listen(
      (employee) async {
        if (!mounted) return;
        if (employee == null || !employee.active) {
          await _forceSignOut(employee == null
              ? 'Hisobingiz o\'chirilgan.'
              : 'Hisobingiz bloklangan. Boshqaruvchiga murojaat qiling.');
          return;
        }
        final access = employee.access;
        if (access.sectionKeys.join(',') != _user.access.sectionKeys.join(',') ||
            access.permissionKeys.join(',') !=
                _user.access.permissionKeys.join(',')) {
          setState(() => _user = _user.withAccess(access));
          await SessionService().save(Session.employee(
            tenantId: widget.session.tenantId!,
            tenantName: widget.session.tenantName ?? '',
            userId: widget.session.userId ?? '',
            employeeId: employeeId,
            displayName: widget.session.displayName ?? '',
            access: access,
          ));
        }
      },
      onError: (Object error) => debugPrint('Xodim yozuvi o\'qilmadi: $error'),
    );
  }

  Future<void> _forceSignOut(String reason) async {
    await AuthService().signOut();
    await SessionService().clearSession();
    await PolicyCenter.instance.stop();
    if (!mounted) return;
    showResult(context, reason, error: true);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _listenToWriteFailures() {
    _writeFailureSub = WriteFailures.stream.listen((failure) {
      if (mounted) showResult(context, failure.message, error: true);
    });
  }

  // ------------------------------------------------------------ navigatsiya

  /// Pastki menyudagi bo'limlar. Omborxona bu yerda YO'Q — u "⋮"
  /// menyuda: kundalik ish bo'limi emas, kamdan-kam ochiladi.
  static const _tabSections = [
    WorkSection.yangi,
    WorkSection.yuvish,
    WorkSection.qadoqlash,
    WorkSection.yetgazma,
  ];

  int _badgeFor(WorkSection s) => switch (s) {
        WorkSection.yangi => 0,
        WorkSection.yuvish => _sections.wash.length,
        WorkSection.qadoqlash => _sections.packaging.length,
        WorkSection.yetgazma => _sections.deliveryBadgeCount,
        WorkSection.ombor => _sections.warehouse.length,
      };

  Widget _screenFor(WorkSection s) => switch (s) {
        WorkSection.yangi => TodayOrdersScreen(
            sections: _sections,
            user: _user,
            todaysOrders: _todaysOrders,
          ),
        WorkSection.yuvish => WashScreen(sections: _sections, user: _user),
        WorkSection.qadoqlash =>
          PackagingScreen(sections: _sections, user: _user),
        WorkSection.yetgazma => YetgazmaScreen(sections: _sections, user: _user),
        WorkSection.ombor => WarehouseScreen(sections: _sections, user: _user),
      };

  @override
  Widget build(BuildContext context) {
    if (_ordersError != null) {
      return Scaffold(
        body: StreamErrorView(error: _ordersError!, onRetry: _retryOrdersStream),
      );
    }
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const sections = _tabSections;
    if (!_initialPicked) {
      _initialPicked = true;
      // Xodim — vakolatli birinchi bo'limda; boshqaruvchi — "Asosiy"da.
      if (!_isManager) {
        _current = sections.firstWhere(_user.access.has,
            orElse: () => sections.first);
      }
    }
    // Omborxona o'chirilgan bo'lsa va xodim u yerda turgan bo'lsa.
    if (_current != null && !sections.contains(_current)) {
      _current = _isManager ? null : sections.first;
    }

    final tabs = <WorkSection?>[if (_isManager) null, ...sections];
    final index = tabs.indexOf(_current).clamp(0, tabs.length - 1);

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          SubscriptionBanner(isOwner: widget.session.isOwner),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                for (final tab in tabs)
                  tab == null
                      ? DashboardScreen(
                          user: _user,
                          sections: _sections,
                          onOpenSection: (s) => setState(() => _current = s),
                        )
                      : _screenFor(tab),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: index,
        onTap: (i) => setState(() => _current = tabs[i]),
        destinations: [
          for (final tab in tabs)
            if (tab == null)
              const NavDestination(
                icon: Icons.space_dashboard_outlined,
                selectedIcon: Icons.space_dashboard_rounded,
                label: 'Asosiy',
              )
            else
              NavDestination(
                icon: tab.icon,
                selectedIcon: tab.selectedIcon,
                label: tab.shortLabel,
                locked: !_user.access.has(tab),
                badge: _user.access.has(tab) ? _badgeFor(tab) : 0,
              ),
        ],
      ),
    );
  }
}
