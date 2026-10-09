import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cosmetics/core/api_client.dart';
import 'package:cosmetics/core/api_exceptions.dart';
import 'package:cosmetics/core/permissions.dart';
import 'package:cosmetics/models/app_user.dart';
import 'package:cosmetics/state/auth_notifier.dart';

import 'api_repository_test.dart' show Adapter, response;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final row in <(Role, String, bool)>[
    (Role.customer, '/products', true),
    (Role.customer, '/products/new', false),
    (Role.customer, '/products/1/edit', false),
    (Role.customer, '/customers', false),
    (Role.customer, '/my-orders', true),
    (Role.staff, '/orders', true),
    (Role.admin, '/orders', false),
    (Role.staff, '/admin', false),
    (Role.admin, '/admin', true),
    (Role.staff, '/account', false),
  ]) {
    test(
      '${row.$1.name}: ${row.$2} → ${row.$3}',
      () => expect(canAccess(row.$1, row.$2), row.$3),
    );
  }
  test('return URL excludes external redirect and login loop', () {
    expect(safeReturnPath('https://example.com'), '/products');
    expect(safeReturnPath('//example.com'), '/products');
    expect(safeReturnPath('/login'), '/products');
    expect(
      safeReturnPath('/products/5?from=/products'),
      '/products/5?from=/products',
    );
  });
  final user = {
    'id': 1,
    'username': 'buyer',
    'fullName': 'Анна',
    'email': 'buyer@example.com',
    'role': 'customer',
  };
  Map<String, dynamic> session(
    DateTime now, {
    String token = 'access',
    String refresh = 'refresh',
  }) => {
    'accessToken': token,
    'refreshToken': refresh,
    'sessionExpiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
    'user': user,
  };
  test(
    'login persists tokens but no password; reload restores; logout clears',
    () async {
      final now = DateTime.now();
      final dio = buildDio();
      dio.httpClientAdapter = Adapter(
        (q, _) async => response(
          q.path == '/auth/me'
              ? user
              : q.path == '/auth/logout'
              ? {}
              : session(now),
        ),
      );
      final auth = AuthNotifier(dio);
      await auth.login('buyer', 'Secret123!');
      expect(auth.isAuthenticated, true);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AuthNotifier.sessionKey),
        isNot(contains('Secret')),
      );
      auth.dispose();
      final next = AuthNotifier(dio);
      await next.restore();
      expect(next.user!.username, 'buyer');
      await next.logout();
      expect(prefs.getString(AuthNotifier.sessionKey), isNull);
      next.dispose();
      dio.close();
    },
  );
  test(
    'idle warning at 150s, activity extends timer, logout at 180s',
    () async {
      var now = DateTime.now();
      final dio = buildDio();
      dio.httpClientAdapter = Adapter(
        (q, _) async => response(q.path == '/auth/logout' ? {} : session(now)),
      );
      final auth = AuthNotifier(dio, clock: () => now);
      await auth.login('buyer', 'Secret123!');
      now = now.add(const Duration(seconds: 150));
      auth.checkTime();
      expect(auth.warningSeconds, 30);
      auth.activity();
      expect(auth.warningSeconds, isNull);
      now = now.add(const Duration(seconds: 179));
      auth.checkTime();
      expect(auth.isAuthenticated, true);
      now = now.add(const Duration(seconds: 1));
      auth.checkTime();
      expect(auth.isAuthenticated, false);
      await Future<void>.delayed(Duration.zero);
      auth.dispose();
      dio.close();
    },
  );
  test('absolute deadline ends session despite activity', () async {
    var now = DateTime.now();
    final dio = buildDio();
    dio.httpClientAdapter = Adapter(
      (q, _) async => response(q.path == '/auth/logout' ? {} : session(now)),
    );
    final auth = AuthNotifier(
      dio,
      clock: () => now,
      idleTimeout: const Duration(hours: 2),
    );
    await auth.login('buyer', 'Secret123!');
    now = now.add(const Duration(minutes: 59));
    auth.activity();
    now = now.add(const Duration(minutes: 1));
    auth.checkTime();
    expect(auth.isAuthenticated, false);
    expect(auth.message, contains('Время сессии'));
    await Future<void>.delayed(Duration.zero);
    auth.dispose();
    dio.close();
  });
  test('idle deadline survives page reload', () async {
    var now = DateTime.now();
    final dio = buildDio();
    dio.httpClientAdapter = Adapter(
      (q, _) async => response(q.path == '/auth/logout' ? {} : session(now)),
    );
    final auth = AuthNotifier(dio, clock: () => now);
    await auth.login('buyer', 'Secret123!');
    auth.dispose();
    now = now.add(const Duration(minutes: 4));
    final next = AuthNotifier(dio, clock: () => now);
    await next.restore();
    expect(next.isAuthenticated, false);
    next.dispose();
    dio.close();
  });
  test(
    'single refresh for concurrent 401; each request repeated once',
    () async {
      final now = DateTime.now();
      late AuthNotifier auth;
      var refreshes = 0;
      final dio = buildDio(
        tokenProvider: () => auth.accessToken,
        refreshSession: () => auth.refreshTokens(),
        endSession: () => auth.logout(),
      );
      dio.httpClientAdapter = Adapter((q, _) async {
        if (q.path == '/auth/login') return response(session(now));
        if (q.path == '/auth/refresh') {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return response(
            session(now, token: 'new-access', refresh: 'new-refresh'),
          );
        }
        if (q.headers['Authorization'] == 'Bearer new-access') {
          return response({'ok': true});
        }
        return response({'message': 'Expired'}, 401);
      });
      auth = AuthNotifier(dio);
      await auth.login('buyer', 'Secret123!');
      await Future.wait([
        auth.request('/products'),
        auth.request('/brands'),
        auth.request('/categories'),
      ]);
      expect(refreshes, 1);
      expect(auth.accessToken, 'new-access');
      auth.dispose();
      dio.close();
    },
  );
  test('failed refresh logs out without recursive request loop', () async {
    final now = DateTime.now();
    late AuthNotifier auth;
    var refreshes = 0, reads = 0;
    final dio = buildDio(
      tokenProvider: () => auth.accessToken,
      refreshSession: () => auth.refreshTokens(),
      endSession: () => auth.logout(),
    );
    dio.httpClientAdapter = Adapter((q, _) async {
      if (q.path == '/auth/login') return response(session(now));
      if (q.path == '/auth/logout') return response({});
      if (q.path == '/auth/refresh') {
        refreshes++;
      } else {
        reads++;
      }
      return response({'message': 'Expired'}, 401);
    });
    auth = AuthNotifier(dio);
    await auth.login('buyer', 'Secret123!');
    await expectLater(
      auth.request('/products'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(refreshes, 1);
    expect(reads, 1);
    expect(auth.isAuthenticated, false);
    auth.dispose();
    dio.close();
  });
  test('client cached display role does not replace server user role in normal build', () async {
    SharedPreferences.setMockInitialValues({'cosmetics_demo_role': 'admin'});
    final now = DateTime.now(), dio = buildDio();
    dio.httpClientAdapter = Adapter((_, _) async => response(session(now)));
    final auth = AuthNotifier(dio);
    await auth.login('buyer', 'Secret123!');
    expect(auth.displayRole, Role.customer);
    expect(auth.user!.role, Role.customer);
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString(AuthNotifier.sessionKey)!)
          .containsKey('password'),
      false,
    );
    auth.dispose();
    dio.close();
  });
}
