import 'package:flutter/material.dart';

import '../../../models/item_status.dart';
import '../../../models/order_history_entry.dart';
import '../../../models/order_item.dart';
import '../../../theme/app_colors.dart';
import 'order_sheets.dart';
import 'order_view_common.dart';

class OrderItemCard extends StatefulWidget {
  const OrderItemCard({
    super.key,
    required this.item,
    required this.inWorkshop,
    required this.canWash,
    required this.canPackage,
    required this.canMeasure,
    required this.canRewash,
    required this.canComment,
    required this.canDelete,
    required this.itemHistory,
    required this.onAdvance,
    required this.onRewash,
    required this.onEdit,
    required this.onDelete,
    required this.onAddComment,
  });

  final OrderItem item;

  /// Shu xizmatga tegishli tarix yozuvlari (vaqt bo'yicha tartiblangan).
  final List<OrderHistoryEntry> itemHistory;

  /// Izoh yozish vakolati. Yo'q bo'lsa izohlar faqat o'qiladi.
  final bool canComment;

  /// Buyurtma sexga tushganmi. "Olib kelish" bosqichida hajm kiritish
  /// hali majburiy emas.
  final bool inWorkshop;

  /// Yuvish bo'limidan turib ishlash vakolati (qadoqlashga o'tkazish).
  final bool canWash;

  /// Qadoqlash bo'limidan turib ishlash vakolati (qadoqlandi / qayta yuvish).
  final bool canPackage;

  /// O'lchash va tahrirlash vakolati (bo'lim + "O'lchash va narx" huquqi).
  final bool canMeasure;

  /// Qayta yuvishga qaytarish vakolati (Qadoqlash bo'limi + alohida huquq).
  final bool canRewash;

  /// Xizmatni buyurtmadan o'chirish vakolati.
  final bool canDelete;

  final ValueChanged<ItemStatus> onAdvance;
  final VoidCallback onRewash;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(String text) onAddComment;

