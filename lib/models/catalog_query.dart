const _unset = Object();

/// Адрес браузера является источником условий отбора.
class CatalogQuery {
  final String search;
  final int? categoryId;
  final int? brandId;
  final int? minPrice;
  final int? maxPrice;
  final String sortField;
  final bool ascending;
  final int page;
  final int size;
  final bool includeDeleted;
  const CatalogQuery({
    this.search = '',
    this.categoryId,
    this.brandId,
    this.minPrice,
    this.maxPrice,
    this.sortField = 'name',
    this.ascending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });
  CatalogQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? brandId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    String? sortField,
    bool? ascending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) => CatalogQuery(
    search: search ?? this.search,
    categoryId: identical(categoryId, _unset)
        ? this.categoryId
        : categoryId as int?,
    brandId: identical(brandId, _unset) ? this.brandId : brandId as int?,
    minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as int?,
    maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as int?,
    sortField: sortField ?? this.sortField,
    ascending: ascending ?? this.ascending,
    page: page ?? 1,
    size: size ?? this.size,
    includeDeleted: includeDeleted ?? this.includeDeleted,
  );
  factory CatalogQuery.fromUri(Uri uri, {bool brands = false}) {
    final p = uri.queryParameters;
    int? number(String key) {
      final value = int.tryParse(p[key] ?? '');
      return value != null && value >= 0 ? value : null;
    }

    final sort = (p['sort'] ?? 'name,asc').split(',');
    final fields = brands
        ? ['name', 'country', 'foundedYear']
        : ['name', 'price', 'stock'];
    final page = number('page') ?? 1;
    final size = number('size') ?? 10;
    return CatalogQuery(
      search: p['search'] ?? '',
      categoryId: brands ? null : number('categoryId'),
      brandId: brands ? null : number('brandId'),
      minPrice: brands ? null : number('minPrice'),
      maxPrice: brands ? null : number('maxPrice'),
      sortField: fields.contains(sort.first) ? sort.first : 'name',
      ascending: sort.length < 2 || sort[1] != 'desc',
      page: page < 1 ? 1 : page,
      size: [10, 25, 50].contains(size) ? size : 10,
      includeDeleted: p['includeDeleted'] == 'true',
    );
  }
  String location(String path) => Uri(
    path: path,
    queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': '$categoryId',
      if (brandId != null) 'brandId': '$brandId',
      if (minPrice != null) 'minPrice': '$minPrice',
      if (maxPrice != null) 'maxPrice': '$maxPrice',
      'sort': '$sortField,${ascending ? 'asc' : 'desc'}',
      'page': '$page',
      'size': '$size',
      if (includeDeleted) 'includeDeleted': 'true',
    },
  ).toString();
}
