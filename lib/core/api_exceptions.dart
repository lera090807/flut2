class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте, запущен ли он. Если сервер работает, проверьте CORS в консоли браузера.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка сервера. Попробуйте позже.']);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('Запрос отменён.');
}
