import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bo'lim ro'yxati tepasidagi ixcham hisoblagich - shu bo'limda nechta
/// buyurtma turganini bir qarashda ko'rsatadi ("12 ta").
class CountBanner extends StatelessWidget {
  const CountBanner({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$count ta',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
