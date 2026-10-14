import 'package:flutter/services.dart';

/// Dart side is intentionally thin — every actual check happens in
/// MainActivity.kt (native layer). This makes Dart-side tampering useless.
enum SecurityStatus { ok, vpn, mitm, tampered, ssl, rooted, frida, emulator, debugger, xposed, error }

class SecurityResult {
  final SecurityStatus status;
  final String? message;
  SecurityResult._(this.status, [this.message]);

  factory SecurityResult.ok() => SecurityResult._(SecurityStatus.ok);
  factory SecurityResult.error(String m) => SecurityResult._(SecurityStatus.error, m);

  bool get isOk => status == SecurityStatus.ok;
}

class SecurityService {
  static const _channel = MethodChannel('hosting/security');

  /// Calls the native fullSecurityCheck() — everything is done in Kotlin.
  static Future<SecurityResult> verify() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('fullSecurityCheck');
      if (raw == null) return SecurityResult.error('no_response');
      if (raw['ok'] == true) return SecurityResult.ok();
      final reason = raw['reason']?.toString() ?? 'error';
      final msg = raw['message']?.toString();
      return SecurityResult._(_map(reason), msg);
    } catch (e) {
      return SecurityResult.error(e.toString());
    }
  }

  static SecurityStatus _map(String r) {
    switch (r) {
      case 'vpn': return SecurityStatus.vpn;
      case 'mitm': return SecurityStatus.mitm;
      case 'tampered': return SecurityStatus.tampered;
      case 'ssl': return SecurityStatus.ssl;
      case 'rooted': return SecurityStatus.rooted;
      case 'frida': return SecurityStatus.frida;
      case 'emulator': return SecurityStatus.emulator;
      case 'debugger': return SecurityStatus.debugger;
      case 'xposed': return SecurityStatus.xposed;
      default: return SecurityStatus.error;
    }
  }
}
