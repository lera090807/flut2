import 'catalog_entity.dart';

class Brand implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String country;
  final int foundedYear;
  final String description;
  @override
  final DateTime? deletedAt;
  const Brand({
    required this.id,
    required this.name,
    required this.country,
    required this.foundedYear,
    required this.description,
    this.deletedAt,
  });
  @override
  bool get isDeleted => deletedAt != null;
  Brand copyWith({
    int? id,
    String? name,
    String? country,
    int? foundedYear,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Brand(
    id: id ?? this.id,
    name: name ?? this.name,
    country: country ?? this.country,
    foundedYear: foundedYear ?? this.foundedYear,
    description: description ?? this.description,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
}
