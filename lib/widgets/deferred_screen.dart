import 'package:flutter/material.dart';

import 'result_message.dart';

class DeferredScreen extends StatefulWidget {
  final Future<void> Function() load;
  final WidgetBuilder builder;
  const DeferredScreen({super.key, required this.load, required this.builder});
  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _pending = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _pending,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return SingleChildScrollView(
          child: ResultMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Не удалось открыть раздел',
            message: 'Проверьте соединение и попробуйте снова.',
            actionLabel: 'Повторить',
            onAction: () => setState(() => _pending = widget.load()),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Загрузка раздела'),
        );
      }
      return widget.builder(context);
    },
  );
}
