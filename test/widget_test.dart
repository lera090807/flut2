import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:cosmetics/app.dart';
import 'package:cosmetics/repositories/seed_data.dart';
import 'package:cosmetics/repositories/product_repository.dart';
import 'package:cosmetics/repositories/brand_repository.dart';

void main() {
  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(1440, 1100),
    String? location,
    ProductRepository? products,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CosmeticsApp(
        initialLocation: location,
        products: products ?? InMemoryProductRepository(latency: Duration.zero),
        brands: InMemoryBrandRepository(latency: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Широкий экран, поиск с задержкой и восстановление URL', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byType(DataTable), findsOneWidget);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'cos-0001');
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('Всего записей: 30'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 1'), findsOneWidget);
    final context = tester.element(find.byType(TextField).first);
    final router = GoRouter.of(context);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['search'],
      'cos-0001',
    );
    router.go('/products?search=неттакоготовара');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    router.go('/products?search=cos-0001');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'cos-0001',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Карточки на 360px, таблица на 600px и переход к брендам', (
    tester,
  ) async {
    await launch(tester, size: const Size(360, 800));
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Бренды').last);
    await tester.pumpAndSettle();
    expect(find.text('Название бренда или страна'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Глубокая ссылка, карточка и возврат с фильтрами', (
    tester,
  ) async {
    await launch(tester, location: '/products?search=cos-0001&sort=price,desc');
    expect(find.text('Всего записей: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Открыть карточку').first);
    await tester.pumpAndSettle();
    expect(find.text('Объём / масса'), findsOneWidget);
    await tester.tap(find.text('Вернуться к списку'));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 1'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'cos-0001',
    );
  });
  testWidgets('Множественное удаление с подтверждением', (tester) async {
    await launch(tester);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(find.text('Удалить выбранные'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить выбранные записи?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 28'), findsOneWidget);
    expect(find.text('Выбрано: 2'), findsNothing);
  });
  testWidgets('Пагинация меняет строки и сохраняет номер в URL', (
    tester,
  ) async {
    await launch(tester, size: const Size(1440, 1300));
    final router = GoRouter.of(tester.element(find.byType(TextField).first));
    for (final step in [
      ('Следующая страница', 2),
      ('Последняя страница', 3),
      ('Предыдущая страница', 2),
      ('Первая страница', 1),
    ]) {
      await tester.ensureVisible(find.byTooltip(step.$1));
      await tester.tap(find.byTooltip(step.$1));
      await tester.pumpAndSettle();
      expect(find.text('${step.$2} / 3'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['page'],
        '${step.$2}',
      );
      expect(
        find.text('Бальзам для губ SPF 15'),
        step.$2 == 1 ? findsOneWidget : findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Размер страницы 25/50 и корректировка ошибочного адреса', (
    tester,
  ) async {
    await launch(
      tester,
      size: const Size(1440, 1300),
      location: '/products?page=999',
    );
    final router = GoRouter.of(tester.element(find.byType(TextField).first));
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['page'],
      '3',
    );
    for (final size in [25, 50, 10]) {
      final dropdown = find.byType(DropdownButton<int>).last;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('$size').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DataTable>(find.byType(DataTable)).rows.length,
        size == 50 ? 30 : size,
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['size'],
        '$size',
      );
      expect(
        router.routeInformationProvider.value.uri.queryParameters['page'],
        '1',
      );
    }
  });
  testWidgets('Удаление последней записи страницы возвращает на предыдущую', (
    tester,
  ) async {
    await launch(
      tester,
      location: '/products?page=3',
      products: InMemoryProductRepository(
        seed: seedProducts.take(21).toList(),
        latency: const Duration(milliseconds: 250),
      ),
    );
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить выбранные'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 20'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(TextField).first))
          .routeInformationProvider
          .value
          .uri
          .queryParameters['page'],
      '2',
    );
  });
  testWidgets('Удаление, восстановление и физическое удаление через меню', (
    tester,
  ) async {
    await launch(tester, location: '/products?search=cos-0001');
    Future<void> menu(String label) async {
      await tester.tap(find.byTooltip('Действия с записью').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await menu('Удалить');
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 1'), findsOneWidget);
    await menu('Восстановить');
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('COS-0001'), findsOneWidget);
    await menu('Удалить навсегда');
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });
  testWidgets('Фильтры через элементы управления и сортировка по заголовку', (
    tester,
  ) async {
    await launch(tester, size: const Size(1440, 1300));
    await tester.tap(find.text('Все категории'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Уход за лицом').last);
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 10'), findsOneWidget);
    await tester.tap(find.text('Все бренды'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bioderma').last);
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 3'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Цена от, ₽'),
      '1800',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Цена до, ₽'),
      '2000',
    );
    await tester.tap(find.text('Применить цену'));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 1'), findsOneWidget);
    expect(find.text('Увлажняющий крем для лица'), findsOneWidget);
    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();
    expect(find.text('Всего записей: 30'), findsOneWidget);
    await tester.tap(find.text('Цена', skipOffstage: true));
    await tester.pumpAndSettle();
    expect(find.text('Тканевая маска с алоэ'), findsOneWidget);
    expect(find.text('Тональный флюид'), findsNothing);
    await tester.tap(find.text('Цена', skipOffstage: true));
    await tester.pumpAndSettle();
    expect(find.text('Тональный флюид'), findsOneWidget);
    expect(find.text('Тканевая маска с алоэ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
