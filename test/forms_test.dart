import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cosmetics/app.dart';

void main() {
  Future<void> launch(
    WidgetTester tester,
    String location, {
    double width = 1440,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CosmeticsApp(initialLocation: location));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
  }

  testWidgets('Пустая форма показывает несколько ошибок под полями', (
    tester,
  ) async {
    await launch(tester, '/products/new');
    await save(tester);
    expect(find.text('Поле обязательно'), findsWidgets);
    expect(find.text('Выберите поставщика'), findsOneWidget);
    expect(find.text('Выберите хотя бы одно значение'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Создание категории, карточка и заполненная форма редактирования',
    (tester) async {
      await launch(tester, '/categories/new');
      await tester.enterText(
        find.byKey(const ValueKey('name')),
        'Подарочные наборы',
      );
      await tester.enterText(
        find.byKey(const ValueKey('description')),
        'Наборы для подарка',
      );
      await save(tester);
      expect(find.text('Подарочные наборы'), findsOneWidget);
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('name')))
            .controller!
            .text,
        'Подарочные наборы',
      );
      await tester.enterText(find.byKey(const ValueKey('name')), 'Подарки');
      await save(tester);
      expect(find.text('Подарки'), findsOneWidget);
    },
  );
  testWidgets(
    'Уникальность артикула показывается в поле и очищается после изменения',
    (tester) async {
      await launch(tester, '/products/1/edit');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('name')))
            .controller!
            .text,
        'Увлажняющий крем для лица',
      );
      await tester.enterText(find.byKey(const ValueKey('sku')), 'COS-0002');
      await save(tester);
      expect(
        find.text('Товар с таким артикулом уже существует'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('sku')));
      await tester.enterText(find.byKey(const ValueKey('sku')), 'COS-0001');
      await tester.pumpAndSettle();
      expect(find.text('Товар с таким артикулом уже существует'), findsNothing);
      await save(tester);
      expect(find.text('Объём / масса'), findsOneWidget);
    },
  );
  testWidgets('Несохранённые изменения блокируют переход через навигацию', (
    tester,
  ) async {
    await launch(tester, '/categories/new');
    await tester.enterText(find.byKey(const ValueKey('name')), 'Не сохранено');
    final router = GoRouter.of(tester.element(find.byType(Form)));
    router.go('/brands');
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();
    expect(find.byType(Form), findsOneWidget);
    router.go('/brands');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Уйти без сохранения'));
    await tester.pumpAndSettle();
    expect(find.byType(Form), findsNothing);
    expect(find.text('Название бренда или страна'), findsOneWidget);
  });
  testWidgets('Мобильная форма покупателя содержит карту без переполнений', (
    tester,
  ) async {
    await launch(tester, '/customers/1/edit', width: 360);
    expect(find.text('Карта лояльности'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('card.number')))
          .controller!
          .text,
      'LC-000001',
    );
    await save(tester);
    expect(find.text('Карта лояльности'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Смена поставщика очищает несовместимый бренд', (tester) async {
    await launch(tester, '/products/1/edit');
    final supplier = find.byKey(const ValueKey('supplierId-'));
    await tester.ensureVisible(supplier);
    await tester.tap(supplier);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Корея Бьюти').last);
    await tester.pumpAndSettle();
    final brand = find.byKey(const ValueKey('brandId-3'));
    await tester.ensureVisible(brand);
    await tester.tap(brand);
    await tester.pumpAndSettle();
    expect(find.text('COSRX'), findsOneWidget);
    expect(find.text('Bioderma'), findsNothing);
    await tester.tap(find.text('COSRX'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(find.text('COSRX'), findsOneWidget);
  });
  testWidgets(
    'Новый покупатель создаётся вместе с картой и датами из календаря',
    (tester) async {
      await launch(tester, '/customers/new');
      for (final entry in {
        'name': 'Новый покупатель',
        'email': 'created@example.com',
        'phone': '+7 900 111-22-33',
        'card.number': 'LC-CREATED',
        'card.points': '0',
      }.entries) {
        await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
        await tester.enterText(find.byKey(ValueKey(entry.key)), entry.value);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('card.issuedAt')));
      await tester.tap(find.byKey(const ValueKey('card.issuedAt')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('card.expiresAt')));
      await tester.tap(find.byKey(const ValueKey('card.expiresAt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ОК'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Новый покупатель'), findsOneWidget);
      expect(find.text('LC-CREATED'), findsOneWidget);
      expect(find.byType(Form), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
