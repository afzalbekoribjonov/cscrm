import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
    this.locked = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Bo'limdagi ish soni. Vakolat bo'lmasa ko'rsatilmaydi.
  final int badge;

  /// Vakolat yo'q — ikonka xira, ustida qulf.
  final bool locked;
}

/// Pastki menyu.
///
/// Material'ning `NavigationBar` i 5 tadan ortiq bo'limga mo'ljallanmagan:
/// tanlov belgisi 64 px eni bilan tor ekranda qo'shnisiga tegib qoladi.
/// Bu yerda belgi ixcham, yorliq esa kerak bo'lsa o'zi kichrayadi —
/// 6 ta bo'lim 320 px ekranda ham tartibli turadi.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        border: Border(top: BorderSide(color: context.colorBorder)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? context.colorPrimaryInk : context.colorTextSecondary;
    final d = destination;
    final icon = Icon(
      selected ? d.selectedIcon : d.icon,
      size: 23,
      color: d.locked ? context.colorTextTertiary : ink,
    );

    return Semantics(
      selected: selected,
      button: true,
      label: t(d.label),
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        containedInkWell: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 50 : 38,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? context.colorPrimarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Center(
                child: d.locked
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          icon,
                          Positioned(
                            right: -5,
                            bottom: -3,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: context.colorSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.lock_rounded,
                                  size: 11, color: context.colorTextTertiary),
                            ),
                          ),
                        ],
                      )
                    : Badge(
                        isLabelVisible: d.badge > 0,
                        offset: const Offset(8, -6),
                        label: Text(d.badge > 99 ? '99+' : '${d.badge}'),
                        child: icon,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  d.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 11.5,
                    height: 1.1,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: d.locked ? context.colorTextTertiary : ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
