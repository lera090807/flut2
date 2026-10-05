import 'catalog_entity.dart';
import 'json_values.dart';

class Product implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String sku;
  final int brandId;
  final int supplierId;
  final List<int> categoryIds;
  int get categoryId => categoryIds.firstOrNull ?? 0;
  final int priceKopecks;
  final int stock;
  final String volume;
  final String description;
  @override
  final DateTime? deletedAt;
  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.brandId,
    int categoryId = 0,
    List<int>? categoryIds,
    this.supplierId = 1,
    required this.priceKopecks,
    required this.stock,
    required this.volume,
    required this.description,
    this.deletedAt,
  }) : categoryIds = List.unmodifiable(
         (categoryIds ?? (categoryId > 0 ? [categoryId] : <int>[])).toSet(),
       );
  @override
  bool get isDeleted => deletedAt != null;
  Product copyWith({
    int? id,
    String? name,
    String? sku,
    int? brandId,
    int? supplierId,
    int? categoryId,
    List<int>? categoryIds,
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
    supplierId: supplierId ?? this.supplierId,
    categoryIds:
        categoryIds ?? (categoryId != null ? [categoryId] : this.categoryIds),
    priceKopecks: priceKopecks ?? this.priceKopecks,
    stock: stock ?? this.stock,
    volume: volume ?? this.volume,
    description: description ?? this.description,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'brandId': brandId,
    'supplierId': supplierId,
    'categoryIds': categoryIds,
    'priceKopecks': priceKopecks,
    'stock': stock,
    'volume': volume,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: jsonInt(j['id']),
    name: jsonString(j['name']),
    sku: jsonString(j['sku']),
    brandId: jsonInt(
      j['brandId'] ?? (j['brand'] is Map ? j['brand']['id'] : null),
    ),
    supplierId: jsonInt(
      j['supplierId'] ?? (j['supplier'] is Map ? j['supplier']['id'] : null),
      1,
    ),
    categoryIds: j['categoryIds'] is List
        ? jsonIds(j['categoryIds'])
        : j['categories'] is List
        ? jsonIds(
            (j['categories'] as List)
                .whereType<Map>()
                .map((e) => e['id'])
                .toList(),
          )
        : [if (jsonInt(j['categoryId']) > 0) jsonInt(j['categoryId'])],
    priceKopecks: jsonInt(j['priceKopecks']),
    stock: jsonInt(j['stock']),
    volume: jsonString(j['volume']),
    description: jsonString(j['description']),
    deletedAt: jsonDate(j['deletedAt']),
  );
}
