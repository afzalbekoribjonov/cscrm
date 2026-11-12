import 'package:flutter/material.dart' hide Text;

import '../../../l10n/text.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/surfaces.dart';

/// Sozlamalar guruhi: sarlavha va bitta kartada qatorlar.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// Guruh ostidagi izoh.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.colorTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: context.colorBorder),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// Sozlamalar qatori: rangli ikonka, nom, holat matni va o'ng tomonda
/// kalit yoki o'q.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.tone = StageTone.brand,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// Holat MATN bilan ham yoziladi — kalitning yoniq-o'chiqligini rangdan
  /// ajratish hammaga ham oson emas.
  final String? value;
  final StageTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileTone = danger ? StageTone.danger : tone;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            IconTile(icon: icon, tone: tileTone, size: 38, radius: 11),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? tileTone.ink(context) : null,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      value!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(Icons.chevron_right_rounded,
                        color: context.colorTextTertiary)),
          ],
        ),
      ),
    );
  }
}

/// Ikki-uch variantdan birini tanlash (yozuv, mavzu) — kartochkalar.
class ChoiceCards<T> extends StatelessWidget {
  const ChoiceCards({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<ChoiceOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _ChoiceCard(
              option: options[i],
              selected: options[i].value == value,
              onTap: () => onChanged(options[i].value),
            )),
          ],
        ],
      ),
    );
  }
}

class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.verbatim = false,
  });

  final T value;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Matn o'girilmaydi — har bir variant o'z yozuvida ko'rinishi uchun.
  final bool verbatim;
}

class _ChoiceCard<T> extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = selected ? context.colorPrimaryInk : context.colorTextPrimary;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(color: ink);
    final subStyle = theme.textTheme.bodySmall;
    return Material(
      color: selected ? context.colorPrimarySoft : context.colorSurfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(option.icon, size: 20, color: ink),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selected ? AppColors.primary : context.colorTextTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              option.verbatim
                  ? Text.verbatim(option.title, style: titleStyle)
                  : Text(option.title, style: titleStyle),
              const SizedBox(height: 2),
              option.verbatim
                  ? Text.verbatim(option.subtitle, style: subStyle)
                  : Text(option.subtitle, style: subStyle),
            ],
          ),
        ),
      ),
    );
  }
}
