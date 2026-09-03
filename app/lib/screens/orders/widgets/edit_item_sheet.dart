import 'package:flutter/material.dart';

import '../../../models/measure_unit.dart';
import '../../../models/product.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/item_measurement_form.dart';
import '../../new_order/product_picker_sheet.dart';

class ItemEditResult {
  const ItemEditResult({
    required this.productId,
    required this.productName,
    required this.hajm,
    required this.price,
    required this.unit,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final String hajm;
  final double price;
  final MeasureUnit unit;
  final double quantity;
}

class EditItemSheet extends StatefulWidget {
  const EditItemSheet({
    super.key,
    required this.product,
    required this.currentHajm,
    required this.currentPrice,
    required this.canChangeProduct,
  });

  final Product product;
  final String currentHajm;
  final double currentPrice;

  /// Xizmat turini almashtirish vakolati ("Xizmatlarni boshqarish").
  final bool canChangeProduct;

  @override
  State<EditItemSheet> createState() => EditItemSheetState();
}

class EditItemSheetState extends State<EditItemSheet> {
  late Product _product = widget.product;
  late ItemMeasurement _measurement = ItemMeasurement(_product);

  @override
  void dispose() {
    _measurement.dispose();
    super.dispose();
  }

  /// Boshqa xizmat turi tanlanganda o'lchash maydonlari ham o'zgaradi
  /// (masalan m² dan kg ga), shu sabab holat noldan qayta quriladi.
  Future<void> _changeProduct() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ProductPickerSheet(singleSelection: true),
    );
    if (picked == null || !mounted || picked.id == _product.id) return;
    setState(() {
      _measurement.dispose();
      _product = picked;
      _measurement = ItemMeasurement(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changed = _product.id != widget.product.id;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_product.name} — o\'lchash',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.canChangeProduct)
                  IconButton(
                    tooltip: 'Xizmat turini almashtirish',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: _changeProduct,
                  ),
              ],
            ),
            if (changed)
              Text(
                'Xizmat turi almashtirildi: ${widget.product.name} → ${_product.name}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.warning),
              )
            else if (widget.currentHajm.isNotEmpty)
              Text(
                'Joriy: ${widget.currentHajm} · ${widget.currentPrice.toStringAsFixed(0)} so\'m',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            ItemMeasurementForm(
              // Tur almashganda forma to'liq qayta qurilishi uchun.
              key: ValueKey(_product.id),
              item: _measurement,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _measurement.isValid
                  ? () => Navigator.of(context).pop(ItemEditResult(
                        productId: _product.id,
                        productName: _product.name,
                        hajm: _measurement.hajm,
                        price: _measurement.price,
                        unit: _measurement.unit,
                        quantity: _measurement.quantity,
                      ))
                  : null,
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Qayta yuvishga qaytarish tasdig'i - sabab kiritilmasa tasdiqlab
/// bo'lmaydi, chunki sabab tarixga yoziladi.
