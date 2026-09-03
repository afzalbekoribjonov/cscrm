import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calculation_method.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';

class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key});

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen> {
  final _service = ProductService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, ekrandagi
  // har qanday kelajakdagi mahalliy setState() ro'yxatni "waiting" holatiga
  // qaytarib flicker qilishiga sabab bo'lardi.
  late final _productsStream = _service.streamProducts();

  Future<void> _openForm({Product? product}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductFormSheet(service: _service, product: product),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xizmatni o\'chirish'),
        content: Text('"${product.name}" o\'chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'O\'chirish',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteProduct(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xizmatlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yangi xizmat'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(
              child: Text(
                'Hali xizmat qo\'shilmagan',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(product.method.icon, color: AppColors.accent),
                  ),
                  title: Text(product.name),
                  subtitle:
                      Text('${product.method.label} · ${product.priceLabel}'),
                  onTap: () => _openForm(product: product),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmDelete(product),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({required this.service, this.product});

  final ProductService service;
  final Product? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.product?.name ?? '');
  late final _priceCtrl = TextEditingController(
    text: widget.product != null && widget.product!.price > 0
        ? widget.product!.price.toStringAsFixed(0)
        : '',
  );
  late final _priceSmallCtrl = TextEditingController(
    text: widget.product != null && widget.product!.priceSmall > 0
        ? widget.product!.priceSmall.toStringAsFixed(0)
        : '',
  );
  late final _priceLargeCtrl = TextEditingController(
    text: widget.product != null && widget.product!.priceLarge > 0
        ? widget.product!.priceLarge.toStringAsFixed(0)
        : '',
  );
  late CalculationMethod _method =
      widget.product?.method ?? CalculationMethod.dona;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _priceSmallCtrl.dispose();
    _priceLargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final priceSmall = double.tryParse(_priceSmallCtrl.text) ?? 0;
    final priceLarge = double.tryParse(_priceLargeCtrl.text) ?? 0;
    if (_isEdit) {
      await widget.service.updateProduct(
        id: widget.product!.id,
        name: _nameCtrl.text,
        method: _method,
        price: price,
        priceSmall: priceSmall,
        priceLarge: priceLarge,
      );
    } else {
      await widget.service.createProduct(
        name: _nameCtrl.text,
        method: _method,
        price: price,
        priceSmall: priceSmall,
        priceLarge: priceLarge,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Xizmatni tahrirlash' : 'Yangi xizmat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nomi',
                hintText: 'masalan: Gilam',
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Nomini kiriting' : null,
            ),
            const SizedBox(height: 16),
            Text('Hisoblash usuli',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CalculationMethod.values.map((m) {
                final selected = _method == m;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _method = m),
                  avatar: Icon(
                    m.icon,
                    size: 17,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                  label: Text(m.label),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : context.colorTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_method.hasTwoSizes)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceSmallCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kichik narxi',
                        suffixText: 'so\'m',
                      ),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Narx kiriting'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceLargeCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Katta narxi',
                        suffixText: 'so\'m',
                      ),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Narx kiriting'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              )
            else
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Narxi',
                  suffixText: _method.unitSymbol.isEmpty
                      ? 'so\'m'
                      : 'so\'m/${_method.unitSymbol}',
                ),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Narx kiriting'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }
}
