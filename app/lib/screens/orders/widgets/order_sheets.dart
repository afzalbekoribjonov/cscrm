import 'package:flutter/material.dart';

import '../../../models/comment.dart';
import '../../../models/order_history_entry.dart';
import '../../../theme/app_colors.dart';
import 'comment_bubble.dart';
import 'order_history_view.dart';

class ItemCommentsSheet extends StatefulWidget {
  const ItemCommentsSheet({
    super.key,
    required this.title,
    required this.comments,
    required this.canWrite,
    required this.onSend,
  });

  final String title;
  final List<Comment> comments;
  final bool canWrite;
  final Future<void> Function(String text) onSend;

  @override
  State<ItemCommentsSheet> createState() => ItemCommentsSheetState();
}

class ItemCommentsSheetState extends State<ItemCommentsSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  /// Yuborilgan izohlar oyna yopilmasdan darhol ko'rinishi uchun -
  /// jonli oqim ortdagi ekranni yangilaydi, lekin bu oyna emas.
  late final List<Comment> _local = [...widget.comments];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      if (!mounted) return;
      setState(() {
        _local.add(Comment(
          key: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          authorId: '',
          authorName: 'Siz',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
        _ctrl.clear();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.title,
      subtitle: 'Izohlar',
      icon: Icons.mode_comment_outlined,
      children: [
        if (_local.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('Hali izoh yo\'q',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
        else
          for (final c in _local)
            CommentBubble(
              authorName: c.authorName,
              text: c.text,
              createdAt: c.createdAt,
            ),
        if (widget.canWrite) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Izoh yozing...',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 20),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bitta xizmatning o'zgarishlar tarixi - alohida oynada.
class ItemHistorySheet extends StatelessWidget {
  const ItemHistorySheet({super.key, required this.title, required this.entries});

  final String title;
  final List<OrderHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: title,
      subtitle: 'O\'zgarishlar tarixi',
      icon: Icons.history_rounded,
      children: [
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('Bu xizmat bo\'yicha o\'zgarish yo\'q',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
        else
          HistoryTimeline(entries: entries),
      ],
    );
  }
}

/// Xizmat oynalari uchun umumiy qobiq - sarlavha, tutqich va joy.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colorBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O'lchash oynasidan qaytadigan natija - xizmat turi ham almashtirilgan
/// bo'lishi mumkin, shu sabab mahsulot ma'lumoti ham qaytariladi.

class RewashReasonDialog extends StatefulWidget {
  const RewashReasonDialog({super.key, required this.productName});

  final String productName;

  @override
  State<RewashReasonDialog> createState() => RewashReasonDialogState();
}

class RewashReasonDialogState extends State<RewashReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Qayta yuvishga qaytarilsinmi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${widget.productName}" qadoqlashdan yuvishga qaytariladi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Sababi',
              hintText: 'Sababni yozing...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Qaytarish'),
        ),
      ],
    );
  }
}
