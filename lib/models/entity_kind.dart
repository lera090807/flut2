import 'catalog_entity.dart';
import 'product.dart';
import 'brand.dart';
import 'category.dart';
import 'supplier.dart';
import 'customer.dart';

enum EntityKind {
  products('Товары', 'товар'),
  brands('Бренды', 'бренд'),
  categories('Категории', 'категорию'),
  suppliers('Поставщики', 'поставщика'),
  customers('Покупатели', 'покупателя');

  final String label;
  final String singular;
  const EntityKind(this.label, this.singular);
  String get path => '/$name';
  CatalogEntity decode(Map<String, dynamic> j) => switch (this) {
    products => Product.fromJson(j),
    brands => Brand.fromJson(j),
    categories => Category.fromJson(j),
    suppliers => Supplier.fromJson(j),
    customers => Customer.fromJson(j),
  };
}
