import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/json_values.dart';
import '../models/product.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/customer.dart';
import '../core/validators.dart';
import '../core/validation_exception.dart';
import 'seed_data.dart';

typedef ShopRows = Map<EntityKind, List<CatalogEntity>>;

class ShopDatabase extends ChangeNotifier {
  static const storageKey = 'cosmetics_shop_v2';
  static const schemaVersion = 2;
  final SharedPreferences? _prefs;
  ShopRows _rows;
  Map<EntityKind, int> _sequences = {};
  String? notice;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  ShopDatabase.memory() : _prefs = null, _rows = _seed() {
    _initSequences();
  }
  ShopDatabase._(this._prefs, this._rows) {
    _initSequences();
  }
  static ShopRows _seed() => {
    EntityKind.products: List.of(seedProducts),
    EntityKind.brands: List.of(seedBrands),
    EntityKind.categories: List.of(seedCategories),
    EntityKind.suppliers: List.of(seedSuppliers),
    EntityKind.customers: List.of(seedCustomers),
  };
  void _initSequences() {
    _sequences = {
      for (final kind in EntityKind.values)
        kind: _rows[kind]!.fold<int>(0, (n, e) => e.id > n ? e.id : n) + 1,
    };
  }

  static Future<ShopDatabase> open(SharedPreferences prefs) async {
    final db = ShopDatabase._(prefs, _seed());
    final rawValue = prefs.get(storageKey);
    final raw = rawValue is String
        ? rawValue
        : rawValue == null
        ? null
        : jsonEncode(rawValue);
    if (raw != null) {
      try {
        final root = jsonMap(jsonDecode(raw));
        if (jsonInt(root['schemaVersion']) != schemaVersion) {
          throw const FormatException('schema');
        }
        final restored = <EntityKind, List<CatalogEntity>>{};
        for (final kind in EntityKind.values) {
          final list = root[kind.name];
          if (list is! List) throw const FormatException('collection');
          final rows = list.map((e) => kind.decode(jsonMap(e))).toList();
          if (rows.any((e) => e.id <= 0 || e.name.trim().isEmpty) ||
              rows.map((e) => e.id).toSet().length != rows.length) {
            throw const FormatException('records');
          }
          restored[kind] = rows;
        }
        db._rows = restored;
        for (final kind in EntityKind.values) {
          for (final entity in restored[kind]!) {
            db.validate(kind, entity, restored, allowDeletedLinks: true);
          }
        }
        db._initSequences();
        final sequences = jsonMap(root['sequences']);
        for (final kind in EntityKind.values) {
          final stored = jsonInt(sequences[kind.name]);
          if (stored > db._sequences[kind]!) db._sequences[kind] = stored;
        }
      } catch (_) {
        if (!await prefs.setString('${storageKey}_recovery', raw)) {
          throw const StorageException(
            'Не удалось сохранить резервную копию старых данных.',
          );
        }
        db._rows = _seed();
        db._initSequences();
        db.notice = 'Формат сохранённых данных устарел или повреждён. Исходные данные сохранены в резервной копии, загружен учебный каталог.';
      }
    } else if (prefs.containsKey('cosmetics_shop_v1')) {
      db.notice = 'Формат данных обновлён до версии 2. Старые данные версии 1 сохранены; загружен новый учебный каталог.';
    }
    await db._persist(db._rows, db._sequences);
    return db;
  }

  List<T> rows<T extends CatalogEntity>(EntityKind kind) =>
      List<T>.unmodifiable(_rows[kind]!.cast<T>());
  Future<void> _persist(ShopRows rows, Map<EntityKind, int> sequences) async {
    if (_prefs == null) return;
    final raw = jsonEncode({
      'schemaVersion': schemaVersion,
      'sequences': {for (final e in sequences.entries) e.key.name: e.value},
      for (final k in EntityKind.values)
        k.name: rows[k]!.map((e) => e.toJson()).toList(),
    });
    try {
      if (!await _prefs.setString(storageKey, raw)) {
        throw const StorageException('Хранилище не подтвердило запись.');
      }
    } catch (_) {
      throw const StorageException(
        'Не удалось сохранить изменения в браузере. Проверьте доступ к хранилищу и попробуйте снова.',
      );
    }
  }

