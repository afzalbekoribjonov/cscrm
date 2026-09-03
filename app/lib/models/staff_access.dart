import 'staff_permission.dart';
import 'work_section.dart';

/// Joriy foydalanuvchining vakolatlari: qaysi bo'limlarda ishlay oladi
/// ([sections]) va o'sha bo'limlar ichida qanday qo'shimcha huquqlarga
/// ega ([permissions]).
///
/// Qoida (boshqaruvchi tomonidan belgilangan):
///  * Xodim faqat o'ziga vakolat berilgan bo'limda ish qila oladi.
///  * Har bir ish faqat o'ziga tegishli bo'lim ICHIDAN turib bajariladi -
///    masalan "Qadoqlandi" tugmasi Yuvish bo'limidan ochilgan buyurtmada
///    ko'rinmaydi, garchi xodimda qadoqlash vakolati bo'lsa ham.
///  * Vakolat bo'lmaganda hech qanday tugma ko'rsatilmaydi (eslatma ham
///    chiqarilmaydi) - buyurtma faqat ko'rish uchun ochiladi.
///  * Boshqaruvchi (admin) uchun barcha cheklovlar o'chiriladi.
class StaffAccess {
  const StaffAccess({
    required this.isAdmin,
    required this.sections,
    this.permissions = const {},
  });

  const StaffAccess.admin()
      : isAdmin = true,
        sections = const {},
        permissions = const {};

  const StaffAccess.none()
      : isAdmin = false,
        sections = const {},
        permissions = const {};

  StaffAccess.fromKeys(
    Iterable<String> sectionKeys, {
    Iterable<String> permissionKeys = const [],
    this.isAdmin = false,
  })  : sections = {
          for (final key in sectionKeys)
            if (WorkSection.fromKey(key) != null) WorkSection.fromKey(key)!,
        },
        permissions = {
          for (final key in permissionKeys)
            if (StaffPermission.fromKey(key) != null)
              StaffPermission.fromKey(key)!,
        };

  final bool isAdmin;
  final Set<WorkSection> sections;
  final Set<StaffPermission> permissions;

  /// Xodimda shu bo'lim vakolati bormi (qaysi bo'limdan ochilganidan
  /// qat'i nazar) - masalan bo'lim ro'yxatida tugma ko'rsatish uchun.
  bool has(WorkSection section) => isAdmin || sections.contains(section);

  /// Qo'shimcha huquq bormi.
  bool can(StaffPermission permission) =>
      isAdmin || permissions.contains(permission);

  /// Amalni bajarishga ruxsat bormi: xodimda [needed] bo'lim vakolati
  /// bo'lishi VA buyurtma aynan o'sha bo'limdan ochilgan bo'lishi shart.
  bool canActIn(WorkSection? openedFrom, WorkSection needed) {
    if (isAdmin) return true;
    return openedFrom == needed && sections.contains(needed);
  }

  List<String> get sectionKeys => sections.map((s) => s.key).toList();
  List<String> get permissionKeys => permissions.map((p) => p.key).toList();
}
