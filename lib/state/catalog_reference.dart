import 'package:flutter/foundation.dart' hide Category;

import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repository.dart';

class CatalogReference extends ChangeNotifier {
  final Map<EntityKind, CatalogRepository<CatalogEntity>> repositories;
  final bool cache;
  CatalogReference(this.repositories, {this.cache = false});
  Future<void>? _pending;
  int _generation = 0;
  int _loadedGeneration = -1;
  void invalidate(EntityKind kind) {
    if (kind == EntityKind.customers) return;
    _generation++;
  }

  Map<EntityKind, List<CatalogEntity>> _data = {};
  bool _disposed = false;
  int _request = 0;
  String? error;
  bool get ready => _data.length == (cache ? 3 : EntityKind.values.length);
  List<T> all<T extends CatalogEntity>(EntityKind kind) =>
      List.unmodifiable((_data[kind] ?? []).cast<T>());
  List<Brand> get brands => all<Brand>(EntityKind.brands);
  List<Category> get categories => all<Category>(EntityKind.categories);
  List<Supplier> get suppliers => all<Supplier>(EntityKind.suppliers);
  List<Product> get products => all<Product>(EntityKind.products);
  String brandName(int id) =>
      brands.where((e) => e.id == id).firstOrNull?.name ?? 'Бренд #$id';
  String categoryName(int id) =>
      categories.where((e) => e.id == id).firstOrNull?.name ?? 'Категория #$id';
  String supplierName(int id) =>
      suppliers.where((e) => e.id == id).firstOrNull?.name ?? 'Поставщик #$id';
  int productCount(int id) => cache
      ? (categories.where((c) => c.id == id).firstOrNull?.productCount ?? 0)
      : products
            .where((p) => !p.isDeleted && p.categoryIds.contains(id))
            .length;
  Future<void> load() {
    if (!cache) return _load();
    if (_pending != null) return _pending!;
    if (ready && _loadedGeneration == _generation) return Future.value();
    final generation = _generation;
    return _pending = _load()
        .then((_) {
          if (error == null) _loadedGeneration = generation;
        })
        .whenComplete(() {
          _pending = null;
        })
        .then((_) async {
          if (!_disposed && generation != _generation) await load();
        });
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final entries = await Future.wait(
        repositories.entries
            .where(
              (entry) =>
                  !cache ||
                  [
                    EntityKind.brands,
                    EntityKind.categories,
                    EntityKind.suppliers,
                  ].contains(entry.key),
            )
            .map((entry) async {
              final list = <CatalogEntity>[];
              var page = 1;
              while (true) {
                final result = await entry.value.find(
                  CatalogQuery(includeDeleted: true, size: 50, page: page),
                );
                list.addAll(result.items);
                if (!result.hasNext) break;
                page++;
              }
              return MapEntry(entry.key, list);
            }),
      );
      if (_disposed || request != _request) return;
      _data = Map.fromEntries(entries);
      error = null;
    } catch (_) {
      if (_disposed || request != _request) return;
      error = 'Не удалось загрузить справочники';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
