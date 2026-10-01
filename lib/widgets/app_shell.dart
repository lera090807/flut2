import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entity_kind.dart';
import '../repositories/shop_database.dart';
import '../core/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.local_offer_outlined,
    Icons.category_outlined,
    Icons.local_shipping_outlined,
    Icons.people_outline,
  ];
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = EntityKind.values.indexWhere(
      (k) => path.startsWith(k.path),
    );
    final index = selected < 0 ? 0 : selected;
    final width = MediaQuery.sizeOf(context).width;
    final database = context.watch<ShopDatabase>();
    void navigate(int i) => context.go(EntityKind.values[i].path);
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
      body: Column(
        children: [
          if (database.notice != null)
            MaterialBanner(
              content: Text(database.notice!),
              actions: [
                TextButton(
                  onPressed: database.dismissNotice,
                  child: const Text('Понятно'),
                ),
              ],
            ),
          Expanded(
            child: Row(
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
                    destinations: [
                      for (var i = 0; i < EntityKind.values.length; i++)
                        NavigationRailDestination(
                          icon: Icon(_icons[i]),
                          label: Text(EntityKind.values[i].label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: width < compactBreakpoint
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigate,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (var i = 0; i < EntityKind.values.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: EntityKind.values[i].label,
                  ),
              ],
            )
          : null,
    );
  }
}
