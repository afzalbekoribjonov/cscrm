import 'package:flutter/material.dart';

/// Ixcham statistik ko'rsatkich kartasi: ikonka, qiymat va yorliq.
///
/// QIYMAT SIQILADI, KESILMAYDI. Summalar uzun bo'lishi mumkin
/// ("12 345 678 so'm") va ular kartadan chiqib ketardi. Uch nuqta bilan
/// qisqartirish ham yaramaydi: "12 345…" degan raqam hech narsa
/// demaydi. Shuning uchun matn joyiga SIG'ADIGAN darajada kichrayadi —
/// to'liq o'qiladi, faqat mayda bo'ladi.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );

    // Qiymat qatorining balandligi QAT'IY.
    //
    // `FittedBox` matnni kichraytirganda uning balandligi ham
    // kichrayadi — natijada yonma-yon turgan kartalarda yorliqlar
    // turli balandlikda qolardi. Qat'iy balandlik buni bartaraf
    // qiladi. Foydalanuvchi tizim shriftini kattalashtirsa, u bilan
    // birga o'sadi.
    final valueHeight =
        MediaQuery.textScalerOf(context).scale(valueStyle?.fontSize ?? 22) *
            1.3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: valueHeight,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: valueStyle),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartalarni TENG BALANDLIKDA qatorga joylaydi.
///
/// NEGA ALOHIDA VIDJET. Oddiy `Row` + `Expanded` da kartalar bir xil
/// KENGLIKDA bo'ladi, lekin balandligi har xil: yorliqning biri bitta
/// qatorga, ikkinchisi ikkitaga sig'sa, kartalar bo'yi turlicha
/// chiqadi va ro'yxat qiyshiq ko'rinadi.
///
/// `IntrinsicHeight` + `stretch` hammasini eng balandiga tenglashtiradi.
/// Qat'iy balandlik yozib qo'yish ham mumkin edi, lekin u foydalanuvchi
/// tizim shriftini kattalashtirganda buzilardi.
class StatTileRow extends StatelessWidget {
  const StatTileRow({super.key, required this.tiles, this.spacing = 10});

  final List<Widget> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// Kartalarni qatorlarga bo'lib joylaydi — har qatorda [perRow] ta.
///
/// Oxirgi qator to'lmasa, qolgan joy BO'SH qoldiriladi: kartalarni
/// cho'zib yuborish ularni boshqa qatorlardagilardan kengroq qilib
/// qo'yardi va to'r buzilardi.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({
    super.key,
    required this.tiles,
    this.perRow = 2,
    this.spacing = 10,
  });

  final List<Widget> tiles;
  final int perRow;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < tiles.length; i += perRow) {
      final chunk = tiles.sublist(i, (i + perRow).clamp(0, tiles.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + perRow < tiles.length ? spacing : 0),
        child: StatTileRow(
          spacing: spacing,
          tiles: [
            ...chunk,
            // To'lmagan joy — bo'sh o'rin.
            for (var k = chunk.length; k < perRow; k++) const SizedBox.shrink(),
          ],
        ),
      ));
    }

    return Column(children: rows);
  }
}
