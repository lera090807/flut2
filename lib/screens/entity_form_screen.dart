import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/form_schema.dart';
import '../core/validators.dart';
import '../core/unload_guard.dart';
import '../models/catalog_entity.dart';
import '../models/entity_kind.dart';
import '../models/json_values.dart';
import '../models/product.dart';
import '../state/catalog_reference.dart';
import '../state/editor_notifier.dart';
import '../state/load_state.dart';
import '../state/navigation_guard.dart';
import '../widgets/result_message.dart';

class EntityFormScreen extends StatelessWidget {
  final String back;
  const EntityFormScreen({super.key, required this.back});
  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorNotifier>();
    return switch (editor.state) {
      Loading() => const Center(child: CircularProgressIndicator()),
      Failed(message: final message) => ResultMessage(
        icon: Icons.error_outline,
        title: 'Форма недоступна',
        message: message,
        actionLabel: 'Повторить',
        onAction: editor.load,
      ),
      Loaded(data: null) when editor.id != null => ResultMessage(
        icon: Icons.search_off,
        title: 'Запись не найдена',
        message: 'Проверьте адрес.',
        actionLabel: 'К списку',
        onAction: () => context.go(back),
      ),
      Loaded(data: final entity) => EntityEditor(
        key: ValueKey('${editor.kind.name}-${editor.id}'),
        entity: entity,
        back: back,
      ),
    };
  }
}

class EntityEditor extends StatefulWidget {
  final CatalogEntity? entity;
  final String back;
  const EntityEditor({super.key, this.entity, required this.back});
  @override
  State<EntityEditor> createState() => _EntityEditorState();
}

