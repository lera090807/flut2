import 'package:flutter/foundation.dart';

import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../repositories/catalog_repository.dart';
import '../core/validation_exception.dart';
import 'catalog_reference.dart';
import 'load_state.dart';
import '../core/api_exceptions.dart';

class EditorNotifier extends ChangeNotifier {
  final EntityKind kind;
  final CatalogRepository<CatalogEntity> _repository;
  final CatalogReference reference;
  final int? id;
  EditorNotifier(this.kind, this._repository, this.reference, this.id);
  LoadState<CatalogEntity?> state = const Loading();
  bool saving = false;
  bool _disposed = false;
  Map<String, String> errors = {};
  String? saveError;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    state = const Loading();
    _notify();
    try {
      await reference.load();
      if (reference.error != null) throw StateError(reference.error!);
      final entity = id == null ? null : await _repository.findById(id!);
      if (!_disposed) state = Loaded(entity);
    } catch (_) {
      if (!_disposed) {
        state = const Failed('Не удалось загрузить форму и справочники');
      }
    }
    _notify();
  }

  void clearError(String key) {
    if (errors.remove(key) != null || saveError != null) {
      saveError = null;
      _notify();
    }
  }

  Future<CatalogEntity?> save(CatalogEntity entity) async {
    if (saving) return null;
    saving = true;
    errors = {};
    saveError = null;
    _notify();
    try {
      final saved = id == null
          ? await _repository.create(entity)
          : await _repository.update(entity);
      await reference.load();
      return saved;
    } on ValidationException catch (e) {
      errors = e.errors;
    } on ApiException catch (e) {
      saveError = e.message;
    } on StorageException catch (e) {
      saveError = e.message;
    } catch (_) {
      saveError = 'Не удалось сохранить запись. Попробуйте ещё раз.';
    } finally {
      saving = false;
      _notify();
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
