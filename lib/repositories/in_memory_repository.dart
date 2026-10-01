import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/page_result.dart';
import 'catalog_repository.dart';

abstract class InMemoryRepository<T extends CatalogEntity>
    implements CatalogRepository<T> {
  final List<T> _rows;
  final Duration latency;
  late int _nextId;
  InMemoryRepository(
    List<T> seed, {
    this.latency = const Duration(milliseconds: 250),
  }) : _rows = List.of(seed) {
    _nextId = _rows.fold<int>(0, (n, e) => e.id > n ? e.id : n) + 1;
  }
  bool matches(T entity, CatalogQuery query);
  int compare(T a, T b, String field);
  T withId(T entity, int id);
  T withDeletedAt(T entity, DateTime? value);
  void validate(T entity) {}

  @override
  Future<PageResult<T>> find(CatalogQuery query) async {
    await Future<void>.delayed(latency);
    if (query.page < 1 || ![10, 25, 50].contains(query.size)) {
      throw ArgumentError('Некорректные параметры страницы');
    }
    final rows = _rows
        .where(
          (e) =>
              (query.onlyDeleted
                  ? e.isDeleted
                  : (query.includeDeleted || !e.isDeleted)) &&
              matches(e, query),
        )
        .toList();
    rows.sort((a, b) {
      final value = compare(a, b, query.sortField);
      final stable = value == 0 ? a.id.compareTo(b.id) : value;
      return query.ascending ? stable : -stable;
    });
    final pages = rows.isEmpty ? 1 : (rows.length / query.size).ceil();
    final page = query.page > pages ? pages : query.page;
    final from = (page - 1) * query.size;
    final to = from + query.size > rows.length
        ? rows.length
        : from + query.size;
    return PageResult(
      items: rows.sublist(from, to),
      page: page,
      size: query.size,
      total: rows.length,
    );
  }

  @override
  Future<T?> findById(int id) async {
    await Future<void>.delayed(latency);
    // Удалённые доступны в карточке для просмотра и восстановления.
    return _rows.where((e) => e.id == id).firstOrNull;
  }

  @override
  Future<T> create(T entity) async {
    validate(entity);
    final created = withId(entity, _nextId++);
    _rows.add(created);
    return created;
  }

  @override
  Future<T> update(T entity) async {
    final i = _index(entity.id);
    validate(entity);
    _rows[i] = entity;
    return entity;
  }

  int _index(int id) {
    final i = _rows.indexWhere((e) => e.id == id);
    if (i < 0) throw StateError('Запись $id не найдена');
    return i;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _index(id);
    if (!_rows[i].isDeleted) _rows[i] = withDeletedAt(_rows[i], DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async => _rows.removeAt(_index(id));
  @override
  Future<void> restore(int id) async {
    final i = _index(id);
    _rows[i] = withDeletedAt(_rows[i], null);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids.toSet()) {
      // В образце b[i] ошибочно обращался к сущности как к массиву.
      final i = _rows.indexWhere(
        (entity) => entity.id == id && !entity.isDeleted,
      );
      if (i != -1) {
        _rows[i] = withDeletedAt(_rows[i], DateTime.now());
        count++;
      }
    }
    return count;
  }
}
