import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/storage.dart';

/// Generates and persists a stable per-install device id.
/// Format: `flt-<random-hex>`.
class DeviceInfo {
  static String? _cached;

  /// Returns the persistent device id (generates one on first call).
  static Future<String> deviceId() async {
    if (_cached != null) return _cached!;
    final existing = await Store.readDeviceId();
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = 'flt-$hex';
    await Store.saveDeviceId(id);
    _cached = id;
    return id;
  }

  /// Best-effort platform tag.
  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'android';
      case TargetPlatform.iOS: return 'ios';
      case TargetPlatform.macOS: return 'macos';
      case TargetPlatform.windows: return 'windows';
      case TargetPlatform.linux: return 'linux';
      default: return 'unknown';
    }
  }
}
