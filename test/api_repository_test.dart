import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmetics/core/api_client.dart';
import 'package:cosmetics/core/api_exceptions.dart';
import 'package:cosmetics/core/validation_exception.dart';
import 'package:cosmetics/models/catalog_query.dart';
import 'package:cosmetics/models/entity_kind.dart';
import 'package:cosmetics/models/catalog_entity.dart';
import 'package:cosmetics/repositories/api_repository.dart';
import 'package:cosmetics/repositories/catalog_repository.dart';
import 'package:cosmetics/repositories/seed_data.dart';
import 'package:cosmetics/state/catalog_reference.dart';

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) answer;
  Adapter(this.answer);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => answer(options, cancelFuture);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
void main() {
  late Dio dio;
  late ApiProductRepository repo;
  setUp(() {
    dio = buildDio(baseUrl: 'http://example.test/api');
    repo = ApiProductRepository(dio, retryDelay: Duration.zero);
  });
  tearDown(() => dio.close(force: true));
  test('server page + query parameters + expanded relationships', () async {
    dio.httpClientAdapter = Adapter((q, _) async {
      expect(q.path, '/products');
      expect(q.queryParameters['page'], 2);
      expect(q.queryParameters['search'], 'крем');
      expect(q.queryParameters['sort'], 'price,desc');
      expect(q.queryParameters['onlyDeleted'], true);
      return response({
        'items': [
          {
            'id': 12,
            'name': 'Крем',
            'brand': {'id': 7},
            'supplier': {'id': 1},
            'categories': [
              {'id': 1},
              {'id': 3},
            ],
          },
        ],
        'page': 2,
        'size': 10,
        'total': 12,
      });
    });
    final page = await repo.find(
      const CatalogQuery(
        search: ' крем ',
        page: 2,
        sortField: 'price',
        ascending: false,
        onlyDeleted: true,
      ),
    );
    expect(page.total, 12);
    expect(page.page, 2);
    expect(page.items.single.brandId, 7);
    expect(page.items.single.categoryIds, [1, 3]);
  });
  test('422 survives interceptor and reaches exact form field', () async {
    dio.httpClientAdapter = Adapter(
      (_, _) async => response({
        'message': 'Ошибка валидации',
        'errors': {'sku': 'Занят'},
      }, 422),
    );
    await expectLater(
      repo.create(seedProducts.first),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['sku'],
          'field',
          'Занят',
        ),
      ),
    );
  });
  test('network read retries at most three attempts', () async {
    var n = 0;
    dio.httpClientAdapter = Adapter((q, _) async {
      n++;
      throw DioException(
        requestOptions: q,
        type: DioExceptionType.connectionError,
      );
    });
    await expectLater(
      repo.find(const CatalogQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(n, 3);
  });
  test('successful read after temporary network failure', () async {
    var n = 0;
    dio.httpClientAdapter = Adapter((q, _) async {
      if (++n < 3) {
        throw DioException(
          requestOptions: q,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return response({'items': [], 'page': 1, 'size': 10, 'total': 0});
    });
    expect((await repo.find(const CatalogQuery())).total, 0);
    expect(n, 3);
  });
  test(
    'mutation is never retried, sends IDs instead of expanded objects',
    () async {
      var n = 0;
      dio.httpClientAdapter = Adapter((q, _) async {
        n++;
        expect(q.method, 'POST');
        expect(q.data['brandId'], 1);
        expect(q.data.containsKey('id'), false);
        expect(q.data.containsKey('deletedAt'), false);
        throw DioException(
          requestOptions: q,
          type: DioExceptionType.connectionError,
        );
      });
      await expectLater(
        repo.create(seedProducts.first),
        throwsA(isA<NetworkException>()),
      );
      expect(n, 1);
    },
  );
  test('404 null, 409 meaningful conflict, 401/403/500 typed errors', () async {
    for (final code in [404, 409, 401, 403, 500]) {
      var n = 0;
      dio.httpClientAdapter = Adapter((_, _) async {
        n++;
        return response({'message': 'Причина'}, code);
      });
      if (code == 404) {
        expect(await repo.findById(123), isNull);
      } else {
        await expectLater(
          repo.findById(123),
          throwsA(switch (code) {
            409 => isA<ConflictException>(),
            401 => isA<UnauthorizedException>(),
            403 => isA<ForbiddenException>(),
            _ => isA<ServerException>(),
          }),
        );
      }
      expect(n, 1);
    }
  });
  test('new search cancels old request using CancelToken, no retry', () async {
    final started = Completer<void>();
    var cancelled = false;
    var n = 0;
    dio.httpClientAdapter = Adapter((q, cancel) async {
      n++;
      if (q.queryParameters['search'] == 'old') {
        started.complete();
        await cancel;
        cancelled = true;
        throw DioException(requestOptions: q, type: DioExceptionType.cancel);
      }
      return response({'items': [], 'page': 1, 'size': 10, 'total': 0});
    });
    final old = repo.find(const CatalogQuery(search: 'old'));
    final checked = expectLater(old, throwsA(isA<RequestCancelledException>()));
    await started.future;
    await repo.find(const CatalogQuery(search: 'new'));
    await checked;
    expect(cancelled, true);
    expect(n, 2);
  });
  test('all CRUD routes and invalidation after successful writes', () async {
    final methods = <String>[];
    var invalidations = 0;
    final r = ApiProductRepository(dio, onChanged: (_) => invalidations++);
    dio.httpClientAdapter = Adapter((q, _) async {
      methods.add('${q.method} ${q.path}');
      if (q.method == 'DELETE') return ResponseBody.fromString('', 204);
      if (q.path.endsWith('bulk-delete')) return response({'deleted': 2});
      return response(seedProducts.first.toJson());
    });
    await r.create(seedProducts.first);
    await r.update(seedProducts.first);
    await r.softDelete(1);
    await r.hardDelete(1);
    await r.restore(1);
    expect(await r.deleteMany([1, 2]), 2);
    expect(invalidations, 6);
    expect(methods, [
      'POST /products',
      'PUT /products/1',
      'DELETE /products/1',
      'DELETE /products/1',
      'POST /products/1/restore',
      'POST /products/bulk-delete',
    ]);
  });
  test(
    'reference cache coalesces requests; never downloads products/customers',
    () async {
      final paths = <String>[];
      dio.httpClientAdapter = Adapter((q, _) async {
        paths.add(q.path);
        return response({
          'items': switch (q.path) {
            '/brands' => seedBrands.map((e) => e.toJson()).toList(),
            '/suppliers' => seedSuppliers.map((e) => e.toJson()).toList(),
            _ => seedCategories.map((e) => e.toJson()).toList(),
          },
          'page': 1,
          'size': 50,
          'total': 1,
        });
      });
      final repositories = <EntityKind, CatalogRepository<CatalogEntity>>{
        for (final k in EntityKind.values)
          k: ApiRepository<CatalogEntity>(dio, k),
      };
      final ref = CatalogReference(repositories, cache: true);
      await Future.wait([ref.load(), ref.load()]);
      await ref.load();
      expect(paths.length, 3);
      expect(paths, containsAll(['/brands', '/categories', '/suppliers']));
      expect(ref.products, isEmpty);
      ref.invalidate(EntityKind.brands);
      await ref.load();
      expect(paths.length, 6);
      ref.dispose();
    },
  );
  test('malformed response becomes domain error rather than crash', () async {
    dio.httpClientAdapter = Adapter(
      (_, _) async => response({'items': 'broken'}),
    );
    await expectLater(
      repo.find(const CatalogQuery()),
      throwsA(isA<ServerException>()),
    );
  });
}
