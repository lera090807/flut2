import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/validation_exception.dart';
import '../models/catalog_entity.dart';
import '../models/catalog_query.dart';
import '../models/page_result.dart';
import '../state/catalog_notifier.dart';
import '../state/catalog_reference.dart';
import '../state/load_state.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/entity_table.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/result_message.dart';

class CatalogScreen<T extends CatalogEntity> extends StatefulWidget {
  final CatalogQuery query;
  final String path;
  final String title;
  final String subtitle;
  final String searchHint;
  final bool products;
  final String? filterLabel;
  final Map<String, String> filterOptions;
  final List<TableColumnSpec<T>> columns;
  final String Function(T) summary;
  const CatalogScreen({
    super.key,
    required this.query,
    required this.path,
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.products,
    this.filterLabel,
    this.filterOptions = const {},
    required this.columns,
    required this.summary,
  });
  @override
  State<CatalogScreen<T>> createState() => _CatalogScreenState<T>();
}

class _CatalogScreenState<T extends CatalogEntity>
    extends State<CatalogScreen<T>> {
  final _search = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  Timer? _debounce;
  String? _priceError;
  CatalogNotifier<T> get notifier => context.read<CatalogNotifier<T>>();
  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _debounce?.cancel();
    _search.text = widget.query.search;
    _min.text = widget.query.minPrice?.toString() ?? '';
    _max.text = widget.query.maxPrice?.toString() ?? '';
    _priceError = null;
    Future.microtask(() {
      if (mounted) notifier.applyQuery(widget.query);
    });
  }

  @override
  void didUpdateWidget(covariant CatalogScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.location(widget.path) !=
        widget.query.location(widget.path)) {
      _sync();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _navigate(CatalogQuery query) {
    _debounce?.cancel();
    final location = query.location(widget.path);
    if (location != widget.query.location(widget.path)) {
      // go сохраняет завершённые изменения фильтров в истории браузера.
      context.go(location);
    }
  }

  void _sort(String field) => _navigate(
    widget.query.copyWith(
      sortField: field,
      ascending: field == widget.query.sortField
          ? !widget.query.ascending
          : true,
    ),
  );
  void _prices() {
    final min = int.tryParse(_min.text);
    final max = int.tryParse(_max.text);
    final invalid =
        (_min.text.isNotEmpty && min == null) ||
        (_max.text.isNotEmpty && max == null) ||
        (min != null && max != null && min > max);
    setState(
      () => _priceError = invalid
          ? 'Проверьте диапазон: цена «от» не должна превышать цену «до».'
          : null,
    );
    if (!invalid) {
      _navigate(widget.query.copyWith(minPrice: min, maxPrice: max));
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _deleteSelected() async {
    if (!await confirmDelete(
      context,
      title: 'Удалить выбранные записи?',
      message:
          'Выбрано: ${notifier.selected.length}. Записи можно будет восстановить.',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      final count = await notifier.deleteSelected();
      _snack('Удалено записей: $count');
    } on RelatedRecordsException catch (e) {
      _snack(e.toString());
    } on StorageException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Не удалось удалить записи. Попробуйте ещё раз.');
    }
  }

  Future<void> _action(T item, String action) async {
    if (action == 'edit') {
      context.go(
        Uri(
          path: '${widget.path}/${item.id}/edit',
          queryParameters: {'from': widget.query.location(widget.path)},
        ).toString(),
      );
      return;
    }
    if (action != 'restore') {
      final confirmed = await confirmDelete(
        context,
        title: action == 'hard' ? 'Удалить навсегда?' : 'Удалить запись?',
        message: action == 'hard'
            ? '«${item.name}» будет удалён без возможности восстановления.'
            : '«${item.name}» будет скрыт из каталога. Его можно восстановить.',
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await notifier.mutate(item.id, action);
      _snack(action == 'restore' ? 'Запись восстановлена' : 'Запись удалена');
    } on RelatedRecordsException catch (e) {
      _snack(e.toString());
    } on StorageException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Не удалось выполнить операцию. Попробуйте ещё раз.');
    }
  }

  List<Widget> _actions(T item) => [
    IconButton(
      tooltip: 'Открыть карточку',
      onPressed: () => context.go(
        Uri(
          path: '${widget.path}/${item.id}',
          queryParameters: {'from': widget.query.location(widget.path)},
        ).toString(),
      ),
      icon: const Icon(Icons.open_in_new, size: 20),
    ),
    PopupMenuButton<String>(
      tooltip: 'Действия с записью',
      enabled: !notifier.busy,
      onSelected: (action) => _action(item, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        if (item.isDeleted)
          const PopupMenuItem(value: 'restore', child: Text('Восстановить'))
        else
          const PopupMenuItem(value: 'soft', child: Text('Удалить')),
        const PopupMenuItem(value: 'hard', child: Text('Удалить навсегда')),
      ],
    ),
  ];
  Widget _filters(bool compact) {
    final reference = context.watch<CatalogReference>();
    final q = widget.query;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Очистить поиск',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _search.clear();
                    _navigate(q.copyWith(search: ''));
                  },
                ),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) _navigate(widget.query.copyWith(search: value));
                });
              },
            ),
            const SizedBox(height: 8),
            if (widget.filterLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('filter-${q.filter}'),
                  initialValue: widget.filterOptions.containsKey(q.filter)
                      ? q.filter
                      : '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: widget.filterLabel),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Все значения'),
                    ),
                    for (final option in widget.filterOptions.entries)
                      DropdownMenuItem(
                        value: option.key,
                        child: Text(option.value),
                      ),
                  ],
                  onChanged: (v) => _navigate(q.copyWith(filter: v ?? '')),
                ),
              ),
            if (widget.products)
              ExpansionTile(
                key: ValueKey('filters-$compact'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                initiallyExpanded: !compact,
                title: const Text(
                  'Фильтры',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: compact ? double.infinity : 205,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('category-${q.categoryId}'),
                            initialValue:
                                reference.categories.any(
                                  (c) => !c.isDeleted && c.id == q.categoryId,
                                )
                                ? q.categoryId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Категория',
                            ),
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('Все категории'),
                              ),
                              for (final c in reference.categories.where(
                                (e) => !e.isDeleted,
                              ))
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                            ],
                            onChanged: (v) =>
                                _navigate(q.copyWith(categoryId: v)),
                          ),
                        ),
                        SizedBox(
                          width: compact ? double.infinity : 185,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('brand-${q.brandId}'),
                            initialValue:
                                reference.brands.any(
                                  (b) => !b.isDeleted && b.id == q.brandId,
                                )
                                ? q.brandId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Бренд',
                            ),
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('Все бренды'),
                              ),
                              for (final b in reference.brands.where(
                                (e) => !e.isDeleted,
                              ))
                                DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name),
                                ),
                            ],
                            onChanged: (v) => _navigate(q.copyWith(brandId: v)),
                          ),
                        ),
                        SizedBox(
                          width: 125,
                          child: TextField(
                            controller: _min,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Цена от, ₽',
                            ),
                            onSubmitted: (_) => _prices(),
                          ),
                        ),
                        SizedBox(
                          width: 125,
                          child: TextField(
                            controller: _max,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Цена до, ₽',
                            ),
                            onSubmitted: (_) => _prices(),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _prices,
                          child: const Text('Применить цену'),
                        ),
                      ],
                    ),
                  ),
                  if (_priceError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _priceError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: q.onlyDeleted,
                      onChanged: (v) => _navigate(
                        q.copyWith(onlyDeleted: v, includeDeleted: false),
                      ),
                    ),
                    const Flexible(child: Text('Только удалённые')),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _navigate(const CatalogQuery()),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(LoadState<PageResult<T>> state, bool compact) =>
      switch (state) {
        Loading() => const Padding(
          padding: EdgeInsets.all(70),
          child: Center(child: CircularProgressIndicator()),
        ),
        Failed(message: final message) => ResultMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Не удалось загрузить каталог',
          message: message,
          actionLabel: 'Повторить',
          onAction: () => notifier.load(),
        ),
        Loaded(data: final result) => _loaded(result, compact),
      };
  Widget _loaded(PageResult<T> result, bool compact) {
    // Корректируем только результат именно этого запроса, например после удаления.
    // Старые данные во время смены URL никогда не должны возвращать прошлую страницу.
    if (result.page != widget.query.page) {
      final requestedLocation = widget.query.location(widget.path);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.query.location(widget.path) != requestedLocation) {
          return;
        }
        final current = notifier.state;
        if (notifier.query.location(widget.path) == requestedLocation &&
            current is Loaded<PageResult<T>> &&
            identical(current.data, result)) {
          context.replace(
            widget.query.copyWith(page: result.page).location(widget.path),
          );
        }
      });
    }
    final n = context.watch<CatalogNotifier<T>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (n.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              spacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Выбрано: ${n.selected.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                FilledButton.icon(
                  onPressed: n.busy ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить выбранные'),
                ),
              ],
            ),
          ),
        if (result.items.isEmpty)
          ResultMessage(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            message: 'Попробуйте другой запрос или сбросьте фильтры.',
            actionLabel: 'Сбросить фильтры',
            onAction: () => _navigate(const CatalogQuery()),
          )
        else if (compact) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('sort-${widget.query.sortField}'),
                  initialValue: widget.query.sortField,
                  decoration: const InputDecoration(labelText: 'Сортировка'),
                  items: [
                    for (final col in widget.columns.where(
                      (c) => c.sortField != null,
                    ))
                      DropdownMenuItem(
                        value: col.sortField,
                        child: Text(col.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _sort(v);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Изменить направление сортировки',
                onPressed: () => _sort(widget.query.sortField),
                icon: Icon(
                  widget.query.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
              ),
            ],
          ),
          for (final item in result.items)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: n.selected.contains(item.id),
                          onChanged: n.busy
                              ? null
                              : (_) => n.toggleSelection(item.id),
                        ),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        widget.summary(item),
                        style: const TextStyle(height: 1.7),
                      ),
                    ),
                    Row(
                      children: [
                        if (item.isDeleted) const Chip(label: Text('Удалено')),
                        const Spacer(),
                        ..._actions(item),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: (result.items.length * 76.0 + 64).clamp(140, 600),
              child: EntityTable<T>(
                columns: widget.columns,
                items: result.items,
                idOf: (e) => e.id,
                selected: n.selected,
                onToggleSelect: n.toggleSelection,
                onSelectAll: (v) =>
                    n.selectAll(result.items.map((e) => e.id), v),
                sortField: widget.query.sortField,
                ascending: widget.query.ascending,
                onSort: _sort,
                actions: _actions,
              ),
            ),
          ),
        ],
        PaginationBar(
          result: result,
          onPage: (p) => _navigate(widget.query.copyWith(page: p)),
          onSize: (s) => _navigate(widget.query.copyWith(size: s)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<CatalogNotifier<T>>();
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'КАТАЛОГ / ${widget.title.toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Color(0xFF927C85),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: compact ? 28 : 36,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Создать запись',
                  onPressed: () => context.go(
                    Uri(
                      path: '${widget.path}/new',
                      queryParameters: {
                        'from': widget.query.location(widget.path),
                      },
                    ).toString(),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Проверка состояний',
                  onSelected: (v) => n.load(simulateError: v == 'error'),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'reload',
                      child: Text('Обновить список'),
                    ),
                    PopupMenuItem(
                      value: 'error',
                      child: Text('Показать учебную ошибку'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: const TextStyle(color: Color(0xFF84717A), height: 1.5),
            ),
            const SizedBox(height: 24),
            _filters(compact),
            _content(
              n.query.location(widget.path) ==
                      widget.query.location(widget.path)
                  ? n.state
                  : const Loading(),
              compact,
            ),
          ],
        ),
      ),
    );
  }
}
