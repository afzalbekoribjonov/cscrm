import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../l10n/transliterate.dart';
import '../../models/calculation_method.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/money.dart';
import '../../widgets/stream_error_view.dart';

/// Xizmatlar va narxlar ro'yxati — qo'shish, tahrirlash, o'chirish.
class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key, @visibleForTesting this.products});

  /// Faqat sinov/rasm uchun.
  final Stream<List<Product>>? products;

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen> {
  late final _service = ProductService();
  late final _stream = widget.products ?? _service.streamProducts();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({Product? product}) async {
    final result = await showAppSheet<String>(
      context,
      (_) => _ProductFormSheet(service: _service, product: product),
    );
    if (result != null && mounted) showResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xizmatlar va narxlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yangi xizmat'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return StreamErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = [...snapshot.data!]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.local_laundry_service_outlined,
              tone: StageTone.brand,
              title: 'Hali xizmat qo\'shilmagan',
              message: 'Gilam, parda, ko\'rpa — har bir xizmatni narxi va '
                  'hisoblash usuli bilan qo\'shing.',
            );
          }
          final q = searchKey(_search.text);
          final products = q.isEmpty
              ? all
              : all.where((p) => searchKey(p.name).contains(q)).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                100 + MediaQuery.of(context).padding.bottom),
            children: [
              if (all.length > 6) ...[
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: t('Xizmatni qidirish'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  '${all.length} ta xizmat · bosib tahrirlang',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < products.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 70, color: context.colorBorder),
                      _ProductRow(
                        product: products[i],
                        onTap: () => _openForm(product: products[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            IconTile(icon: product.method.icon, tone: StageTone.brand, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(product.method.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                product.priceLabel,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}

/// Xizmat qo'shish/tahrirlash. Natija — natija xabari (yoki `null`).
class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({required this.service, this.product});

  final ProductService service;
  final Product? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
  late final _priceCtrl = TextEditingController(text: _money(widget.product?.price));
  late final _smallCtrl =
      TextEditingController(text: _money(widget.product?.priceSmall));
  late final _largeCtrl =
      TextEditingController(text: _money(widget.product?.priceLarge));
  late CalculationMethod _method =
      widget.product?.method ?? CalculationMethod.m2;
  var _saving = false;
  var _showErrors = false;

  bool get _isEdit => widget.product != null;

  static String _money(double? v) => v == null || v <= 0 ? '' : formatMoney(v);

  static const _suggestions = [
    'Gilam', 'Palos', 'Ko\'rpa', 'Adyol', 'Parda', 'Yostiq', 'Divan',
    'Kurtka', 'Kostyum',
  ];

  static String _methodHint(CalculationMethod m) => switch (m) {
        CalculationMethod.m2 => 'Eni × bo\'yi o\'lchanadi, m² ga ko\'paytiriladi',
        CalculationMethod.dona => 'Har bir dona uchun bir xil narx',
        CalculationMethod.metr => 'Uzunligi o\'lchanadi, metrga ko\'paytiriladi',
        CalculationMethod.kg => 'Tortiladi, kilogrammga ko\'paytiriladi',
        CalculationMethod.kichikKatta => 'Ikki narx: kichik va katta o\'lcham',
      };

  /// Narx qanday hisoblanishini misol bilan ko'rsatadi.
  String? get _example {
    final price = parseMoney(_priceCtrl.text);
    return switch (_method) {
      CalculationMethod.m2 when price > 0 =>
        'Masalan: 2 × 3 m = 6 m² × ${formatMoney(price)} = ${formatSom(price * 6)}',
      CalculationMethod.metr when price > 0 =>
        'Masalan: 4 m × ${formatMoney(price)} = ${formatSom(price * 4)}',
      CalculationMethod.kg when price > 0 =>
        'Masalan: 5 kg × ${formatMoney(price)} = ${formatSom(price * 5)}',
      CalculationMethod.dona when price > 0 =>
        'Masalan: 3 dona × ${formatMoney(price)} = ${formatSom(price * 3)}',
      _ => null,
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _smallCtrl.dispose();
    _largeCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_method.hasTwoSizes) {
      return parseMoney(_smallCtrl.text) > 0 && parseMoney(_largeCtrl.text) > 0;
    }
    return parseMoney(_priceCtrl.text) > 0;
  }

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final two = _method.hasTwoSizes;
    try {
      if (_isEdit) {
        await widget.service.updateProduct(
          id: widget.product!.id,
          name: _nameCtrl.text,
          method: _method,
          price: two ? 0 : parseMoney(_priceCtrl.text),
          priceSmall: two ? parseMoney(_smallCtrl.text) : 0,
          priceLarge: two ? parseMoney(_largeCtrl.text) : 0,
        );
      } else {
        await widget.service.createProduct(
          name: _nameCtrl.text,
          method: _method,
          price: two ? 0 : parseMoney(_priceCtrl.text),
          priceSmall: two ? parseMoney(_smallCtrl.text) : 0,
          priceLarge: two ? parseMoney(_largeCtrl.text) : 0,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(_isEdit ? 'Xizmat saqlandi' : 'Xizmat qo\'shildi');
      }
    } catch (_) {
      if (mounted) {
        showResult(context, 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Xizmatni o\'chirish',
      message: '"${widget.product!.name}" yangi buyurtmalarda tanlanmaydi. '
          'Avvalgi buyurtmalar o\'zgarmaydi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await widget.service.deleteProduct(widget.product!.id);
    if (mounted) Navigator.of(context).pop('Xizmat o\'chirildi');
  }

  Widget _priceField(TextEditingController c, String label, String suffix) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        const MoneyInputFormatter(),
      ],
      onChanged: (_) => setState(() {}),
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontFeatures: AppFonts.tabular),
      decoration: InputDecoration(
        labelText: t(label),
        suffixText: t(suffix),
        errorText: _showErrors && parseMoney(c.text) <= 0 ? t('Narxni kiriting') : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = _method.unitSymbol;
    return SheetFrame(
      title: _isEdit ? 'Xizmatni tahrirlash' : 'Yangi xizmat',
      actions: Row(
        children: [
          if (_isEdit) ...[
            IconButton.outlined(
              tooltip: t('O\'chirish'),
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('Xizmat nomi'),
              prefixIcon: const Icon(Icons.local_laundry_service_outlined),
              errorText: _showErrors && _nameCtrl.text.trim().isEmpty
                  ? t('Nomini kiriting')
                  : null,
            ),
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => _nameCtrl.text = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text('Narx qanday hisoblanadi', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final m in CalculationMethod.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MethodOption(
                method: m,
                hint: _methodHint(m),
                selected: m == _method,
                onTap: () => setState(() => _method = m),
              ),
            ),
          const SizedBox(height: 10),
          if (_method.hasTwoSizes)
            Row(
              children: [
                Expanded(child: _priceField(_smallCtrl, 'Kichik', 'so\'m')),
                const SizedBox(width: 10),
                Expanded(child: _priceField(_largeCtrl, 'Katta', 'so\'m')),
              ],
            )
          else
            _priceField(_priceCtrl, 'Narxi', unit.isEmpty ? 'so\'m' : 'so\'m/$unit'),
          if (_example != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      size: 18, color: context.colorTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_example!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontFeatures: AppFonts.tabular)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.method,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final CalculationMethod method;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? context.colorPrimarySoft : context.colorSurfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(method.icon,
                  color: selected ? context.colorPrimaryInk : context.colorTextSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: selected ? context.colorPrimaryInk : null,
                      ),
                    ),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppColors.primary : context.colorTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
