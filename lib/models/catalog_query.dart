const _unset = Object();

class CatalogQuery {
  final String search;
  final String filter;
  final int? categoryId;
  final int? brandId;
  final int? minPrice;
  final int? maxPrice;
  final String sortField;
  final bool ascending;
  final int page;
  final int size;
  final bool includeDeleted;
  final bool onlyDeleted;
  final int? debugFail;
  final int? debugDelay;
  const CatalogQuery({
    this.search = '',
    this.filter = '',
    this.categoryId,
    this.brandId,
    this.minPrice,
    this.maxPrice,
    this.sortField = 'name',
    this.ascending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.onlyDeleted = false,
    this.debugFail,
    this.debugDelay,
  });
  CatalogQuery copyWith({
    String? search,
    String? filter,
    Object? categoryId = _unset,
    Object? brandId = _unset,
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    String? sortField,
    bool? ascending,
    int? page,
    int? size,
    bool? includeDeleted,
    bool? onlyDeleted,
    int? debugFail,
    int? debugDelay,
  }) => CatalogQuery(
    search: search ?? this.search,
    filter: filter ?? this.filter,
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
    onlyDeleted: onlyDeleted ?? this.onlyDeleted,
    debugFail: debugFail ?? this.debugFail,
    debugDelay: debugDelay ?? this.debugDelay,
  );
  factory CatalogQuery.fromUri(Uri uri, {bool brands = false, String? entity}) {
    final p = uri.queryParameters;
    int? number(String key) {
      final value = int.tryParse(p[key] ?? '');
      return value != null && value >= 0 ? value : null;
    }

    final sort = (p['sort'] ?? 'name,asc').split(',');
    final kind = entity ?? (brands ? 'brands' : 'products');
    final fields = switch (kind) {
      'brands' => ['name', 'country', 'foundedYear'],
      'categories' => ['name', 'id', 'productCount'],
      'suppliers' => ['name', 'city', 'email'],
      'customers' => ['name', 'email', 'points'],
      _ => ['name', 'price', 'stock'],
    };
    final page = number('page') ?? 1;
    final size = number('size') ?? 10;
    return CatalogQuery(
      search: p['search'] ?? '',
      debugFail: number('__fail'),
      debugDelay: number('__delay'),
      filter: p['filter'] ?? '',
      categoryId: brands ? null : number('categoryId'),
      brandId: brands ? null : number('brandId'),
      minPrice: brands ? null : number('minPrice'),
      maxPrice: brands ? null : number('maxPrice'),
      sortField: fields.contains(sort.first) ? sort.first : 'name',
      ascending: sort.length < 2 || sort[1] != 'desc',
      page: page < 1 ? 1 : page,
      size: [10, 25, 50].contains(size) ? size : 10,
      onlyDeleted: p['onlyDeleted'] == 'true' || p['includeDeleted'] == 'true',
    );
  }
  String location(String path) => Uri(
    path: path,
    queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (filter.isNotEmpty) 'filter': filter,
      if (categoryId != null) 'categoryId': '$categoryId',
      if (brandId != null) 'brandId': '$brandId',
      if (minPrice != null) 'minPrice': '$minPrice',
      if (maxPrice != null) 'maxPrice': '$maxPrice',
      'sort': '$sortField,${ascending ? 'asc' : 'desc'}',
      'page': '$page',
      'size': '$size',
      if (includeDeleted) 'includeDeleted': 'true',
      if (onlyDeleted) 'onlyDeleted': 'true',
      if (debugFail != null) '__fail': '$debugFail',
      if (debugDelay != null) '__delay': '$debugDelay',
    },
  ).toString();
}
