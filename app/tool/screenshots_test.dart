// ignore_for_file: invalid_use_of_visible_for_testing_member
// Ekranlarni PNG qilib chizadi — ko'z bilan tekshirish uchun.
//
// Ishga tushirish (`app/` papkasidan):
//     flutter test tool/screenshots_test.dart
//
// Fayllar `build/screens/` ga tushadi (git'ga kirmaydi).
//
// NEGA KERAK: joylashuv xatolari — matn chetdan chiqib ketishi, element
// bir-birining ustiga tushishi, tor ekranda siqilib qolishi — sinov
// tekshiruvlarida KO'RINMAYDI. Ular faqat chizilgan rasmda ko'rinadi.
//
// Ma'lumot namunaviy (tool/sample_data.dart) — bazaga ulanilmaydi.

import 'package:cscrm/l10n/material_cyrillic.dart';
import 'package:cscrm/l10n/script.dart';
import 'package:cscrm/models/app_user.dart';
import 'package:cscrm/models/staff_access.dart';
import 'package:cscrm/models/work_section.dart';
import 'package:cscrm/screens/dashboard/dashboard_screen.dart';
import 'package:cscrm/screens/dashboard/employee_day_screen.dart';
import 'package:cscrm/screens/delivery/yetgazma_screen.dart';
import 'package:cscrm/screens/new_order/new_order_screen.dart';
import 'package:cscrm/screens/new_order/today_orders_screen.dart';
import 'package:cscrm/screens/orders/order_detail_screen.dart';
import 'package:cscrm/screens/packaging/packaging_screen.dart';
import 'package:cscrm/screens/search/order_search_screen.dart';
import 'package:cscrm/screens/wash/wash_screen.dart';
import 'package:cscrm/screens/warehouse/warehouse_screen.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:cscrm/ui/app_nav_bar.dart';
import 'package:cscrm/ui/uz_date_picker.dart';
import 'package:cscrm/utils/order_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render.dart';
import 'sample_data.dart';

