import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../../l10n/text.dart';
import '../../../models/item_status.dart';
import '../../../models/order_item.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/action_menu.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/money.dart';
import '../../../utils/uz_dates.dart';
import '../../../widgets/stage_visuals.dart';

/// Xizmat ustida bajariladigan amallar va ularning ruxsatlari.
class ItemPermissions {
  const ItemPermissions({
    this.wash = false,
    this.package = false,
    this.measure = false,
    this.rewash = false,
    this.delete = false,
    this.comment = false,
    this.measureBeforeWash = false,
    this.measureBeforePackaging = true,
  });

  /// Yuvish bo'limidan turib ishlash (Yuvish, Qadoqlashga o'tkazish).
  final bool wash;

  /// Qadoqlash bo'limidan turib ishlash (Qadoqlandi).
  final bool package;
  final bool measure;
  final bool rewash;
  final bool delete;
  final bool comment;

  /// "Ilova qonuniyatlari".
  final bool measureBeforeWash;
  final bool measureBeforePackaging;
}

/// Buyurtma ichidagi bitta xizmat — holati, o'lchami va keyingi qadam.
///
/// Har bir bosqichda faqat BITTA asosiy tugma bor, u ham faqat vakolat
/// bo'lsa:
///   Navbatda → "Yuvish" → Yuvilmoqda (jonli) → "Qadoqlashga o'tkazish"
///   → Qadoqlashda → "Qadoqlandi" → Tayyor
class OrderItemTile extends StatelessWidget {
  const OrderItemTile({
    super.key,
    required this.item,
    required this.permissions,
    required this.onWash,
    required this.onAdvance,
    required this.onRewash,
    required this.onMeasure,
    required this.onDelete,
    required this.onComments,
    required this.onHistory,
    this.busy = false,
  });

