import 'catalog_entity.dart';
import 'json_values.dart';

class Category implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String description;
  @override
  final DateTime? deletedAt;
  const Category(this.id, this.name, {this.description = '', this.deletedAt});
  @override
  bool get isDeleted => deletedAt != null;
  Category copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Category(
    id ?? this.id,
    name ?? this.name,
    description: description ?? this.description,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    jsonInt(j['id']),
    jsonString(j['name']),
    description: jsonString(j['description']),
    deletedAt: jsonDate(j['deletedAt']),
  );
}
