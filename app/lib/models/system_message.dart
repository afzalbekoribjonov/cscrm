/// CSCRM'dan kelgan xabar.
///
/// Buyurtma hodisalaridan ([AppNotification]) BUTUNLAY boshqa narsa:
/// u sexdagi ishga tegishli, bu esa bizdan — yangilik, eslatma yoki
/// taklif. Shu sabab ikkalasi bildirishnoma ekranida alohida bo'limda
/// turadi: aralashtirilsa, muhim e'lon o'nlab "buyurtma yetkazildi"
/// yozuvlari orasida ko'milib ketardi.
class SystemMessage {
  const SystemMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String body;

  /// `yangilik` · `eslatma` · `taklif`
  final String kind;

  final int createdAt;
  final int? expiresAt;

  String get kindLabel {
    switch (kind) {
      case 'eslatma':
        return 'Eslatma';
      case 'taklif':
        return 'Taklif';
      default:
        return 'Yangilik';
    }
  }

  factory SystemMessage.fromJson(Map<String, dynamic> json) => SystemMessage(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        kind: json['kind'] as String? ?? 'yangilik',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        expiresAt: (json['expiresAt'] as num?)?.toInt(),
      );
}