  final OrderItem item;
  final ItemPermissions permissions;
  final VoidCallback onWash;
  final ValueChanged<ItemStatus> onAdvance;
  final VoidCallback onRewash;
  final VoidCallback onMeasure;
  final VoidCallback onDelete;
  final VoidCallback onComments;
  final VoidCallback onHistory;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = ItemStage.of(item);
    final visual = stage.visual;
    final p = permissions;
    final unmeasured = !item.hasNumericMeasure;
    final locked = item.status == ItemStatus.tayyor;
    final canMeasureNow = p.measure && !locked;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      borderColor: unmeasured && item.status.isWashStage
          ? StageTone.danger.fill.withValues(alpha: 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: visual.icon, tone: visual.tone, size: 38, radius: 11),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.itemId.isNotEmpty)
                          Text('№${item.itemId}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFeatures: AppFonts.tabular,
                              )),
                        TonePill(
                          label: visual.label,
                          tone: visual.tone,
                          dense: true,
                          dot: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ItemMenu(
                item: item,
                permissions: p,
                canMeasureNow: canMeasureNow,
                onMeasure: onMeasure,
                onRewash: onRewash,
                onDelete: onDelete,
                onComments: onComments,
                onHistory: onHistory,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MeasureLine(item: item),
          ),
          if ((item.rewashReason ?? '').isNotEmpty &&
              item.status != ItemStatus.tayyor) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Qayta yuvish sababi: ${item.rewashReason}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: StageTone.rewash.ink(context)),
              ),
            ),
          ],
          if (item.isHanded) ...[
            const SizedBox(height: 6),
            Text(
              'Topshirildi · ${UzDates.dateTime(UzDates.fromMillis(item.handedAt!))}'
              '${item.handedByName.isNotEmpty ? ' · ${item.handedByName}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (item.status == ItemStatus.yuvilmoqda && !item.isHanded) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: WashingIndicator(startedAt: item.washStartedAt),
            ),
          ],
          ..._action(context, unmeasured, canMeasureNow),
          if (item.comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onComments,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_outlined,
                        size: 15, color: context.colorTextSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.comments.length} ta izoh · ${item.comments.last.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bosqichga mos asosiy tugma.
  List<Widget> _action(
      BuildContext context, bool unmeasured, bool canMeasureNow) {
    final p = permissions;
    if (item.isHanded) return const [];

    Widget hint(String text) => Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: StageTone.danger.ink(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StageTone.danger.ink(context),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        );

    Widget buttons(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 10, right: 8),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );

    final measureButton = OutlinedButton.icon(
      style: _compact,
      onPressed: busy ? null : onMeasure,
      icon: const Icon(Icons.straighten_rounded, size: 18),
      label: const Text('O\'lchash'),
    );

    if (item.status.awaitsWash && p.wash) {
      final blocked = p.measureBeforeWash && unmeasured;
      return [
        if (blocked) hint('Yuvishdan oldin xizmatni o\'lchang'),
        buttons([
          if (unmeasured && canMeasureNow) measureButton,
          FilledButton.icon(
            style: _compactFilled(StageTone.washing.fill),
            onPressed: busy || blocked ? null : onWash,
            icon: const Icon(Icons.local_laundry_service_rounded, size: 18),
            label: const Text('Yuvish'),
          ),
        ]),
      ];
    }

    if (item.status == ItemStatus.yuvilmoqda && p.wash) {
      final blocked = p.measureBeforePackaging && unmeasured;
      return [
        if (blocked) hint('Qadoqlashga o\'tkazishdan oldin o\'lchang'),
        buttons([
          if (unmeasured && canMeasureNow) measureButton,
          FilledButton.icon(
            style: _compactFilled(StageTone.packaging.fill),
            onPressed: busy || blocked
                ? null
                : () => onAdvance(ItemStatus.qadoqlashda),
            icon: const Icon(Icons.inventory_2_rounded, size: 18),
            label: Text(unmeasured && canMeasureNow
                ? 'Qadoqlashga'
                : 'Qadoqlashga o\'tkazish'),
          ),
        ]),
      ];
    }

    if (item.status == ItemStatus.qadoqlashda && p.package) {
      return [
        buttons([
          if (p.rewash)
            OutlinedButton.icon(
              style: _compact,
              onPressed: busy ? null : onRewash,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Qayta yuvish'),
            ),
          FilledButton.icon(
            style: _compactFilled(StageTone.ready.fill),
            onPressed: busy ? null : () => onAdvance(ItemStatus.tayyor),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Qadoqlandi'),
          ),
        ]),
      ];
    }

    if (unmeasured && canMeasureNow && item.status.isWashStage) {
      return [buttons([measureButton])];
    }
    return const [];
  }
}

final ButtonStyle _compact = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  textStyle: const TextStyle(
      fontFamily: AppFonts.sans, fontWeight: FontWeight.w700, fontSize: 14),
);

ButtonStyle _compactFilled(Color color) => FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: const TextStyle(
          fontFamily: AppFonts.sans, fontWeight: FontWeight.w700, fontSize: 14),
    );

