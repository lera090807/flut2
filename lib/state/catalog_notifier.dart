import 'package:flutter/foundation.dart';

import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/page_result.dart';
import '../repositories/catalog_repository.dart';
import 'load_state.dart';
import '../core/api_exceptions.dart';
import '../repositories/api_repository.dart';

class CatalogNotifier<T extends CatalogEntity> extends ChangeNotifier {
  final CatalogRepository<T> _repository;
  final void Function()? refreshReferences;
  CatalogNotifier(this._repository, {this.refreshReferences});
  CatalogQuery _query = const CatalogQuery();
  CatalogQuery get query => _query;
  LoadState<PageResult<T>> _state = const Loading();
  LoadState<PageResult<T>> get state => _state;
  final Set<int> _selected = {};
  Set<int> get selected => Set.unmodifiable(_selected);
  bool _disposed = false;
  bool _busy = false;
  bool get busy => _busy;
  int _request = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> applyQuery(CatalogQuery query) async {
    _query = query;
    _selected.clear();
    await load();
  }

  Future<void> load({bool simulateError = false}) async {
    refreshReferences?.call();
    final request = ++_request;
    final query = _query;
    _state = const Loading();
    _notify();
    try {
      if (simulateError && _repository is! CancellableRepository) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        throw StateError('Учебная имитация ошибки загрузки');
      }
      final result = await _repository.find(
        simulateError ? query.copyWith(debugFail: 500) : query,
      );
      if (_disposed || request != _request) return;
      _state = Loaded(result);
    } catch (e) {
      if (_disposed || request != _request) return;
      _state = Failed(
        simulateError && _repository is! CancellableRepository
            ? 'Вот пример ошибки загрузки. Нажмите «Повторить», чтобы вернуть каталог.'
            : e is ApiException
            ? e.message
            : 'Не удалось загрузить каталог. Попробуйте ещё раз.',
      );
    }
    _notify();
  }

  void toggleSelection(int id) {
    if (_busy) return;
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _notify();
  }

  void selectAll(Iterable<int> ids, bool selected) {
    if (_busy) return;
    selected ? _selected.addAll(ids) : _selected.removeAll(ids);
    _notify();
  }

  Future<int> deleteSelected() async {
    if (_busy) return 0;
    _busy = true;
    _notify();
    try {
      final count = await _repository.deleteMany(_selected.toList());
      _selected.clear();
      await load();
      return count;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> mutate(int id, String action) async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      switch (action) {
        case 'restore':
          await _repository.restore(id);
        case 'hard':
          await _repository.hardDelete(id);
        default:
          await _repository.softDelete(id);
      }
      _selected.remove(id);
      await load();
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    if (_repository case CancellableRepository r) {
      r.cancelPending();
    }
    _disposed = true;
    _request++;
    super.dispose();
  }
}