class _EntityEditorState extends State<EntityEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  late final List<FieldSpec> _fields;
  late final NavigationGuard _guard;
  bool _dirty = false;
  Future<bool>? _decision;
  EditorNotifier get editor => context.read<EditorNotifier>();
  @override
  void initState() {
    super.initState();
    _fields = fieldsFor(editor.kind);
    final json = widget.entity?.toJson() ?? <String, dynamic>{};
    _values.addAll(json);
    if (widget.entity case Product p) {
      _values['price'] = (p.priceKopecks / 100).toStringAsFixed(2);
    }
    final card = jsonMap(json['card']);
    for (final field in _fields) {
      final value = field.key.startsWith('card.')
          ? card[field.key.substring(5)]
          : _values[field.key];
      if (field.type == FieldType.date) {
        _values[field.key] = jsonDate(value);
      } else if (field.type == FieldType.multi) {
        _values[field.key] = jsonIds(value);
      } else if (field.type == FieldType.select) {
        _values[field.key] = value;
      } else {
        final text = value == null ? '' : '$value';
        _controllers[field.key] = TextEditingController(text: text);
        _values[field.key] = text;
      }
    }
    _guard = context.read<NavigationGuard>();
    _guard.confirm = _confirmLeave;
  }

  @override
  void dispose() {
    if (_guard.confirm == _confirmLeave) _guard.confirm = null;
    setUnsavedChanges(false);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (editor.saving) return false;
    if (!_dirty) return true;
    if (_decision != null) return _decision!;
    _decision = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Изменения будут потеряны. Покинуть форму?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти без сохранения'),
          ),
        ],
      ),
    ).then((v) => v ?? false);
    final allow = await _decision!;
    _decision = null;
    if (allow && mounted) {
      setState(() => _dirty = false);
      setUnsavedChanges(false);
    }
    return allow;
  }

  void _change(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _dirty = true;
    });
    setUnsavedChanges(true);
    editor.clearError(key);
  }

  List<CatalogEntity> _options(String key, CatalogReference reference) {
    if (key == 'supplierId') {
      return reference.suppliers.where((e) => !e.isDeleted).toList();
    }
    if (key == 'brandIds') {
      return reference.brands.where((e) => !e.isDeleted).toList();
    }
    if (key == 'brandId') {
      final supplier = reference.suppliers
          .where((s) => s.id == _values['supplierId'])
          .firstOrNull;
      return reference.brands
          .where(
            (b) =>
                !b.isDeleted &&
                supplier != null &&
                supplier.brandIds.contains(b.id),
          )
          .toList();
    }
    return reference.categories.where((e) => !e.isDeleted).toList();
  }

  String? _dateError(String key, DateTime? value) {
    if (value == null) return 'Выберите дату';
    if (key == 'card.issuedAt' && value.isAfter(DateTime.now())) {
      return 'Дата выдачи не может быть в будущем';
    }
    final issued = _values['card.issuedAt'] as DateTime?;
    if (key == 'card.expiresAt' && (issued == null || !value.isAfter(issued))) {
      return 'Дата окончания должна быть позже даты выдачи';
    }
    return editor.errors[key];
  }

  Widget _field(FieldSpec spec, CatalogReference reference) {
    final key = spec.key;
    if (spec.type == FieldType.select) {
      final options = _options(key, reference);
      final id = _values[key] as int?;
      return DropdownButtonFormField<int>(
        key: ValueKey('$key-${key == 'brandId' ? _values['supplierId'] : ''}'),
        initialValue: options.any((e) => e.id == id) ? id : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: spec.label,
          helperText: key == 'brandId'
              ? 'Доступные бренды выбранного поставщика'
              : null,
        ),
        items: [
          for (final e in options)
            DropdownMenuItem(value: e.id, child: Text(e.name)),
        ],
        validator: (value) => value == null
            ? key == 'supplierId'
                  ? 'Выберите поставщика'
                  : 'Выберите бренд'
            : editor.errors[key],
        onChanged: (value) {
          if (key == 'supplierId') {
            final supplier = reference.suppliers
                .where((s) => s.id == value)
                .firstOrNull;
            if (supplier == null ||
                !supplier.brandIds.contains(_values['brandId'])) {
              _values['brandId'] = null;
              editor.clearError('brandId');
            }
          }
          _change(key, value);
        },
      );
    }
    if (spec.type == FieldType.multi) {
      final options = _options(key, reference);
      return FormField<List<int>>(
        initialValue: List<int>.from(_values[key] as List),
        validator: (v) => v == null || v.isEmpty
            ? 'Выберите хотя бы одно значение'
            : editor.errors[key],
        builder: (field) => InputDecorator(
          decoration: InputDecoration(
            labelText: spec.label,
            errorText: field.errorText,
          ),
          child: options.isEmpty
              ? const Text('Сначала добавьте записи в справочник.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in options)
                      FilterChip(
                        label: Text(option.name),
                        selected: field.value!.contains(option.id),
                        onSelected: (selected) {
                          final next = [...field.value!];
                          selected
                              ? next.add(option.id)
                              : next.remove(option.id);
                          field.didChange(next);
                          _change(key, next);
                        },
                      ),
                  ],
                ),
        ),
      );
    }
    if (spec.type == FieldType.date) {
      return FormField<DateTime>(
        initialValue: _values[key] as DateTime?,
        validator: (value) => _dateError(key, value),
        builder: (field) => InkWell(
          key: ValueKey(key),
          onTap: () async {
            final first = DateTime(2000),
                last = key == 'card.issuedAt'
                    ? DateTime.now()
                    : DateTime(2100, 12, 31);
            final current = field.value ?? DateTime.now();
            final initial = current.isBefore(first)
                ? first
                : current.isAfter(last)
                ? last
                : current;
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: first,
              lastDate: last,
            );
            if (date != null && mounted) {
              field.didChange(date);
              _change(key, date);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: spec.label,
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              field.value == null
                  ? 'Выберите дату'
                  : DateFormat('dd.MM.yyyy').format(field.value!),
            ),
          ),
        ),
      );
    }
    return TextFormField(
      controller: _controllers[key],
      key: ValueKey(key),
      maxLines: spec.lines,
      decoration: InputDecoration(labelText: spec.label),
      keyboardType: switch (spec.type) {
        FieldType.integer => TextInputType.number,
        FieldType.price => const TextInputType.numberWithOptions(decimal: true),
        FieldType.email => TextInputType.emailAddress,
        FieldType.phone => TextInputType.phone,
        _ => spec.lines > 1 ? TextInputType.multiline : TextInputType.text,
      },
      textInputAction: spec.lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      validator: (value) => spec.validator?.call(value) ?? editor.errors[key],
      onChanged: (value) => _change(key, value),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  CatalogEntity _entity() {
    final json = <String, dynamic>{
      ...?widget.entity?.toJson(),
      'id': widget.entity?.id ?? 0,
    };
    for (final field in _fields) {
      final value = _values[field.key];
      if (!field.key.startsWith('card.')) {
        json[field.key] = value is String ? value.trim() : value;
      }
    }
    if (editor.kind == EntityKind.products) {
      json['priceKopecks'] = V.kopecks(_controllers['price']!.text);
      json['stock'] = int.parse(_controllers['stock']!.text.trim());
    }
    if (editor.kind == EntityKind.brands) {
      json['foundedYear'] = int.parse(_controllers['foundedYear']!.text.trim());
    }
    if (editor.kind == EntityKind.customers) {
      json['card'] = {
        'id': widget.entity?.id ?? 0,
        'number': _controllers['card.number']!.text.trim(),
        'points': int.parse(_controllers['card.points']!.text.trim()),
        'issuedAt': (_values['card.issuedAt'] as DateTime).toIso8601String(),
        'expiresAt': (_values['card.expiresAt'] as DateTime).toIso8601String(),
      };
    }
    return editor.kind.decode(json);
  }

  Future<void> _submit() async {
    if (editor.saving) return;
    editor.errors.clear();
    if (!_form.currentState!.validate()) return;
    final saved = await editor.save(_entity());
    if (!mounted) return;
    if (saved == null) {
      _form.currentState!.validate();
      return;
    }
    setState(() => _dirty = false);
    setUnsavedChanges(false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
    context.go(
      Uri(
        path: '${editor.kind.path}/${saved.id}',
        queryParameters: {'from': widget.back},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<EditorNotifier>();
    final reference = context.watch<CatalogReference>();
    return PopScope(
      canPop: !_dirty && !n.saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !n.saving) context.go(widget.back);
      },
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: n.saving
                            ? null
                            : () => context.go(widget.back),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('К списку'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${n.id == null ? 'Создать' : 'Редактировать'} ${n.kind.singular}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Заполните поля и сохраните изменения.'),
                    const SizedBox(height: 24),
                    AbsorbPointer(
                      absorbing: n.saving,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final spec in _fields) ...[
                            if (spec.key == 'card.number') ...[
                              const Divider(height: 32),
                              Text(
                                'Карта лояльности',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 20),
                            ],
                            _field(spec, reference),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    if (n.saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          n.saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: n.saving ? null : _submit,
                          icon: n.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(n.saving ? 'Сохранение…' : 'Сохранить'),
                        ),
                        OutlinedButton(
                          onPressed: n.saving
                              ? null
                              : () => context.go(widget.back),
                          child: const Text('Отмена'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
