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

  /// تنبيه يُعرض للمستخدم بعد الدخول (مثل "الجهاز مربوط بحساب آخر")
  String? deviceWarning;

  // =========================================================
  //  BOOTSTRAP
  // =========================================================
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

    // محاولة دخول تلقائي بـ refresh token
    if (refresh != null) {
      try {
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        _ensureDeviceLockInBackground();
        await _loadBootstrapSafe();
        return;
      } on AuthException {
        await Store.clearAuth();
        api!.setTokens();
      } catch (_) {}
    }

    state = AuthState.loggedOut;
    notifyListeners();
  }

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

  Future<Bootstrap?> loadBootstrap() async {
    if (api == null) return null;
    try {
      bootstrap_ = await api!.bootstrap();
      return bootstrap_;
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  //  LOGIN — بدون device_id في الـ body
  // =========================================================
  Future<String?> login(String u, String p) async {
    try {
      // ignore: avoid_print
      print('[AUTH] login attempt user=$u device=$deviceId');

      // 1) إرسال بيانات الدخول فقط
      await api!.login(u, p);

      // 2) حفظ التوكن
      await Store.saveTokens(api!.token, api!.refreshToken);
      await Store.saveUsernameHint(u);

      // 3) جلب بيانات المستخدم
      user = await api!.me();
      state = AuthState.loggedIn;
      deviceWarning = null;
      notifyListeners();

      // 4) فحص الجهاز في الخلفية (بدون حجب المستخدم)
      _ensureDeviceLockInBackground();

      await _loadBootstrapSafe();
      return null;
    } on HostingException catch (e) {
      // ignore: avoid_print
      print('[AUTH] login failed status=${e.status} detail=${e.detail}');
      if (e.status == 401 || e.status == 403) {
        return 'اسم المستخدم أو كلمة المرور خطأ ($e.status)';
      }
      if (e.status == 0) return 'تعذّر الاتصال بالسيرفر';
      return e.message;
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] login exception: $e');
      return 'خطأ: $e';
    }
  }

  // =========================================================
  //  REGISTER
  // =========================================================
  Future<String?> register(String u, String p, String invite) async {
    try {
      final r = await api!.register(u, p, invite);
      if (r['token'] != null) {
        await Store.saveTokens(api!.token, api!.refreshToken);
        await Store.saveUsernameHint(u);
        user = await api!.me();
        state = AuthState.loggedIn;
        deviceWarning = null;
        notifyListeners();
        _ensureDeviceLockInBackground();
        await _loadBootstrapSafe();
        return null;
      }
      return 'PENDING:${r['message'] ?? 'قيد المراجعة'}';
    } on HostingException catch (e) {
      // ignore: avoid_print
      print('[AUTH] register failed: ${e.status} ${e.detail}');
      return e.message;
    } catch (e) {
      return 'خطأ: $e';
    }
  }

  // =========================================================
  //  DEVICE LOCK — يعمل بعد الدخول فقط
  // =========================================================
  Future<void> _ensureDeviceLockInBackground() async {
    try {
      // 1) هل الجهاز مربوط؟
      final check = await api!.deviceCheck(deviceId);
      // ignore: avoid_print
      print('[AUTH] device check: $check');

      final locked = check['locked'] == true;
      final lockedUser = check['username']?.toString();

      if (!locked) {
        // الجهاز جديد — نربطه بالحساب الحالي
        try {
          await api!.deviceLock();
          // ignore: avoid_print
          print('[AUTH] device locked to ${user?.username}');
        } catch (e) {
          // ignore: avoid_print
          print('[AUTH] device lock failed: $e');
        }
      } else if (lockedUser != null &&
                 lockedUser.toLowerCase() != (user?.username ?? '').toLowerCase()) {
        // الجهاز مربوط بحساب آخر
        deviceWarning = 'هذا الجهاز مربوط بحساب آخر: $lockedUser\n'
                        'قد تُمنع بعض الميزات.';
        notifyListeners();
        // ignore: avoid_print
        print('[AUTH] device locked to another user: $lockedUser');
      }
      // else: الجهاز مربوط بنفس المستخدم → لا شيء
    } catch (e) {
      // ignore: avoid_print
      print('[AUTH] device check skipped: $e');
    }
  }

  /// إخفاء التنبيه (عند عرضه للمستخدم)
  void clearDeviceWarning() {
    deviceWarning = null;
    notifyListeners();
  }

  // =========================================================
  //  LOGOUT
  // =========================================================
  Future<void> logout() async {
    try { await api!.logout(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    deviceWarning = null;
    notifyListeners();
  }

  Future<void> logoutAll() async {
    try { await api!.logoutAll(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    deviceWarning = null;
    notifyListeners();
  }

  // =========================================================
  //  BASE URL
  // =========================================================
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

  Future<void> refreshMe() async {
    try { user = await api!.me(); notifyListeners(); } catch (_) {}
  }

  Future<void> recheckKillSwitch() async => _loadBootstrapSafe();
}
