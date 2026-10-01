import 'catalog_entity.dart';
import 'json_values.dart';

class Supplier implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String city;
  final String email;
  final String phone;
  final List<int> brandIds;
  @override
  final DateTime? deletedAt;
  Supplier({
    required this.id,
    required this.name,
    required this.city,
    required this.email,
    required this.phone,
    required List<int> brandIds,
    this.deletedAt,
  }) : brandIds = List.unmodifiable(brandIds.toSet());
  @override
  bool get isDeleted => deletedAt != null;
  Supplier copyWith({
    int? id,
    String? name,
    String? city,
    String? email,
    String? phone,
    List<int>? brandIds,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    city: city ?? this.city,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    brandIds: brandIds ?? this.brandIds,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'email': email,
    'phone': phone,
    'brandIds': brandIds,
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: jsonInt(j['id']),
    name: jsonString(j['name']),
    city: jsonString(j['city']),
    email: jsonString(j['email']),
    phone: jsonString(j['phone']),
    brandIds: jsonIds(j['brandIds']),
    deletedAt: jsonDate(j['deletedAt']),
  );
}
