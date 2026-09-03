import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// AppBar'dagi kun/tun rejimini almashtiruvchi tugma - qurilma
/// sozlamasiga bog'liq emas, tanlov qurilmada saqlanadi.
class ThemeToggleAction extends StatelessWidget {
  const ThemeToggleAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: isDark ? 'Kun rejimi' : 'Tun rejimi',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          onPressed: ThemeController.instance.toggle,
        );
      },
    );
  }
}
