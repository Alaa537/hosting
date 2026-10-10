import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/bootstrap.dart';
import '../services/api_client.dart';
import '../services/storage.dart';
import '../utils/device_info.dart';

enum AuthState { loading, loggedOut, loggedIn, blocked }

class AuthProvider extends ChangeNotifier {
  AuthState state = AuthState.loading;
  ApiClient? api;
  User? user;
  String baseUrl = '';
  String deviceId = '';
  String appVersion = '1.0.0';
  Bootstrap? bootstrap_;
  String? blockedReason;

  // ---------- bootstrap (startup) ----------
  Future<void> bootstrap() async {
    baseUrl = await Store.readBase();
    deviceId = await DeviceInfo.deviceId();
    appVersion = await Store.readAppVersion();

    final token = await Store.readToken();
    final refresh = await Store.readRefresh();

    api = ApiClient(baseUrl, onTokenUpdate: (access, rt) async {
      await Store.saveTokens(access, rt);
    })
      ..deviceId = deviceId
      ..appVersion = appVersion;

    if (token != null || refresh != null) {
      api!.setTokens(access: token, refresh: refresh);
    }

    // Try silent auto-login
    if (refresh != null) {
      try {
        await api!.me();
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        await _loadBootstrapSafe();
        return;
      } on AuthException {
        await Store.clearAuth();
        api!.setTokens();
      } catch (_) {
        // Network issue → fall through to login screen
      }
    }

    state = AuthState.loggedOut;
    notifyListeners();
  }

  /// Refresh bootstrap data silently. Never throws.
  Future<void> _loadBootstrapSafe() async {
    try {
      bootstrap_ = await api!.bootstrap();
      if (bootstrap_!.killSwitch) {
        blockedReason = bootstrap_!.killReason;
        state = AuthState.blocked;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Called by SplashScreen.
  Future<Bootstrap?> loadBootstrap() async {
    if (api == null) return null;
    try {
      bootstrap_ = await api!.bootstrap();
      return bootstrap_;
    } catch (_) {
      return null;
    }
  }

  // ---------- login ----------
  Future<String?> login(String u, String p) async {
    try {
      // Server-side device check FIRST
      try {
        final check = await api!.deviceCheck(deviceId);
        final locked = check['locked'] == true;
        final lockedUser = check['username']?.toString();
        if (locked && lockedUser != null &&
            lockedUser.toLowerCase() != u.toLowerCase()) {
          return 'هذا الجهاز مرتبط بحساب "$lockedUser" بالفعل.\n'
                 'لا يمكنك تسجيل الدخول بحساب آخر من نفس الجهاز.';
        }
      } catch (_) {
        // Device-lock endpoint may not exist yet — skip
      }

      await api!.login(u, p);
      await Store.saveTokens(api!.token, api!.refreshToken);
      await Store.saveUsernameHint(u);
      user = await api!.me();
      state = AuthState.loggedIn;
      notifyListeners();

      // Register device lock (server-side) in background
      try { await api!.deviceLock(); } catch (_) {}

      await _loadBootstrapSafe();
      return null;
    } on HostingException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ---------- register ----------
  Future<String?> register(String u, String p, String invite) async {
    try {
      // Device check
      try {
        final check = await api!.deviceCheck(deviceId);
        final locked = check['locked'] == true;
        final lockedUser = check['username']?.toString();
        if (locked && lockedUser != null) {
          return 'هذا الجهاز مرتبط بحساب "$lockedUser" بالفعل.';
        }
      } catch (_) {}

      final r = await api!.register(u, p, invite);
      if (r['token'] != null) {
        await Store.saveTokens(api!.token, api!.refreshToken);
        await Store.saveUsernameHint(u);
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        try { await api!.deviceLock(); } catch (_) {}
        await _loadBootstrapSafe();
        return null;
      }
      return 'PENDING:${r['message'] ?? 'قيد المراجعة'}';
    } on HostingException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ---------- logout ----------
  Future<void> logout() async {
    try { await api!.logout(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<void> logoutAll() async {
    try { await api!.logoutAll(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  // ---------- base URL ----------
  Future<void> setBase(String b) async {
    baseUrl = b;
    api?.dispose();
    api = ApiClient(b, onTokenUpdate: (access, rt) async {
      await Store.saveTokens(access, rt);
    })
      ..deviceId = deviceId
      ..appVersion = appVersion;
    await Store.saveBase(b);
    await Store.clearAuth();
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  // ---------- helpers ----------
  Future<void> refreshMe() async {
    try { user = await api!.me(); notifyListeners(); } catch (_) {}
  }

  Future<void> recheckKillSwitch() async {
    await _loadBootstrapSafe();
  }
}
