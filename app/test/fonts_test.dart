import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Ilova shriftlarida o'zbek alifbosining BARCHA harflari bormi.
///
/// Shriftda harf bo'lmasa, Flutter uni boshqa shriftdan oladi va so'z
/// ichida bitta harf boshqacha ko'rinadi. Ilgari shunday bo'lgan:
/// Manrope'da "Қ Ғ Ҳ" yo'q edi. Bu sinov shrift almashtirilganda yoki
/// yangilanganda xuddi shu xato qaytmasligini kafolatlaydi.
void main() {
  const required = {
    'Ў': 0x040E, 'ў': 0x045E, 'Қ': 0x049A, 'қ': 0x049B, 'Ғ': 0x0492,
    'ғ': 0x0493, 'Ҳ': 0x04B2, 'ҳ': 0x04B3, 'Ё': 0x0401, 'ъ': 0x044A,
    '‘': 0x2018, '’': 0x2019, '№': 0x2116, '—': 0x2014, '·': 0x00B7,
    '²': 0x00B2, '×': 0x00D7, '…': 0x2026,
  };

  const fonts = [
    'assets/fonts/roboto/Roboto-Regular.ttf',
    'assets/fonts/roboto/Roboto-Medium.ttf',
    'assets/fonts/roboto/Roboto-Bold.ttf',
    'assets/fonts/montserrat/Montserrat-Medium.ttf',
    'assets/fonts/montserrat/Montserrat-SemiBold.ttf',
    'assets/fonts/montserrat/Montserrat-Bold.ttf',
  ];

  for (final path in fonts) {
    test(path.split('/').last, () {
      final cmap = _cmap(File(path).readAsBytesSync());
      final missing = required.entries
          .where((e) => !cmap.contains(e.value))
          .map((e) => e.key)
          .toList();
      expect(missing, isEmpty, reason: 'shriftda yo\'q belgilar: $missing');
    });
  }
}

/// TrueType `cmap` jadvalidagi barcha belgilar (format 4 va 12).
Set<int> _cmap(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  var offset = -1;
  for (var i = 0; i < tables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') offset = data.getUint32(rec + 8);
  }
  expect(offset, greaterThan(0), reason: 'cmap jadvali topilmadi');

  final result = <int>{};
  final count = data.getUint16(offset + 2);
  for (var i = 0; i < count; i++) {
    final sub = offset + data.getUint32(offset + 4 + i * 8 + 4);
    final format = data.getUint16(sub);
    if (format == 4) {
      final segX2 = data.getUint16(sub + 6);
      final ends = sub + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = data.getUint16(ends + s * 2);
        final start = data.getUint16(starts + s * 2);
        final delta = data.getInt16(deltas + s * 2);
        final rangeOffset = data.getUint16(ranges + s * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (rangeOffset == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final p = ranges + s * 2 + rangeOffset + (c - start) * 2;
            glyph = data.getUint16(p);
            if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          }
          if (glyph != 0) result.add(c);
        }
      }
    } else if (format == 12) {
      final groups = data.getUint32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final base = sub + 16 + g * 12;
        final start = data.getUint32(base);
        final end = data.getUint32(base + 4);
        for (var c = start; c <= end; c++) {
          result.add(c);
        }
      }
    }
  }
  return result;
}
