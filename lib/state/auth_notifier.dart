import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../core/unload_guard.dart';
import '../models/app_user.dart';

class AuthNotifier extends ChangeNotifier {
  final Dio dio;
  final Duration idleTimeout;
  final DateTime Function() clock;
  AuthNotifier(
    this.dio, {
    this.idleTimeout = const Duration(minutes: 3),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  static const sessionKey = 'cosmetics_auth_session';
  SharedPreferences? _prefs;
  String? accessToken, _refreshToken;
  AppUser? user;
  bool ready = false, busy = false, _disposed = false;
  String? message, restoreError;
  DateTime? _lastAction, _deadline;
  Timer? _timer;
  Future<void>? _refreshing;
  int _epoch = 0;
  int sessionRevision = 0;
  int get epoch => _epoch;
  int? warningSeconds;
  bool get isAuthenticated => user != null;
  Role get displayRole {
    const demo = bool.fromEnvironment('AUTH_DEMO_UI');
    final value = demo ? _prefs?.getString('cosmetics_demo_role') : null;
    return value == null ? (user?.role ?? Role.customer) : Role.parse(value);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? data,
  }) async {
    try {
      return (await dio.request(
        path,
        data: data,
        options: Options(method: method),
      )).data;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (accessToken == null) return;
    final ok = await _prefs!.setString(
      sessionKey,
      jsonEncode({
        'accessToken': accessToken,
        'refreshToken': _refreshToken,
        'lastAction': _lastAction?.toIso8601String(),
        'deadline': _deadline?.toIso8601String(),
      }),
    );
    if (!ok) throw const ApiException('Не удалось сохранить сессию в браузере');
  }

  Future<void> _apply(Map<String, dynamic> data) async {
    accessToken = data['accessToken'] as String;
    _refreshToken = data['refreshToken'] as String;
    user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    _deadline = DateTime.parse(data['sessionExpiresAt'] as String);
    await _persist();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => checkTime());
    checkTime();
  }

  Future<void> restore() async {
    ready = false;
    restoreError = null;
    _notify();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(sessionKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        accessToken = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String?;
        _lastAction = DateTime.tryParse(data['lastAction'] ?? '');
        _deadline = DateTime.tryParse(data['deadline'] ?? '');
        if (_lastAction == null ||
            _deadline == null ||
            !clock().isBefore(_deadline!) ||
            clock().difference(_lastAction!) >= idleTimeout) {
          await logout(reason: 'Сессия завершена. Войдите снова.');
          return;
        }
        try {
          user = AppUser.fromJson(
            await request('/auth/me') as Map<String, dynamic>,
          );
        } on UnauthorizedException {
          await refreshTokens();
        }
        _startTimer();
      }
      ready = true;
    } on NetworkException catch (e) {
      restoreError = e.message;
    } on ServerException catch (e) {
      restoreError = e.message;
    } catch (_) {
      await logout(reason: 'Сессия завершена. Войдите снова.');
    }
    _notify();
  }

  Future<void> login(String username, String password) async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    final epoch = ++_epoch;
    try {
      final data = await request(
        '/auth/login',
        method: 'POST',
        data: {'username': username, 'password': password},
      ) as Map<String, dynamic>;
      if (epoch != _epoch || _disposed) return;
      _lastAction = clock();
      await _apply(data);
      sessionRevision++;
      ready = true;
      _startTimer();
    } catch (_) {
      accessToken = null;
      _refreshToken = null;
      user = null;
      rethrow;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> register(Map<String, String> data) async {
    await request('/auth/register', method: 'POST', data: data);
  }

  Future<void> refreshTokens() {
    if (_refreshing != null) return _refreshing!;
    return _refreshing = _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final epoch = _epoch;
    try {
      if (_refreshToken == null ||
          _deadline == null ||
          !clock().isBefore(_deadline!) ||
          (_lastAction != null &&
              clock().difference(_lastAction!) >= idleTimeout)) {
        throw const UnauthorizedException();
      }
      final data = await request(
        '/auth/refresh',
        method: 'POST',
        data: {'refreshToken': _refreshToken},
      ) as Map<String, dynamic>;
      if (epoch != _epoch || _disposed) throw const UnauthorizedException();
      await _apply(data);
      _notify();
    } catch (_) {
      if (epoch == _epoch) {
        await logout(reason: 'Сессия завершена. Войдите снова.');
      }
      rethrow;
    }
  }

  Future<void> logout({String? reason}) async {
    final refresh = _refreshToken;
    _epoch++;
    sessionRevision++;
    user = null;
    accessToken = null;
    _refreshToken = null;
    _timer?.cancel();
    warningSeconds = null;
    ready = true;
    restoreError = null;
    message = reason;
    setUnsavedChanges(false);
    _notify();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(sessionKey);
    if (refresh != null) {
      try {
        await request(
          '/auth/logout',
          method: 'POST',
          data: {'refreshToken': refresh},
        );
      } catch (_) {}
    }
  }

  void activity() {
    if (!isAuthenticated) return;
    final now = clock();
    if ((_deadline != null && !now.isBefore(_deadline!)) ||
        (_lastAction != null && now.difference(_lastAction!) >= idleTimeout)) {
      checkTime();
      return;
    }
    if (_lastAction != null &&
        now.difference(_lastAction!) < const Duration(seconds: 1)) {
      return;
    }
    _lastAction = now;
    unawaited(_persist().catchError((Object _) {}));
    if (warningSeconds != null) {
      warningSeconds = null;
      _notify();
    }
  }

  void checkTime() {
    if (!isAuthenticated) return;
    final now = clock();
    if (_deadline != null && !now.isBefore(_deadline!)) {
      unawaited(logout(reason: 'Время сессии закончилось. Войдите снова.'));
      return;
    }
    final left =
        idleTimeout.inSeconds - now.difference(_lastAction ?? now).inSeconds;
    if (left <= 0) {
      unawaited(
        logout(reason: 'Вы вышли из системы: три минуты не было действий.'),
      );
      return;
    }
    final warning = left <= 30 ? left : null;
    if (warningSeconds != warning) {
      warningSeconds = warning;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    super.dispose();
  }
}
