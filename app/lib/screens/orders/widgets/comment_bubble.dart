import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'order_view_common.dart';

class CommentBubble extends StatelessWidget {
  const CommentBubble({
    super.key,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String authorName;
  final String text;
  final int createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                authorName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                createdAt == 0
                    ? ''
                    : orderTimeFormat
                        .format(DateTime.fromMillisecondsSinceEpoch(createdAt)),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: context.colorTextSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Bitta xizmat (mahsulot birligi) kartasi. Tugmalar faqat tegishli
/// bo'lim vakolati bo'lganda va aynan o'sha bo'limdan ochilganda
/// ko'rsatiladi - aks holda karta faqat ko'rish uchun chiziladi.
