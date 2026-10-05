String jsonString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
int jsonInt(Object? value, [int fallback = 0]) => value is int
    ? value
    : value is num && value.isFinite
    ? value.toInt()
    : int.tryParse('$value') ?? fallback;
List<int> jsonIds(Object? value) => value is List
    ? value.map((v) => jsonInt(v)).where((v) => v > 0).toSet().toList()
    : [];
DateTime? jsonDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
Map<String, dynamic> jsonMap(Object? value) => value is Map
    ? Map<String, dynamic>.fromEntries(
        value.entries
            .where((e) => e.key is String)
            .map((e) => MapEntry(e.key as String, e.value)),
      )
    : {};
