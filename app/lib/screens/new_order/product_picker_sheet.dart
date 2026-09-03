import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import 'cart_line.dart';

/// Xizmat(lar) tanlash oynasi. Ikki rejimda ishlaydi:
///
///  * standart - soni bilan bir nechta xizmat to'plab, `List<CartLine>`
///    qaytaradi (buyurtmaga qo'shish uchun);
///  * [singleSelection] - soni so'ralmaydi, bitta xizmat tanlanishi bilan
///    `Product` qaytadi (mavjud xizmatning turini almashtirish uchun).
class ProductPickerSheet extends StatefulWidget {
  const ProductPickerSheet({super.key, this.singleSelection = false});

  final bool singleSelection;

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  final _productService = ProductService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, har bir
  // setState() (masalan mahsulot sonini yozayotganda) yangi Stream obyekti
  // hosil qilib, StreamBuilder'ni "waiting" holatiga qaytarib yuborardi va
  // shu bilan foydalanuvchi hozir yozayotgan inputni (fokus bilan birga)
  // yo'qotardi.
  late final _productsStream = _productService.streamProducts();
  final List<CartLine> _staged = [];
  Product? _selected;
  int _quantity = 1;

  void _selectProduct(Product product) {
    // Almashtirish rejimida soni so'ralmaydi - tanlangan zahoti qaytadi.
    if (widget.singleSelection) {
      Navigator.of(context).pop<Product>(product);
      return;
    }
    setState(() {
      _selected = product;
      _quantity = 1;
    });
  }

  void _stageCurrentSelection() {
    final product = _selected;
    if (product == null) return;
    setState(() {
      _staged.add(CartLine(product: product, quantity: _quantity));
      _selected = null;
      _quantity = 1;
    });
  }

  void _onAddMore() {
    if (_selected == null) return;
    _stageCurrentSelection();
  }

  void _onSave() {
    _stageCurrentSelection();
    Navigator.of(context).pop<List<CartLine>>(_staged);
  }

  void _removeStaged(int index) {
    setState(() => _staged.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm = _selected != null || _staged.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: context.colorBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                widget.singleSelection
                    ? 'Xizmat turini tanlang'
                    : 'Xizmat qo\'shish',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (_staged.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_staged.length, (i) {
                    final line = _staged[i];
                    return Chip(
                      label: Text('${line.product.name} ×${line.quantity}'),
                      onDeleted: () => _removeStaged(i),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
              ],
              Expanded(
                child: StreamBuilder<List<Product>>(
                  stream: _productsStream,
                  builder: (context, snapshot) {
                    final products = snapshot.data ?? [];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          'Xizmatlar hali qo\'shilmagan.\n'
                          'Boshqaruvchi panelidan qo\'shing.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final selected = _selected?.id == product.id;
                        return Column(
                          children: [
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: product.id,
                              groupValue: _selected?.id,
                              onChanged: (_) => _selectProduct(product),
                              title: Text(product.name),
                              subtitle: Text(product.priceLabel),
                              secondary: Icon(product.method.icon,
                                  color: AppColors.primary),
                            ),
                            if (selected && !widget.singleSelection)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _QuantityStepper(
                                  quantity: _quantity,
                                  onChanged: (q) =>
                                      setState(() => _quantity = q),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              // Almashtirish rejimida xizmat tanlangan zahoti oyna yopiladi,
              // shu sabab pastki tugmalar kerak emas.
              if (!widget.singleSelection) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: canConfirm ? _onAddMore : null,
                        child: const Text('Yana qo\'shish'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canConfirm ? _onSave : null,
                        child: const Text('Saqlash'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late final _ctrl = TextEditingController(text: '${widget.quantity}');

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = int.tryParse(_ctrl.text.trim());
    if (widget.quantity != oldWidget.quantity && widget.quantity != current) {
      _ctrl.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final n = int.tryParse(value.trim());
    if (n != null && n > 0) widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
      child: Row(
        children: [
          Text('Soni:', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 14),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: _onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
