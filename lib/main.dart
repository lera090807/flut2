import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'repositories/shop_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  try {
    final prefs = await SharedPreferences.getInstance();
    final database = await ShopDatabase.open(prefs);
    runApp(CosmeticsApp(database: database));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Не удалось открыть хранилище браузера. Разрешите сохранение данных сайта и повторите попытку.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Повторить')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
