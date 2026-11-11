import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/work_section.dart';
import '../../ui/action_menu.dart';
import '../../ui/surfaces.dart';
import '../../utils/order_sections.dart';
import '../../widgets/notification_action.dart';
import '../search/order_search_screen.dart';
import 'app_menu.dart';

/// Bo'lim sahifasining umumiy ramkasi.
///
/// Yuqorida: bo'lim nomi va qisqa holat, o'ng tomonda faqat uchta
/// tugma — qidiruv, xabarlar va "⋮" (qolgan hamma imkoniyat). Vakolat
/// bo'lmasa ichidagi ro'yxat o'rniga "Sizda vakolat mavjud emas"
/// ko'rinadi va qidiruv ham yashiriladi.
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.user,
    required this.section,
    required this.sections,
    required this.body,
    this.title,
    this.subtitle,
    this.bottom,
    this.floatingActionButton,
  });

  final AppUser user;
  final WorkSection section;
  final OrderSections sections;
  final Widget body;
  final String? title;
  final String? subtitle;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final allowed = user.access.has(section);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title ?? section.label, style: theme.textTheme.headlineSmall),
            if (allowed && subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(subtitle!, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
        actions: [
          if (allowed)
            IconButton(
              tooltip: t('Qidiruv'),
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OrderSearchScreen(
                  sections: sections,
                  user: user,
                  section: section,
                ),
              )),
            ),
          const NotificationAction(),
          MoreButton(onPressed: () => openAppMenu(context, user)),
          const SizedBox(width: 4),
        ],
        bottom: allowed ? bottom : null,
      ),
      body: allowed ? body : const NoAccessView(),
      floatingActionButton: allowed ? floatingActionButton : null,
    );
  }
}
