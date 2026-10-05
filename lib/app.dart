import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/api_client.dart';
import 'repositories/api_repository.dart';
import 'models/catalog_entity.dart';
import 'models/product.dart';
import 'models/brand.dart';
import 'models/category.dart';
import 'models/supplier.dart';
import 'models/customer.dart';
import 'models/entity_kind.dart';
import 'models/catalog_query.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/brand_repository.dart';
import 'repositories/persistent_repository.dart';
import 'repositories/shop_database.dart';
import 'state/catalog_notifier.dart';
import 'state/catalog_reference.dart';
import 'state/detail_notifier.dart';
import 'state/editor_notifier.dart';
import 'state/navigation_guard.dart';
import 'screens/product_list_screen.dart';
import 'screens/brand_list_screen.dart';
import 'screens/reference_list_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/entity_form_screen.dart';
import 'widgets/app_shell.dart';
import 'widgets/result_message.dart';

class CosmeticsApp extends StatefulWidget {
  final bool useApi;
  final ProductRepository? products;
  final BrandRepository? brands;
  final ShopDatabase? database;
  final String? initialLocation;
  const CosmeticsApp({
    super.key,
    this.useApi = true,
    this.products,
    this.brands,
    this.database,
    this.initialLocation,
  });
  @override
  State<CosmeticsApp> createState() => _CosmeticsAppState();
}

class _CosmeticsAppState extends State<CosmeticsApp> {
  late final ShopDatabase? _db = widget.useApi
      ? null
      : widget.database ?? ShopDatabase.memory();
  late final _dio = buildDio();
  void _changed(EntityKind kind) {
    _reference.invalidate(kind);
    _reference.load();
  }

  void _localChanged() {
    _reference.load();
  }

  late final ProductRepository _products =
      widget.products ??
      (widget.useApi
          ? ApiProductRepository(_dio, onChanged: _changed)
          : PersistentProductRepository(_db!));
  late final BrandRepository _brands =
      widget.brands ??
      (widget.useApi
          ? ApiBrandRepository(_dio, onChanged: _changed)
          : PersistentBrandRepository(_db!));
  late final CatalogRepository<Category> _categories = widget.useApi
      ? ApiRepository<Category>(
          _dio,
          EntityKind.categories,
          onChanged: _changed,
        )
      : PersistentRepository<Category>(_db!, EntityKind.categories);
  late final CatalogRepository<Supplier> _suppliers = widget.useApi
      ? ApiRepository<Supplier>(_dio, EntityKind.suppliers, onChanged: _changed)
      : PersistentRepository<Supplier>(_db!, EntityKind.suppliers);
  late final CatalogRepository<Customer> _customers = widget.useApi
      ? ApiRepository<Customer>(_dio, EntityKind.customers, onChanged: _changed)
      : PersistentRepository<Customer>(_db!, EntityKind.customers);
  late final Map<EntityKind, CatalogRepository<CatalogEntity>> _repositories = {
    EntityKind.products: _products,
    EntityKind.brands: _brands,
    EntityKind.categories: _categories,
    EntityKind.suppliers: _suppliers,
    EntityKind.customers: _customers,
  };
  late final _reference = CatalogReference(_repositories, cache: widget.useApi);
  final _guard = NavigationGuard();
  @override
  void initState() {
    super.initState();
    _reference.load();
    _db?.addListener(_localChanged);
  }

  String _back(GoRouterState state, String fallback) {
    final from = state.uri.queryParameters['from'];
    final uri = from == null ? null : Uri.tryParse(from);
    return uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path == fallback
        ? from!
        : fallback;
  }

  List<RouteBase> _routes<T extends CatalogEntity>(
    EntityKind kind,
    CatalogRepository<T> repository,
    Widget Function(CatalogQuery) list,
  ) => [
    GoRoute(
      path: kind.path,
      builder: (_, s) => list(
        CatalogQuery.fromUri(
          s.uri,
          entity: kind.name,
          brands: kind == EntityKind.brands,
        ),
      ),
    ),
    GoRoute(
      path: '${kind.path}/new',
      onExit: (_, _) => _guard.allowExit(),
      builder: (_, s) => ChangeNotifierProvider(
        key: ValueKey(s.uri.path),
        create: (_) =>
            EditorNotifier(kind, repository, _reference, null)..load(),
        child: EntityFormScreen(back: _back(s, kind.path)),
      ),
    ),
    GoRoute(
      path: '${kind.path}/:id/edit',
      onExit: (_, _) => _guard.allowExit(),
      builder: (_, s) => ChangeNotifierProvider(
        key: ValueKey(s.uri.path),
        create: (_) => EditorNotifier(
          kind,
          repository,
          _reference,
          int.tryParse(s.pathParameters['id']!) ?? -1,
        )..load(),
        child: EntityFormScreen(back: _back(s, kind.path)),
      ),
    ),
    GoRoute(
      path: '${kind.path}/:id',
      builder: (_, s) => ChangeNotifierProvider(
        key: ValueKey(s.uri.path),
        create: (_) => DetailNotifier<T>(
          repository,
          int.tryParse(s.pathParameters['id']!) ?? -1,
        )..load(),
        child: DetailScreen<T>(back: _back(s, kind.path)),
      ),
    ),
  ];
  late final _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/products'),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          ..._routes<Product>(
            EntityKind.products,
            _products,
            (q) => ProductListScreen(query: q),
          ),
          ..._routes<Brand>(
            EntityKind.brands,
            _brands,
            (q) => BrandListScreen(query: q),
          ),
          ..._routes<Category>(
            EntityKind.categories,
            _categories,
            (q) => ReferenceListScreen<Category>(
              kind: EntityKind.categories,
              query: q,
            ),
          ),
          ..._routes<Supplier>(
            EntityKind.suppliers,
            _suppliers,
            (q) => ReferenceListScreen<Supplier>(
              kind: EntityKind.suppliers,
              query: q,
            ),
          ),
          ..._routes<Customer>(
            EntityKind.customers,
            _customers,
            (q) => ReferenceListScreen<Customer>(
              kind: EntityKind.customers,
              query: q,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: ResultMessage(
        icon: Icons.wrong_location_outlined,
        title: 'Страница не найдена',
        message: 'Проверьте адрес или вернитесь в каталог.',
        actionLabel: 'В каталог',
        onAction: () => context.go('/products'),
      ),
    ),
  );
  @override
  void dispose() {
    _router.dispose();
    _db?.removeListener(_localChanged);
    _reference.dispose();
    if (widget.database == null) _db?.dispose();
    if (widget.useApi) _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      if (_db != null) ChangeNotifierProvider<ShopDatabase>.value(value: _db),
      ChangeNotifierProvider<CatalogReference>.value(value: _reference),
      Provider<NavigationGuard>.value(value: _guard),
      ChangeNotifierProvider(
        create: (_) => CatalogNotifier<Product>(
          _products,
          refreshReferences: widget.useApi ? _reference.load : null,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CatalogNotifier<Brand>(
          _brands,
          refreshReferences: widget.useApi ? _reference.load : null,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CatalogNotifier<Category>(
          _categories,
          refreshReferences: widget.useApi ? _reference.load : null,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CatalogNotifier<Supplier>(
          _suppliers,
          refreshReferences: widget.useApi ? _reference.load : null,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CatalogNotifier<Customer>(
          _customers,
          refreshReferences: widget.useApi ? _reference.load : null,
        ),
      ),
    ],
    child: MaterialApp.router(
      title: 'Магазин косметики',
      debugShowCheckedModeBanner: false,
      theme: cosmeticsTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    ),
  );
}
