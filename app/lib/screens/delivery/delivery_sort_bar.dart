import 'package:flutter/material.dart';

import '../../utils/delivery_sort.dart';

/// "Tayyor" ro'yxati ustidagi saralash tugmalari.
///
/// Faqat SHU ro'yxatda: "Olib kelish" va "Yetgazildi" boshqa mantiqqa
/// ega — birinchisida buyurtmani olib kelish kerak, ikkinchisi esa
/// tugagan ish. Saralash faqat "hozir qaysi biriga borsam" degan
/// savolga javob beradi.
class DeliverySortBar extends StatelessWidget {
  const DeliverySortBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.locating,
  });

  final DeliverySort value;
  final ValueChanged<DeliverySort> onChanged;

  /// GPS so'ralayotgan payt — "Manzil" tugmasida aylanma ko'rinadi.
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          for (final sort in DeliverySort.values) ...[
            _Chip(
              label: sort.label,
              selected: sort == value,
              // Aylanma FAQAT "Manzil" da: GPS so'rovi bir necha
              // soniya davom etishi mumkin va foydalanuvchi nimadir
              // bo'layotganini ko'rishi kerak.
              busy: locating && sort == DeliverySort.distance,
              onTap: () => onChanged(sort),
            ),
            if (sort != DeliverySort.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : theme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
