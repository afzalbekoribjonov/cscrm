import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Sozlamalarning bir guruhi: sarlavha + qatorlar kartasi.
///
/// Qatorlar orasidagi ajratgich SHU YERDA qo'yiladi — har bir qator
/// o'zi chizsa, oxirgisida ortiqcha chiziq qolardi.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 62),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bitta sozlama qatori.
///
/// Uch ko'rinishda ishlatiladi: bosiladigan (o'q bilan), kalitli
/// (switch) va faqat ma'lumot beruvchi. Farqni [onTap] va [trailing]
/// belgilaydi.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.color,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// Nom ostidagi qator: joriy holat yoki qisqa izoh.
  final String? value;

  /// Ikonka kvadratining rangi. Berilmasa — brend rangi.
  final Color? color;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Chiqish kabi qaytarib bo'lmaydigan amallar uchun.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = danger ? AppColors.danger : (color ?? AppColors.primary);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      // Rangli kvadrat ikonka — qatorlarni bir qarashda ajratadi.
      // Oddiy kulrang ikonkalar ro'yxatni bir xil massaga aylantiradi.
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: tint),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: danger ? AppColors.danger : null,
        ),
      ),
      subtitle: value == null
          ? null
          : Text(
              value!,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded, size: 20)),
    );
  }
}
