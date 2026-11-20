import 'package:cscrm/l10n/script.dart';
import 'package:cscrm/services/warning_center.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:cscrm/ui/range_picker.dart';
import 'package:cscrm/widgets/warning_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('uz'));

  final now = DateTime(2026, 11, 20, 15, 30);

  group('davr (DateRange)', () {
    test('bugun — standart, nomida sana bilan', () {
      final r = DateRange.today(now: now);
      expect(r.isToday(now: now), isTrue);
      expect(r.days, 1);
      expect(r.from, DateTime(2026, 11, 20));
      expect(r.to, DateTime(2026, 11, 20, 23, 59, 59, 999));
      expect(r.label(now: now), 'Bugun · 20-noyabr');
    });

    test('teskari tanlangan oraliq to\'g\'rilanadi', () {
      final r = DateRange(DateTime(2026, 11, 12), DateTime(2026, 11, 3));
      expect(r.start, DateTime(2026, 11, 3));
      expect(r.end, DateTime(2026, 11, 12));
      expect(r.days, 10);
      expect(r.label(now: now), '3–12-noyabr');
    });

    test('oylar chegarasidagi oraliq', () {
      final r = DateRange(DateTime(2026, 10, 28), DateTime(2026, 11, 3));
      expect(r.label(now: now), '28-oktabr — 3-noyabr');
    });

    test('butun oy: joriy oyda bugungacha, nomi — oy', () {
      final current = DateRange.month(DateTime(2026, 11), now: now);
      expect(current.end, DateTime(2026, 11, 20));
      expect(current.isWholeMonth(now: now), isTrue);
      expect(current.label(now: now), 'Noyabr 2026');

      final october = DateRange.month(DateTime(2026, 10), now: now);
      expect(october.days, 31);
      expect(october.label(now: now), 'Oktabr 2026');
    });

    test('kecha', () {
      final r = DateRange.day(DateTime(2026, 11, 19));
      expect(r.label(now: now), 'Kecha · 19-noyabr');
    });
  });

  group('qayta yuvish ogohlantirishi belgisi', () {
    Widget app() => MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(appBar: AppBar(actions: const [WarningAction()])),
        );

    tearDown(() => WarningCenter.instance.value = const []);

    testWidgets("ogohlantirish yo'q — belgi ko'rinmaydi", (tester) async {
      await tester.pumpWidget(app());
      expect(find.byIcon(Icons.priority_high_rounded), findsNothing);
    });

    testWidgets('ko\'rilmagan ogohlantirish — qo\'ng\'iroqdan oldin "!"',
        (tester) async {
      WarningCenter.instance.value = const [
        WorkWarning(
          id: 'w1',
          at: 1,
          orderId: 5,
          productName: 'Gilam',
          reason: "Dog' qolgan",
          byName: 'Malika',
          deduction: 9000,
        ),
        WorkWarning(
          id: 'w0',
          at: 0,
          orderId: 4,
          productName: 'Palos',
          reason: '',
          byName: 'Malika',
          seenAt: 2,
        ),
      ];
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
      expect(WarningCenter.instance.unseenCount, 1);

      // Bosilsa — ogohlantirishlar sahifasi, sabab va ushlanma bilan.
      await tester.tap(find.byIcon(Icons.priority_high_rounded));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text(t('Ogohlantirishlar')), findsOneWidget);
      expect(find.textContaining(t("Dog' qolgan"), findRichText: true),
          findsOneWidget);
      expect(find.textContaining(t('Ishbayidan ushlandi'), findRichText: true),
          findsOneWidget);
      expect(find.text(t('Tanishdim, e\'tibor beraman')), findsOneWidget);
    });
  });
}
