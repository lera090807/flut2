import '../models/brand.dart';
import '../models/catalog_query.dart';
import 'catalog_repository.dart';
import 'in_memory_repository.dart';
import 'seed_data.dart';

abstract interface class BrandRepository implements CatalogRepository<Brand> {}

class InMemoryBrandRepository extends InMemoryRepository<Brand>
    implements BrandRepository {
  InMemoryBrandRepository({List<Brand>? seed, super.latency})
    : super(seed ?? seedBrands);
  @override
  bool matches(Brand b, CatalogQuery q) {
    final search = q.search.trim().toLowerCase();
    return b.name.toLowerCase().contains(search) ||
        b.country.toLowerCase().contains(search);
  }

  @override
  int compare(Brand a, Brand b, String field) => switch (field) {
    'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
    'foundedYear' => a.foundedYear.compareTo(b.foundedYear),
    _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  };
  @override
  Brand withId(Brand entity, int id) => entity.copyWith(id: id);
  @override
  Brand withDeletedAt(Brand entity, DateTime? value) =>
      entity.copyWith(deletedAt: value, clearDeletedAt: value == null);
  @override
  void validate(Brand entity) {
    if (entity.name.trim().isEmpty ||
        entity.country.trim().isEmpty ||
        entity.foundedYear <= 0) {
      throw ArgumentError('Проверьте название, страну и год основания');
    }
  }
}
