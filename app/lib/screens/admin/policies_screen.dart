import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/business_policies.dart';
import '../../services/policy_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../settings/widgets/settings_group.dart';

/// "Ilova qonuniyatlari" — biznes egasi belgilaydigan ish qoidalari.
///
/// Qaysi qadam MAJBURIY, qaysi biri IXTIYORIY; topshirish muddati;
/// omborxona. O'zgarish saqlanishi bilan barcha xodimlarning telefonida
/// darhol kuchga kiradi (qoidalar jonli kuzatiladi).
class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key, this.center});

  /// Sinov uchun — boshqa nusxa.
  final PolicyCenter? center;

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  late final PolicyCenter _center = widget.center ?? PolicyCenter.instance;
  late BusinessPolicies _persisted = _center.value;
  Timer? _debounce;
  var _saving = false;

  @override
  void dispose() {
    // Kutilayotgan o'zgarish yo'qolmasin — sahifa yopilsa ham saqlanadi.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      unawaited(_center.save(_center.value).catchError((Object _) {}));
    }
    super.dispose();
  }

  /// O'zgarish ekranda DARHOL ko'rinadi. Kunlar (+/−) ketma-ket
  /// bosilganda har bosishda emas, to'xtagandan keyin bir marta saqlanadi.
  void _save(BusinessPolicies next, {bool debounce = false}) {
    _center.value = next;
    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 700), () => _persist(next));
    } else {
      _persist(next);
    }
  }

  Future<void> _persist(BusinessPolicies next) async {
    if (next == _persisted) return;
    setState(() => _saving = true);
    try {
      await _center.save(next);
      _persisted = next;
      if (mounted) showResult(context, 'Qoida saqlandi');
    } on PolicySaveException catch (e) {
      // Saqlanmadi — oldingi holatga qaytamiz.
      _center.value = _persisted;
      if (mounted) showResult(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ilova qonuniyatlari'),
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _center.serverReady,
        builder: (context, ready, _) => ValueListenableBuilder<BusinessPolicies>(
          valueListenable: _center,
          builder: (context, p, _) {
            final enabled = ready;
            return ListView(
              padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                  32 + MediaQuery.of(context).padding.bottom),
              children: [
                AppCard(
                  color: context.colorPrimarySoft,
                  borderColor: Colors.transparent,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel_rounded, color: context.colorPrimaryInk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ready
                              ? 'Biznesingizning ish qoidalari: qaysi qadam '
                                  'majburiy, qaysi biri ixtiyoriy. O\'zgarish '
                                  'barcha xodimlarda darhol kuchga kiradi.'
                              : 'Qoidalarni o\'zgartirish tez orada ishga '
                                  'tushadi. Hozircha quyidagi standart qoidalar '
                                  'amal qiladi.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SettingsGroup(
                  title: 'Muddatlar',
                  children: [
                    _DaysRow(
                      icon: Icons.event_available_outlined,
                      tone: StageTone.brand,
                      label: 'Topshirish muddati',
                      describe: (d) => d == 0
                          ? 'Oldindan belgilanmaydi — har safar qo\'lda'
                          : 'Qabul qilingandan keyin $d kunda',
                      value: p.deadlineDays,
                      min: BusinessPolicies.deadlineDaysRange.min,
                      max: BusinessPolicies.deadlineDaysRange.max,
                      enabled: enabled,
                      onChanged: (d) =>
                          _save(p.copyWith(deadlineDays: d), debounce: true),
                    ),
                    _SwitchRow(
                      icon: Icons.warehouse_outlined,
                      tone: StageTone.warehouse,
                      label: 'Omborxona',
                      on: 'Uzoq olib ketilmagan buyurtmalar omborga o\'tadi',
                      off: 'O\'chirilgan — tayyor buyurtmalar Yetgazmada qoladi',
                      value: p.warehouseEnabled,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(warehouseEnabled: v)),
                    ),
                    if (p.warehouseEnabled)
                      _DaysRow(
                        icon: Icons.schedule_rounded,
                        tone: StageTone.warehouse,
                        label: 'Omborga o\'tish muddati',
                        describe: (d) => 'Tayyor bo\'lganidan $d kun o\'tgach',
                        value: p.warehouseDays,
                        min: BusinessPolicies.warehouseDaysRange.min,
                        max: BusinessPolicies.warehouseDaysRange.max,
                        enabled: enabled,
                        onChanged: (d) =>
                            _save(p.copyWith(warehouseDays: d), debounce: true),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsGroup(
                  title: 'Yangi buyurtma',
                  children: [
                    _SwitchRow(
                      icon: Icons.place_outlined,
                      tone: StageTone.info,
                      label: 'Manzil',
                      on: 'Majburiy — manzilsiz buyurtma saqlanmaydi',
                      off: 'Ixtiyoriy',
                      value: p.addressRequired,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(addressRequired: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsGroup(
                  title: 'Yetgazma',
                  children: [
                    _SwitchRow(
                      icon: Icons.my_location_rounded,
                      tone: StageTone.pickup,
                      label: 'Olib kelishda GPS manzil',
                      on: 'Majburiy — saqlanmaguncha qabul qilinmaydi',
                      off: 'Ixtiyoriy',
                      value: p.pickupGpsRequired,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(pickupGpsRequired: v)),
                    ),
                    _SwitchRow(
                      icon: Icons.event_note_outlined,
                      tone: StageTone.pickup,
                      label: 'Qabul qilishda topshirish sanasi',
                      on: p.deadlineDays > 0
                          ? 'Majburiy — muddat avtomatik qo\'yiladi'
                          : 'Majburiy — kalendar ochiladi',
                      off: 'Ixtiyoriy',
                      value: p.deadlineRequired,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(deadlineRequired: v)),
                    ),
                    _SwitchRow(
                      icon: Icons.request_quote_outlined,
                      tone: StageTone.warning,
                      label: 'Qarzga topshirish',
                      on: 'Ruxsat — to\'lanmagan qism qarz bo\'ladi',
                      off: 'Taqiqlangan — to\'liq to\'lov olinadi',
                      value: p.debtAllowed,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(debtAllowed: v)),
                    ),
                    _SwitchRow(
                      icon: Icons.call_split_rounded,
                      tone: StageTone.almost,
                      label: 'Bo\'lib topshirish',
                      on: 'Tayyor xizmatlarni oldinroq berish mumkin',
                      off: 'Faqat hammasi tayyor bo\'lganda',
                      value: p.partialHandoverEnabled,
                      enabled: enabled,
                      onChanged: (v) =>
                          _save(p.copyWith(partialHandoverEnabled: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsGroup(
                  title: 'Yuvish',
                  children: [
                    _SwitchRow(
                      icon: Icons.straighten_rounded,
                      tone: StageTone.washing,
                      label: 'Yuvishdan oldin o\'lchash',
                      on: 'Majburiy — o\'lchanmagan xizmat yuvilmaydi',
                      off: 'Ixtiyoriy',
                      value: p.measureBeforeWash,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(measureBeforeWash: v)),
                    ),
                    _SwitchRow(
                      icon: Icons.inventory_2_outlined,
                      tone: StageTone.washing,
                      label: 'Qadoqlashdan oldin o\'lchash',
                      on: 'Majburiy — o\'lchanmagan xizmat qadoqlashga o\'tmaydi',
                      off: 'Ixtiyoriy',
                      value: p.measureBeforePackaging,
                      enabled: enabled,
                      onChanged: (v) =>
                          _save(p.copyWith(measureBeforePackaging: v)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsGroup(
                  title: 'Qadoqlash',
                  children: [
                    _SwitchRow(
                      icon: Icons.replay_rounded,
                      tone: StageTone.rewash,
                      label: 'Qayta yuvish sababi',
                      on: 'Majburiy — sababsiz qaytarilmaydi',
                      off: 'Ixtiyoriy',
                      value: p.rewashReasonRequired,
                      enabled: enabled,
                      onChanged: (v) => _save(p.copyWith(rewashReasonRequired: v)),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.on,
    required this.off,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final StageTone tone;
  final String label;
  final String on;
  final String off;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      tone: tone,
      label: label,
      value: value ? on : off,
      onTap: enabled ? () => onChanged(!value) : null,
      trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
    );
  }
}

class _DaysRow extends StatelessWidget {
  const _DaysRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.describe,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final StageTone tone;
  final String label;
  final String Function(int days) describe;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          IconTile(icon: icon, tone: tone, size: 38, radius: 11),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(describe(value), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colorSurfaceMuted,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t('Kamaytirish'),
                  visualDensity: VisualDensity.compact,
                  onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove_rounded, size: 20),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Ko\'paytirish'),
                  visualDensity: VisualDensity.compact,
                  onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
