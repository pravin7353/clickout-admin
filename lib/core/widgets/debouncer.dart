import 'dart:async';

/// Reusable debouncer for search fields, API-lookup fields (pincode, IFSC,
/// branch-code check) etc. Prevents firing an API call on every keystroke.
///
/// Usage:
///   final _debouncer = Debouncer(milliseconds: 500);
///   onChanged: (v) => _debouncer.run(() => _checkBranchCode(v));
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 500});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
