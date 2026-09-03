import 'package:flutter/material.dart';

/// AppBar sarlavhasi + tagida joriy xodim ismi - har doim yuqorida
/// ko'rinib turishi uchun barcha asosiy ekranlarda ishlatiladi.
class EmployeeAppBarTitle extends StatelessWidget {
  const EmployeeAppBarTitle({
    super.key,
    required this.title,
    required this.employeeName,
  });

  final String title;
  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(
          'Xodim: $employeeName',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
