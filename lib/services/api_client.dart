import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../models/bootstrap.dart';
import '../models/app_models.dart';

class HostingException implements Exception {
  final int status;
  final dynamic detail;
  final String url;
  HostingException(this.status, this.detail, this.url);
  String get message {
    dynamic d = detail;
    if (d is Map && d.containsKey('detail')) d = d['detail'];
    return '[$status] $d';
  }
  @override
  String toString() => message;
}

class AuthException extends HostingException {
  AuthException(super.status, super.detail, super.url);
}

class TokenExpiredException extends AuthException {
  TokenExpiredException(super.status, super.detail, super.url);
}

class ConflictException extends HostingException {
  ConflictException(super.status, super.detail, super.url);
  String get code {
    if (detail is Map && detail['detail'] != null) {
      return detail['detail'].toString();
    }
    return detail?.toString() ?? '';
  }
}

typedef TokenCallback = void Function(String? access, String? refresh);

class ApiClient {
  final String baseUrl;
  String? _token;
  String? _refreshToken;
  String? _deviceId;
  String _appVersion = '1.0.0';
  DateTime? _expiresAt;
  final http.Client _http = http.Client();
  final TokenCallback? onTokenUpdate;
  Future<bool>? _refreshing;

  ApiClient(this.baseUrl, {this.onTokenUpdate});

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get deviceId => _deviceId;
  set deviceId(String? id) => _deviceId = id;
  set appVersion(String v) => _appVersion = v;

