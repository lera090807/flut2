import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/catalog_entity.dart';
import '../models/product.dart';
import '../models/brand.dart';
import '../state/detail_notifier.dart';
import '../state/catalog_reference.dart';
import '../state/load_state.dart';
import '../widgets/result_message.dart';

class DetailScreen<T extends CatalogEntity> extends StatelessWidget {
  final String back;
  const DetailScreen({super.key, required this.back});
  @override
  Widget build(BuildContext context) {
    final n = context.watch<DetailNotifier<T>>();
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go(back),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Вернуться к списку'),
                  ),
                ),
                const SizedBox(height: 20),
                switch (n.state) {
                  Loading() => const Center(child: CircularProgressIndicator()),
                  Failed(message: final message) => ResultMessage(
                    icon: Icons.error_outline,
                    title: 'Ошибка',
                    message: message,
                    actionLabel: 'Повторить',
                    onAction: n.load,
                  ),
                  Loaded(data: null) => const ResultMessage(
                    icon: Icons.search_off,
                    title: 'Запись не найдена',
                    message:
                        'Возможно, она была удалена или адрес указан неверно.',
                  ),
                  Loaded(data: final item?) => _card(context, item),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, T item) {
    final ref = context.read<CatalogReference>();
    final fields = switch (item) {
      Product p => <String, String>{
        'Артикул': p.sku,
        'Бренд': ref.brandName(p.brandId),
        'Категория': ref.categoryName(p.categoryId),
        'Цена': money(p.priceKopecks),
        'Остаток': '${p.stock} шт.',
        'Объём / масса': p.volume,
        'Описание': p.description,
      },
      Brand b => <String, String>{
        'Страна': b.country,
        'Год основания': '${b.foundedYear}',
        'Описание': b.description,
      },
      _ => <String, String>{},
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item is Product ? Icons.spa_outlined : Icons.local_offer_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(item.name, style: Theme.of(context).textTheme.headlineMedium),
            if (item.isDeleted)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Chip(
                  label: Text('Удалено · восстановление доступно в списке'),
                ),
              ),
            const SizedBox(height: 24),
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF8B7881),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      entry.value,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            if (item case Product p)
              TextButton(
                onPressed: () => context.go('/brands/${p.brandId}'),
                child: const Text('Подробнее о бренде'),
              ),
          ],
        ),
      ),
    );
  }
}
