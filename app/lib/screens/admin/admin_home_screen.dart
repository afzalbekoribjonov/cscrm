import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/license_status.dart';
import '../../models/staff_access.dart';
import '../../services/license_controller.dart';
import '../../services/license_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/subscription_view.dart';
import '../home/app_menu.dart';
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

/// Boshqaruv paneli — biznesni sozlash va boshqarish bo'limlari.
///
/// Ilgari tepada 3 ta statistika kartasi turardi va ular uchun har
/// ochilishda bugungi buyurtmalar QAYTA so'ralardi (bosh sahifa ularni
/// allaqachon ko'rsatadi). Endi panel faqat bo'limlar ro'yxati — hech
/// qanday qo'shimcha so'rov yo'q.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  var _businessName = '';

  @override
  void initState() {
    super.initState();
    SessionService().loadSession().then((session) {
      if (mounted) setState(() => _businessName = session.tenantName ?? '');
    });
  }

  void _push(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    const admin = StaffAccess.admin();
    return Scaffold(
      appBar: AppBar(title: const Text('Boshqaruv paneli')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            Gap.page, 4, Gap.page, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          ValueListenableBuilder<LicenseResolution?>(
            valueListenable: LicenseController.instance,
            builder: (context, resolution, _) => _BusinessCard(
              name: _businessName,
              status: resolution?.status,
              onOpen: () => _push((_) => ProfileScreen(businessName: _businessName)),
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Biznes',
            children: [
              SettingsTile(
                icon: Icons.storefront_outlined,
                label: 'Profilim',
                value: 'Tarif, obuna muddati va to\'lovlar',
                onTap: () => _push((_) => ProfileScreen(businessName: _businessName)),
              ),
              SettingsTile(
                icon: Icons.gavel_rounded,
                tone: StageTone.packaging,
                label: 'Ilova qonuniyatlari',
                value: 'Topshirish muddati, omborxona, majburiy qadamlar',
                onTap: () => _push((_) => const PoliciesScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Jamoa va xizmatlar',
            children: [
              SettingsTile(
                icon: Icons.groups_outlined,
                tone: StageTone.info,
                label: 'Xodimlar',
                value: 'Qo\'shish, vakolatlar, faoliyat',
                onTap: () => _push((_) => const EmployeesListScreen()),
              ),
              SettingsTile(
                icon: Icons.local_laundry_service_outlined,
                tone: StageTone.washing,
                label: 'Xizmatlar va narxlar',
                value: 'Gilam, parda, ko\'rpa va boshqalar',
                onTap: () => _push((_) => const ProductsAdminScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Buyurtmalar va moliya',
            children: [
              SettingsTile(
                icon: Icons.calendar_month_outlined,
                tone: StageTone.brand,
                label: 'Buyurtmalar tarixi',
                value: 'Kalendar bo\'yicha barcha buyurtmalar',
                onTap: () => _push((_) => OrdersAdminScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                    )),
              ),
              SettingsTile(
                icon: Icons.insights_rounded,
                tone: StageTone.success,
                label: 'Hisobotlar',
                value: 'Tushum, xodimlar faolligi, hajm',
                onTap: () => _push((_) => IncomeActivityScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      access: admin,
                    )),
              ),
              SettingsTile(
                icon: Icons.receipt_long_outlined,
                tone: StageTone.danger,
                label: 'Chiqimlar',
                value: 'Oylar bo\'yicha sarflar',
                onTap: () => _push((_) => ExpensesScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                    )),
              ),
              SettingsTile(
                icon: Icons.request_quote_outlined,
                tone: StageTone.warning,
                label: 'Qarzdorlar',
                value: 'Oylar bo\'yicha to\'lanmagan summalar',
                onTap: () => _push((_) => DebtorsScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      access: admin,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: 'Hisob',
            children: [
              SettingsTile(
                icon: Icons.key_outlined,
                tone: StageTone.neutral,
                label: 'Login va parol',
                value: 'Boshqaruvchi hisobiga kirish ma\'lumotlari',
                onTap: () => _push((_) =>
                    AdminCredentialsScreen(currentLogin: widget.currentUserName)),
              ),
              SettingsTile(
                icon: Icons.settings_outlined,
                tone: StageTone.neutral,
                label: 'Sozlamalar',
                value: 'Yozuv, mavzu, ilova qulfi',
                onTap: () => _push((_) => const SettingsScreen()),
              ),
            ],
          ),
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
                    TonePill(label: view.label, tone: view.tone, dot: true, dense: true),
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
