import 'dart:async';

class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({this.duration = const Duration(milliseconds: 300)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancel any pending execution
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check if there's a pending execution
  bool get isActive => _timer?.isActive ?? false;

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
