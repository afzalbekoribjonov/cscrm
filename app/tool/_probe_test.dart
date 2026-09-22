import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe', () {
    for (final locale in ['uz', 'uz_UZ', 'ru']) {
      try {
        final f = NumberFormat.decimalPattern(locale);
        final s = f.format(132456);
        // ignore: avoid_print
        print('$locale -> "$s"  kodlar: ${s.codeUnits}');
      } catch (e) {
        // ignore: avoid_print
        print('$locale -> XATO: $e');
      }
    }
  });
}
