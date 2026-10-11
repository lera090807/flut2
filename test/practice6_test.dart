import 'dart:async';

import 'package:cosmetics/app.dart';
import 'package:cosmetics/core/api_client.dart';
import 'package:cosmetics/core/api_exceptions.dart';
import 'package:cosmetics/models/app_user.dart';
import 'package:cosmetics/models/catalog_query.dart';
import 'package:cosmetics/models/page_result.dart';
import 'package:cosmetics/models/product.dart';
import 'package:cosmetics/repositories/brand_repository.dart';
import 'package:cosmetics/repositories/product_repository.dart';
import 'package:cosmetics/state/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class ControlledProducts extends InMemoryProductRepository {
  Completer<void>? gate;
  bool offline = false;
  ControlledProducts() : super(latency: Duration.zero);
  @override
  Future<PageResult<Product>> find(CatalogQuery query) async {
    await gate?.future;
    if (offline) throw const NetworkException();
    return super.find(query);
  }
}

void main() {
  Future<void> launch(
    WidgetTester tester, {
    ProductRepository? products,
    Role? role,
    double width = 1280,
    String location = '/products',
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 950);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthNotifier(buildDio())
      ..user = AppUser(
        id: 1,
        username: 'buyer',
        fullName: 'Валерия Храброва',
        email: 'buyer@example.com',
        role: role ?? Role.admin,
      );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: CosmeticsApp(
          useApi: false,
          initialLocation: location,
          products:
              products ?? InMemoryProductRepository(latency: Duration.zero),
          brands: InMemoryBrandRepository(latency: Duration.zero),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('Загрузка видна до ответа, затем появляются товары', (
    tester,
  ) async {
    final repo = ControlledProducts()..gate = Completer<void>();
    await launch(tester, products: repo, settle: false);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Всего записей: 30'), findsOneWidget);
  });

  testWidgets('Пустой каталог показывает сообщение и сброс фильтров', (
    tester,
  ) async {
    await launch(
      tester,
      products: InMemoryProductRepository(seed: [], latency: Duration.zero),
    );
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.text('Сбросить фильтры'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'Ошибка сети: повтор загружает данные без пересоздания приложения',
    (tester) async {
      final repo = ControlledProducts()..offline = true;
      await launch(tester, products: repo);
      expect(find.text('Не удалось загрузить каталог'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      repo.offline = false;
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Всего записей: 30'), findsOneWidget);
      expect(find.text('Не удалось загрузить каталог'), findsNothing);
    },
  );

  testWidgets('Пустая форма не сохраняется и показывает ошибки полей', (
    tester,
  ) async {
    await launch(tester, location: '/categories/new');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Поле обязательно'), findsWidgets);
    expect(find.byType(Form), findsOneWidget);
  });

  testWidgets('Покупателю скрыты создание, удаление и меню изменения', (
    tester,
  ) async {
    await launch(tester, role: Role.customer);
    expect(find.byTooltip('Создать запись'), findsNothing);
    expect(find.byTooltip('Действия с записью'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('Открыть карточку'), findsWidgets);
  });

  for (final role in Role.values) {
    testWidgets('360px: нижняя навигация для ${role.name} без переполнений', (
      tester,
    ) async {
      await launch(tester, role: role, width: 360);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      if (role != Role.customer) {
        await tester.tap(find.text('Ещё'));
        await tester.pumpAndSettle();
        expect(
          find.text(role == Role.staff ? 'Обработка заказов' : 'Пользователи'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Изменение ширины 360–768–1280–1920 сохраняет фильтр', (
    tester,
  ) async {
    await launch(tester, width: 360, location: '/products?search=cos-0001');
    for (final width in [360.0, 768.0, 1280.0, 1920.0, 360.0]) {
      tester.view.physicalSize = Size(width, 950);
      await tester.pumpAndSettle();
      expect(find.text('Всего записей: 1'), findsOneWidget);
      expect(
        find.byType(DataTable),
        width >= 1200 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationRail),
        width >= 600 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });
  for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
    testWidgets('Формы и карточки всех сущностей на ${width.toInt()}px', (
      tester,
    ) async {
      for (final kind in [
        'products',
        'brands',
        'categories',
        'suppliers',
        'customers',
      ]) {
        for (final suffix in ['/1', '/new']) {
          await tester.pumpWidget(const SizedBox());
          await launch(tester, width: width, location: '/$kind$suffix');
          expect(
            tester.takeException(),
            isNull,
            reason: '$kind$suffix at $width',
          );
        }
      }
    });
  }
}