  Future<R> transaction<R>(R Function(ShopRows, Map<EntityKind, int>) action) {
    final future = _queue.then((_) async {
      final next = <EntityKind, List<CatalogEntity>>{
        for (final e in _rows.entries) e.key: List.of(e.value),
      };
      final sequences = Map<EntityKind, int>.of(_sequences);
      final result = action(next, sequences);
      await _persist(next, sequences);
      _rows = next;
      _sequences = sequences;
      if (!_disposed) notifyListeners();
      return result;
    });
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  void validate(
    EntityKind kind,
    CatalogEntity entity,
    ShopRows rows, {
    bool allowDeletedLinks = false,
  }) {
    final errors = <String, String>{};
    void check(String field, String value, Validator validator) {
      final error = validator(value);
      if (error != null) errors[field] = error;
    }

    bool exists(EntityKind k, int id) =>
        rows[k]!.any((e) => e.id == id && (allowDeletedLinks || !e.isDeleted));
    check('name', entity.name, V.text());
    switch (entity) {
      case Product p:
        check('sku', p.sku, V.code());
        check('volume', p.volume, V.text(max: 40));
        check('description', p.description, V.text(max: 1000));
        if (p.priceKopecks <= 0 || p.priceKopecks > 100000000) {
          errors['price'] = 'Цена должна быть от 0,01 до 1 000 000 ₽';
        }
        check('stock', '${p.stock}', V.integer(min: 0, max: 100000));
        if (rows[kind]!.cast<Product>().any(
          (e) =>
              e.id != p.id && e.sku.toLowerCase() == p.sku.trim().toLowerCase(),
        )) {
          errors['sku'] = 'Товар с таким артикулом уже существует';
        }
        if (!exists(EntityKind.suppliers, p.supplierId)) {
          errors['supplierId'] = 'Выберите действующего поставщика';
        }
        if (!exists(EntityKind.brands, p.brandId)) {
          errors['brandId'] = 'Выберите действующий бренд';
        }
        final supplier =
            rows[EntityKind.suppliers]!
                    .where((e) => e.id == p.supplierId)
                    .firstOrNull
                as Supplier?;
        if (supplier != null && !supplier.brandIds.contains(p.brandId)) {
          errors['brandId'] =
              'Этот бренд не поставляется выбранным поставщиком';
        }
        if (p.categoryIds.isEmpty ||
            p.categoryIds.any((id) => !exists(EntityKind.categories, id))) {
          errors['categoryIds'] = 'Выберите хотя бы одну действующую категорию';
        }
      case Brand b:
        check('country', b.country, V.text(max: 60));
        check('description', b.description, V.text(max: 1000));
        check(
          'foundedYear',
          '${b.foundedYear}',
          V.integer(min: 1800, max: DateTime.now().year),
        );
      case Category c:
        check('description', c.description, V.length(max: 1000));
      case Supplier s:
        check('city', s.city, V.text(max: 80));
        check('email', s.email, V.combine([V.length(max: 254), V.email()]));
        check('phone', s.phone, V.phone());
        if (s.brandIds.isEmpty ||
            s.brandIds.any((id) => !exists(EntityKind.brands, id))) {
          errors['brandIds'] = 'Выберите хотя бы один действующий бренд';
        }
        final incompatible = rows[EntityKind.products]!
            .cast<Product>()
            .where(
              (p) => p.supplierId == s.id && !s.brandIds.contains(p.brandId),
            )
            .length;
        if (incompatible > 0) {
          errors['brandIds'] =
              'Нельзя убрать бренд: связанных товаров — $incompatible';
        }
      case Customer c:
        check('email', c.email, V.combine([V.length(max: 254), V.email()]));
        check('phone', c.phone, V.phone());
        check('card.number', c.card.number, V.code());
        check(
          'card.points',
          '${c.card.points}',
          V.integer(min: 0, max: 1000000),
        );
        if (c.card.issuedAt == null ||
            c.card.issuedAt!.isAfter(DateTime.now())) {
          errors['card.issuedAt'] = 'Выберите дату выдачи не позднее сегодня';
        }
        if (c.card.expiresAt == null ||
            c.card.issuedAt == null ||
            !c.card.expiresAt!.isAfter(c.card.issuedAt!)) {
          errors['card.expiresAt'] =
              'Дата окончания должна быть позже даты выдачи';
        }
        final others = rows[kind]!.cast<Customer>().where((e) => e.id != c.id);
        if (others.any(
          (e) => e.email.toLowerCase() == c.email.trim().toLowerCase(),
        )) {
          errors['email'] = 'Покупатель с такой почтой уже существует';
        }
        if (others.any(
          (e) =>
              e.card.number.toLowerCase() == c.card.number.trim().toLowerCase(),
        )) {
          errors['card.number'] = 'Карта с таким номером уже существует';
        }
        if (c.card.id != c.id) {
          errors['card.number'] = 'Карта должна принадлежать этому покупателю';
        }
    }
    if (errors.isNotEmpty) throw ValidationException(errors);
  }

  void checkDelete(EntityKind kind, int id, ShopRows rows) {
    final products = rows[EntityKind.products]!.cast<Product>();
    final count = switch (kind) {
      EntityKind.brands => products.where((p) => p.brandId == id).length,
      EntityKind.categories =>
        products.where((p) => p.categoryIds.contains(id)).length,
      EntityKind.suppliers => products.where((p) => p.supplierId == id).length,
      _ => 0,
    };
    if (count > 0) {
      throw RelatedRecordsException(count, 'товары, включая удалённые');
    }
    if (kind == EntityKind.brands) {
      final suppliers = rows[EntityKind.suppliers]!
          .cast<Supplier>()
          .where((s) => s.brandIds.contains(id))
          .length;
      if (suppliers > 0) throw RelatedRecordsException(suppliers, 'поставщики');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
