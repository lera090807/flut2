import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = path.startsWith('/brands') ? 1 : 0;
    final width = MediaQuery.sizeOf(context).width;
    void navigate(int i) => context.go(i == 0 ? '/products' : '/brands');
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, color: Color(0xFF805266)),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Магазин косметики',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          if (width >= compactBreakpoint) ...[
            NavigationRail(
              extended: width >= 1200,
              backgroundColor: const Color(0xFFFAF8F6),
              selectedIndex: index,
              onDestinationSelected: navigate,
              labelType: width >= 1200
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Товары'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.local_offer_outlined),
                  selectedIcon: Icon(Icons.local_offer),
                  label: Text('Бренды'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: width < compactBreakpoint
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: 'Товары',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_offer_outlined),
                  label: 'Бренды',
                ),
              ],
            )
          : null,
    );
  }
}
