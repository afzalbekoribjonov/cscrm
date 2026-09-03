import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../utils/phone.dart';
import '../../widgets/required_label.dart';

class EmployeeFormScreen extends StatefulWidget {
  const EmployeeFormScreen({super.key, this.employee});

  /// null bo'lsa - yangi xodim qo'shish, aks holda tahrirlash.
  final Employee? employee;

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstNameCtrl =
      TextEditingController(text: widget.employee?.firstName ?? '');
  late final _lastNameCtrl =
      TextEditingController(text: widget.employee?.lastName ?? '');
  late final _phoneCtrl = TextEditingController(
    text: widget.employee == null
        ? ''
        : formatPhoneForDisplay(widget.employee!.phone),
  );
  final _pinCtrl = TextEditingController();
  final _service = EmployeeService();

  late bool _active = widget.employee?.active ?? true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.employee != null;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final id = widget.employee!.id;
        await _service.updateEmployee(
          id: id,
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
        );
        // PIN alohida yo'l bilan o'zgaradi: hash faqat serverda
        // hisoblanadi, shuning uchun uni bazaga to'g'ridan-to'g'ri
        // yozib bo'lmaydi.
        if (_pinCtrl.text.isNotEmpty) {
          await _service.setPin(id: id, pin: _pinCtrl.text);
        }
        if (_active != widget.employee!.active) {
          await _service.setActive(id, _active);
        }
      } else {
        await _service.createEmployee(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          phone: _phoneCtrl.text,
          pin: _pinCtrl.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on EmployeeServiceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Kutilmagan xatolik. Qayta urining.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEdit ? 'Xodimni tahrirlash' : 'Yangi xodim'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _firstNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(label: requiredLabel('Ism')),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Ismni kiriting' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(label: requiredLabel('Familiya')),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Familiyani kiriting'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  // Telefon raqami xodimni tizimda topish kaliti — u orqali
                  // qaysi biznesga tegishli ekani aniqlanadi. Uni almashtirish
                  // serverdagi indeksni qayta yozishni talab qiladi, shuning
                  // uchun tahrirlashda o'zgartirilmaydi (aks holda maydon
                  // tahrirlanadigandek ko'rinib, saqlanmay qolardi).
                  readOnly: _isEdit,
                  enabled: !_isEdit,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  decoration: InputDecoration(
                    label: requiredLabel('Telefon raqami'),
                    hintText: '+998 90 123 45 67',
                    helperText: _isEdit
                        ? 'Raqamni o\'zgartirib bo\'lmaydi'
                        : null,
                  ),
                  validator: (v) {
                    if (!isCompletePhone(v ?? '')) {
                      return 'Telefon raqamini to\'liq kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    label: _isEdit
                        ? const Text('Yangi PIN-kod')
                        : requiredLabel('PIN-kod'),
                    hintText: '4-8 xonali raqam',
                    counterText: '',
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    // Server 4-8 xona qabul qiladi. Uzunroq PIN sezilarli
                    // darajada xavfsizroq: 4 xonada 10 000 ta variant bor,
                    // 6 xonada esa million.
                    if (!_isEdit && value.length < 4) {
                      return 'Kamida 4 xonali PIN kiriting';
                    }
                    if (value.isNotEmpty && value.length < 4) {
                      return 'Kamida 4 xonali bo\'lishi kerak';
                    }
                    return null;
                  },
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Faol'),
                    subtitle: const Text('Nofaol xodim tizimga kira olmaydi'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEdit ? 'Saqlash' : 'Qo\'shish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
