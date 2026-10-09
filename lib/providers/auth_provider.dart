import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/storage.dart';
import '../models/models.dart';

enum AuthState { loading, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  AuthState state = AuthState.loading;
  ApiClient? api;
  User? user;
  String baseUrl = '';

  Future<void> bootstrap() async {
    final s = await Store.load();
    baseUrl = s.base;
    api = ApiClient(s.base);
    if (s.token != null) {
      api!.token = s.token;
      try {
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        return;
      } on AuthException {
        await Store.saveToken(null);
        api!.token = null;
      } catch (_) {
        // Network issue - keep token, go to login to retry
      }
    }
    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<String?> login(String u, String p) async {
    try {
      await api!.login(u, p);
      await Store.saveToken(api!.token);
      user = await api!.me();
      state = AuthState.loggedIn;
      notifyListeners();
      return null;
    } on HostingException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register(String u, String p, String invite) async {
    try {
      final r = await api!.register(u, p, invite);
      if (r['token'] != null) {
        await Store.saveToken(api!.token);
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        return null;
      }
      return 'PENDING:${r['message'] ?? 'Awaiting approval'}';
    } on HostingException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logoutAll() async {
    try { await api!.logoutAll(); } catch (_) {}
  }

  Future<void> logout() async {
    try { await api!.logoutAll(); } catch (_) {}
    await Store.saveToken(null);
    api!.token = null;
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<void> setBase(String b) async {
    baseUrl = b;
    api = ApiClient(b);
    await Store.saveBase(b);
    await Store.saveToken(null);
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try { user = await api!.me(); notifyListeners(); } catch (_) {}
  }
}
