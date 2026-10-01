import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/customer.dart';
import '../state/catalog_reference.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class ReferenceListScreen<T extends CatalogEntity> extends StatelessWidget {
  final EntityKind kind;
  final CatalogQuery query;
  const ReferenceListScreen({
    super.key,
    required this.kind,
    required this.query,
  });
  @override
  Widget build(BuildContext context) {
    final ref = context.watch<CatalogReference>();
    final columns = <TableColumnSpec<T>>[
      TableColumnSpec(
        label: kind == EntityKind.customers ? 'ФИО' : 'Название',
        sortField: 'name',
        build: (e) => SizedBox(
          width: 220,
          child: Text(
            '${e.name}${e.isDeleted ? ' · Удалено' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (kind == EntityKind.categories) ...[
        TableColumnSpec(
          label: 'Номер',
          sortField: 'id',
          numeric: true,
          build: (e) => Text('${e.id}'),
        ),
        TableColumnSpec(
          label: 'Товаров',
          sortField: 'productCount',
          numeric: true,
          build: (e) => Text('${ref.productCount(e.id)}'),
        ),
      ],
      if (kind == EntityKind.suppliers) ...[
        TableColumnSpec(
          label: 'Город',
          sortField: 'city',
          build: (e) => Text((e as Supplier).city),
        ),
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (e) => Text((e as Supplier).email),
        ),
      ],
      if (kind == EntityKind.customers) ...[
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (e) => Text((e as Customer).email),
        ),
        TableColumnSpec(
          label: 'Баллы',
          sortField: 'points',
          numeric: true,
          build: (e) => Text('${(e as Customer).card.points}'),
        ),
      ],
    ];
    return CatalogScreen<T>(
      query: query,
      path: kind.path,
      products: false,
      title: kind.label,
      subtitle: switch (kind) {
        EntityKind.categories => 'Разделы каталога и связанные товары.',
        EntityKind.suppliers => 'Партнёры магазина и поставляемые бренды.',
        _ => 'Контакты покупателей и карты лояльности.',
      },
      searchHint: kind == EntityKind.customers
          ? 'Имя, почта, телефон или карта'
          : 'Название, описание или город',
      columns: columns,
      filterLabel: kind == EntityKind.suppliers
          ? 'Город'
          : kind == EntityKind.customers
          ? 'Срок карты'
          : 'Связанные товары',
      filterOptions: switch (kind) {
        EntityKind.suppliers => {
          for (final s in ref.suppliers.where((s) => !s.isDeleted))
            s.city: s.city,
        },
        EntityKind.customers => {
          'active': 'Действующая карта',
          'expired': 'Истёкшая карта',
        },
        _ => {'used': 'С товарами', 'unused': 'Без товаров'},
      },
      summary: (e) => switch (e) {
        Category c => 'Товаров: ${ref.productCount(c.id)}\n${c.description}',
        Supplier s => '${s.city} · ${s.phone}\n${s.email}',
        Customer c =>
          '${c.email}\nКарта ${c.card.number} · ${c.card.points} баллов',
        _ => e.name,
      },
    );
  }
}
