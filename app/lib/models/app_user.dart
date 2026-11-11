import 'staff_access.dart';

/// Ilovadan foydalanayotgan odam: kim, qaysi biznesda va qanday vakolat
/// bilan. Ekranlar shu bitta obyektni oladi — ilgari har bir ekranga
/// uchta alohida qiymat (ID, ism, vakolat) uzatilardi.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.access,
    this.businessName = '',
  });

  /// Buyurtma tarixida "kim qildi" deb yoziladigan ID.
  final String id;

  /// Ko'rinadigan ism. Boshqaruvchi uchun — login.
  final String name;
  final StaffAccess access;
  final String businessName;

  bool get isManager => access.isAdmin;

  /// Tarixda yoziladigan ism: boshqaruvchi qilgan o'zgarish "Boshqaruvchi"
  /// deb ko'rinadi.
  String get historyName => isManager ? 'Boshqaruvchi' : name;

  String get roleLabel => isManager ? 'Boshqaruvchi' : 'Xodim';

  /// Avatar uchun bosh harflar.
  String get initials => initialsOf(name);

  AppUser withAccess(StaffAccess next) =>
      AppUser(id: id, name: name, access: next, businessName: businessName);
}

/// Ismdan avatar uchun bosh harflar: "Sardor Aliyev" → "SA".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters =
      parts.take(2).map((p) => String.fromCharCode(p.runes.first)).join();
  return letters.isEmpty ? 'C' : letters.toUpperCase();
}
