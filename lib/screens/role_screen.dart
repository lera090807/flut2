import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';

class RoleScreen extends StatefulWidget {
  final String section;
  const RoleScreen({super.key, required this.section});
  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  Map<String, dynamic>? _data, _stats;
  List<dynamic> _products = [];
  String? _error;
  bool _loading = true, _busy = false;
  int? _productId;
  AuthNotifier get auth => context.read<AuthNotifier>();
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final endpoint = widget.section == 'admin'
          ? '/admin/users'
          : '/${widget.section}';
      final data = await auth.request(endpoint) as Map<String, dynamic>;
      Map<String, dynamic>? stats;
      List<dynamic> products = [];
      if (widget.section == 'admin') {
        stats = await auth.request('/admin/stats') as Map<String, dynamic>;
      }
      if (widget.section == 'my-orders') {
        products =
            (await auth.request('/products?size=100')
                    as Map<String, dynamic>)['items']
                as List;
      }
      if (mounted) {
        setState(() {
          _data = data;
          _stats = stats;
          _products = products.where((e) => e['stock'] > 0).toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить данные');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(
    String path,
    String method,
    Map<String, dynamic> data,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await auth.request(path, method: method, data: data);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить изменения')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String status(dynamic value) =>
      const {
        'new': 'Новый',
        'ready': 'Готов к выдаче',
        'completed': 'Выдан',
        'cancelled': 'Отменён',
      }[value] ??
      '$value';
  @override
  Widget build(BuildContext context) {
    final title = const {
      'account': 'Личный кабинет',
      'my-orders': 'Мои заказы',
      'orders': 'Обработка заказов',
      'admin': 'Пользователи и статистика',
    }[widget.section]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ] else if (widget.section == 'account') ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user!.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(auth.user!.email),
                    Text('Ваших заказов: ${_data!['orders']}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/my-orders'),
                      child: const Text('Открыть мои заказы'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (widget.section == 'admin') ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in {
                    'products': 'Товаров',
                    'customers': 'Покупателей',
                    'users': 'Пользователей',
                    'orders': 'Заказов',
                  }.entries)
                    SizedBox(
                      width: 200,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            '${e.value}: ${_stats![e.key]}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              for (final u in _data!['items'])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          child: Text(
                            '${u['fullName']}\n${u['username']} · ${u['email']}',
                          ),
                        ),
                        SizedBox(
                          width: 230,
                          child: DropdownButtonFormField<String>(
                            initialValue: u['role'],
                            decoration: const InputDecoration(
                              labelText: 'Роль',
                            ),
                            items: [
                              for (final r in Role.values)
                                DropdownMenuItem(
                                  value: r.name,
                                  child: Text(r.label),
                                ),
                            ],
                            onChanged: _busy || u['id'] == auth.user!.id
                                ? null
                                : (value) => _action(
                                    '/admin/users/${u['id']}/role',
                                    'PUT',
                                    {'role': value},
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              if (widget.section == 'my-orders')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Забронировать товар',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            _products.map((e) => e['id']).join(','),
                          ),
                          isExpanded: true,
                          initialValue:
                              _products.any((e) => e['id'] == _productId)
                              ? _productId
                              : null,
                          decoration: const InputDecoration(labelText: 'Товар'),
                          items: [
                            for (final p in _products)
                              DropdownMenuItem(
                                value: p['id'] as int,
                                child: Text(
                                  p['name'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _productId = value),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy || _productId == null
                              ? null
                              : () => _action('/my-orders', 'POST', {
                                  'productId': _productId,
                                }),
                          child: const Text('Оформить заказ'),
                        ),
                      ],
                    ),
                  ),
                ),
              if ((_data!['items'] as List).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Заказов пока нет'),
                ),
              for (final order in _data!['items'])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Заказ №${order['id']} · ${order['productName']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Статус: ${status(order['status'])}'),
                        if (widget.section == 'orders')
                          Text('Покупатель: ${order['customerName']}'),
                        Text(
                          'Забрать до: ${DateTime.parse(order['pickupUntil']).toLocal().toString().substring(0, 16)}',
                        ),
                        const SizedBox(height: 12),
                        if (widget.section == 'my-orders' &&
                            order['extended'] != true &&
                            ['new', 'ready'].contains(order['status']))
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _action(
                                    '/my-orders/${order['id']}/extend',
                                    'POST',
                                    {},
                                  ),
                            child: const Text('Продлить на 2 дня'),
                          ),
                        if (widget.section == 'orders')
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final next
                                  in (order['status'] == 'new'
                                      ? ['ready', 'cancelled']
                                      : order['status'] == 'ready'
                                      ? ['completed', 'cancelled']
                                      : <String>[]))
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _action(
                                          '/orders/${order['id']}',
                                          'PUT',
                                          {'status': next},
                                        ),
                                  child: Text(status(next)),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
