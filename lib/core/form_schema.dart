import '../models/entity_kind.dart';
import 'validators.dart';

enum FieldType { text, integer, price, email, phone, date, select, multi }

class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final Validator? validator;
  final int lines;
  const FieldSpec(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.validator,
    this.lines = 1,
  });
}

List<FieldSpec> fieldsFor(EntityKind kind) => [
  FieldSpec(
    'name',
    kind == EntityKind.customers ? 'ФИО' : 'Название',
    validator: V.text(),
  ),
  ...switch (kind) {
    EntityKind.products => [
      FieldSpec(
        'sku',
        'Артикул',
        validator: V.combine([V.required(), V.code()]),
      ),
      FieldSpec(
        'price',
        'Цена, ₽',
        type: FieldType.price,
        validator: V.combine([V.required(), V.price()]),
      ),
      FieldSpec(
        'stock',
        'Остаток, шт.',
        type: FieldType.integer,
        validator: V.combine([V.required(), V.integer(min: 0, max: 100000)]),
      ),
      FieldSpec('volume', 'Объём / масса', validator: V.text(max: 40)),
      const FieldSpec('supplierId', 'Поставщик', type: FieldType.select),
      const FieldSpec('brandId', 'Бренд', type: FieldType.select),
      const FieldSpec('categoryIds', 'Категории', type: FieldType.multi),
      FieldSpec(
        'description',
        'Описание',
        lines: 3,
        validator: V.text(max: 1000),
      ),
    ],
    EntityKind.brands => [
      FieldSpec('country', 'Страна', validator: V.text(max: 60)),
      FieldSpec(
        'foundedYear',
        'Год основания',
        type: FieldType.integer,
        validator: V.combine([
          V.required(),
          V.integer(min: 1800, max: DateTime.now().year),
        ]),
      ),
      FieldSpec(
        'description',
        'Описание',
        lines: 3,
        validator: V.text(max: 1000),
      ),
    ],
    EntityKind.categories => [
      FieldSpec(
        'description',
        'Описание (необязательно)',
        lines: 3,
        validator: V.length(max: 1000),
      ),
    ],
    EntityKind.suppliers => [
      FieldSpec('city', 'Город', validator: V.text(max: 80)),
      FieldSpec(
        'email',
        'Электронная почта',
        type: FieldType.email,
        validator: V.combine([V.required(), V.length(max: 254), V.email()]),
      ),
      FieldSpec(
        'phone',
        'Телефон',
        type: FieldType.phone,
        validator: V.combine([V.required(), V.phone()]),
      ),
      const FieldSpec('brandIds', 'Поставляемые бренды', type: FieldType.multi),
    ],
    EntityKind.customers => [
      FieldSpec(
        'email',
        'Электронная почта',
        type: FieldType.email,
        validator: V.combine([V.required(), V.length(max: 254), V.email()]),
      ),
      FieldSpec(
        'phone',
        'Телефон',
        type: FieldType.phone,
        validator: V.combine([V.required(), V.phone()]),
      ),
      FieldSpec(
        'card.number',
        'Номер карты',
        validator: V.combine([V.required(), V.code()]),
      ),
      const FieldSpec('card.issuedAt', 'Дата выдачи', type: FieldType.date),
      const FieldSpec('card.expiresAt', 'Действует до', type: FieldType.date),
      FieldSpec(
        'card.points',
        'Бонусные баллы',
        type: FieldType.integer,
        validator: V.combine([V.required(), V.integer(min: 0, max: 1000000)]),
      ),
    ],
  },
];
