import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/page_result.dart';

abstract interface class CatalogRepository<T extends CatalogEntity> {
  Future<PageResult<T>> find(CatalogQuery query);
  Future<T?> findById(int id);
  Future<T> create(T entity);
  Future<T> update(T entity);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
