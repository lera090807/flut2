import 'json_values.dart';

class LoyaltyCard {
  final int id;
  final String number;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final int points;
  const LoyaltyCard({
    this.id = 0,
    this.number = '',
    this.issuedAt,
    this.expiresAt,
    this.points = 0,
  });
  LoyaltyCard copyWith({
    int? id,
    String? number,
    DateTime? issuedAt,
    DateTime? expiresAt,
    int? points,
  }) => LoyaltyCard(
    id: id ?? this.id,
    number: number ?? this.number,
    issuedAt: issuedAt ?? this.issuedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    points: points ?? this.points,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'issuedAt': issuedAt?.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'points': points,
  };
  factory LoyaltyCard.fromJson(Map<String, dynamic> j) => LoyaltyCard(
    id: jsonInt(j['id']),
    number: jsonString(j['number']),
    issuedAt: jsonDate(j['issuedAt']),
    expiresAt: jsonDate(j['expiresAt']),
    points: jsonInt(j['points']),
  );
}
