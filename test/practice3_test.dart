import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cosmetics/core/validators.dart';
import 'package:cosmetics/core/validation_exception.dart';
import 'package:cosmetics/models/catalog_entity.dart';
import 'package:cosmetics/models/catalog_query.dart';
import 'package:cosmetics/models/entity_kind.dart';
import 'package:cosmetics/models/product.dart';
import 'package:cosmetics/models/brand.dart';
import 'package:cosmetics/models/category.dart';
import 'package:cosmetics/models/supplier.dart';
import 'package:cosmetics/models/customer.dart';
import 'package:cosmetics/models/loyalty_card.dart';
import 'package:cosmetics/repositories/shop_database.dart';
import 'package:cosmetics/repositories/persistent_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Все модели переносят отсутствующие/null/неверные значения JSON', () {
    for (final kind in EntityKind.values) {
      final e = kind.decode({
        'id': null,
        'name': null,
        'categoryIds': [null, '2', 'bad'],
        'card': null,
        'deletedAt': 'wrong',
      });
      expect(e.id, 0);
      expect(e.name, '');
      expect(e.deletedAt, isNull);
      expect(kind.decode(e.toJson()).toJson(), e.toJson());
    }
    expect(LoyaltyCard.fromJson({}).toJson()['points'], 0);
    final p = Product.fromJson({'id': '12', 'categoryId': 2});
    expect(p.id, 12);
    expect(p.categoryIds, [2]);
    expect(() => p.categoryIds.add(3), throwsUnsupportedError);
  });
  test(
    'Валидаторы проверяют обязательность, число, деньги, почту и телефон',
    () {
      expect(V.required()('  '), isNotNull);
      expect(V.text()('Я'), isNotNull);
      expect(V.integer(min: 1)('0'), isNotNull);
      expect(V.integer()('1.5'), isNotNull);
      expect(V.price()('-10'), isNotNull);
      expect(V.price()('1.234'), isNotNull);
      expect(V.kopecks('12,34'), 1234);
      expect(V.kopecks('0.01'), 1);
      expect(V.email()('a@b'), isNotNull);
      expect(V.email()('ann@example.com'), isNull);
      expect(V.phone()('123'), isNotNull);
      expect(V.phone()('+7 900 111-22-33'), isNull);
    },
  );
  test(
    'CRUD всех пяти сущностей сохраняется и удалённые восстанавливаются',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final db = await ShopDatabase.open(prefs);
      final examples = <EntityKind, CatalogEntity>{
        EntityKind.products: db
            .rows<Product>(EntityKind.products)
            .first
            .copyWith(id: 0, sku: 'NEW-001', categoryIds: [1, 3]),
        EntityKind.brands: const Brand(
          id: 0,
          name: 'Новый бренд',
          country: 'Россия',
          foundedYear: 2020,
          description: 'Описание нового бренда',
        ),
        EntityKind.categories: const Category(
          0,
          'Новая категория',
          description: 'Описание',
        ),
        EntityKind.suppliers: Supplier(
          id: 0,
          name: 'Новый поставщик',
          city: 'Москва',
          email: 'new@example.com',
          phone: '+7 900 111-22-33',
          brandIds: [1],
        ),
        EntityKind.customers: Customer(
          id: 0,
          name: 'Новый покупатель',
          email: 'new@example.com',
          phone: '+7 900 111-22-33',
          card: LoyaltyCard(
            number: 'LC-NEW',
            issuedAt: DateTime(2026, 1, 1),
            expiresAt: DateTime(2029, 1, 1),
            points: 10,
          ),
        ),
      };
      for (final entry in examples.entries) {
        final repo = PersistentRepository<CatalogEntity>(
          db,
          entry.key,
          latency: Duration.zero,
        );
        expect(
          (await repo.find(const CatalogQuery(onlyDeleted: true))).total,
          0,
        );
        final created = await repo.create(entry.value);
        final changed = await repo.update(
          entry.key.decode({...created.toJson(), 'name': 'Изменённая запись'}),
        );
        expect(changed.name, 'Изменённая запись');
        await repo.softDelete(created.id);
        expect((await repo.findById(created.id))!.isDeleted, true);
        expect(
          (await repo.find(const CatalogQuery(search: 'Изменённая'))).total,
          0,
        );
        final deleted = await repo.find(const CatalogQuery(onlyDeleted: true));
        expect(deleted.items.map((e) => e.id), [created.id]);
        await repo.restore(created.id);
        expect(
          (await repo.find(const CatalogQuery(onlyDeleted: true))).total,
          0,
        );
        expect((await repo.findById(created.id))!.isDeleted, false);
        final restored = await ShopDatabase.open(prefs);
        expect(
          restored
              .rows<CatalogEntity>(entry.key)
              .any((e) => e.id == created.id && e.name == 'Изменённая запись'),
          true,
        );
        restored.dispose();
        await repo.hardDelete(created.id);
        expect(await repo.findById(created.id), isNull);
      }
      db.dispose();
    },
  );
  test('Уникальность артикула и почты проверяется без учёта регистра, редактирование себя допустимо', () async {
    final db = ShopDatabase.memory();
    final products = PersistentProductRepository(db);
    final p = db.rows<Product>(EntityKind.products).first;
    await expectLater(
      products.create(p.copyWith(id: 0, sku: p.sku.toLowerCase())),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors.containsKey('sku'),
          'sku',
          true,
        ),
      ),
    );
    await products.update(p.copyWith(stock: 3));
    final customers = PersistentRepository<Customer>(db, EntityKind.customers);
    final c = db.rows<Customer>(EntityKind.customers).first;
    await expectLater(
      customers.create(
        c.copyWith(
          id: 0,
          email: c.email.toUpperCase(),
          card: c.card.copyWith(number: 'OTHER'),
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors.containsKey('email'),
          'email',
          true,
        ),
      ),
    );
    await expectLater(
      customers.create(c.copyWith(id: 0, email: 'other@example.com')),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors.containsKey('card.number'),
          'card',
          true,
        ),
      ),
    );
    await customers.update(c.copyWith(name: 'Другое имя'));
    db.dispose();
  });
  test(
    'Поставщик с товарами не удаляется; групповое удаление атомарно',
    () async {
      final db = ShopDatabase.memory();
      final repo = PersistentRepository<Supplier>(db, EntityKind.suppliers);
      final expected = db
          .rows<Product>(EntityKind.products)
          .where((p) => p.supplierId == 1)
          .length;
      await expectLater(
        repo.softDelete(1),
        throwsA(
          isA<RelatedRecordsException>().having(
            (e) => e.count,
            'count',
            expected,
          ),
        ),
      );
      await expectLater(
        repo.hardDelete(1),
        throwsA(isA<RelatedRecordsException>()),
      );
      final free = await repo.create(
        Supplier(
          id: 0,
          name: 'Без товаров',
          city: 'Москва',
          email: 'free@example.com',
          phone: '+7 900 111-22-33',
          brandIds: [1],
        ),
      );
      await expectLater(
        repo.deleteMany([free.id, 1]),
        throwsA(isA<RelatedRecordsException>()),
      );
      expect((await repo.findById(free.id))!.isDeleted, false);
      db.dispose();
    },
  );
  test('Каскадные связи проверяются и в репозитории, удаление используемой категории запрещено', () async {
    final db = ShopDatabase.memory();
    final repo = PersistentProductRepository(db);
    final p = db.rows<Product>(EntityKind.products).first;
    await expectLater(
      repo.update(p.copyWith(supplierId: 3)),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors.containsKey('brandId'),
          'brandId',
          true,
        ),
      ),
    );
    final categories = PersistentRepository<Category>(
      db,
      EntityKind.categories,
    );
    await expectLater(
      categories.hardDelete(1),
      throwsA(isA<RelatedRecordsException>()),
    );
    await repo.update(p.copyWith(categoryIds: [1, 3]));
    expect(
      (await repo.find(const CatalogQuery(categoryId: 3, search: 'COS-0001')))
          .total,
      1,
    );
    db.dispose();
  });
  test(
    'Повреждённое хранилище восстанавливается с сообщением и резервной копией',
    () async {
      SharedPreferences.setMockInitialValues({
        ShopDatabase.storageKey: '{broken',
      });
      final prefs = await SharedPreferences.getInstance();
      final db = await ShopDatabase.open(prefs);
      expect(db.notice, isNotNull);
      expect(db.rows<Product>(EntityKind.products).length, 30);
      expect(prefs.getString('${ShopDatabase.storageKey}_recovery'), '{broken');
      expect(
        jsonDecode(prefs.getString(ShopDatabase.storageKey)!)['schemaVersion'],
        2,
      );
      db.dispose();
    },
  );
  test('Смена версии сохраняет старый ключ и показывает сообщение', () async {
    SharedPreferences.setMockInitialValues({'cosmetics_shop_v1': 'old-data'});
    final prefs = await SharedPreferences.getInstance();
    final db = await ShopDatabase.open(prefs);
    expect(db.notice, contains('версии 2'));
    expect(prefs.getString('cosmetics_shop_v1'), 'old-data');
    db.dispose();
  });
  test('Параллельные сохранения не теряют записи; ID после перезагрузки не переиспользуются', () async {
    final prefs = await SharedPreferences.getInstance();
    final db = await ShopDatabase.open(prefs);
    final repo = PersistentRepository<Category>(db, EntityKind.categories);
    final created = await Future.wait([
      repo.create(const Category(0, 'Первая новая')),
      repo.create(const Category(0, 'Вторая новая')),
    ]);
    expect(created.map((e) => e.id).toSet().length, 2);
    final last = created.last.id;
    await repo.hardDelete(last);
    final reopened = await ShopDatabase.open(prefs);
    final next = await PersistentRepository<Category>(
      reopened,
      EntityKind.categories,
    ).create(const Category(0, 'Третья новая'));
    expect(next.id, greaterThan(last));
    db.dispose();
    reopened.dispose();
  });
  test('Фильтры и сортировка новых списков', () async {
    final db = ShopDatabase.memory();
    expect(
      (await PersistentRepository<Brand>(
        db,
        EntityKind.brands,
      ).find(const CatalogQuery(filter: 'Франция'))).total,
      4,
    );
    expect(
      (await PersistentRepository<Supplier>(
        db,
        EntityKind.suppliers,
      ).find(const CatalogQuery(filter: 'Москва'))).total,
      1,
    );
    expect(
      (await PersistentRepository<Category>(
        db,
        EntityKind.categories,
      ).find(const CatalogQuery(filter: 'used'))).total,
      5,
    );
    final result =
        await PersistentRepository<Customer>(db, EntityKind.customers).find(
          const CatalogQuery(
            filter: 'active',
            sortField: 'points',
            ascending: false,
          ),
        );
    expect(result.total, 12);
    expect(result.items.first.card.points, 1200);
    expect(result.totalPages, 2);
    db.dispose();
  });
  test('Неверный тип значения хранилища не ломает запуск', () async {
    SharedPreferences.setMockInitialValues({ShopDatabase.storageKey: 42});
    final prefs = await SharedPreferences.getInstance();
    final db = await ShopDatabase.open(prefs);
    expect(db.notice, isNotNull);
    expect(db.rows<Product>(EntityKind.products).length, 30);
    expect(prefs.getString('${ShopDatabase.storageKey}_recovery'), '42');
    db.dispose();
  });
}
