sealed class LoadState<T> {
  const LoadState();
}

class Loading<T> extends LoadState<T> {
  const Loading();
}

class Loaded<T> extends LoadState<T> {
  final T data;
  const Loaded(this.data);
}

class Failed<T> extends LoadState<T> {
  final String message;
  const Failed(this.message);
}
