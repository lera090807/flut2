abstract interface class CatalogEntity {
  int get id;
  String get name;
  DateTime? get deletedAt;
  bool get isDeleted;
}
