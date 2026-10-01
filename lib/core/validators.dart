typedef Validator = String? Function(String?);

class V {
  static Validator required() =>
      (v) => v == null || v.trim().isEmpty ? 'Поле обязательно' : null;
  static Validator length({int min = 0, int max = 200}) => (v) {
    final n = (v ?? '').trim().length;
    return n < min
        ? 'Не короче $min символов'
        : n > max
        ? 'Не длиннее $max символов'
        : null;
  };
  static Validator integer({int min = 0, int max = 1000000}) => (v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null
        ? 'Введите целое число'
        : n < min || n > max
        ? 'Допустимо от $min до $max'
        : null;
  };
  static int? kopecks(String? value) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(v)) return null;
    final parts = v.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  static Validator price() => (v) {
    final n = kopecks(v);
    return n == null
        ? 'Введите цену, не более двух знаков после запятой'
        : n <= 0 || n > 100000000
        ? 'Цена должна быть от 0,01 до 1 000 000 ₽'
        : null;
  };
  static Validator email() =>
      (v) =>
          RegExp(
            r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
          ).hasMatch(v?.trim() ?? '')
          ? null
          : 'Некорректный адрес почты';
  static Validator phone() => (v) {
    final text = (v ?? '').trim();
    final n = text.replaceAll(RegExp(r'\D'), '').length;
    return RegExp(r'^\+?[\d\s()\-]+$').hasMatch(text) && n >= 10 && n <= 15
        ? null
        : 'Введите телефон: от 10 до 15 цифр';
  };
  static Validator code() =>
      (v) =>
          RegExp(r'^[A-Za-zА-Яа-я0-9][A-Za-zА-Яа-я0-9_\-]{2,31}$')
              .hasMatch((v ?? '').trim())
          ? null
          : 'От 3 до 32 букв, цифр, дефисов или подчёркиваний';
  static Validator combine(List<Validator> validators) => (value) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) return error;
    }
    return null;
  };
  static Validator text({int max = 120}) =>
      combine([required(), length(min: 2, max: max)]);
}
