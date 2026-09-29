import '../models/brand.dart';
import '../models/category.dart';
import '../repositories/seed_data.dart';

/// Справочные подписи сохраняются и после удаления бренда из каталога.
/// В ПР2 справочники предзаполнены; экран не обращается к хранилищу.
class CatalogReference {
  List<Brand> get brands => List.unmodifiable(seedBrands);
  List<Category> get categories => List.unmodifiable(seedCategories);
  String brandName(int id) =>
      brands.where((b) => b.id == id).firstOrNull?.name ?? 'Бренд #$id';
  String categoryName(int id) =>
      categories.where((c) => c.id == id).firstOrNull?.name ?? 'Категория #$id';
}
