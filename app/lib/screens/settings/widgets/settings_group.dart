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
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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
                if (i > 0) const Divider(height: 1, indent: 56),
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
/// Uchta ko'rinishda ishlatiladi: bosiladigan (o'q bilan), kalitli
/// (switch) va faqat ma'lumot beruvchi. Farqni [onTap] va [trailing]
/// belgilaydi.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// O'ng tomonda yoki nom ostida ko'rinadigan joriy qiymat.
  final String? value;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Chiqish kabi qaytarib bo'lmaydigan amallar uchun.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? AppColors.danger : theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, size: 22, color: danger ? AppColors.danger : null),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: value == null
          ? null
          : Text(value!, style: theme.textTheme.bodySmall),
      trailing: trailing ??
          (onTap == null
              ? null
              : const Icon(Icons.chevron_right_rounded, size: 20)),
    );
  }
}
