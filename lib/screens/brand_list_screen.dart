import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/catalog_reference.dart';

import '../models/brand.dart';
import '../models/catalog_query.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class BrandListScreen extends StatelessWidget {
  final CatalogQuery query;
  const BrandListScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context) => CatalogScreen<Brand>(
    query: query,
    path: '/brands',
    products: false,
    filterLabel: 'Страна',
    filterOptions: {
      for (final b in context.watch<CatalogReference>().brands.where(
        (b) => !b.isDeleted,
      ))
        b.country: b.country,
    },
    title: 'Бренды',
    subtitle: 'Знакомьтесь с марками нашей коллекции.',
    searchHint: 'Название бренда или страна',
    summary: (b) =>
        '${b.country} · Основан в ${b.foundedYear} году\n${b.description}',
    columns: [
      TableColumnSpec(
        label: 'Бренд',
        sortField: 'name',
        build: (b) => Text(
          '${b.name}${b.isDeleted ? ' · Удалено' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      TableColumnSpec(
        label: 'Страна',
        sortField: 'country',
        build: (b) => Text(b.country),
      ),
      TableColumnSpec(
        label: 'Год основания',
        sortField: 'foundedYear',
        numeric: true,
        build: (b) => Text('${b.foundedYear}'),
      ),
    ],
  );
}
