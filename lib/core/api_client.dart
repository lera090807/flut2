import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'validation_exception.dart';
import 'config.dart';

ApiException mapHttpError(int status, dynamic body) {
  final message = body is Map && body['message'] is String
      ? body['message'] as String
      : null;
  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
      body is Map && body['errors'] is Map
          ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : {},
    ),
    _ => ServerException(message ?? 'Ошибка сервера (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  if (e.error is ApiException) return e.error as ApiException;
  if (e.response != null) {
    return mapHttpError(e.response!.statusCode ?? 500, e.response!.data);
  }
  return switch (e.type) {
    DioExceptionType.cancel => const RequestCancelledException(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя. Попробуйте ещё раз.',
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => const NetworkException(),
    _ => const ServerException(),
  };
}

Dio buildDio({
  String? baseUrl,
  String? Function()? tokenProvider,
  Future<void> Function()? refreshSession,
  Future<void> Function()? endSession,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) debugPrint('[API] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint(
            '[API] ${response.requestOptions.method} ${response.requestOptions.uri} → ${response.statusCode}',
          );
        }
        if ((response.statusCode ?? 0) >= 400) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(response.statusCode!, response.data),
            ),
            true,
          );
        } else {
          handler.next(response);
        }
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 &&
            !e.requestOptions.path.startsWith('/auth/') &&
            refreshSession != null) {
          final options = e.requestOptions;
          if (options.extra['authRetried'] == true) {
            await endSession?.call();
          } else {
            try {
              final sent = options.headers['Authorization'];
              final current = tokenProvider?.call();
              if (current == null || sent == 'Bearer $current') {
                await refreshSession();
              }
              if (options.cancelToken?.isCancelled == true) {
                handler.next(e);
                return;
              }
              options.extra['authRetried'] = true;
              options.headers['Authorization'] =
                  'Bearer ${tokenProvider?.call()}';
              final response = await dio.fetch(options);
              handler.resolve(response);
              return;
            } on DioException catch (retryError) {
              handler.next(retryError);
              return;
            } catch (_) {
              handler.next(
                e.copyWith(
                  error: const UnauthorizedException(
                    'Сессия завершена. Войдите снова.',
                  ),
                ),
              );
              return;
            }
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[API] ${e.requestOptions.method} ${e.requestOptions.uri} → ${e.response?.statusCode ?? e.type.name}',
          );
        }
        handler.next(e.copyWith(error: mapDioError(e)));
      },
    ),
  );
  return dio;
}
