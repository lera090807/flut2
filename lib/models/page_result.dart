class PageResult<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;
  PageResult({
    required List<T> items,
    required this.page,
    required this.size,
    required this.total,
  }) : items = List.unmodifiable(items);
  int get totalPages => total == 0 ? 1 : (total / size).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;
}
