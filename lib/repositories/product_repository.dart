import '../models/product.dart';
import '../models/catalog_query.dart';
import 'catalog_repository.dart';
import 'in_memory_repository.dart';
import 'seed_data.dart';

abstract interface class ProductRepository
    implements CatalogRepository<Product> {}

class InMemoryProductRepository extends InMemoryRepository<Product>
    implements ProductRepository {
  InMemoryProductRepository({List<Product>? seed, super.latency})
    : super(seed ?? seedProducts);
  @override
  bool matches(Product p, CatalogQuery q) {
    final search = q.search.trim().toLowerCase();
    return (p.name.toLowerCase().contains(search) ||
            p.sku.toLowerCase().contains(search)) &&
        (q.categoryId == null || p.categoryIds.contains(q.categoryId)) &&
        (q.brandId == null || p.brandId == q.brandId) &&
        (q.minPrice == null || p.priceKopecks >= q.minPrice! * 100) &&
        (q.maxPrice == null || p.priceKopecks <= q.maxPrice! * 100);
  }

  @override
  int compare(Product a, Product b, String field) => switch (field) {
    'price' => a.priceKopecks.compareTo(b.priceKopecks),
    'stock' => a.stock.compareTo(b.stock),
    _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  };
  @override
  Product withId(Product entity, int id) => entity.copyWith(id: id);
  @override
  Product withDeletedAt(Product entity, DateTime? value) =>
      entity.copyWith(deletedAt: value, clearDeletedAt: value == null);
  @override
  void validate(Product entity) {
    if (entity.name.trim().isEmpty ||
        entity.sku.trim().isEmpty ||
        entity.priceKopecks < 0 ||
        entity.stock < 0) {
      throw ArgumentError('Проверьте название, артикул, цену и остаток');
    }
  }
}
