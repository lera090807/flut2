import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../models/catalog_query.dart';
import '../state/catalog_reference.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class ProductListScreen extends StatelessWidget {
  final CatalogQuery query;
  const ProductListScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context) {
    final ref = context.read<CatalogReference>();
    return CatalogScreen<Product>(
      query: query,
      path: '/products',
      products: true,
      title: 'Коллекция косметики',
      subtitle: 'Уход, макияж и маленькие ежедневные ритуалы.',
      searchHint: 'Название или артикул',
      summary: (p) =>
          '${ref.brandName(p.brandId)} · ${ref.categoryName(p.categoryId)}\n${money(p.priceKopecks)} · ${p.volume} · Остаток: ${p.stock} шт.',
      columns: [
        TableColumnSpec(
          label: 'Товар',
          sortField: 'name',
          build: (p) => SizedBox(
            width: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: p.isDeleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${p.sku}${p.isDeleted ? ' · Удалено' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B7881),
                  ),
                ),
              ],
            ),
          ),
        ),
        TableColumnSpec(
          label: 'Бренд',
          build: (p) => Text(ref.brandName(p.brandId)),
        ),
        TableColumnSpec(
          label: 'Категория',
          build: (p) => Text(ref.categoryName(p.categoryId)),
        ),
        TableColumnSpec(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (p) => Text(money(p.priceKopecks)),
        ),
        TableColumnSpec(
          label: 'Остаток',
          sortField: 'stock',
          numeric: true,
          build: (p) => Text('${p.stock} шт.'),
        ),
      ],
    );
  }
}