const _phone = Size(390, 844);
const _narrow = Size(320, 640);
const _tall = Size(390, 1500);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz')],
      localizationsDelegates: [
        if (ScriptController.instance.isCyrillic)
          const UzCyrillicMaterialDelegate()
        else
          GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

final _manager = AppUser(
  id: 'owner',
  name: 'Afzalbek',
  access: const StaffAccess.admin(),
  businessName: 'Nihol gilam yuvish',
);

final _washer = AppUser(
  id: 'e2',
  name: 'Jasur Toshmatov',
  access: StaffAccess.fromKeys(
    const ['yuvish', 'qadoqlash'],
    permissionKeys: const ['measure', 'rewash', 'comment', 'view_phone'],
  ),
);

final _courier = AppUser(
  id: 'e3',
  name: 'Sardor Aliyev',
  access: StaffAccess.fromKeys(
    const ['yetgazma', 'ombor', 'yangi'],
    permissionKeys: const ['view_phone', 'comment'],
  ),
);

/// Ochilishi bilan kalendarni ko'rsatadigan yordamchi sahifa.
class _PickerHarness extends StatefulWidget {
  const _PickerHarness();

  @override
  State<_PickerHarness> createState() => _PickerHarnessState();
}

class _PickerHarnessState extends State<_PickerHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUzDatePicker(
        context,
        title: 'Topshirish sanasi',
        initial: DateTime.now().add(const Duration(days: 3)),
        first: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

void main() {
  testWidgets('ekranlar chiziladi', (tester) async {
    SharedPreferences.setMockInitialValues({
      'session_role': 'owner',
      'session_tenant_id': 't1',
      'session_tenant_name': 'Nihol gilam yuvish',
      'session_user_id': 'u1',
      'session_display_name': 'Afzalbek',
    });
    await initializeDateFormatting('uz');
    await loadRenderFont();

    final sections = OrderSections.from(sampleOrders, now: sampleNow);
    final sources = SampleDashboardSources();
    final today = sampleOrders
        .where((o) => o.createdAt >= DateTime(sampleNow.year, sampleNow.month, sampleNow.day).millisecondsSinceEpoch)
        .toList();

    Future<void> shot(String name, Widget screen,
        {Size size = _phone, bool dark = false}) async {
      await renderToPng(
        tester,
        child: _app(screen, dark: dark),
        path: 'build/screens/$name.png',
        size: size,
      );
    }

    for (final cyr in [false, true]) {
      ScriptController.instance.value =
          cyr ? UzScript.cyrillic : UzScript.latin;
      final p = cyr ? 'kirill-' : '';

      await shot('${p}asosiy', DashboardScreen(
        user: _manager,
        sections: sections,
        onOpenSection: (_) {},
        sources: sources,
      ), size: _tall);

      await shot('${p}yuvish', WashScreen(sections: sections, user: _washer));
      await shot('${p}buyurtma-yuvish', OrderDetailScreen(
        orderId: 1282,
        user: _washer,
        section: WorkSection.yuvish,
        orderStream: Stream.value(sampleOrders[1]),
      ), size: _tall);
      await shot('${p}yetgazma', YetgazmaScreen(sections: sections, user: _courier));
    }
    ScriptController.instance.value = UzScript.latin;

    // Kunduzgi/tungi va tor ekran.
    await shot('asosiy-tun', DashboardScreen(
      user: _manager,
      sections: sections,
      onOpenSection: (_) {},
      sources: sources,
    ), size: _tall, dark: true);
    await shot('asosiy-tor', DashboardScreen(
      user: _manager,
      sections: sections,
      onOpenSection: (_) {},
      sources: sources,
    ), size: const Size(320, 1400));

    await shot('qadoqlash', PackagingScreen(sections: sections, user: _washer));
    await shot('qadoqlash-tun',
        PackagingScreen(sections: sections, user: _washer), dark: true);
    await shot('omborxona', WarehouseScreen(sections: sections, user: _courier));
    await shot('yangi', TodayOrdersScreen(
      sections: sections,
      user: _courier,
      todaysOrders: today,
    ));
    await shot('vakolat-yoq',
        YetgazmaScreen(sections: sections, user: _washer));
    await shot('yuvish-tor', WashScreen(sections: sections, user: _washer),
        size: _narrow);

    await shot('buyurtma-deyarli-tayyor', OrderDetailScreen(
      orderId: 1283,
      user: _courier,
      section: WorkSection.yetgazma,
      orderStream: Stream.value(sampleOrders[2]),
    ), size: _tall);
    await shot('buyurtma-qadoqlash', OrderDetailScreen(
      orderId: 1284,
      user: _washer,
      section: WorkSection.qadoqlash,
      orderStream: Stream.value(sampleOrders[3]),
    ), size: _tall);
    await shot('buyurtma-boshqaruvchi', OrderDetailScreen(
      orderId: 1283,
      user: _manager,
      orderStream: Stream.value(sampleOrders[2]),
    ), size: _tall);
    await shot('buyurtma-tun', OrderDetailScreen(
      orderId: 1282,
      user: _washer,
      section: WorkSection.yuvish,
      orderStream: Stream.value(sampleOrders[1]),
    ), size: _tall, dark: true);

    await shot('qidiruv', OrderSearchScreen(sections: sections, user: _manager));
    await shot('yangi-buyurtma', NewOrderScreen(user: _courier, sections: sections));
    await shot('xodim-kuni', EmployeeDayScreen(
      employees: sampleEmployees,
      user: _manager,
      initialEmployeeId: 'e2',
      sources: sources,
    ));
    await shot('kalendar', const _PickerHarness());

    for (final width in [320.0, 390.0]) {
      await shot('menyu-${width.toInt()}', Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: AppNavBar(
          currentIndex: 2,
          onTap: (_) {},
          destinations: [
            const NavDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: 'Asosiy',
            ),
            for (final s in WorkSection.values)
              NavDestination(
                icon: s.icon,
                selectedIcon: s.selectedIcon,
                label: s.shortLabel,
                badge: s == WorkSection.yuvish ? 4 : 0,
                locked: s == WorkSection.ombor,
              ),
          ],
        ),
      ), size: Size(width, 160));
    }
  });
}
