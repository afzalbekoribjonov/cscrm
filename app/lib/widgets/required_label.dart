import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Majburiy inputlar uchun yorliq - "(ixtiyoriy)" so'zi o'rniga, aksincha,
/// to'ldirilishi shart bo'lgan maydonlarga qizil "*" belgisi qo'yiladi.
/// Ixtiyoriy maydonlarda esa hech qanday belgi bo'lmaydi.
Widget requiredLabel(String text) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text),
        const TextSpan(
          text: ' *',
          style:
              TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