/// O'lcham va narx qatori. O'lchanmagan bo'lsa — qizil, miltillovchi
/// belgi bilan.
class _MeasureLine extends StatelessWidget {
  const _MeasureLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!item.hasNumericMeasure && item.hajm.isEmpty) {
      return Row(
        children: [
          const _Blink(child: Icon(Icons.error_rounded, size: 17, color: AppColors.danger)),
          const SizedBox(width: 6),
          Text(
            'O\'lchanmagan',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: StageTone.danger.ink(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.straighten_rounded, size: 16, color: context.colorTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.hajm,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
        Text(
          formatSom(item.price),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: AppFonts.tabular,
          ),
        ),
      ],
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.item,
    required this.permissions,
    required this.canMeasureNow,
    required this.onMeasure,
    required this.onRewash,
    required this.onDelete,
    required this.onComments,
    required this.onHistory,
  });

  final OrderItem item;
  final ItemPermissions permissions;
  final bool canMeasureNow;
  final VoidCallback onMeasure;
  final VoidCallback onRewash;
  final VoidCallback onDelete;
  final VoidCallback onComments;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return MoreButton(
      tooltip: t('Xizmat amallari'),
      dot: item.comments.isNotEmpty,
      onPressed: () => showActionMenu(
        context,
        title: item.productName,
        groups: [
          MenuGroup(actions: [
            if (canMeasureNow)
              MenuAction(
                icon: Icons.straighten_rounded,
                label: item.hasNumericMeasure ? 'O\'lchamni tahrirlash' : 'O\'lchash',
                subtitle: 'Hajm, narx va xizmat turi',
                onTap: onMeasure,
              ),
            MenuAction(
              icon: Icons.mode_comment_outlined,
              label: 'Izohlar',
              subtitle: item.comments.isEmpty
                  ? (permissions.comment ? 'Izoh qoldirish' : 'Izoh yo\'q')
                  : '${item.comments.length} ta izoh',
              tone: StageTone.info,
              badge: item.comments.length,
              onTap: onComments,
            ),
            MenuAction(
              icon: Icons.history_rounded,
              label: 'O\'zgarishlar tarixi',
              subtitle: 'Kim, qachon, nima qildi',
              tone: StageTone.neutral,
              onTap: onHistory,
            ),
          ]),
          MenuGroup(actions: [
            if (permissions.rewash &&
                permissions.package &&
                item.status == ItemStatus.qadoqlashda)
              MenuAction(
                icon: Icons.replay_rounded,
                label: 'Qayta yuvishga qaytarish',
                tone: StageTone.rewash,
                onTap: onRewash,
              ),
            if (permissions.delete && item.status != ItemStatus.tayyor)
              MenuAction(
                icon: Icons.delete_outline_rounded,
                label: 'Xizmatni o\'chirish',
                subtitle: 'Buyurtma narxi qayta hisoblanadi',
                destructive: true,
                onTap: onDelete,
              ),
          ]),
        ],
      ),
    );
  }
}

/// "Yuvilmoqda" — jonli ko'rsatkich: harakatlanuvchi chiziq va o'tgan
/// vaqt ("12 daqiqadan beri"). Xodim xizmat haqiqatan yuvilayotganini
/// bir qarashda ko'radi.
class WashingIndicator extends StatefulWidget {
  const WashingIndicator({super.key, this.startedAt});

  final int? startedAt;

  @override
  State<WashingIndicator> createState() => _WashingIndicatorState();
}

class _WashingIndicatorState extends State<WashingIndicator> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // O'tgan vaqt har daqiqada yangilanadi — har soniyada qayta chizish
    // batareyani bekorga sarflardi.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _elapsed() {
    final at = widget.startedAt;
    if (at == null || at <= 0) return 'Yuvilmoqda';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (d.inMinutes < 1) return 'Yuvish hozir boshlandi';
    if (d.inHours < 1) return '${d.inMinutes} daqiqadan beri yuvilmoqda';
    final m = d.inMinutes % 60;
    if (d.inDays < 1) {
      return m == 0
          ? '${d.inHours} soatdan beri yuvilmoqda'
          : '${d.inHours} soat $m daqiqadan beri yuvilmoqda';
    }
    return '${d.inDays} kundan beri yuvilmoqda';
  }

  @override
  Widget build(BuildContext context) {
    final tone = StageTone.washing;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Spin(child: Icon(Icons.autorenew_rounded, size: 16, color: tone.ink(context))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _elapsed(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tone.ink(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              color: tone.fill,
              backgroundColor: tone.fill.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.child});
  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: widget.child);
}

/// Diqqat tortish uchun sekin miltillash.
class _Blink extends StatefulWidget {
  const _Blink({required this.child});
  final Widget child;

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.25).animate(_c),
        child: widget.child,
      );
}
