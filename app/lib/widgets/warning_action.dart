import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../screens/warnings/warnings_screen.dart';
import '../services/warning_center.dart';
import '../theme/app_colors.dart';

/// Qo'ng'iroqdan OLDIN turadigan jiddiy "!" belgisi — xodimda ko'rilmagan
/// qayta yuvish ogohlantirishi bo'lsa. Bo'lmasa — umuman ko'rinmaydi.
class WarningAction extends StatelessWidget {
  const WarningAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WorkWarning>>(
      valueListenable: WarningCenter.instance,
      builder: (context, _, __) {
        final count = WarningCenter.instance.unseenCount;
        if (count == 0) return const SizedBox.shrink();
        return IconButton(
          tooltip: t('$count ta ogohlantirish'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WarningsScreen()),
          ),
          icon: _PulsingAlert(count: count),
        );
      },
    );
  }
}

class _PulsingAlert extends StatefulWidget {
  const _PulsingAlert({required this.count});

  final int count;

  @override
  State<_PulsingAlert> createState() => _PulsingAlertState();
}

class _PulsingAlertState extends State<_PulsingAlert>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('${widget.count}'),
      isLabelVisible: widget.count > 1,
      backgroundColor: Colors.white,
      textColor: AppColors.danger,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.06).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.priority_high_rounded,
              size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
