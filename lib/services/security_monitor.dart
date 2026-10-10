import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'security_service.dart';

/// Global singleton that re-verifies security every N seconds.
/// When a check fails, it fires [onFailure] — the UI layer shows
/// the block screen and stops the app.
class SecurityMonitor with WidgetsBindingObserver {
  static final SecurityMonitor I = SecurityMonitor._();
  SecurityMonitor._();

  static const _interval = Duration(seconds: 5);

  Timer? _timer;
  bool _running = false;
  bool _appInForeground = true;

  /// Last result (so the UI can show the correct message).
  SecurityResult? lastResult;

  /// Called whenever the check fails. Overwrite from main().
  void Function(SecurityResult result)? onFailure;

  /// Called when a check succeeds after previously failing.
  VoidCallback? onRecovered;

  SecurityResult? _lastFailed;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    // First check immediately
    _tick();
    _timer = Timer.periodic(_interval, (_) {
      if (_appInForeground) _tick();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    try { WidgetsBinding.instance.removeObserver(this); } catch (_) {}
  }

  Future<void> _tick() async {
    try {
      final r = await SecurityService.verify();
      lastResult = r;

      if (!r.isOk) {
        _lastFailed = r;
        onFailure?.call(r);
      } else if (_lastFailed != null) {
        // Recovered (e.g. VPN turned off)
        _lastFailed = null;
        onRecovered?.call();
      }
    } catch (_) {
      // Ignore network errors during periodic check
    }
  }

  /// Force an immediate check (e.g. on resume).
  Future<void> poke() => _tick();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
      // Resume → check immediately
      poke();
    }
  }
}
