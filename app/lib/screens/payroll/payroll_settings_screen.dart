import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../models/calculation_method.dart';
import '../../models/payroll.dart';
import '../../models/product.dart';
import '../../services/payroll_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/money.dart';
import 'payroll_sources.dart';
import 'payroll_widgets.dart';

/// "Maosh sozlamasi" — ishbayi narxlari va ulushlar.
///
///  * Har bir xizmat uchun 1 birlikni (m², m, kg, dona) YUVISH va
///    QADOQLASH narxi alohida. Kichik/katta o'lchamli xizmatda — har
///    o'lcham uchun alohida.
///  * Dastavchik — topshirgan xizmatlari summasidan foiz.
///  * Dispetcher — yaratgan buyurtmasi topshirilganda yakuniy narxidan
///    foiz YOKI har bir yaratilgan buyurtma uchun qat'iy summa.
///
/// Narx o'zgarsa — faqat SHUNDAN KEYINGI ishga ta'sir qiladi.
class PayrollSettingsScreen extends StatefulWidget {
  const PayrollSettingsScreen({super.key, this.sources});

  /// Berilmasa — Firebase. Maosh sahifasi o'z manbasini uzatadi.
  final PayrollSources? sources;

  @override
  State<PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends State<PayrollSettingsScreen> {
  late final PayrollSources _src = widget.sources ?? FirebasePayrollSources();

  StreamSubscription<PayrollRates>? _ratesSub;
  StreamSubscription<List<Product>>? _productsSub;

  PayrollRates? _rates;
  List<Product>? _products;
  Object? _error;
  var _filled = false;
  var _saving = false;
  var _dirty = false;

  final _ctrl = <String, TextEditingController>{};
  final _courier = TextEditingController();
  final _dispatcher = TextEditingController();
  var _mode = DispatcherMode.percent;

  @override
  void initState() {
    super.initState();
    _ratesSub = _src.rates().listen(
      (r) => setState(() {
        _rates = r;
        _fill();
      }),
      onError: (Object e) => setState(() => _error = e),
    );
    _productsSub = _src.products().listen(
      (p) => setState(() {
        _products = [...p]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _fill();
      }),
      onError: (Object e) => setState(() => _error = e),
    );
  }

  @override
  void dispose() {
    _ratesSub?.cancel();
    _productsSub?.cancel();
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _courier.dispose();
    _dispatcher.dispose();
    super.dispose();
  }

  /// Maydonlar BIR MARTA to'ldiriladi — keyingi oqim yangilanishi
  /// foydalanuvchi yozayotgan qiymatni ustidan yozib yubormasin.
  void _fill() {
    final rates = _rates;
    final products = _products;
    if (_filled || rates == null || products == null) return;
    _filled = true;
    String money(double v) => v > 0 ? formatMoney(v) : '';
    for (final p in products) {
      final r = rates.rateOf(p.id);
      _field('${p.id}/wash').text = money(r.wash);
      _field('${p.id}/pack').text = money(r.pack);
      _field('${p.id}/washSmall').text = money(r.washSmall);
      _field('${p.id}/washLarge').text = money(r.washLarge);
      _field('${p.id}/packSmall').text = money(r.packSmall);
      _field('${p.id}/packLarge').text = money(r.packLarge);
    }
    _courier.text = rates.courierPct > 0 ? _pct(rates.courierPct) : '';
    _mode = rates.dispatcherMode;
    _dispatcher.text = rates.dispatcherValue <= 0
        ? ''
        : _mode == DispatcherMode.percent
            ? _pct(rates.dispatcherValue)
            : formatMoney(rates.dispatcherValue);
  }

  static String _pct(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');

  static double _parsePct(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

  TextEditingController _field(String key) =>
      _ctrl.putIfAbsent(key, TextEditingController.new);

  double _money(String key) => parseMoney(_ctrl[key]?.text ?? '');

  Future<void> _save() async {
    final products = _products ?? const <Product>[];
    final courier = _parsePct(_courier.text);
    final dispatcherValue = _mode == DispatcherMode.percent
        ? _parsePct(_dispatcher.text)
        : parseMoney(_dispatcher.text);
    if (courier > PayrollRates.maxPercent ||
        (_mode == DispatcherMode.percent &&
            dispatcherValue > PayrollRates.maxPercent)) {
      showResult(context,
          'Ulush ${PayrollRates.maxPercent.toInt()}% dan oshmasligi kerak.',
          error: true);
      return;
    }
    final rates = PayrollRates(
      products: {
        for (final p in products)
          p.id: ProductRate(
            wash: _money('${p.id}/wash'),
            pack: _money('${p.id}/pack'),
            washSmall: _money('${p.id}/washSmall'),
            washLarge: _money('${p.id}/washLarge'),
            packSmall: _money('${p.id}/packSmall'),
            packLarge: _money('${p.id}/packLarge'),
          ),
      },
      courierPct: courier,
      dispatcherMode: _mode,
      dispatcherValue: dispatcherValue,
    );
    setState(() => _saving = true);
    try {
      await _src.saveRates(rates);
      if (!mounted) return;
      setState(() => _dirty = false);
      showResult(context, 'Maosh sozlamasi saqlandi');
    } on PayrollException catch (e) {
      if (mounted) showResult(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showResult(context, 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maosh sozlamasi')),
        body: PayrollUnavailable(error: error),
      );
    }
    final products = _products;
    if (products == null || _rates == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maosh sozlamasi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Maosh sozlamasi')),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(Gap.page, 10, Gap.page, 12 + bottom),
        decoration: BoxDecoration(
          color: context.colorSurface,
          border: Border(top: BorderSide(color: context.colorBorder)),
        ),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _saving || !_dirty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_dirty ? 'Saqlash' : 'Saqlangan'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 24),
        children: [
          const InfoNote(
            icon: Icons.info_outline_rounded,
            text: 'Narx o\'zgarsa, u faqat shundan keyingi ishga '
                'qo\'llanadi — o\'tgan kunlar qayta hisoblanmaydi.',
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Ishbayi narxlari',
            subtitle: '1 birlikni yuvish va qadoqlash uchun xodimga '
                'to\'lanadigan summa',
          ),
          if (products.isEmpty)
            AppCard(
              child: Text(
                'Avval "Xizmatlar va narxlar" bo\'limida xizmat qo\'shing.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final p in products) ...[
              _ProductRateCard(
                product: p,
                field: _field,
                onChanged: _changed,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Dastavchik ulushi',
            subtitle: 'Mijozga topshirgan xizmatlari summasidan',
          ),
          AppCard(
            child: Row(
              children: [
                const IconTile(
                    icon: Icons.local_shipping_rounded, tone: StageTone.ready),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Har bir topshirishdan',
                      style: theme.textTheme.bodyMedium),
                ),
                SizedBox(
                  width: 110,
                  child: _PercentField(
                    controller: _courier,
                    onChanged: _changed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Dispetcher ulushi',
            subtitle: 'Buyurtma qabul qilgan (yaratgan) xodim uchun',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<DispatcherMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in DispatcherMode.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _dispatcher.clear();
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _mode == DispatcherMode.percent
                      ? 'Yaratgan buyurtmasi mijozga topshirilganda, '
                          'buyurtmaning yakuniy narxidan foiz.'
                      : 'Har bir yaratgan buyurtmasi uchun qat\'iy summa — '
                          'buyurtma yaratilgan kuni yoziladi. Buyurtma '
                          'o\'chirilsa, qaytarib olinadi.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _mode == DispatcherMode.percent
                    ? _PercentField(
                        controller: _dispatcher,
                        onChanged: _changed,
                        label: 'Foiz',
                      )
                    : MoneyField(
                        controller: _dispatcher,
                        label: 'Har buyurtmaga',
                        onChanged: _changed,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRateCard extends StatelessWidget {
  const _ProductRateCard({
    required this.product,
    required this.field,
    required this.onChanged,
  });

  final Product product;
  final TextEditingController Function(String key) field;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;
    final unit = rateUnitLabel(p);
    final twoSizes = p.method == CalculationMethod.kichikKatta;

    Widget pair(String a, String labelA, String b, String labelB) => Row(
          children: [
            Expanded(
              child: MoneyField(
                controller: field('${p.id}/$a'),
                label: labelA,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneyField(
                controller: field('${p.id}/$b'),
                label: labelB,
                onChanged: onChanged,
              ),
            ),
          ],
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: p.method.icon,
                tone: StageTone.washing,
                size: 34,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              TonePill(
                label: twoSizes ? 'kichik / katta' : '1 $unit uchun',
                tone: StageTone.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (twoSizes) ...[
            Text('Yuvish', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            pair('washSmall', 'Kichik', 'washLarge', 'Katta'),
            const SizedBox(height: 10),
            Text('Qadoqlash', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            pair('packSmall', 'Kichik', 'packLarge', 'Katta'),
          ] else
            pair('wash', 'Yuvish', 'pack', 'Qadoqlash'),
        ],
      ),
    );
  }
}

class _PercentField extends StatelessWidget {
  const _PercentField({
    required this.controller,
    required this.onChanged,
    this.label,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(5),
      ],
      textAlign: TextAlign.end,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFeatures: AppFonts.tabular,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label == null ? null : t(label!),
        hintText: '0',
        suffixText: '%',
      ),
    );
  }
}
