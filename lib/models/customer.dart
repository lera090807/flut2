import 'catalog_entity.dart';
import 'json_values.dart';
import 'loyalty_card.dart';

class Customer implements CatalogEntity {
  @override
  final int id;
  @override
  final String name;
  final String email;
  final String phone;
  final LoyaltyCard card;
  @override
  final DateTime? deletedAt;
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.card,
    this.deletedAt,
  });
  @override
  bool get isDeleted => deletedAt != null;
  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    LoyaltyCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    card: card ?? this.card,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'card': card.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
    id: jsonInt(j['id']),
    name: jsonString(j['name']),
    email: jsonString(j['email']),
    phone: jsonString(j['phone']),
    card: LoyaltyCard.fromJson(jsonMap(j['card'])),
    deletedAt: jsonDate(j['deletedAt']),
  );
}
