import 'package:cscrm/theme/app_colors.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:cscrm/widgets/section_stats_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kartalar ekran kengligiga MOSLASHISHI kerak — tor telefonda
/// bir-birini ezib, matn kesilib ketmasin.

const _stats = [
  SectionStat(
    icon: Icons.local_laundry_service_rounded,
    color: AppColors.primary,
    value: '12 ta',
    label: 'Buyurtma yuvishda',
  ),
  SectionStat(
    icon: Icons.replay_rounded,
    color: AppColors.danger,
    value: '3 ta',
    label: 'Qayta yuvish',
    emphasise: true,
  ),
  SectionStat(
    icon: Icons.straighten_rounded,
    color: AppColors.warning,
    value: '5 ta',
    label: 'Mahsulot o\'lchanmagan',
    emphasise: true,
  ),
  SectionStat(
    icon: Icons.water_drop_rounded,
    color: AppColors.statusWashing,
    value: '8 ta',
    label: 'Mahsulot yuvilmoqda',
  ),
];

Future<void> pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SectionStatsBar(stats: _stats),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('tor ekranda ham hamma karta chiziladi', (tester) async {
    await pumpAt(tester, 320);
    for (final s in _stats) {
      expect(find.text(s.label), findsOneWidget);
      expect(find.text(s.value), findsOneWidget);
    }
  });

  testWidgets('tor ekranda matn kesilmaydi (overflow yo\'q)', (tester) async {
    await pumpAt(tester, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keng ekranda ham buziladigan joyi yo\'q', (tester) async {
    await pumpAt(tester, 900);
    expect(tester.takeException(), isNull);
    expect(find.text('Qayta yuvish'), findsOneWidget);
  });

  testWidgets('bo\'sh ro\'yxatda hech narsa chizilmaydi', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SectionStatsBar(stats: [])),
    ));
    await tester.pump();

    expect(find.byType(Wrap), findsNothing);
  });
}
