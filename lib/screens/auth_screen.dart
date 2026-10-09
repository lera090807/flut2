import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../core/api_exceptions.dart';
import '../core/validation_exception.dart';
import '../core/validators.dart';
import '../core/permissions.dart';

class AuthScreen extends StatefulWidget {
  final bool register;
  final String? from;
  const AuthScreen({super.key, this.register = false, this.from});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final k in ['username', 'password', 'fullName', 'email'])
      k: TextEditingController(),
  };
  Map<String, String> _errors = {};
  String? _error;
  bool _busy = false, _visible = false;
  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _errors = {};
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthNotifier>();
    try {
      if (widget.register) {
        await auth.register({
          for (final e in _controllers.entries) e.key: e.value.text,
        });
        if (mounted) {
          context.go(
            Uri(
              path: '/login',
              queryParameters: {
                'registered': 'true',
                'from': safeReturnPath(widget.from),
              },
            ).toString(),
          );
        }
      } else {
        await auth.login(
          _controllers['username']!.text.trim(),
          _controllers['password']!.text,
        );
      }
    } on ValidationException catch (e) {
      if (mounted) setState(() => _errors = e.errors);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось выполнить вход. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final pass = _controllers['password']!.text;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.spa_outlined, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Магазин косметики',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.register ? 'Регистрация' : 'Вход',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (!widget.register && auth.message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(auth.message!),
                          ),
                        if (!widget.register &&
                            GoRouterState.of(context)
                                    .uri
                                    .queryParameters['registered'] ==
                                'true')
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Text('Аккаунт создан. Теперь можно войти.'),
                          ),
                        for (final key in [
                          if (widget.register) 'fullName',
                          if (widget.register) 'email',
                          'username',
                          'password',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              key: ValueKey(key),
                              controller: _controllers[key],
                              enabled: !_busy,
                              obscureText: key == 'password' && !_visible,
                              autocorrect: key != 'password',
                              enableSuggestions: key != 'password',
                              keyboardType: key == 'email'
                                  ? TextInputType.emailAddress
                                  : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: const {
                                  'fullName': 'Имя',
                                  'email': 'Электронная почта',
                                  'username': 'Логин',
                                  'password': 'Пароль',
                                }[key],
                                errorText: _errors[key],
                                suffixIcon: key == 'password'
                                    ? IconButton(
                                        tooltip: _visible
                                            ? 'Скрыть пароль'
                                            : 'Показать пароль',
                                        onPressed: () => setState(
                                          () => _visible = !_visible,
                                        ),
                                        icon: Icon(
                                          _visible
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {
                                _errors.remove(key);
                                _error = null;
                              }),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Поле обязательно';
                                }
                                if (key == 'email') return V.email()(value);
                                if (widget.register &&
                                    key == 'username' &&
                                    !RegExp(r'^[a-zA-Z0-9_]{3,32}$')
                                        .hasMatch(value)) {
                                  return 'От 3 до 32 латинских букв, цифр или подчёркиваний';
                                }
                                if (widget.register &&
                                    key == 'password' &&
                                    (value.length < 8 ||
                                        value.length > 128 ||
                                        !RegExp(r'[0-9]').hasMatch(value) ||
                                        !RegExp(
                                          r'[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]',
                                        ).hasMatch(value))) {
                                  return 'Нужны 8–128 символов, цифра и специальный символ';
                                }
                                if (key == 'fullName') return V.text()(value);
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ),
                        if (widget.register)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              '${pass.length >= 8 ? '✓' : '○'} Не менее 8 символов\n${RegExp(r'[0-9]').hasMatch(pass) ? '✓' : '○'} Хотя бы одна цифра\n${RegExp(r'[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]').hasMatch(pass) ? '✓' : '○'} Специальный символ, например !',
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _busy
                                ? 'Подождите…'
                                : widget.register
                                ? 'Зарегистрироваться'
                                : 'Войти',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(
                                  Uri(
                                    path: widget.register
                                        ? '/login'
                                        : '/register',
                                    queryParameters: {
                                      'from': safeReturnPath(widget.from),
                                    },
                                  ).toString(),
                                ),
                          child: Text(
                            widget.register
                                ? 'Уже есть аккаунт? Войти'
                                : 'Создать аккаунт',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: auth.restoreError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(auth.restoreError!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: auth.restore,
                      child: const Text('Повторить'),
                    ),
                    TextButton(
                      onPressed: () => auth.logout(),
                      child: const Text('Перейти ко входу'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
