import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

/// Multi-source signature verification + VPN + instrumentation detection.
class SecurityService {
  static const _sources = [
    'https://raw.githubusercontent.com/Alaa537/hosting-sec/main/signature.json',
    'https://cdn.jsdelivr.net/gh/Alaa537/hosting-sec@main/signature.json',
    'https://cdn.statically.io/gh/Alaa537/hosting-sec/main/signature.json',
    'https://alaa537.github.io/hosting-sec/signature.json',
  ];

  static const _channel = MethodChannel('hosting/security');

  /// Returns null if OK, otherwise a reason code.
  static Future<SecurityResult> verify() async {
    // 1) VPN check (best-effort via platform channel + fallback)
    final vpn = await _checkVpn();
    if (vpn) return SecurityResult.vpnDetected();

    // 2) HTTP proxy / instrumentation check
    final mitm = await _checkMitm();
    if (mitm) return SecurityResult.mitmDetected();

    // 3) Signature check from remote source
    final sig = await _checkSignature();
    return sig;
  }

  // ---------- VPN ----------
  static Future<bool> _checkVpn() async {
    try {
      final r = await _channel.invokeMethod<bool>('isVpnActive');
      return r == true;
    } catch (_) {
      // Fallback: try reading /proc/net via platform channel
      try {
        final r = await _channel.invokeMethod<bool>('hasVpnInterface');
        return r == true;
      } catch (_) {
        return false;
      }
    }
  }

  // ---------- MITM detection ----------
  static Future<bool> _checkMitm() async {
    try {
      // Check system proxy settings
      final proxy = await _channel.invokeMethod<String>('getHttpProxy');
      if (proxy != null && proxy.isNotEmpty) return true;

      // Check common CA certs installed (Canary/Charles)
      final ca = await _channel.invokeMethod<bool>('hasSuspiciousCa');
      if (ca == true) return true;

      // Check running processes for known MITM tools
      final procs = await _channel.invokeMethod<String>('getRunningProcs');
      if (procs != null) {
        final lower = procs.toLowerCase();
        for (final name in const [
          'canary', 'charles', 'fiddler', 'mitmproxy',
          'burpsuite', 'httpcanary', 'httptoolkit', 'packetcapture',
        ]) {
          if (lower.contains(name)) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------- Signature ----------
  static Future<SecurityResult> _checkSignature() async {
    final localSha = await _getLocalSignatureSha256();
    if (localSha == null || localSha.isEmpty) {
      return SecurityResult.error('تعذّر قراءة توقيع التطبيق');
    }

    String? remoteSha;
    for (final url in _sources) {
      try {
        final r = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 6));
        if (r.statusCode == 200) {
          final j = jsonDecode(r.body) as Map<String, dynamic>;
          final sigs = j['signatures'] as Map<String, dynamic>?;
          if (sigs != null) {
            remoteSha = _normalize(sigs['sha256']?.toString() ?? '');
            if (remoteSha.isNotEmpty) break;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (remoteSha == null || remoteSha.isEmpty) {
      return SecurityResult.error('تعذّر التحقق من التوقيع عبر الشبكة');
    }

    if (_normalize(localSha) != remoteSha) {
      return SecurityResult.tampered();
    }
    return SecurityResult.ok();
  }

  /// Reads the APK signature SHA-256 from native side.
  static Future<String?> _getLocalSignatureSha256() async {
    try {
      return await _channel.invokeMethod<String>('getApkSignatureSha256');
    } catch (_) {
      return null;
    }
  }

  static String _normalize(String s) =>
      s.replaceAll(':', '').replaceAll(' ', '').toLowerCase().trim();
}

class SecurityResult {
  final SecurityStatus status;
  final String? message;

  SecurityResult._(this.status, [this.message]);

  factory SecurityResult.ok() => SecurityResult._(SecurityStatus.ok);
  factory SecurityResult.vpnDetected() => SecurityResult._(
      SecurityStatus.vpn, 'تم كشف اتصال VPN نشط.');
  factory SecurityResult.mitmDetected() => SecurityResult._(
      SecurityStatus.mitm, 'تم كشف أداة مراقبة الشبكة.');
  factory SecurityResult.tampered() => SecurityResult._(
      SecurityStatus.tampered, 'توقيع التطبيق غير مطابق. النسخة معدّلة.');
  factory SecurityResult.error(String msg) =>
      SecurityResult._(SecurityStatus.error, msg);

  bool get isOk => status == SecurityStatus.ok;
}

enum SecurityStatus { ok, vpn, mitm, tampered, error }
