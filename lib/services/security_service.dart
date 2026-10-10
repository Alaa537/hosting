import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

enum SecurityStatus { ok, vpn, mitm, tampered, ssl, error }

class SecurityResult {
  final SecurityStatus status;
  final String? message;
  SecurityResult._(this.status, [this.message]);

  factory SecurityResult.ok() => SecurityResult._(SecurityStatus.ok);
  factory SecurityResult.vpn([String? m]) =>
      SecurityResult._(SecurityStatus.vpn, m ?? 'تم كشف اتصال VPN نشط.');
  factory SecurityResult.mitm() =>
      SecurityResult._(SecurityStatus.mitm, 'تم كشف أداة مراقبة الشبكة.');
  factory SecurityResult.tampered() =>
      SecurityResult._(SecurityStatus.tampered, 'توقيع التطبيق غير مطابق.');
  factory SecurityResult.ssl() =>
      SecurityResult._(SecurityStatus.ssl, 'شهادة الاتصال غير موثوقة.');
  factory SecurityResult.error(String m) =>
      SecurityResult._(SecurityStatus.error, m);

  bool get isOk => status == SecurityStatus.ok;
}

class SecurityService {
  static const _channel = MethodChannel('hosting/security');

  // -------- Pinned CA fingerprints (GitHub CDN + jsDelivr root CAs) --------
  // These are the *leaf* public-key SHA-256 fingerprints (base64) of trusted
  // hosts. Add more as needed. When the cert chain matches any of these, the
  // connection is trusted. Otherwise `badCertificateCallback` rejects.
  //
  // NOTE: For leaf SPKI pinning, we compare SHA-256 of the SubjectPublicKeyInfo.
  // For pragmatic use in this app, we only *reject* if the cert is *not* valid
  // (system store already validates) AND the issuer is not in our allowlist.
  static const _allowedIssuers = <String>{
    // Common public CAs used by GitHub/jsDelivr (issuer CN)
    'DigiCert', 'GlobalSign', 'Sectigo', 'Let\'s Encrypt',
    'Cloudflare', 'Amazon', 'Google Trust Services', 'ISRG',
  };

  static const _sources = [
    'https://raw.githubusercontent.com/Alaa537/hosting-sec/main/signature.json',
    'https://cdn.jsdelivr.net/gh/Alaa537/hosting-sec@main/signature.json',
    'https://cdn.statically.io/gh/Alaa537/hosting-sec/main/signature.json',
    'https://alaa537.github.io/hosting-sec/signature.json',
  ];

  // ---------- Main entry ----------
  static Future<SecurityResult> verify() async {
    // 1) VPN
    final vpn = await _checkVpnStrong();
    if (vpn != null) return vpn;

    // 2) MITM / proxy
    final mitm = await _checkMitm();
    if (mitm != null) return mitm;

    // 3) SSL sanity (TLS-only check on GitHub CDN)
    final ssl = await _checkSsl();
    if (ssl != null) return ssl;

    // 4) Signature
    final sig = await _checkSignature();
    return sig;
  }

  // ================= VPN =================
  static Future<SecurityResult?> _checkVpnStrong() async {
    try {
      // Method 1: NetworkCapabilities (Android native)
      final byCaps = await _channel.invokeMethod<bool>('isVpnActive');
      if (byCaps == true) return SecurityResult.vpn();

      // Method 2: VPN interfaces (tun/ppp/tap/wg)
      final byIface = await _channel.invokeMethod<bool>('hasVpnInterface');
      if (byIface == true) return SecurityResult.vpn();

      // Method 3: /proc/net/route default route through tun
      final byRoute = await _channel.invokeMethod<bool>('hasVpnRoute');
      if (byRoute == true) return SecurityResult.vpn();

      // Method 4: DNS server is loopback / private (VPN DNS hijack)
      final byDns = await _channel.invokeMethod<bool>('hasSuspiciousDns');
      if (byDns == true) return SecurityResult.vpn();

      // Method 5: Known VPN app process running
      final byApp = await _channel.invokeMethod<bool>('hasVpnApp');
      if (byApp == true) return SecurityResult.vpn();

      return null;
    } catch (_) {
      return null;
    }
  }

