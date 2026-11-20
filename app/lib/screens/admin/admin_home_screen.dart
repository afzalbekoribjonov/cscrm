import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/license_status.dart';
import '../../services/license_controller.dart';
import '../../services/license_service.dart';
import '../../services/live_sections.dart';
import '../../services/policy_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/order_sections.dart';
import '../../utils/subscription_view.dart';
import '../home/app_menu.dart';
import '../payroll/payroll_screen.dart';
import '../payroll/payroll_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/widgets/settings_group.dart';
import 'admin_credentials_screen.dart';
import 'debtors_screen.dart';
import 'employees_list_screen.dart';
import 'expenses_screen.dart';
import 'income_activity_screen.dart';
import 'orders_admin_screen.dart';
import 'policies_screen.dart';
import 'products_admin_screen.dart';
import 'profile_screen.dart';

/// Boshqaruv paneli — biznesni boshqarishning BARCHA bo'limlari, to'liq
/// sahifada, mavzular bo'yicha guruhlangan plitkalar ko'rinishida.
///
/// Boshqaruvchi uni har bir bo'lim tepasidagi boshqaruv belgisidan
/// BIR bosishda ochadi (ilgari "⋮" menyu → "Boshqaruv paneli" — ikki
/// qadam edi). Har bir plitka o'z sahifasini ochadi: hammasi bitta
/// sahifaga tiqilmaydi.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  var _businessName = '';

  @override
  void initState() {
    super.initState();
    _businessName = widget.user.businessName;
    SessionService().loadSession().then((session) {
      final name = session.tenantName ?? '';
      if (mounted && name.isNotEmpty) setState(() => _businessName = name);
    }).catchError((Object _) {});
  }

  void _push(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Boshqaruv paneli')),
      body: ValueListenableBuilder<OrderSections>(
        valueListenable: LiveSections.instance,
        builder: (context, sections, _) {
          final warehouseOn = PolicyCenter.instance.value.warehouseEnabled;
          final inWarehouse = sections.warehouse.length;
          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 32 + bottom),
            children: [
              ValueListenableBuilder<LicenseResolution?>(
                valueListenable: LicenseController.instance,
                builder: (context, resolution, _) => _BusinessCard(
                  name: _businessName,
                  status: resolution?.status,
                  onOpen: () => _push(
                      (_) => ProfileScreen(businessName: _businessName)),
                ),
              ),
              const SizedBox(height: 22),
              _HubSection(
                title: 'Moliya',
                tiles: [
                  _HubTile(
                    icon: Icons.insights_rounded,
                    tone: StageTone.success,
                    label: 'Hisobotlar',
                    caption: 'Sof foyda va tushum',
                    onTap: () => _push((_) => IncomeActivityScreen(
                          currentUserId: user.id,
                          currentUserName: user.name,
                          access: user.access,
                        )),
                  ),
                  _HubTile(
                    icon: Icons.payments_rounded,
                    tone: StageTone.brand,
                    label: 'Maosh',
                    caption: 'Ishbayi, oylik, avans',
                    onTap: () => _push((_) => PayrollScreen(user: user)),
                  ),
                  _HubTile(
                    icon: Icons.receipt_long_rounded,
                    tone: StageTone.danger,
                    label: 'Chiqimlar',
                    caption: 'Kalendar bo\'yicha',
                    onTap: () => _push((_) => ExpensesScreen(
                          currentUserId: user.id,
                          currentUserName: user.name,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _HubSection(
                title: 'Buyurtmalar',
                tiles: [
                  _HubTile(
                    icon: Icons.calendar_month_rounded,
                    tone: StageTone.info,
                    label: 'Buyurtmalar tarixi',
                    caption: 'Kun bo\'yicha',
                    onTap: () => _push((_) => OrdersAdminScreen(
                          currentUserId: user.id,
                          currentUserName: user.name,
                        )),
                  ),
                  _HubTile(
                    icon: Icons.request_quote_rounded,
                    tone: StageTone.warning,
                    label: 'Qarzdorlar',
                    caption: 'To\'lanmagan summalar',
                    onTap: () => _push((_) => DebtorsScreen(
                          currentUserId: user.id,
                          currentUserName: user.name,
                          access: user.access,
                        )),
                  ),
                  if (warehouseOn)
                    _HubTile(
                      icon: Icons.warehouse_rounded,
                      tone: StageTone.warehouse,
                      label: 'Omborxona',
                      caption: inWarehouse == 0
                          ? 'Bo\'sh'
                          : '$inWarehouse ta buyurtma',
                      badge: inWarehouse,
                      onTap: () => openWarehouse(context, user),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              _HubSection(
                title: 'Jamoa va xizmatlar',
                tiles: [
                  _HubTile(
                    icon: Icons.groups_rounded,
                    tone: StageTone.info,
                    label: 'Xodimlar',
                    caption: 'Vakolat va faoliyat',
                    onTap: () => _push((_) => const EmployeesListScreen()),
                  ),
                  _HubTile(
                    icon: Icons.local_laundry_service_rounded,
                    tone: StageTone.washing,
                    label: 'Xizmatlar va narxlar',
                    caption: 'Gilam, parda, ko\'rpa',
                    onTap: () => _push((_) => const ProductsAdminScreen()),
                  ),
                  _HubTile(
                    icon: Icons.tune_rounded,
                    tone: StageTone.packaging,
                    label: 'Maosh sozlamasi',
                    caption: 'Ishbayi narxlari, ulushlar',
                    onTap: () => _push((_) => const PayrollSettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SettingsGroup(
                title: 'Biznes va hisob',
                children: [
                  SettingsTile(
                    icon: Icons.storefront_rounded,
                    label: 'Profilim',
                    value: 'Tarif, obuna muddati va to\'lov',
                    onTap: () => _push(
                        (_) => ProfileScreen(businessName: _businessName)),
                  ),
                  SettingsTile(
                    icon: Icons.gavel_rounded,
                    tone: StageTone.packaging,
                    label: 'Ilova qonuniyatlari',
                    value: 'Majburiy qadamlar, muddat, omborxona',
                    onTap: () => _push((_) => const PoliciesScreen()),
                  ),
                  SettingsTile(
                    icon: Icons.key_rounded,
                    tone: StageTone.neutral,
                    label: 'Login va parol',
                    value: 'Boshqaruvchi hisobiga kirish',
                    onTap: () => _push((_) =>
                        AdminCredentialsScreen(currentLogin: user.name)),
                  ),
                  SettingsTile(
                    icon: Icons.settings_rounded,
                    tone: StageTone.neutral,
                    label: 'Sozlamalar',
                    value: 'Yozuv, mavzu, ilova qulfi',
                    onTap: () => _push((_) => const SettingsScreen()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Guruh: sarlavha va plitkalar to'ri (telefonda 3 ustun, keng ekranda 4).
class _HubSection extends StatelessWidget {
  const _HubSection({required this.title, required this.tiles});

  final String title;
  final List<_HubTile> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.colorTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 3;
            const gap = 10.0;
            final rows = <List<_HubTile>>[
              for (var i = 0; i < tiles.length; i += columns)
                tiles.sublist(i, (i + columns).clamp(0, tiles.length)),
            ];
            return Column(
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: gap),
                  // Bir qatordagi plitkalar BIR XIL balandlikda — matni
                  // ikki qatorga tushgani ham, bir qatorligi ham.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columns; c++) ...[
                          if (c > 0) const SizedBox(width: gap),
                          Expanded(
                            child: c < rows[r].length
                                ? rows[r][c]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.tone,
    required this.label,
    required this.onTap,
    this.caption,
    this.badge = 0,
  });

  final IconData icon;
  final StageTone tone;
  final String label;
  final String? caption;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            label: Text('$badge'),
            isLabelVisible: badge > 0,
            backgroundColor: tone.fill,
            child: IconTile(icon: icon, tone: tone, size: 46, radius: 14),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(height: 1.2),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
            ),
          ],
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.name,
    required this.status,
    required this.onOpen,
  });

  final String name;
  final LicenseStatus? status;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = subscriptionView(status);
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(initials: initialsOf(name), size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Biznes' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TonePill(
                        label: view.label, tone: view.tone, dot: true, dense: true),
                    if (view.remaining != null)
                      Text(
                        view.ended ? view.remaining! : 'Qoldi: ${view.remaining}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
        ],
      ),
    );
  }
}
