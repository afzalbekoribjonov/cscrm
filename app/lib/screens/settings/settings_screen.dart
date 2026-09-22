import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/logout_action.dart';
import 'change_account_pin_screen.dart';
import 'set_app_pin_screen.dart';
import 'widgets/settings_group.dart';

/// Sozlamalar.
///
/// Bu yerga ilgari har bir ekranning yuqori o'ng burchagida turgan
/// narsalar yig'ildi: kun/tun tugmasi va chiqish. Ular har ekranda
/// takrorlanib, asosiy ish tugmalari bilan joy talashardi — vaholanki
/// ularga kuniga bir marta ham tegilmaydi.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.lock});

  /// Sinovda almashtirish uchun. Odatda `null`.
  final AppLockService? lock;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _lock = widget.lock ?? AppLockService.instance;

  /// Sessiya SHU YERDA o'qiladi, tashqaridan berilmaydi.
  ///
  /// Aks holda uni to'rtta ish ekrani orqali shu tugmagacha
  /// uzatish kerak bo'lardi — ular esa sessiya haqida hech narsa
  /// bilmaydi va bilishi ham shart emas.
  Session _session = const Session.none();

  var _lockEnabled = false;
  var _biometricsEnabled = false;
  var _biometricsAvailable = false;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService().loadSession();
    final enabled = await _lock.isEnabled();
    final bio = await _lock.biometricsEnabled();
    final available = await _lock.biometricsAvailable();
    if (!mounted) return;
    setState(() {
      _session = session;
      _lockEnabled = enabled;
      _biometricsEnabled = bio;
      _biometricsAvailable = available;
      _loaded = true;
    });
  }

  // -------------------------------------------------------------------
  // Qulf
  // -------------------------------------------------------------------

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final set = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SetAppPinScreen(service: widget.lock),
        ),
      );
      if (set == true) await _load();
      return;
    }

    // O'chirishda tasdiqlash so'raladi: bu himoyani olib tashlaydi va
    // tasodifan bosilishi mumkin.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN-kodni o\'chirish'),
        content: const Text('Ilova PIN-kodsiz ochiladigan bo\'ladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _lock.disable();
    await _load();
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (on) {
      // Yoqishdan oldin bir marta tekshiramiz: qurilmada barmoq izi
      // sozlanmagan bo'lsa, kalit yoniq turib ishlamasdi.
      final result = await _lock.authenticateBiometric();
      if (result != BiometricResult.ok) {
        // Sababi bor bo'lsa aytiladi. Ilgari kalit JIMGINA qaytib
        // tushardi va foydalanuvchi nima bo'lganini bilolmasdi.
        final message = result.message;
        if (message != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    await _lock.setBiometrics(on);
    await _load();
  }

  Future<void> _changeAccountPin() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ChangeAccountPinScreen()),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN-kod o\'zgartirildi'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // -------------------------------------------------------------------
  // Ko'rinish
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isEmployee = session.employeeId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Sessiya hali o'qilmagan bo'lsa guruh umuman
            // ko'rsatilmaydi — bo'sh qator 'nimadir buzilgan' degan
            // taassurot qoldiradi.
            if ((session.displayName ?? '').isNotEmpty)
              SettingsGroup(
                title: 'Hisob',
                children: [
                  SettingsTile(
                    icon: Icons.person_outline_rounded,
                    label: session.displayName!,
                    value: session.tenantName,
                  ),
                  if (isEmployee)
                    SettingsTile(
                      icon: Icons.password_rounded,
                      label: 'PIN-kodni o\'zgartirish',
                      onTap: _changeAccountPin,
                    ),
                ],
              ),
            const SizedBox(height: 22),

            SettingsGroup(
              title: 'Ilova',
              children: [
                // Mavzu `ValueNotifier` — o'zgarganda faqat SHU qator
                // qayta chiziladi, butun ekran emas.
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance,
                  builder: (context, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return SettingsTile(
                      icon: dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: 'Tungi rejim',
                      trailing: Switch(
                        value: dark,
                        onChanged: (_) => ThemeController.instance.toggle(),
                      ),
                    );
                  },
                ),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'PIN-kod bilan ochish',
                  trailing: Switch(
                    value: _lockEnabled,
                    onChanged: _loaded ? _toggleLock : null,
                  ),
                ),
                // Barmoq izi faqat IKKI shart bajarilganda ko'rinadi:
                // qurilma qo'llab-quvvatlasa va PIN o'rnatilgan bo'lsa.
                // U PIN o'rniga emas, PIN bilan BIRGA ishlaydi — barmoq
                // izi tanilmasa PIN qoladi.
                if (_biometricsAvailable && _lockEnabled)
                  SettingsTile(
                    icon: Icons.fingerprint_rounded,
                    label: 'Barmoq izi',
                    trailing: Switch(
                      value: _biometricsEnabled,
                      onChanged: _toggleBiometrics,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            Card(
              child: SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Chiqish',
                danger: true,
                // O'q belgisi ATAYLAB yo'q: bu boshqa ekranga o'tish
                // emas, amal — u tasdiqlash oynasini ochadi.
                trailing: const SizedBox.shrink(),
                onTap: () => confirmAndLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
