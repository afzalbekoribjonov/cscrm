import 'package:flutter/material.dart';

import '../../ui/choice_chips_bar.dart';
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
    return ChoiceChipsBar<DeliverySort>(
      values: DeliverySort.values,
      value: value,
      labelOf: (s) => s.label,
      // Aylanma FAQAT "Manzil" da: GPS so'rovi bir necha soniya davom
      // etishi mumkin va foydalanuvchi nimadir bo'layotganini ko'rishi
      // kerak.
      busyOf: (s) => locating && s == DeliverySort.distance,
      onChanged: onChanged,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    );
  }
}
