import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T) build;
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatefulWidget {
  final bool selectable;
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T) idOf;
  final Set<int> selected;
  final ValueChanged<int> onToggleSelect;
  final ValueChanged<bool> onSelectAll;
  final String sortField;
  final bool ascending;
  final ValueChanged<String> onSort;
  final List<Widget> Function(T) actions;
  const EntityTable({
    super.key,
    this.selectable = true,
    required this.columns,
    required this.items,
    required this.idOf,
    required this.selected,
    required this.onToggleSelect,
    required this.onSelectAll,
    required this.sortField,
    required this.ascending,
    required this.onSort,
    required this.actions,
  });
  @override
  State<EntityTable<T>> createState() => _EntityTableState<T>();
}

class _EntityTableState<T> extends State<EntityTable<T>> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortIndex = widget.columns.indexWhere(
      (c) => c.sortField == widget.sortField,
    );
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Scrollbar(
              controller: _vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                child: DataTable(
                  sortColumnIndex: sortIndex < 0 ? null : sortIndex,
                  sortAscending: widget.ascending,
                  onSelectAll: widget.selectable
                      ? (v) => widget.onSelectAll(v ?? false)
                      : null,
                  showCheckboxColumn: widget.selectable,
                  columns: [
                    for (final c in widget.columns)
                      DataColumn(
                        label: Text(c.label),
                        numeric: c.numeric,
                        onSort: c.sortField == null
                            ? null
                            : (_, _) => widget.onSort(c.sortField!),
                      ),
                    const DataColumn(label: Text('Действия')),
                  ],
                  rows: [
                    for (final item in widget.items)
                      DataRow(
                        selected: widget.selected.contains(widget.idOf(item)),
                        onSelectChanged: widget.selectable
                            ? (_) => widget.onToggleSelect(widget.idOf(item))
                            : null,
                        cells: [
                          for (final c in widget.columns)
                            DataCell(c.build(item)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: widget.actions(item),
                            ),
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
