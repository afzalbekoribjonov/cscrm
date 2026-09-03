import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

final ButtonStyle compactButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 10),
  minimumSize: const Size(0, 40),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

final ButtonStyle compactFilledStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 10),
  minimumSize: const Size(0, 40),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class PickupActionCard extends StatelessWidget {
  const PickupActionCard({
    super.key,
    required this.hasGps,
    required this.busy,
    required this.onSaveGps,
    required this.onAccept,
  });

  final bool hasGps;
  final bool busy;
  final VoidCallback onSaveGps;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasGps)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 6),
                  Expanded(child: Text('Manzil GPS orqali saqlangan')),
                ],
              )
            else
              OutlinedButton.icon(
                style: compactButtonStyle,
                onPressed: busy ? null : onSaveGps,
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('GPS manzilni saqlash'),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: compactFilledStyle,
              onPressed: busy ? null : onAccept,
              child: const Text('Qabul qilindi'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransportActionCard extends StatelessWidget {
  const TransportActionCard({
    super.key,
    required this.label,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ElevatedButton(
              style: compactFilledStyle,
              onPressed: busy ? null : onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class DropdownSection extends StatelessWidget {
  const DropdownSection({
    super.key,
    required this.icon,
    required this.label,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 18, color: context.colorTextSecondary),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 4),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: context.colorTextSecondary,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
      ],
    );
  }
}

/// "O'zgarishlar tarixi" - har bir yozuv tartib raqami, rangli ikonka va
/// inson tilidagi tavsif bilan, vertikal chiziq orqali ulangan holda.
