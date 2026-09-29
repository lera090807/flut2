import 'package:flutter/material.dart';

import '../models/page_result.dart';

class PaginationBar<T> extends StatelessWidget {
  final PageResult<T> result;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;
  const PaginationBar({
    super.key,
    required this.result,
    required this.onPage,
    required this.onSize,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Всего записей: ${result.total}'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('На странице: '),
            DropdownButton<int>(
              value: result.size,
              items: [
                for (final size in [10, 25, 50])
                  DropdownMenuItem(value: size, child: Text('$size')),
              ],
              onChanged: (v) {
                if (v != null) onSize(v);
              },
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Первая страница',
              onPressed: result.hasPrevious ? () => onPage(1) : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              tooltip: 'Предыдущая страница',
              onPressed: result.hasPrevious
                  ? () => onPage(result.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${result.page} / ${result.totalPages}'),
            IconButton(
              tooltip: 'Следующая страница',
              onPressed: result.hasNext ? () => onPage(result.page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Последняя страница',
              onPressed: result.hasNext
                  ? () => onPage(result.totalPages)
                  : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ],
    ),
  );
}
