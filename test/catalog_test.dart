import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cosmetics/models/catalog_query.dart';
import 'package:cosmetics/models/product.dart';
import 'package:cosmetics/models/page_result.dart';
import 'package:cosmetics/repositories/product_repository.dart';
import 'package:cosmetics/repositories/brand_repository.dart';
import 'package:cosmetics/repositories/seed_data.dart';
import 'package:cosmetics/state/catalog_notifier.dart';
import 'package:cosmetics/state/load_state.dart';

class DelayedRepository extends InMemoryProductRepository {
  final requests = <Completer<PageResult<Product>>>[];
  @override
  Future<PageResult<Product>> find(CatalogQuery query) {
    final request = Completer<PageResult<Product>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test('Комбинируются поиск, категория, бренд и границы цены', () async {
    final repo = InMemoryProductRepository(latency: Duration.zero);
    final result = await repo.find(
      const CatalogQuery(
        search: 'крем',
        categoryId: 1,
        brandId: 1,
        minPrice: 1800,
        maxPrice: 2000,
      ),
    );
    expect(result.items.map((p) => p.id), [1]);
    expect(
      (await repo.find(const CatalogQuery(search: 'cos-0001'))).items.single.id,
      1,
    );
    expect(
      (await repo.find(const CatalogQuery(search: 'несуществующее'))).total,
      0,
    );
  });
  test('Сортировка, страницы и коррекция номера за пределами списка', () async {
    final repo = InMemoryProductRepository(latency: Duration.zero);
    final first = await repo.find(
      const CatalogQuery(sortField: 'price', ascending: false),
    );
    expect(first.total, 30);
    expect(first.items.length, 10);
    expect(first.items.first.priceKopecks, 249000);
    expect(first.hasNext, true);
    final last = await repo.find(const CatalogQuery(page: 999));
    expect(last.page, 3);
    expect(last.hasNext, false);
    expect((await repo.find(const CatalogQuery(size: 25))).items.length, 25);
  });
  test(
    'deleteMany игнорирует дубликаты, отсутствующие и уже удалённые записи',
    () async {
      final repo = InMemoryProductRepository(latency: Duration.zero);
      final original = await repo.findById(1);
      expect(await repo.deleteMany([1, 1, 2, 999]), 2);
      expect(original!.deletedAt, isNull);
      expect(await repo.deleteMany([1, 2]), 0);
      expect((await repo.find(const CatalogQuery())).total, 28);
      expect(
        (await repo.find(const CatalogQuery(includeDeleted: true))).total,
        30,
      );
      await repo.restore(1);
      expect((await repo.findById(1))!.isDeleted, false);
      await repo.hardDelete(2);
      expect(await repo.findById(2), isNull);
    },
  );
  test(
    'Создание и изменение выполняются через репозиторий с новым id',
    () async {
      final repo = InMemoryProductRepository(latency: Duration.zero);
      final created = await repo.create(
        seedProducts.first.copyWith(name: 'Новый товар'),
      );
      expect(created.id, 31);
      await repo.update(created.copyWith(stock: 99));
      expect((await repo.findById(31))!.stock, 99);
      expect(seedProducts.first.stock, 24);
    },
  );
  test(
    'Бренды: поиск по стране, сортировка, удаление и восстановление',
    () async {
      final repo = InMemoryBrandRepository(latency: Duration.zero);
      expect(
        (await repo.find(const CatalogQuery(search: 'корея')))
            .items
            .single
            .name,
        'COSRX',
      );
      expect(
        (await repo.find(const CatalogQuery(sortField: 'foundedYear')))
            .items
            .first
            .id,
        2,
      );
      await repo.softDelete(1);
      expect((await repo.find(const CatalogQuery())).total, 7);
      await repo.restore(1);
      expect((await repo.find(const CatalogQuery())).total, 8);
    },
  );
  test(
    'URL восстанавливает все параметры; изменение фильтра сбрасывает страницу',
    () {
      const query = CatalogQuery(
        search: 'крем & масло',
        categoryId: 1,
        brandId: 3,
        minPrice: 500,
        maxPrice: 2000,
        sortField: 'price',
        ascending: false,
        page: 3,
        size: 25,
        onlyDeleted: true,
      );
      final restored = CatalogQuery.fromUri(
        Uri.parse(query.location('/products')),
      );
      expect(restored.location('/products'), query.location('/products'));
      expect(query.copyWith(search: 'масло').page, 1);
      expect(query.copyWith(brandId: null).brandId, isNull);
      expect(query.copyWith().brandId, 3);
      final invalid = CatalogQuery.fromUri(
        Uri.parse('/products?page=-4&size=0&sort=bad,asc'),
      );
      expect(invalid.page, 1);
      expect(invalid.size, 10);
      expect(invalid.sortField, 'name');
    },
  );
  test('Notifier очищает выделение, обрабатывает ошибку и повтор', () async {
    final n = CatalogNotifier(
      InMemoryProductRepository(latency: Duration.zero),
    );
    await n.load();
    n.toggleSelection(1);
    await n.applyQuery(const CatalogQuery(search: 'крем'));
    expect(n.selected, isEmpty);
    await n.load(simulateError: true);
    expect(n.state, isA<Failed<PageResult<Product>>>());
    await n.load();
    expect(n.state, isA<Loaded<PageResult<Product>>>());
    n.dispose();
  });
  test('Устаревший запрос и завершение после dispose безопасны', () async {
    final repo = DelayedRepository();
    final n = CatalogNotifier<Product>(repo);
    final old = n.applyQuery(const CatalogQuery(search: 'старый'));
    final latest = n.applyQuery(const CatalogQuery(search: 'новый'));
    repo.requests[1].complete(
      PageResult(items: [seedProducts[1]], page: 1, size: 10, total: 1),
    );
    await latest;
    repo.requests[0].complete(
      PageResult(items: [seedProducts[0]], page: 1, size: 10, total: 1),
    );
    await old;
    expect((n.state as Loaded<PageResult<Product>>).data.items.single.id, 2);
    final pending = n.load();
    n.dispose();
    repo.requests[2].complete(
      PageResult(items: [], page: 1, size: 10, total: 0),
    );
    await pending;
  });
}
