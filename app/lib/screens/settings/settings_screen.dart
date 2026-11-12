import 'package:flutter/material.dart' hide Text;
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/script.dart';
import '../../l10n/text.dart';
import '../../services/app_lock_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../ui/sheets.dart';
import '../../widgets/logout_action.dart';
import 'change_account_pin_screen.dart';
import 'set_app_pin_screen.dart';
import 'widgets/account_header.dart';
import 'widgets/settings_group.dart';

/// Ilova sozlamalari: yozuv (lotin/kirill), mavzu, xavfsizlik va hisob.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.lock});

  /// Sinovda o'rniga soxta xizmat beriladi.
  final AppLockService? lock;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _lock = widget.lock ?? AppLockService.instance;

  Session _session = const Session.none();
  var _lockEnabled = false;
  var _biometricsEnabled = false;
  var _biometricsAvailable = false;
  var _loaded = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadVersion();
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

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // Versiya ko'rinmasa ham sozlamalar ishlayveradi.
    }
  }

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final set = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SetAppPinScreen(service: widget.lock)),
      );
      if (set == true) await _load();
      return;
    }
    // O'chirish himoyani olib tashlaydi — tasdiq so'raladi.
    final ok = await confirmAction(
      context,
      title: 'Ilova qulfini o\'chirish',
      message: 'Ilova PIN-kodsiz ochiladigan bo\'ladi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
      icon: Icons.lock_open_rounded,
    );
    if (!ok) return;
    await _lock.disable();
    await _load();
  }

  Future<void> _toggleBiometrics(bool on) async {
    if (on) {
      // Yoqishdan oldin bir marta tekshiriladi: qurilmada barmoq izi
      // sozlanmagan bo'lsa, kalit yoniq turib ishlamasdi.
      final result = await _lock.authenticateBiometric();
      if (result != BiometricResult.ok) {
        final message = result.message;
        if (message != null && mounted) showResult(context, message, error: true);
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
    if (changed == true && mounted) showResult(context, 'PIN-kod o\'zgartirildi');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmployee = _session.employeeId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            Gap.page, 4, Gap.page, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          // Sessiya o'qilmaguncha ko'rsatilmaydi — bo'sh ism "nimadir
          // buzilgan" degan taassurot qoldiradi.
          if (_loaded) AccountHeader(session: _session),
          const SizedBox(height: 24),

          SettingsGroup(
            title: 'Yozuv',
            footer: 'Ilovadagi barcha yozuvlar, kalendar va xabarlar tanlangan '
                'yozuvda ko\'rinadi.',
            children: [
              ValueListenableBuilder<UzScript>(
                valueListenable: ScriptController.instance,
                builder: (context, script, _) => ChoiceCards<UzScript>(
                  value: script,
                  onChanged: ScriptController.instance.set,
                  options: const [
                    ChoiceOption(
                      value: UzScript.latin,
                      title: 'O‘zbekcha',
                      subtitle: 'Lotin yozuvi',
                      icon: Icons.translate_rounded,
                      verbatim: true,
                    ),
                    ChoiceOption(
                      value: UzScript.cyrillic,
                      title: 'Ўзбекча',
                      subtitle: 'Кирилл ёзуви',
                      icon: Icons.translate_rounded,
                      verbatim: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SettingsGroup(
            title: 'Ko\'rinish',
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) => ChoiceCards<ThemeMode>(
                  value: mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
                  onChanged: ThemeController.instance.setMode,
                  options: const [
                    ChoiceOption(
                      value: ThemeMode.light,
                      title: 'Kunduzgi',
                      subtitle: 'Yorug\' fon',
                      icon: Icons.light_mode_outlined,
                    ),
                    ChoiceOption(
                      value: ThemeMode.dark,
                      title: 'Tungi',
                      subtitle: 'Ko\'zni toliqtirmaydi',
                      icon: Icons.dark_mode_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SettingsGroup(
            title: 'Xavfsizlik',
            children: [
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'Ilova qulfi',
                value: _lockEnabled
                    ? 'Yoqilgan — ochishda PIN so\'raladi'
                    : 'O\'chirilgan',
                trailing: Switch(
                  value: _lockEnabled,
                  onChanged: _loaded ? _toggleLock : null,
                ),
              ),
              // Barmoq izi PIN o'rniga emas, PIN bilan BIRGA ishlaydi —
              // tanilmasa PIN qoladi.
              if (_biometricsAvailable && _lockEnabled)
                SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  tone: StageTone.success,
                  label: 'Barmoq izi',
                  value: _biometricsEnabled
                      ? 'Yoqilgan'
                      : 'PIN o\'rniga tezroq ochish',
                  trailing: Switch(
                    value: _biometricsEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                ),
              if (isEmployee)
                SettingsTile(
                  icon: Icons.password_rounded,
                  tone: StageTone.info,
                  label: 'Kirish PIN-kodi',
                  value: 'Tizimga kirishda ishlatiladigan kod',
                  onTap: _changeAccountPin,
                ),
            ],
          ),
          const SizedBox(height: 24),

          SettingsGroup(
            title: 'Hisob',
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Tizimdan chiqish',
                danger: true,
                trailing: const SizedBox.shrink(),
                onTap: () => confirmAndLogout(context),
              ),
            ],
          ),

          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Text.verbatim(
                  'CSCRM',
                  style: TextStyle(
                    fontFamily: 'CscrmLogo',
                    fontSize: 18,
                    letterSpacing: 1.2,
                    color: context.colorTextTertiary,
                  ),
                ),
                if (_version.isNotEmpty)
                  Text('Versiya $_version', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