  void setTokens({String? access, String? refresh, int? expiresInSeconds}) {
    _token = access;
    _refreshToken = refresh;
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      final safeTtl = expiresInSeconds > 90 ? expiresInSeconds - 60 : expiresInSeconds;
      _expiresAt = DateTime.now().add(Duration(seconds: safeTtl));
    } else {
      _expiresAt = null;
    }
    onTokenUpdate?.call(_token, _refreshToken);
  }

  bool get _needsRefresh {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    if (_token == null || _token!.isEmpty) return true;
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) return true;
    return false;
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': 'hosting-flutter/$_appVersion',
        if (_deviceId != null) 'X-Device-Id': _deviceId!,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final uri = Uri.parse('$baseUrl$path');
    if (q == null || q.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...q.map((k, v) => MapEntry(k, '$v')),
    });
  }

  dynamic _decode(http.Response r) {
    if (r.statusCode >= 400) {
      dynamic detail;
      try { detail = jsonDecode(r.body); }
      catch (_) { detail = r.body.isNotEmpty ? r.body : r.reasonPhrase; }

      final detailStr = _detailString(detail);

      // 401 — expired access token
      if (r.statusCode == 401) {
        if (detailStr.contains('ACCESS_TOKEN_EXPIRED') ||
            detailStr.contains('TOKEN_EXPIRED')) {
          throw TokenExpiredException(r.statusCode, detail,
              r.request?.url.toString() ?? '');
        }
        throw AuthException(r.statusCode, detail,
            r.request?.url.toString() ?? '');
      }

      // 403 — pending / banned / rejected / admin only
      if (r.statusCode == 403) {
        throw AuthException(r.statusCode, detail,
            r.request?.url.toString() ?? '');
      }

      // 409 — device lock / username exists
      if (r.statusCode == 409) {
        throw ConflictException(r.statusCode, detail,
            r.request?.url.toString() ?? '');
      }

      throw HostingException(r.statusCode, detail,
          r.request?.url.toString() ?? '');
    }
    if (r.body.isEmpty) return null;
    final ct = r.headers['content-type'] ?? '';
    if (ct.contains('application/json')) {
      try { return jsonDecode(r.body); } catch (_) { return r.body; }
    }
    return r.body;
  }

  static String _detailString(dynamic detail) {
    if (detail is Map && detail['detail'] != null) {
      return detail['detail'].toString();
    }
    return detail?.toString() ?? '';
  }

  Future<bool> refresh() async {
    if (_refreshing != null) return _refreshing!;
    final completer = Completer<bool>();
    _refreshing = completer.future;
    try {
      final rt = _refreshToken;
      if (rt == null || rt.isEmpty) { completer.complete(false); return false; }
      final r = await _http.post(_u('/auth/refresh'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'refresh_token': rt}));
      if (r.statusCode >= 400) {
        _token = null; _refreshToken = null; _expiresAt = null;
        onTokenUpdate?.call(null, null);
        completer.complete(false); return false;
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      setTokens(access: data['token'], refresh: data['refresh_token'],
          expiresInSeconds: data['expires_in']);
      completer.complete(true); return true;
    } catch (_) {
      completer.complete(false); return false;
    } finally { _refreshing = null; }
  }

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, dynamic>? q, bool retry = true}) async {
    if (retry && _needsRefresh) await refresh();
    try {
      http.Response r;
      switch (method) {
        case 'GET':
          r = await _http.get(_u(path, q), headers: _headers); break;
        case 'POST':
          r = await _http.post(_u(path, q),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: body == null ? null : jsonEncode(body)); break;
        case 'PUT':
          r = await _http.put(_u(path, q),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: body == null ? null : jsonEncode(body)); break;
        case 'DELETE':
          r = await _http.delete(_u(path, q),
              headers: body == null ? _headers
                  : {..._headers, 'Content-Type': 'application/json'},
              body: body == null ? null : jsonEncode(body)); break;
        default: throw ArgumentError('method');
      }
      if (r.statusCode == 401 && retry &&
          (r.body.contains('ACCESS_TOKEN_EXPIRED') ||
           r.body.contains('TOKEN_EXPIRED'))) {
        if (await refresh()) {
          return _send(method, path, body: body, q: q, retry: false);
        }
      }
      return _decode(r);
    } on TokenExpiredException {
      if (retry && await refresh()) {
        return _send(method, path, body: body, q: q, retry: false);
      }
      rethrow;
    }
  }

  Future<dynamic> _get(String p, {Map<String, dynamic>? q}) => _send('GET', p, q: q);
  Future<dynamic> _post(String p, {Object? body, Map<String, dynamic>? q}) =>
      _send('POST', p, body: body, q: q);
  Future<dynamic> _put(String p, {Object? body}) => _send('PUT', p, body: body);
  Future<dynamic> _del(String p, {Map<String, dynamic>? q, Object? body}) =>
      _send('DELETE', p, q: q, body: body);

  // ====== AUTH ======
  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _get('/health'));

  Future<Map<String, dynamic>> login(String u, String p, {String? modelName}) async {
    // v4: device_id REQUIRED in body
    final body = <String, dynamic>{
      'username': u,
      'password': p,
      if (_deviceId != null) 'device_id': _deviceId,
      if (_deviceId != null) 'platform': Platform.operatingSystem,
      if (modelName != null) 'model': modelName,
      'app_version': _appVersion,
    };
    final r = await _send('POST', '/auth/login', body: body, retry: false);
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) {
      setTokens(access: m['token'], refresh: m['refresh_token'],
          expiresInSeconds: m['expires_in']);
    }
    return m;
  }

  Future<Map<String, dynamic>> register(String u, String p, String invite,
      {String? modelName}) async {
    // v4: device_id REQUIRED in body
    final body = <String, dynamic>{
      'username': u,
      'password': p,
      'invite': invite,
      if (_deviceId != null) 'device_id': _deviceId,
      if (_deviceId != null) 'platform': Platform.operatingSystem,
      if (modelName != null) 'model': modelName,
      'app_version': _appVersion,
    };
    final r = await _send('POST', '/auth/register', body: body, retry: false);
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) {
      setTokens(access: m['token'], refresh: m['refresh_token'],
          expiresInSeconds: m['expires_in']);
    }
    return m;
  }

  Future<void> logout() async {
    try { await _post('/auth/logout', body: {'refresh_token': _refreshToken}); }
    finally { setTokens(); }
  }

  Future<void> logoutAll() async {
    try { await _post('/auth/logout-all'); }
    finally { setTokens(); }
  }

  Future<void> changePassword(String o, String n) =>
      _post('/me/password', body: {'old_password': o, 'new_password': n});

  Future<User> me() async =>
      User.fromJson(Map<String, dynamic>.from(await _get('/me')));

  // ====== SESSIONS ======
  Future<Map<String, dynamic>> sessions() async =>
      Map<String, dynamic>.from(await _get('/auth/sessions'));

  Future<void> revokeSession(int id) =>
      _post('/auth/sessions/revoke', body: {'session_id': id});

  // ====== DEVICE LOCK ======
  Future<Map<String, dynamic>> deviceLock() async =>
      Map<String, dynamic>.from(await _post('/auth/device-lock', body: {
        if (_deviceId != null) 'device_id': _deviceId,
        'platform': Platform.operatingSystem,
        'app_version': _appVersion,
      }));

  Future<Map<String, dynamic>> deviceCheck(String deviceId) async =>
      Map<String, dynamic>.from(
          await _get('/auth/device-lock', q: {'device_id': deviceId}));

  Future<Map<String, dynamic>> myDevices() async =>
      Map<String, dynamic>.from(await _get('/me/devices'));

  // ====== BOOTSTRAP ======
  Future<Bootstrap> bootstrap() async {
    final j = await _get('/client/bootstrap', q: {
      'device_id': _deviceId ?? '',
      'app_version': _appVersion,
      'platform': Platform.operatingSystem,
    });
    return Bootstrap.fromJson(Map<String, dynamic>.from(j));
  }

  Future<void> dismissModal(int id) =>
      _post('/client/modal-dismiss', body: {'modal_id': id});

  // ====== USER INFO ======
  Future<Map<String, dynamic>> usage() async =>
      Map<String, dynamic>.from(await _get('/me/usage'));

  Future<Map<String, dynamic>> activity({int limit = 50}) async =>
      Map<String, dynamic>.from(await _get('/me/activity', q: {'limit': limit}));

  Future<Map<String, dynamic>> alerts({int limit = 50, bool unreadOnly = false}) async =>
      Map<String, dynamic>.from(await _get('/me/alerts',
          q: {'limit': limit, 'unread_only': unreadOnly}));

  Future<void> alertsRead([List<int>? ids]) =>
      _post('/me/alerts/read', body: {'ids': ids});

  // ====== APP (single-app mode) ======
  Future<AppStatus> appStatus() async =>
      AppStatus.fromJson(Map<String, dynamic>.from(await _get('/app')));

  Future<String> appRead() async {
    final r = await _get('/app/file');
    if (r is Map) return r['content'] as String? ?? '';
    return r.toString();
  }

  Future<void> appWrite(String content) =>
      _post('/app/file', body: {'content': content});

  Future<Map<String, dynamic>> appUpload(File file, {File? requirements}) async {
    final req = http.MultipartRequest('POST', _u('/app/upload'));
    req.headers.addAll(_headers);
    req.files.add(await http.MultipartFile.fromPath(
        'file', file.path, filename: file.uri.pathSegments.last));
    if (requirements != null && await requirements.exists()) {
      req.files.add(await http.MultipartFile.fromPath(
          'requirements', requirements.path,
          filename: requirements.uri.pathSegments.last));
    }
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<void> appStart() => _post('/app/start');
  Future<void> appStop() => _post('/app/stop');
  Future<void> appRestart() => _post('/app/restart');
  Future<void> appKill() => _post('/app/kill');
  Future<void> appCommand(String cmd) =>
      _post('/app/command', body: {'command': cmd});

  // ====== BACKUPS ======
  Future<Map<String, dynamic>> backups() async =>
      Map<String, dynamic>.from(await _get('/backups'));

  Future<void> backupCreate(String name) =>
      _post('/backups', body: {'name': name, 'locked': false});

  Future<void> backupRestore(String uuid, {bool truncate = false}) =>
      _post('/backups/$uuid/restore', body: {'truncate': truncate});

  Future<void> backupDelete(String uuid) => _del('/backups/$uuid');
  Future<void> backupLock(String uuid) => _post('/backups/$uuid/lock');

  Future<String> backupDownloadUrl(String uuid) async {
    final r = await _get('/backups/$uuid/download');
    return (r as Map)['url'] as String;
  }

  Future<Map<String, dynamic>> backupPolicyGet() async =>
      Map<String, dynamic>.from(await _get('/backups/policy'));

  Future<void> backupPolicySet(bool en, int hours, int keep) =>
      _put('/backups/policy', body: {
        'enabled': en, 'interval_hours': hours, 'keep': keep});

  Future<Map<String, dynamic>> restoreStatus() async =>
      Map<String, dynamic>.from(await _get('/backups/restore-status'));

  // ====== NOTIFICATIONS ======
  Future<List<Announcement>> announcements() async {
    final l = await _get('/announcements') as List;
    return l.map((e) => Announcement.fromJson(e)).toList();
  }

  Future<List<NotificationItem>> notifications({bool unread = false, int limit = 50}) async {
    final l = await _get('/notifications', q: {'unread': unread, 'limit': limit}) as List;
    return l.map((e) => NotificationItem.fromJson(e)).toList();
  }

  Future<void> notificationsRead([List<int>? ids]) =>
      _post('/notifications/read', body: {'ids': ids});
  Future<void> notificationsClear() => _del('/notifications');

  // ====== SERVER ======
  Future<ServerResources> serverResources() async =>
      ServerResources.fromJson(Map<String, dynamic>.from(await _get('/server/resources')));
  Future<void> power(String s) => _post('/server/power', body: {'signal': s});
  Future<void> setAutoRestart(bool e) =>
      _put('/server/auto-restart', body: {'enabled': e});

  Future<Map<String, dynamic>> startup() async =>
      Map<String, dynamic>.from(await _get('/startup'));

  Future<void> setStartupVar(String k, String v) =>
      _put('/startup/variable', body: {'key': k, 'value': v});

  Future<void> reinstall() =>
      _post('/server/reinstall', body: {'confirm': 'REINSTALL'});

  Future<void> sendCommand(String c) =>
      _post('/server/command', body: {'command': c});

  // ====== ADMIN ======
  Future<AdminStats> adminStats() async =>
      AdminStats.fromJson(Map<String, dynamic>.from(await _get('/admin/stats')));

  Future<List<Map<String, dynamic>>> adminRequests({String status = 'pending'}) async {
    final r = await _get('/admin/requests', q: {'status': status});
    return ((r as Map)['requests'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminApprove(int uid, {int? days, int? maxBots}) =>
      _post('/admin/requests/$uid/approve', body: {
        if (days != null) 'days': days,
        if (maxBots != null) 'max_bots': maxBots,
      });

  Future<void> adminReject(int uid, String reason) =>
      _post('/admin/requests/$uid/reject', body: {'reason': reason});

  Future<void> adminBulk(List<int> uids, String action,
      {String reason = '', int days = 30, String text = ''}) =>
      _post('/admin/bulk', body: {
        'user_ids': uids, 'action': action,
        'reason': reason, 'days': days, 'text': text,
      });

  Future<List<AdminUser>> adminUsers({String search = ''}) async {
    final l = await _get('/admin/users', q: {'search': search}) as List;
    return l.map((e) => AdminUser.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> adminUserDetail(int uid) async =>
      Map<String, dynamic>.from(await _get('/admin/users/$uid'));

  Future<void> adminBan(int uid, String reason) =>
      _post('/admin/users/$uid/ban', body: {'reason': reason, 'kill_server': true});
  Future<void> adminUnban(int uid) => _post('/admin/users/$uid/unban');
  Future<void> adminSetPassword(int uid, String pw) =>
      _post('/admin/users/$uid/password', body: {'new_password': pw});
  Future<void> adminSetRole(int uid, String role) =>
      _post('/admin/users/$uid/role', body: {'role': role});
  Future<void> adminSetExpiry(int uid, int? days) =>
      _post('/admin/users/$uid/expiry', body: {'days': days});
  Future<void> adminDeleteUser(int uid, {bool wipe = true}) =>
      _del('/admin/users/$uid', q: {'wipe': wipe});
  Future<void> adminSetNote(int uid, String note) =>
      _post('/admin/users/$uid/note', body: {'note': note});
  Future<void> adminMessage(int uid, String text) =>
      _post('/admin/users/$uid/message', body: {'text': text});
  Future<void> adminUserAlert(int uid, String text) =>
      _post('/admin/users/$uid/alert', body: {'text': text});
  Future<void> adminForceLogout(int uid) => _post('/admin/users/$uid/logout');
  Future<void> adminRevokeSessions(int uid) =>
      _post('/admin/users/$uid/revoke-sessions');
  Future<void> adminUnlockDevice(int uid) =>
      _post('/admin/users/$uid/unlock-device');
  Future<void> adminPower(int uid, String s) =>
      _post('/admin/users/$uid/power', body: {'signal': s});
  Future<void> adminWipe(int uid) =>
      _post('/admin/users/$uid/wipe', body: {'confirm': 'WIPE'});

  Future<Map<String, dynamic>> adminSessions({bool activeOnly = true, int limit = 300}) async =>
      Map<String, dynamic>.from(await _get('/admin/sessions',
          q: {'active_only': activeOnly, 'limit': limit}));

  Future<void> adminRevokeSession(int id) =>
      _post('/admin/sessions/revoke', body: {'session_id': id});

  Future<Map<String, dynamic>> adminDevices({String search = ''}) async =>
      Map<String, dynamic>.from(await _get('/admin/device-lock', q: {'search': search}));

  Future<void> adminDeleteDevice(String deviceId) =>
      _del('/admin/device-lock/$deviceId');

  Future<Map<String, dynamic>> adminCreateModal(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await _post('/admin/modals', body: fields));
  Future<List<Map<String, dynamic>>> adminModals({bool activeOnly = true}) async {
    final l = await _get('/admin/modals', q: {'active_only': activeOnly}) as List;
    return l.cast<Map<String, dynamic>>();
  }
  Future<void> adminDeleteModal(int id) => _del('/admin/modals/$id');

  Future<Map<String, dynamic>> adminCreateUpdate(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await _post('/admin/update', body: fields));
  Future<List<Map<String, dynamic>>> adminUpdates() async {
    final l = await _get('/admin/update') as List;
    return l.cast<Map<String, dynamic>>();
  }
  Future<void> adminDeleteUpdate(int id) => _del('/admin/update/$id');

  Future<Map<String, dynamic>> adminCreateBanner(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await _post('/admin/banner', body: fields));
  Future<List<Map<String, dynamic>>> adminBanners() async {
    final l = await _get('/admin/banner') as List;
    return l.cast<Map<String, dynamic>>();
  }
  Future<void> adminDeleteBanner(int id) => _del('/admin/banner/$id');

  Future<void> adminKillSwitch(bool enabled, {String reason = ''}) =>
      _post('/admin/kill-switch', body: {'enabled': enabled, 'reason': reason});

  Future<Map<String, dynamic>> adminSettings() async =>
      Map<String, dynamic>.from(await _get('/admin/settings'));

  Future<void> adminSettingsUpdate(Map<String, dynamic> body) =>
      _post('/admin/settings', body: body);

  Future<List<Map<String, dynamic>>> adminAudit({int limit = 100}) async {
    final l = await _get('/admin/audit', q: {'limit': limit, 'action': ''}) as List;
    return l.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminMetrics({int hours = 24}) async {
    final l = await _get('/admin/metrics', q: {'hours': hours}) as List;
    return l.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> dbBackup() async =>
      Map<String, dynamic>.from(await _post('/admin/db-backup'));

  Future<void> announce(String text) =>
      _post('/admin/announcements', body: {'text': text});

  Future<List<Map<String, dynamic>>> announcementsAdmin() async {
    final l = await _get('/admin/announcements') as List;
    return l.cast<Map<String, dynamic>>();
  }

  // ====== WEBSOCKET ======
  Future<WebSocket> connectEvents() async {
    final ws = baseUrl.replaceFirst('http', 'ws');
    final url = '$ws/ws/events?token=$_token';
    return WebSocket.connect(url);
  }

  // ============ FILES (general file manager) ============

  Future<List<Map<String, dynamic>>> listFiles({String directory = '/'}) async {
    final l = await _get('/files', q: {'directory': directory}) as List;
    return l.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fileMeta(String path) async =>
      Map<String, dynamic>.from(await _get('/files/meta', q: {'path': path}));

  Future<Map<String, dynamic>> readFileRaw(String file) async =>
      Map<String, dynamic>.from(await _get('/files/content', q: {'file': file}));

  Future<void> writeFileRaw(String file, String content) =>
      _post('/files/write', body: {'file': file, 'content': content});

  Future<Map<String, dynamic>> uploadFile(File local, {String directory = '/'}) async {
    final req = http.MultipartRequest('POST', _u('/files/upload', {'directory': directory}));
    req.headers.addAll(_headers);
    req.files.add(await http.MultipartFile.fromPath('f', local.path,
        filename: local.uri.pathSegments.last));
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  Future<void> createFolder(String directory, String name) =>
      _post('/files/folder', body: {'directory': directory, 'name': name});

  Future<Map<String, dynamic>> filesBatch(String op, List<String> items, {
    String root = '/', String? destination, List<String>? newNames, String? mode,
  }) async {
    final body = <String, dynamic>{'op': op, 'root': root, 'items': items};
    if (destination != null) body['destination'] = destination;
    if (newNames != null) body['new_names'] = newNames;
    if (mode != null) body['mode'] = mode;
    return Map<String, dynamic>.from(await _post('/files/batch', body: body));
  }

  Future<void> renameFile(String root, String oldName, String newName) =>
      filesBatch('rename', [oldName], root: root, newNames: [newName]);

  Future<void> moveFiles(String root, List<String> items, String dest) =>
      filesBatch('move', items, root: root, destination: dest);

  Future<void> chmodFiles(String root, List<String> items, String mode) =>
      filesBatch('chmod', items, root: root, mode: mode);

  Future<Map<String, dynamic>> searchFiles(String q,
      {String directory = '/', int maxDepth = 3, int limit = 50}) async =>
    Map<String, dynamic>.from(await _get('/files/search', q: {
      'q': q, 'directory': directory,
      'max_depth': maxDepth, 'limit': limit,
    }));

  void dispose() => _http.close();
}