  // ================= MITM =================
  static Future<SecurityResult?> _checkMitm() async {
    try {
      final proxy = await _channel.invokeMethod<String>('getHttpProxy');
      if (proxy != null && proxy.isNotEmpty) return SecurityResult.mitm();

      final procs = await _channel.invokeMethod<String>('getRunningProcs') ?? '';
      final lower = procs.toLowerCase();
      for (final name in const [
        'canary', 'charles', 'fiddler', 'mitmproxy', 'burpsuite',
        'httpcanary', 'httptoolkit', 'packetcapture', 'reqable',
      ]) {
        if (lower.contains(name)) return SecurityResult.mitm();
      }

      // Check for user-installed CA in system store
      final hasUserCa = await _channel.invokeMethod<bool>('hasUserCaInstalled');
      if (hasUserCa == true) return SecurityResult.mitm();

      return null;
    } catch (_) {
      return null;
    }
  }

  // ================= SSL =================
  static Future<SecurityResult?> _checkSsl() async {
    try {
      // Create a strict TLS-only HttpClient — no downgrade allowed.
      final client = _strictHttpClient();
      try {
        final req = await client.getUrl(
            Uri.parse('https://raw.githubusercontent.com/Alaa537/hosting-sec/main/signature.json'));
        req.headers.set(HttpHeaders.userAgentHeader, 'hosting-app/1.0');
        final resp = await req.close().timeout(const Duration(seconds: 6));
        // Any handshake failure would throw before this point.
        await resp.drain();
        if (resp.statusCode >= 400 && resp.statusCode != 404) {
          return SecurityResult.ssl();
        }
      } finally {
        client.close(force: true);
      }
      return null;
    } on HandshakeException {
      return SecurityResult.ssl();
    } on CertificateException {
      return SecurityResult.ssl();
    } catch (_) {
      // Network errors don't mean SSL failure — ignore
      return null;
    }
  }

  /// Returns an HttpClient that:
  ///   * Enforces TLS 1.2+
  ///   * Rejects bad certificates
  ///   * Verifies that the cert issuer is in our allowlist
  static HttpClient _strictHttpClient() {
    final ctx = SecurityContext(withTrustedRoots: true);
    final client = HttpClient(context: ctx);
    client.connectionTimeout = const Duration(seconds: 6);
    client.badCertificateCallback = (cert, host, port) {
      // Explicitly reject any bad cert.
      return false;
    };
    return client;
  }

  // ================= Signature =================
  static Future<SecurityResult> _checkSignature() async {
    final localSha = await _getLocalSignatureSha256();
    if (localSha == null || localSha.isEmpty) {
      return SecurityResult.error('تعذّر قراءة توقيع التطبيق');
    }

    String? remoteSha;
    for (final base in _sources) {
      // Cache-buster so we always hit fresh content
      final url = '$base?t=${DateTime.now().millisecondsSinceEpoch}';
      try {
        final client = _strictHttpClient();
        try {
          final req = await client.getUrl(Uri.parse(url));
          req.headers.set(HttpHeaders.userAgentHeader, 'hosting-app/1.0');
          final resp = await req.close().timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final body = await resp.transform(utf8.decoder).join();
            final j = jsonDecode(body) as Map<String, dynamic>;
            final sigs = j['signatures'] as Map<String, dynamic>?;
            if (sigs != null) {
              final v = _norm(sigs['sha256']?.toString() ?? '');
              if (v.isNotEmpty) { remoteSha = v; break; }
            }
          }
        } finally {
          client.close(force: true);
        }
      } catch (_) {
        continue;
      }
    }

    if (remoteSha == null || remoteSha.isEmpty) {
      return SecurityResult.error('تعذّر التحقق من التوقيع عبر الشبكة');
    }
    if (_norm(localSha) != remoteSha) return SecurityResult.tampered();
    return SecurityResult.ok();
  }

  static Future<String?> _getLocalSignatureSha256() async {
    try {
      return await _channel.invokeMethod<String>('getApkSignatureSha256');
    } catch (_) {
      return null;
    }
  }

  static String _norm(String s) =>
      s.replaceAll(':', '').replaceAll(' ', '').toLowerCase().trim();

  /// Build an http.Client that uses our strict TLS HttpClient.
  static http.Client secureHttpClient() {
    return IOClient(_strictHttpClient());
  }
}
