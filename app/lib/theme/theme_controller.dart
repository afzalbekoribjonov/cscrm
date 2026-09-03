import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kun/tun rejimini qurilma sozlamasidan mustaqil boshqaradi - ilova
/// ichidagi tugma orqali almashtiriladi va qurilmada saqlanadi.
/// Standart qiymat - kun (yorug') rejimi.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);

  static final ThemeController instance = ThemeController._();

  static const _kThemeMode = 'theme_mode';

  bool get isDark => value == ThemeMode.dark;

  /// Ilova ishga tushganda oxirgi tanlangan rejimni tiklaydi.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_kThemeMode) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {
      // Saqlangan qiymatni o'qib bo'lmasa standart (kun) rejimida qolamiz.
    }
  }

  Future<void> toggle() async {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeMode, isDark ? 'dark' : 'light');
    } catch (_) {
      // Saqlanmasa ham joriy sessiyada rejim ishlayveradi.
    }
  }
}