  @override
  State<OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<OrderItemCard> {
  Future<void> _openComments() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemCommentsSheet(
        title: widget.item.productName,
        comments: widget.item.comments,
        canWrite: widget.canComment,
        onSend: widget.onAddComment,
      ),
    );
  }

  Future<void> _openHistory() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemHistorySheet(
        title: widget.item.productName,
        entries: widget.itemHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final color = itemStatusColor[item.status] ?? context.colorTextSecondary;
    final unmeasured = item.hajm.isEmpty;
    // Hajm faqat buyurtma Yuvish bo'limiga o'tgach majburiy bo'ladi.
    final mustMeasureNow = widget.inWorkshop && unmeasured;
    // "Tayyor" holatidagi xizmat qulflanadi - hajmi ham, ma'lumoti ham
    // boshqa hech qachon o'zgartirilmaydi.
    final locked = item.status == ItemStatus.tayyor;
    final showEdit = widget.canMeasure && !locked;
    final showRewash =
        widget.canRewash && item.status == ItemStatus.qadoqlashda;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: mustMeasureNow
              ? AppColors.danger.withValues(alpha: 0.45)
              : context.colorBorder,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(11, 6, 6, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (item.itemId.isNotEmpty)
                        TextSpan(
                          text: '${item.itemId}  ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colorTextSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(
                        text: item.productName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ItemIconButton(
                icon: Icons.history_rounded,
                tooltip: 'O\'zgarishlar tarixi',
                onTap: _openHistory,
              ),
              _ItemIconButton(
                icon: Icons.mode_comment_outlined,
                tooltip: 'Izohlar',
                badge: item.comments.length,
                onTap: _openComments,
              ),
              if (showRewash)
                _ItemIconButton(
                  icon: Icons.replay_rounded,
                  tooltip: 'Qayta yuvishga qaytarish',
                  color: AppColors.danger,
                  onTap: widget.onRewash,
                ),
              // O'lchanmagan xizmat - yonib o'chuvchi undov. Alohida
              // "O'lchash" tugmasi kerak emas: qalamchaning o'zi shu ishni
              // bajaradi, undov esa diqqatni tortadi.
              if (mustMeasureNow) const _BlinkingWarning(),
              if (showEdit)
                _ItemIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'O\'lchash va tahrirlash',
                  onTap: widget.onEdit,
                ),
              if (widget.canDelete && !locked)
                _ItemIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Xizmatni o\'chirish',
                  color: AppColors.danger,
                  onTap: widget.onDelete,
                ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status.label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5),
                ),
              ),
              const Spacer(),
              if (!unmeasured)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Text(
                    '${item.hajm}  ·  ${item.price.toStringAsFixed(0)} so\'m',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (item.rewashReason != null && item.rewashReason!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Qayta yuvish sababi: ${item.rewashReason}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          ..._buildActions(context, item, mustMeasureNow),
        ],
      ),
    );
  }

  /// Holatni o'zgartiruvchi tugmalar. Vakolat bo'lmasa umuman
  /// qaytarilmaydi - ortiqcha eslatma matni ham chiqarilmaydi.
  List<Widget> _buildActions(
      BuildContext context, OrderItem item, bool mustMeasureNow) {
    final isWashStage = item.status == ItemStatus.yuvilmoqda ||
        item.status == ItemStatus.qaytaYuvildi;

    if (isWashStage && widget.canWash) {
      // O'lchanmagan xizmat keyingi bosqichga o'tmaydi - tugma shunchaki
      // ko'rsatilmaydi (eslatma matni chiqarilmaydi, undov belgisining
      // o'zi yetarli).
      if (mustMeasureNow) return const [];
      return [
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: _compactItemButtonStyle,
            onPressed: () => widget.onAdvance(ItemStatus.qadoqlashda),
            child: const Text('Qadoqlashga o\'tkazish'),
          ),
        ),
        const SizedBox(height: 4),
      ];
    }

    if (item.status == ItemStatus.qadoqlashda && widget.canPackage) {
      return [
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: _compactItemButtonStyle,
            onPressed: () => widget.onAdvance(ItemStatus.tayyor),
            child: const Text('Qadoqlandi'),
          ),
        ),
        const SizedBox(height: 4),
      ];
    }

    return const [];
  }
}

final ButtonStyle _compactItemButtonStyle = ElevatedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 8),
  minimumSize: const Size(0, 36),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Xizmat kartasidagi ixcham ikonka tugmasi. Ixtiyoriy [badge] soni
/// ikonkaning yuqori o'ng burchagida kichik raqam sifatida chiqadi.
class _ItemIconButton extends StatelessWidget {
  const _ItemIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: badge > 0
          ? Badge(
              label: Text('$badge'),
              textStyle: const TextStyle(fontSize: 9),
              child: Icon(icon,
                  size: 17, color: color ?? context.colorTextSecondary),
            )
          : Icon(icon, size: 17, color: color ?? context.colorTextSecondary),
      onPressed: onTap,
    );
  }
}

/// O'lchanmagan xizmat uchun yonib o'chuvchi undov belgisi - diqqatni
/// tortadi, lekin ekranga qo'shimcha matn qo'shmaydi.
class _BlinkingWarning extends StatefulWidget {
  const _BlinkingWarning();

  @override
  State<_BlinkingWarning> createState() => _BlinkingWarningState();
}

class _BlinkingWarningState extends State<_BlinkingWarning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 1, end: 0.15).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hajmi kiritilmagan',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FadeTransition(
          opacity: _opacity,
          child: const Icon(Icons.error_rounded,
              size: 19, color: AppColors.danger),
        ),
      ),
    );
  }
}

/// Bitta xizmatning izohlari - alohida oynada ochiladi. Vakolat bo'lmasa
/// izohlar faqat o'qiladi (yozish maydoni ko'rsatilmaydi).
