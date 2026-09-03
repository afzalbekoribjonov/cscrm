import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/api_client.dart';
import '../../services/license_service.dart';
import '../../theme/app_colors.dart';

final _money = NumberFormat.decimalPattern('uz');

/// "To'lov qildim" formasi.
///
/// To'lov usuli qo'lda karta o'tkazma — bank bizga xabar bermaydi. Shu
/// sabab mijozning o'zi qaysi rejaga, qancha va qaysi o'tkazma bilan
/// to'laganini aytishi kerak: aks holda super-admin bank ko'chirmasidagi
/// summani qaysi biznesniki ekanini taxmin qilishi kerak bo'lardi.
///
/// Natija: yuborilgan so'rov, yoki bekor qilinsa `null`.
Future<PaymentRequest?> showPaymentRequestSheet({
  required BuildContext context,
  required List<SubscriptionPlan> plans,
  SubscriptionPlan? initialPlan,
}) {
  return showModalBottomSheet<PaymentRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaymentRequestSheet(
      plans: plans,
      initialPlan: initialPlan,
    ),
  );
}

class _PaymentRequestSheet extends StatefulWidget {
  const _PaymentRequestSheet({required this.plans, this.initialPlan});

  final List<SubscriptionPlan> plans;
  final SubscriptionPlan? initialPlan;

  @override
  State<_PaymentRequestSheet> createState() => _PaymentRequestSheetState();
}

class _PaymentRequestSheetState extends State<_PaymentRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();

  late SubscriptionPlan? _plan = widget.initialPlan ?? widget.plans.firstOrNull;
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fillAmountFromPlan();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Narx belgilangan bo'lsa summani oldindan to'ldiramiz. Belgilanmagan
  /// bo'lsa (kelishiladigan narx) foydalanuvchi o'zi yozadi.
  void _fillAmountFromPlan() {
    final plan = _plan;
    if (plan == null || plan.priceUnset) {
      _amount.clear();
      return;
    }
    _amount.text = plan.price.round().toString();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final plan = _plan;
    if (plan == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final request = await LicenseService().submitPaymentRequest(
        planId: plan.id,
        amount: double.tryParse(_amount.text.trim()),
        reference: _reference.text,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(request);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'So\'rovni yuborib bo\'lmadi. Internetni tekshiring.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colorBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text('To\'lov haqida xabar berish',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Pulni o\'tkazganingizdan keyin shu formani to\'ldiring. '
                'Biz tekshirib, obunani uzaytiramiz.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _plan?.id,
                decoration: const InputDecoration(labelText: 'Qaysi reja'),
                items: [
                  for (final p in widget.plans)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.priceUnset
                            ? p.name
                            : '${p.name} — ${_money.format(p.price)} so\'m',
                      ),
                    ),
                ],
                onChanged: _sending
                    ? null
                    : (id) => setState(() {
                          _plan = widget.plans.firstWhere((p) => p.id == id);
                          _fillAmountFromPlan();
                        }),
                validator: (v) => v == null ? 'Rejani tanlang' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_sending,
                decoration: const InputDecoration(
                  labelText: 'To\'langan summa',
                  suffixText: 'so\'m',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Summani kiriting';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _reference,
                enabled: !_sending,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'O\'tkazma raqami',
                  helperText: 'Chekdagi raqam — to\'lovni tezroq topamiz',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _note,
                enabled: !_sending,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Izoh',
                  counterText: '',
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Yuborilmoqda...' : 'Yuborish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
