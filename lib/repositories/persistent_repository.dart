import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/product.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import 'catalog_repository.dart';
import 'product_repository.dart';
import 'brand_repository.dart';
import 'shop_database.dart';

class PersistentRepository<T extends CatalogEntity>
    implements CatalogRepository<T> {
  final ShopDatabase database;
  final EntityKind kind;
  final Duration latency;
  PersistentRepository(
    this.database,
    this.kind, {
    this.latency = const Duration(milliseconds: 150),
  });
  List<T> get _rows => database.rows<T>(kind);
  int _productCount(int id) => database
      .rows<Product>(EntityKind.products)
      .where((p) => !p.isDeleted && p.categoryIds.contains(id))
      .length;
  bool _matches(T e, CatalogQuery q) {
    final needle = q.search.trim().toLowerCase();
    final text = switch (e) {
      Product p => '${p.name} ${p.sku}',
      Brand b => '${b.name} ${b.country}',
      Category c => '${c.name} ${c.description}',
      Supplier s => '${s.name} ${s.city} ${s.email}',
      Customer c => '${c.name} ${c.email} ${c.phone} ${c.card.number}',
      _ => e.name,
    };
    if (!text.toLowerCase().contains(needle)) return false;
    return switch (e) {
      Product p =>
        (q.categoryId == null || p.categoryIds.contains(q.categoryId)) &&
            (q.brandId == null || p.brandId == q.brandId) &&
            (q.minPrice == null || p.priceKopecks >= q.minPrice! * 100) &&
            (q.maxPrice == null || p.priceKopecks <= q.maxPrice! * 100),
      Brand b => q.filter.isEmpty || b.country == q.filter,
      Supplier s => q.filter.isEmpty || s.city == q.filter,
      Category c =>
        q.filter.isEmpty ||
            (q.filter == 'used'
                ? _productCount(c.id) > 0
                : _productCount(c.id) == 0),
      Customer c =>
        q.filter.isEmpty ||
            (q.filter == 'active'
                ? c.card.expiresAt?.isAfter(DateTime.now()) == true
                : c.card.expiresAt?.isAfter(DateTime.now()) != true),
      _ => true,
    };
  }

  Object _sortValue(T e, String field) => switch ((e, field)) {
    (Product p, 'price') => p.priceKopecks,
    (Product p, 'stock') => p.stock,
    (Brand b, 'country') => b.country,
    (Brand b, 'foundedYear') => b.foundedYear,
    (Supplier s, 'city') => s.city,
    (Supplier s, 'email') => s.email,
    (Customer c, 'email') => c.email,
    (Customer c, 'points') => c.card.points,
    (Category c, 'productCount') => _productCount(c.id),
    (_, 'id') => e.id,
    _ => e.name,
  };
  @override
  Future<PageResult<T>> find(CatalogQuery q) async {
    await Future<void>.delayed(latency);
    if (q.page < 1 || ![10, 25, 50].contains(q.size)) {
      throw ArgumentError('Некорректная страница');
    }
    final rows = _rows
        .where(
          (e) =>
              (q.onlyDeleted
                  ? e.isDeleted
                  : (q.includeDeleted || !e.isDeleted)) &&
              _matches(e, q),
        )
        .toList();
    rows.sort((a, b) {
      final av = _sortValue(a, q.sortField), bv = _sortValue(b, q.sortField);
      final value = av is int && bv is int
          ? av.compareTo(bv)
          : '$av'.toLowerCase().compareTo('$bv'.toLowerCase());
      return (value == 0 ? a.id.compareTo(b.id) : value) *
          (q.ascending ? 1 : -1);
    });
    final pages = rows.isEmpty ? 1 : (rows.length / q.size).ceil();
    final page = q.page > pages ? pages : q.page;
    final from = (page - 1) * q.size;
    final end = (from + q.size).clamp(0, rows.length);
    return PageResult(
      items: rows.sublist(from, end),
      page: page,
      size: q.size,
      total: rows.length,
    );
  }

  @override
  Future<T?> findById(int id) async {
    await Future<void>.delayed(latency);
    return _rows.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<T> create(T entity) => _save(entity, true);
  @override
  Future<T> update(T entity) => _save(entity, false);
  Future<T> _save(T entity, bool create) =>
      database.transaction((rows, sequences) {
        final id = create ? sequences[kind]! : entity.id;
        final index = rows[kind]!.indexWhere((e) => e.id == id);
        if (!create && index < 0) throw StateError('Запись не найдена');
        final data = {...entity.toJson(), 'id': id};
        if (entity is Customer) {
          data['card'] = {...(entity as Customer).card.toJson(), 'id': id};
        }
        final saved = kind.decode(data) as T;
        database.validate(kind, saved, rows);
        if (create) {
          rows[kind]!.add(saved);
          sequences[kind] = id + 1;
        } else {
          rows[kind]![index] = saved;
        }
        return saved;
      });
  Future<void> _change(int id, String action) =>
      database.transaction<void>((rows, _) {
        final index = rows[kind]!.indexWhere((e) => e.id == id);
        if (index < 0) throw StateError('Запись не найдена');
        if (action != 'restore') database.checkDelete(kind, id, rows);
        if (action == 'hard') {
          rows[kind]!.removeAt(index);
          return;
        }
        final entity = kind.decode({
          ...rows[kind]![index].toJson(),
          'deletedAt': action == 'restore'
              ? null
              : DateTime.now().toIso8601String(),
        });
        if (action == 'restore') database.validate(kind, entity, rows);
        rows[kind]![index] = entity;
      });
  @override
  Future<void> softDelete(int id) => _change(id, 'soft');
  @override
  Future<void> hardDelete(int id) => _change(id, 'hard');
  @override
  Future<void> restore(int id) => _change(id, 'restore');
  @override
  Future<int> deleteMany(List<int> ids) => database.transaction((rows, _) {
    final selected = rows[kind]!
        .where((e) => ids.contains(e.id) && !e.isDeleted)
        .toList();
    for (final entity in selected) {
      database.checkDelete(kind, entity.id, rows);
    }
    for (final entity in selected) {
      final i = rows[kind]!.indexWhere((e) => e.id == entity.id);
      rows[kind]![i] = kind.decode({
        ...entity.toJson(),
        'deletedAt': DateTime.now().toIso8601String(),
      });
    }
    return selected.length;
  });
}

class PersistentProductRepository extends PersistentRepository<Product>
    implements ProductRepository {
  PersistentProductRepository(ShopDatabase db) : super(db, EntityKind.products);
}

class PersistentBrandRepository extends PersistentRepository<Brand>
    implements BrandRepository {
  PersistentBrandRepository(ShopDatabase db) : super(db, EntityKind.brands);
}
