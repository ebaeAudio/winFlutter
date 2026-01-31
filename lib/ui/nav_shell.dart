import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/user_settings.dart';
import 'components/corner_nav_bubble_bar.dart';
import 'spacing.dart';

class NavShell extends ConsumerWidget {
  const NavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;
  static const double navBarHeight = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsControllerProvider);
    final oneHandEnabled = settings.oneHandModeEnabled;
    final hand = settings.oneHandModeHand;

    const destinations = [
      CornerNavBubbleDestination(
        icon: Icons.check_circle_outline,
        label: 'Tasks',
      ),
      CornerNavBubbleDestination(icon: Icons.today, label: 'Now'),
      CornerNavBubbleDestination(icon: Icons.lock, label: 'Dumb'),
      CornerNavBubbleDestination(icon: Icons.settings, label: 'Settings'),
    ];

    return Scaffold(
      body: oneHandEnabled
          ? Stack(
              children: [
                navigationShell,
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s8),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: hand == OneHandModeHand.left
                          ? Alignment.bottomLeft
                          : Alignment.bottomRight,
                      child: CornerNavBubbleBar(
                        destinations: destinations,
                        selectedIndex: navigationShell.currentIndex,
                        corner: hand == OneHandModeHand.left
                            ? Corner.bottomLeft
                            : Corner.bottomRight,
                        onSelected: (index) {
                          navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == navigationShell.currentIndex,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            )
          : navigationShell,
      bottomNavigationBar: oneHandEnabled
          ? null
          : NavigationBar(
              height: navBarHeight,
              selectedIndex: navigationShell.currentIndex,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  label: 'Tasks',
                ),
                NavigationDestination(icon: Icon(Icons.today), label: 'Now'),
                NavigationDestination(icon: Icon(Icons.lock), label: 'Dumb'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              onDestinationSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
    );
  }
}
