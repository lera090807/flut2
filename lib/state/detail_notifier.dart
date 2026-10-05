import 'package:flutter/foundation.dart';

import '../models/catalog_entity.dart';
import '../repositories/catalog_repository.dart';
import 'load_state.dart';
import '../core/api_exceptions.dart';

class DetailNotifier<T extends CatalogEntity> extends ChangeNotifier {
  final CatalogRepository<T> _repository;
  final int id;
  DetailNotifier(this._repository, this.id);
  LoadState<T?> state = const Loading();
  bool _disposed = false;
  Future<void> load() async {
    state = const Loading();
    if (!_disposed) notifyListeners();
    try {
      final item = await _repository.findById(id);
      if (_disposed) return;
      state = Loaded(item);
    } catch (e) {
      if (_disposed) return;
      state = Failed(
        e is ApiException ? e.message : 'Не удалось загрузить карточку',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
