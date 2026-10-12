import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/auth_notifier.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier?>();
    final customer = auth?.displayRole == Role.customer;
    final categories = const [
      (Icons.face_retouching_natural, 'Уход за лицом', 1),
      (Icons.brush_outlined, 'Макияж', 2),
      (Icons.self_improvement_outlined, 'Уход за телом', 3),
      (Icons.content_cut_outlined, 'Уход за волосами', 4),
      (Icons.wb_sunny_outlined, 'Защита от солнца', 5),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF805266), Color(0xFFB47A91)],
              ),
            ),
            child: Wrap(
              spacing: 32,
              runSpacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добро пожаловать, ${auth?.user?.fullName ?? 'пользователь'}!',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        customer
                            ? 'Косметика для ухода и макияжа в одном каталоге.'
                            : 'Управление каталогом магазина косметики.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF805266),
                        ),
                        onPressed: () => context.go('/products'),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Открыть каталог'),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.spa_outlined,
                  size: 110,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Категории', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final category in categories)
                SizedBox(
                  width: 210,
                  height: 130,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () =>
                          context.go('/products?categoryId=${category.$3}'),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(category.$1, color: const Color(0xFF805266)),
                            Text(
                              category.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
