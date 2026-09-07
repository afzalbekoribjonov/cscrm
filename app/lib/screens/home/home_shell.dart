import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/message_center.dart';
import '../../services/notification_center.dart';
import '../../services/order_service.dart';
import '../../services/session_service.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/offline_write.dart';
import '../../utils/order_change_detector.dart';
import '../../utils/order_sections.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/stream_error_view.dart';
import '../../widgets/subscription_banner.dart';
import '../admin/admin_home_screen.dart';
import '../auth/login_screen.dart';
import '../delivery/yetgazma_screen.dart';
import '../new_order/new_order_screen.dart';
import '../packaging/packaging_screen.dart';
import '../wash/wash_screen.dart';

/// Asosiy ilova qobig'i: pastki navigatsiya + 4 operatsion bo'lim
/// (Yangi / Yuvish / Qadoqlash / Yetgazma). Boshqaruvchi (admin) uchun
/// pastki menyuning o'rtasiga "Boshqaruv" tugmasi qo'shiladi.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  /// Joriy sessiya: kim kirgan, qaysi biznesga va qanday vakolat bilan.
  final Session session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  OrderService _orderService = OrderService();

  // Oqim StreamBuilder o'rniga SHU YERDA tinglanadi.
  //
  // Sabab: ovozli signal va bo'limlarni hisoblash - bular yon ta'sir va
  // holat o'zgarishi. Ilgari ular `build()` ichida bajarilardi, bu esa
  // Flutter'da noto'g'ri: build faqat chizishi kerak, hech narsani
  // o'zgartirmasligi kerak.
  StreamSubscription<List<Order>>? _ordersSub;
  StreamSubscription<Employee?>? _employeeSub;
  StreamSubscription<LateWriteFailure>? _writeFailureSub;

  OrderSections _sections = const OrderSections.empty();
  Object? _ordersError;
  var _loaded = false;

  late final _changeDetector =
      OrderChangeDetector(currentActorId: widget.session.actorId);

  /// Vakolatlar sessiyadan olinadi, lekin xodim yozuvi o'zgarsa jonli
  /// yangilanadi (qarang: [_listenToEmployee]).
  late StaffAccess _access = widget.session.access;

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.start(widget.session.actorId);
    // CSCRM xabarlarini bir marta olib qo'yamiz - qo'ng'iroq ustidagi
    // raqam ekran ochilishini kutmasdan to'g'ri ko'rinsin.
    MessageCenter.instance.refresh();
    _listenToOrders();
    _listenToEmployee();
    _listenToWriteFailures();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _employeeSub?.cancel();
    _writeFailureSub?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Buyurtmalar oqimi
  // -------------------------------------------------------------------

  void _listenToOrders() {
    _ordersSub?.cancel();
    _ordersSub = _orderService.streamOperational().listen(
      (orders) {
        // Ovoz build'dan TASHQARIDA chalinadi va faqat BOSHQA odam qilgan
        // o'zgarishda - xodim o'z tugmasini bosganda o'ziga ovoz
        // eshittirmaydi.
        if (_changeDetector.shouldNotify(orders)) {
          SoundService.instance.playNotification();
        }
        // Bildirishnomalar ham shu oqimdan hisoblanadi - alohida
        // so'rov yoki alohida tugun kerak emas.
        NotificationCenter.instance.update(orders);

        if (!mounted) return;
        setState(() {
          _sections = OrderSections.from(orders);
          _ordersError = null;
          _loaded = true;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _ordersError = error);
      },
    );
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

  // -------------------------------------------------------------------
  // Vakolatlarni jonli kuzatish
  // -------------------------------------------------------------------

  /// Xodim yozuvini kuzatadi.
  ///
  /// Ilgari vakolatlar faqat KIRISH paytida o'qilib, qurilmada saqlanardi:
  /// boshqaruvchi vakolatni olib qo'ysa yoki xodimni bloklasa, xodim
  /// chiqib qayta kirmaguncha eski huquqlar bilan ishlayverardi.
  ///
  /// Endi o'zgarish darhol kuchga kiradi, xodim bloklansa esa tizimdan
  /// chiqariladi.
  void _listenToEmployee() {
    final employeeId = widget.session.employeeId;
    if (employeeId == null) return; // ega - kuzatish kerak emas

    _employeeSub = EmployeeService().streamEmployee(employeeId).listen(
      (employee) async {
        if (!mounted) return;

        // Xodim o'chirilgan yoki bloklangan.
        if (employee == null || !employee.active) {
          await _forceSignOut(
            employee == null
                ? 'Hisobingiz o\'chirilgan.'
                : 'Hisobingiz bloklangan. Boshqaruvchiga murojaat qiling.',
          );
          return;
        }

        if (employee.access.sectionKeys.join(',') !=
                _access.sectionKeys.join(',') ||
            employee.access.permissionKeys.join(',') !=
                _access.permissionKeys.join(',')) {
          setState(() => _access = employee.access);
          // Sessiyani ham yangilaymiz - ilova qayta ochilganda to'g'ri
          // vakolat bilan boshlanadi.
          await SessionService().save(
            Session.employee(
              tenantId: widget.session.tenantId!,
              tenantName: widget.session.tenantName ?? '',
              userId: widget.session.userId ?? '',
              employeeId: employeeId,
              displayName: widget.session.displayName ?? '',
              access: employee.access,
            ),
          );
        }
      },
      // Vakolat o'qilmasa ish to'xtamasin - mavjud vakolat bilan davom
      // etadi, haqiqiy cheklov baribir Database qoidalarida.
      onError: (Object error) => debugPrint('Xodim yozuvi o\'qilmadi: $error'),
    );
  }

  Future<void> _forceSignOut(String reason) async {
    await AuthService().signOut();
    await SessionService().clearSession();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reason),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // -------------------------------------------------------------------
  // Yozuv xatoliklari
  // -------------------------------------------------------------------

  void _listenToWriteFailures() {
    // Rad etilgan yozuv (masalan `permission-denied`) javobi ekran
    // yopilgandan keyin kelsa ham foydalanuvchiga yetkaziladi.
    _writeFailureSub = WriteFailures.stream.listen((failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  // -------------------------------------------------------------------
  // Navigatsiya
  // -------------------------------------------------------------------

  bool get _isAdmin => _access.isAdmin;

  /// Buyurtma tarixida "kim qildi" deb yoziladigan ID.
  String get _actorId => widget.session.actorId;
  String get _actorName => widget.session.displayName ?? '';

  /// "Boshqaruv" tugmasi pastki menyuning o'rtasiga (2-o'ringa) qo'yiladi -
  /// bu haqiqiy ekran emas, shu sabab IndexedStack indeksi bilan bevosita
  /// mos kelmaydi.
  static const _adminNavIndex = 2;

  int _navIndexForScreenIndex(int screenIndex) {
    if (!_isAdmin) return screenIndex;
    return screenIndex < _adminNavIndex ? screenIndex : screenIndex + 1;
  }

  int? _screenIndexForNavIndex(int navIndex) {
    if (!_isAdmin) return navIndex;
    if (navIndex == _adminNavIndex) return null;
    return navIndex < _adminNavIndex ? navIndex : navIndex - 1;
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminHomeScreen(
          currentUserId: _actorId,
          currentUserName: _actorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ordersError != null) {
      return Scaffold(
        body: StreamErrorView(
          error: _ordersError!,
          onRetry: _retryOrdersStream,
        ),
      );
    }

    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Bo'limlar oqim kelganda BIR MARTA hisoblangan - bu yerda faqat
    // tayyor ro'yxatlar tarqatiladi. Ilgari har bir ekran va har bir
    // nishoncha ro'yxatni qaytadan filtrlardi.
    final screens = [
      NewOrderScreen(
        currentUserId: _actorId,
        currentUserName: _actorName,
        access: _access,
      ),
      WashScreen(
        sections: _sections,
        currentUserId: _actorId,
        currentUserName: _actorName,
        access: _access,
      ),
      PackagingScreen(
        sections: _sections,
        currentUserId: _actorId,
        currentUserName: _actorName,
        access: _access,
      ),
      YetgazmaScreen(
        sections: _sections,
        currentUserId: _actorId,
        currentUserName: _actorName,
        access: _access,
      ),
    ];

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          // Muddat tugashiga oz qolganda eslatma. Holat tinch bo'lsa
          // hech narsa chizmaydi.
          SubscriptionBanner(isOwner: widget.session.isOwner),
          Expanded(
            child: IndexedStack(index: _index, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _navIndexForScreenIndex(_index),
          onTap: (navIndex) {
            final screenIndex = _screenIndexForNavIndex(navIndex);
            if (screenIndex == null) {
              _openAdminPanel();
            } else {
              setState(() => _index = screenIndex);
            }
          },
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.note_add_rounded),
              label: 'Yangi',
            ),
            BottomNavigationBarItem(
              icon: _NavBadge(
                count: _sections.wash.length,
                icon: Icons.local_laundry_service_rounded,
              ),
              label: 'Yuvish',
            ),
            if (_isAdmin)
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_rounded),
                label: 'Boshqaruv',
              ),
            BottomNavigationBarItem(
              icon: _NavBadge(
                count: _sections.packaging.length,
                icon: Icons.inventory_2_rounded,
              ),
              label: 'Qadoqlash',
            ),
            BottomNavigationBarItem(
              icon: _NavBadge(
                count: _sections.deliveryBadgeCount,
                icon: Icons.local_shipping_rounded,
              ),
              label: 'Yetgazma',
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count, required this.icon});

  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('$count'),
      isLabelVisible: count > 0,
      child: Icon(icon),
    );
  }
}
