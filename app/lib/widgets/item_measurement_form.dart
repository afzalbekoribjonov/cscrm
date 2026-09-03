import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/calculation_method.dart';
import '../models/measure_unit.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';

String fmtNum(double v) {
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

String fmtSom(double v) => '${v.toStringAsFixed(0)} so\'m';

/// Bitta jismoniy birlik (masalan bitta gilam) uchun hisoblash holati.
/// Mahsulotning hisoblash usuliga qarab kerakli maydonlarni saqlaydi va
/// hajm tavsifi + narxni hisoblab beradi. Yangi buyurtma yaratishda ham,
/// mavjud buyurtmaga mahsulot qo'shish/tahrirlashda ham ishlatiladi.
class ItemMeasurement {
  ItemMeasurement(this.product);

  final Product product;
  final widthCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final valueCtrl = TextEditingController();
  String? sizeChoice; // 'kichik' | 'katta'

  void dispose() {
    widthCtrl.dispose();
    heightCtrl.dispose();
    valueCtrl.dispose();
  }

  bool get isValid {
    switch (product.method) {
      case CalculationMethod.m2:
        return _num(widthCtrl.text) > 0 && _num(heightCtrl.text) > 0;
      case CalculationMethod.dona:
        return true;
      case CalculationMethod.metr:
      case CalculationMethod.kg:
        return _num(valueCtrl.text) > 0;
      case CalculationMethod.kichikKatta:
        return sizeChoice != null;
    }
  }

  double get price {
    switch (product.method) {
      case CalculationMethod.m2:
        return _num(widthCtrl.text) * _num(heightCtrl.text) * product.price;
      case CalculationMethod.dona:
        return product.price;
      case CalculationMethod.metr:
      case CalculationMethod.kg:
        return _num(valueCtrl.text) * product.price;
      case CalculationMethod.kichikKatta:
        if (sizeChoice == 'katta') return product.priceLarge;
        if (sizeChoice == 'kichik') return product.priceSmall;
        return 0;
    }
  }

  String get hajm {
    switch (product.method) {
      case CalculationMethod.m2:
        final area = _num(widthCtrl.text) * _num(heightCtrl.text);
        return '${fmtNum(_num(widthCtrl.text))}×${fmtNum(_num(heightCtrl.text))} m (${fmtNum(area)} m²)';
      case CalculationMethod.dona:
        return '1 dona';
      case CalculationMethod.metr:
        return '${fmtNum(_num(valueCtrl.text))} m';
      case CalculationMethod.kg:
        return '${fmtNum(_num(valueCtrl.text))} kg';
      case CalculationMethod.kichikKatta:
        return sizeChoice == 'katta' ? 'Katta' : 'Kichik';
    }
  }

  /// Statistikada jamlanadigan raqamli miqdor - [hajm] matnidan farqli
  /// o'laroq buni qo'shib bo'ladi.
  double get quantity {
    switch (product.method) {
      case CalculationMethod.m2:
        return _num(widthCtrl.text) * _num(heightCtrl.text);
      case CalculationMethod.dona:
      case CalculationMethod.kichikKatta:
        return 1;
      case CalculationMethod.metr:
      case CalculationMethod.kg:
        return _num(valueCtrl.text);
    }
  }

  MeasureUnit get unit {
    switch (product.method) {
      case CalculationMethod.m2:
        return MeasureUnit.m2;
      case CalculationMethod.dona:
        return MeasureUnit.dona;
      case CalculationMethod.metr:
        return MeasureUnit.metr;
      case CalculationMethod.kg:
        return MeasureUnit.kg;
      case CalculationMethod.kichikKatta:
        return sizeChoice == 'katta' ? MeasureUnit.katta : MeasureUnit.kichik;
    }
  }

  static double _num(String s) => double.tryParse(s.trim()) ?? 0;
}

/// Mahsulotning hisoblash usuliga mos kiritish maydoni(lari) + jonli narx.
class ItemMeasurementForm extends StatelessWidget {
  const ItemMeasurementForm({
    super.key,
    required this.item,
    required this.onChanged,
  });

  final ItemMeasurement item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MethodInput(item: item, onChanged: onChanged),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Narxi', style: theme.textTheme.bodyMedium),
              Text(
                fmtSom(item.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodInput extends StatelessWidget {
  const _MethodInput({required this.item, required this.onChanged});

  final ItemMeasurement item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    switch (item.product.method) {
      case CalculationMethod.m2:
        return Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: item.widthCtrl,
                label: 'Eni (m)',
                autofocus: true,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: item.heightCtrl,
                label: 'Bo\'yi (m)',
                onChanged: onChanged,
              ),
            ),
          ],
        );
      case CalculationMethod.metr:
        return _NumberField(
          controller: item.valueCtrl,
          label: 'Uzunligi (m)',
          autofocus: true,
          onChanged: onChanged,
        );
      case CalculationMethod.kg:
        return _NumberField(
          controller: item.valueCtrl,
          label: 'Og\'irligi (kg)',
          autofocus: true,
          onChanged: onChanged,
        );
      case CalculationMethod.dona:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colorSurfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'Qo\'shimcha o\'lcham kerak emas',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      case CalculationMethod.kichikKatta:
        return Row(
          children: [
            Expanded(
              child: _SizeOption(
                label: 'Kichik',
                price: item.product.priceSmall,
                selected: item.sizeChoice == 'kichik',
                onTap: () {
                  item.sizeChoice = 'kichik';
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SizeOption(
                label: 'Katta',
                price: item.product.priceLarge,
                selected: item.sizeChoice == 'katta',
                onTap: () {
                  item.sizeChoice = 'katta';
                  onChanged();
                },
              ),
            ),
          ],
        );
    }
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textInputAction: TextInputAction.next,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.colorSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : context.colorTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(fmtSom(price), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
