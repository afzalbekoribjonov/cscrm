import 'package:flutter/foundation.dart';

import '../utils/order_sections.dart';

/// Ilova qobig'i hisoblagan bo'limlar — ilovaning istalgan joyidan jonli
/// o'qish uchun.
///
/// Pastki menyudagi bo'limlar ma'lumotni qobiqdan to'g'ridan-to'g'ri
/// oladi. Lekin "⋮" menyudan ochiladigan sahifa (Omborxona) alohida
/// sahifa sifatida ochiladi — u ham yangi ma'lumotni darhol ko'rishi
/// uchun shu yerdan kuzatadi. Qo'shimcha so'rov yo'q: bu qobiq allaqachon
/// olgan buyurtmalarning o'zi.
class LiveSections extends ValueNotifier<OrderSections> {
  LiveSections._() : super(OrderSections.empty());

  static final LiveSections instance = LiveSections._();
}
