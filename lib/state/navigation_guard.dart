class NavigationGuard {
  Future<bool> Function()? confirm;
  Future<bool> allowExit() async => await confirm?.call() ?? true;
}
