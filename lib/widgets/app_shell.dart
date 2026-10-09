import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entity_kind.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../state/navigation_guard.dart';
import '../repositories/shop_database.dart';
import '../core/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier?>(),
        database = context.watch<ShopDatabase?>();
    final role = auth?.displayRole;
    final entries = <({String path, String title, IconData icon})>[
      for (final k in EntityKind.values)
        if (role != Role.customer ||
            [
              EntityKind.products,
              EntityKind.brands,
              EntityKind.categories,
            ].contains(k))
          (
            path: k.path,
            title: k.label,
            icon: switch (k) {
              EntityKind.products => Icons.inventory_2_outlined,
              EntityKind.brands => Icons.local_offer_outlined,
              EntityKind.categories => Icons.category_outlined,
              EntityKind.suppliers => Icons.local_shipping_outlined,
              _ => Icons.people_outline,
            },
          ),
      if (role == Role.customer) ...[
        (path: '/account', title: 'Личный кабинет', icon: Icons.person_outline),
        (
          path: '/my-orders',
          title: 'Мои заказы',
          icon: Icons.shopping_bag_outlined,
        ),
      ],
      if (role == Role.staff)
        (
          path: '/orders',
          title: 'Обработка заказов',
          icon: Icons.receipt_long_outlined,
        ),
      if (role == Role.admin)
        (
          path: '/admin',
          title: 'Пользователи',
          icon: Icons.admin_panel_settings_outlined,
        ),
    ];
    final current = GoRouterState.of(context).uri.path;
    final selected = entries.indexWhere((e) => current.startsWith(e.path));
    final width = MediaQuery.sizeOf(context).width;
    void go(int index) => context.go(entries[index].path);
    Future<void> logout() async {
      if (await context.read<NavigationGuard>().allowExit()) {
        await auth?.logout();
      }
    }

    final navigation = [
      for (final e in entries)
        NavigationRailDestination(icon: Icon(e.icon), label: Text(e.title)),
    ];
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
        actions: [
          if (auth?.user != null) ...[
            if (width >= 700)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${auth!.user!.fullName}\n${role!.label}',
                  textAlign: TextAlign.end,
                ),
              ),
            IconButton(
              tooltip: 'Выйти',
              onPressed: logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ],
      ),
      drawer: width < compactBreakpoint
          ? Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    if (auth?.user != null)
                      ListTile(
                        title: Text(auth!.user!.fullName),
                        subtitle: Text(role!.label),
                      ),
                    for (var i = 0; i < entries.length; i++)
                      ListTile(
                        leading: Icon(entries[i].icon),
                        title: Text(entries[i].title),
                        selected: i == selected,
                        onTap: () {
                          Navigator.pop(context);
                          go(i);
                        },
                      ),
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: width < compactBreakpoint && entries.length <= 5
          ? NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: go,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: [
                for (final e in entries)
                  NavigationDestination(icon: Icon(e.icon), label: e.title),
              ],
            )
          : null,
      body: Column(
        children: [
          if (database?.notice != null)
            MaterialBanner(
              content: Text(database!.notice!),
              actions: [
                TextButton(
                  onPressed: database.dismissNotice,
                  child: const Text('Понятно'),
                ),
              ],
            ),
          if (auth?.warningSeconds != null)
            MaterialBanner(
              content: Text(
                'Вы давно ничего не делали. Выход через ${auth!.warningSeconds} с.',
              ),
              actions: [
                TextButton(
                  onPressed: auth.activity,
                  child: const Text('Продолжить работу'),
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
                    selectedIndex: selected < 0 ? null : selected,
                    onDestinationSelected: go,
                    labelType: width >= 1200
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: navigation,
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
