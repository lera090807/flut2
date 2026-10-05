import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/entity_kind.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/brand.dart';
import 'catalog_repository.dart';
import 'product_repository.dart';
import 'brand_repository.dart';
abstract interface class CancellableRepository {
  void cancelPending();
}

class ApiRepository<T extends CatalogEntity>
    implements CatalogRepository<T>, CancellableRepository {
  final Dio dio;
  final EntityKind kind;
  final void Function(EntityKind)? onChanged;
  final Duration retryDelay;
  CancelToken? _listToken;
  ApiRepository(
    this.dio,
    this.kind, {
    this.onChanged,
    this.retryDelay = const Duration(milliseconds: 300),
  });
  @override
  void cancelPending() {
    _listToken?.cancel('Устаревший запрос');
    _listToken = null;
  }

  Future<R> _guard<R>(
    Future<R> Function() action, {
    bool read = false,
    CancelToken? token,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (token?.isCancelled == true) throw const RequestCancelledException();
      try {
        return await action();
      } on DioException catch (e) {
        final error = mapDioError(e);
        if (!read || error is! NetworkException || attempt >= 2) throw error;
        await Future<void>.delayed(retryDelay * (1 << attempt));
      } on FormatException {
        throw const ServerException('Сервер вернул некорректные данные.');
      }
    }
  }

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }

  T _decode(dynamic value) => kind.decode(_object(value)) as T;
  @override
  Future<PageResult<T>> find(CatalogQuery q) {
    CancelToken? token;
    if (!q.includeDeleted) {
      cancelPending();
      token = _listToken = CancelToken();
    }
    return _guard(
      () async {
        final response = await dio.get(
          kind.path,
          queryParameters: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            if (q.filter.isNotEmpty) 'filter': q.filter,
            if (q.categoryId != null) 'categoryId': q.categoryId,
            if (q.brandId != null) 'brandId': q.brandId,
            if (q.minPrice != null) 'minPrice': q.minPrice,
            if (q.maxPrice != null) 'maxPrice': q.maxPrice,
            'sort': '${q.sortField},${q.ascending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,
            if (q.onlyDeleted) 'onlyDeleted': true,
            if (q.debugFail != null) '__fail': q.debugFail,
            if (q.debugDelay != null) '__delay': q.debugDelay,
          },
          cancelToken: token,
        );
        final data = _object(response.data);
        if (data['items'] is! List ||
            data['page'] is! int ||
            data['size'] is! int ||
            data['total'] is! int ||
            data['size'] <= 0 ||
            data['page'] < 1 ||
            data['total'] < 0) {
          throw const FormatException();
        }
        return PageResult<T>(
          items: (data['items'] as List).map(_decode).toList(),
          page: data['page'],
          size: data['size'],
          total: data['total'],
        );
      },
      read: true,
      token: token,
    );
  }

  @override
  Future<T?> findById(int id) async {
    try {
      return await _guard(
        () async => _decode((await dio.get('${kind.path}/$id')).data),
        read: true,
      );
    } on NotFoundException {
      return null;
    }
  }

  Map<String, dynamic> _input(T entity) {
    final data = Map<String, dynamic>.from(entity.toJson())
      ..remove('id')
      ..remove('deletedAt')
      ..remove('productCount');
    if (data['card'] is Map) {
      data['card'] = Map<String, dynamic>.from(data['card'])..remove('id');
    }
    return data;
  }

  Future<R> _write<R>(Future<R> Function() action) async {
    final result = await _guard(action);
    onChanged?.call(kind);
    return result;
  }

  @override
  Future<T> create(T entity) => _write(
    () async => _decode((await dio.post(kind.path, data: _input(entity))).data),
  );
  @override
  Future<T> update(T entity) => _write(
    () async => _decode(
      (await dio.put('${kind.path}/${entity.id}', data: _input(entity))).data,
    ),
  );
  @override
  Future<void> softDelete(int id) => _write(() async {
    await dio.delete('${kind.path}/$id');
  });
  @override
  Future<void> hardDelete(int id) => _write(() async {
    await dio.delete('${kind.path}/$id', queryParameters: {'hard': true});
  });
  @override
  Future<void> restore(int id) => _write(() async {
    await dio.post('${kind.path}/$id/restore', data: {});
  });
  @override
  Future<int> deleteMany(List<int> ids) => _write(() async {
    final data = _object(
      (await dio.post('${kind.path}/bulk-delete', data: {'ids': ids})).data,
    );
    if (data['deleted'] is! int) throw const FormatException();
    return data['deleted'] as int;
  });
}

class ApiProductRepository extends ApiRepository<Product>
    implements ProductRepository {
  ApiProductRepository(Dio dio, {super.onChanged, super.retryDelay})
    : super(dio, EntityKind.products);
}

class ApiBrandRepository extends ApiRepository<Brand>
    implements BrandRepository {
  ApiBrandRepository(Dio dio, {super.onChanged, super.retryDelay})
    : super(dio, EntityKind.brands);
}
