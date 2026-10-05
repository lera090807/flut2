import 'api_exceptions.dart';

class ValidationException extends ApiException {
  final Map<String, String> errors;
  ValidationException(this.errors) : super('Ошибка валидации');
}

class RelatedRecordsException implements Exception {
  final int count;
  final String relation;
  const RelatedRecordsException(this.count, this.relation);
  @override
  String toString() =>
      'Нельзя удалить запись: связанных записей ($relation) — $count. Сначала измените или удалите связи.';
}

class StorageException implements Exception {
  final String message;
  const StorageException(this.message);
  @override
  String toString() => message;
}
