import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/auth_notifier.dart';

class SessionWatcher extends StatefulWidget {
  final AuthNotifier auth;
  final Widget child;
  const SessionWatcher({super.key, required this.auth, required this.child});
  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher>
    with WidgetsBindingObserver {
  bool _key(KeyEvent event) {
    widget.auth.activity();
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.auth.checkTime();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => widget.auth.activity(),
    onPointerMove: (_) => widget.auth.activity(),
    onPointerHover: (_) => widget.auth.activity(),
    onPointerSignal: (_) => widget.auth.activity(),
    child: widget.child,
  );
}
