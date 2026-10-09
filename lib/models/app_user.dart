enum Role {
  customer('Покупатель'),
  staff('Сотрудник'),
  admin('Администратор');

  final String label;
  const Role(this.label);
  static Role parse(Object? value) =>
      Role.values.where((r) => r.name == value).firstOrNull ?? Role.customer;
}

class AppUser {
  final int id;
  final String username, fullName, email;
  final Role role;
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
  });
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as int,
    username: j['username'] as String,
    fullName: j['fullName'] as String,
    email: j['email'] as String,
    role: Role.parse(j['role']),
  );
  bool get canEdit => role == Role.staff || role == Role.admin;
  bool get canErase => role == Role.admin;
}
