import 'catalog_entity.dart';

class Product implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String sku;
  final int brandId;
  final int categoryId;
  // Цена в копейках: вычисления не теряют точность из-за double.
  final int priceKopecks;
  final int stock;
  final String volume;
  final String description;
  @override
  final DateTime? deletedAt;
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.brandId,
    required this.categoryId,
    required this.priceKopecks,
    required this.stock,
    required this.volume,
    required this.description,
    this.deletedAt,
  });
  @override
  bool get isDeleted => deletedAt != null;
  Product copyWith({
    int? id,
    String? name,
    String? sku,
    int? brandId,
    int? categoryId,
    int? priceKopecks,
    int? stock,
    String? volume,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    brandId: brandId ?? this.brandId,
    categoryId: categoryId ?? this.categoryId,
    priceKopecks: priceKopecks ?? this.priceKopecks,
    stock: stock ?? this.stock,
    volume: volume ?? this.volume,
    description: description ?? this.description,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
}
