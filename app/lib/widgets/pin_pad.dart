import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// PIN-kod kiritish uchun raqamli klaviatura + nuqta indikatori.
///
/// PIN uzunligi 4 dan 8 gacha bo'lishi mumkin (server ham shu oraliqni
/// qabul qiladi). Shu sabab "kiritildi" degan qarorni pad o'zi qabul qila
/// olmaydi:
///
///  * [minLength] ga yetguncha tasdiqlash tugmasi o'chiq turadi
///  * [maxLength] ga yetganda avtomatik yuboriladi (odatiy 4 xonali PIN
///    uchun eski, bir qadamli tajriba saqlanadi)
///  * oraliqda esa foydalanuvchi tugmani bosib tasdiqlaydi
///
/// Xatolikdan so'ng tashqaridan [PinPadState.clear] orqali tozalanadi.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.minLength = 4,
    this.maxLength = 8,
    this.submitLabel = 'Kirish',
  });

  final ValueChanged<String> onCompleted;
  final int minLength;
  final int maxLength;
  final String submitLabel;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _value = '';

  void clear() => setState(() => _value = '');

  bool get _canSubmit => _value.length >= widget.minLength;

  void _onDigit(String d) {
    if (_value.length >= widget.maxLength) return;
    setState(() => _value += d);
    // Eng ko'p ishlatiladigan holat - 4 xonali PIN. Uzunligi chegaraga
    // yetganda tugma bosishni kutmaymiz.
    if (_value.length == widget.maxLength) _submit();
  }

  void _onBackspace() {
    if (_value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onCompleted(_value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kiritilgan raqamlar soni - `maxLength` ta bo'sh katak chizish
        // o'rniga faqat kiritilganini ko'rsatamiz, chunki PIN uzunligi
        // oldindan noma'lum.
        SizedBox(
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.maxLength; i++)
                if (i < _value.length || i < widget.minLength)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _value.length
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: i < _value.length
                            ? AppColors.primary
                            : context.colorBorder,
                        width: 1.6,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PinGrid(onDigit: _onDigit, onBackspace: _onBackspace),
        const SizedBox(height: 12),
        SizedBox(
          width: 232,
          child: ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}

class _PinGrid extends StatelessWidget {
  const _PinGrid({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 56);
              }
              final isBackspace = key == '⌫';
              return SizedBox(
                width: 72,
                height: 56,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isBackspace ? onBackspace : () => onDigit(key),
                    child: Center(
                      child: isBackspace
                          ? const Icon(Icons.backspace_outlined, size: 20)
                          : Text(
                              key,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
