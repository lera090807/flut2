import '../models/app_user.dart';

bool canAccess(Role role, String path) {
  if (path == '/account' || path.startsWith('/my-orders')) {
    return role == Role.customer;
  }
  if (path.startsWith('/orders')) return role == Role.staff;
  if (path.startsWith('/admin')) return role == Role.admin;
  if (path.startsWith('/suppliers') ||
      path.startsWith('/customers') ||
      path.endsWith('/new') ||
      path.endsWith('/edit')) {
    return role != Role.customer;
  }
  return true;
}

String safeReturnPath(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      ['/login', '/register', '/session'].contains(uri.path)) {
    return '/products';
  }
  return uri.toString();
}
