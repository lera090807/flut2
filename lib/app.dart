import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'models/product.dart';
import 'models/brand.dart';
import 'models/catalog_query.dart';
import 'repositories/product_repository.dart';
import 'repositories/brand_repository.dart';
import 'state/catalog_notifier.dart';
import 'state/catalog_reference.dart';
import 'state/detail_notifier.dart';
import 'screens/product_list_screen.dart';
import 'screens/brand_list_screen.dart';
import 'screens/detail_screen.dart';
import 'widgets/app_shell.dart';
import 'widgets/result_message.dart';

class CosmeticsApp extends StatefulWidget {
  final ProductRepository? products;
  final BrandRepository? brands;
  final String? initialLocation;
  const CosmeticsApp({
    super.key,
    this.products,
    this.brands,
    this.initialLocation,
  });
  @override
  State<CosmeticsApp> createState() => _CosmeticsAppState();
}

class _CosmeticsAppState extends State<CosmeticsApp> {
  late final ProductRepository _products =
      widget.products ?? InMemoryProductRepository();
  late final BrandRepository _brands =
      widget.brands ?? InMemoryBrandRepository();
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

  late final _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/products'),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/products',
            builder: (_, state) =>
                ProductListScreen(query: CatalogQuery.fromUri(state.uri)),
          ),
          GoRoute(
            path: '/brands',
            builder: (_, state) => BrandListScreen(
              query: CatalogQuery.fromUri(state.uri, brands: true),
            ),
          ),
          GoRoute(
            path: '/products/:id',
            builder: (_, state) => ChangeNotifierProvider(
              key: ValueKey(state.uri.path),
              create: (_) => DetailNotifier<Product>(
                _products,
                int.tryParse(state.pathParameters['id']!) ?? -1,
              )..load(),
              child: DetailScreen<Product>(back: _back(state, '/products')),
            ),
          ),
          GoRoute(
            path: '/brands/:id',
            builder: (_, state) => ChangeNotifierProvider(
              key: ValueKey(state.uri.path),
              create: (_) => DetailNotifier<Brand>(
                _brands,
                int.tryParse(state.pathParameters['id']!) ?? -1,
              )..load(),
              child: DetailScreen<Brand>(back: _back(state, '/brands')),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<ProductRepository>.value(value: _products),
      Provider<BrandRepository>.value(value: _brands),
      Provider(create: (_) => CatalogReference()),
      ChangeNotifierProvider(
        create: (context) =>
            CatalogNotifier<Product>(context.read<ProductRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            CatalogNotifier<Brand>(context.read<BrandRepository>()),
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
