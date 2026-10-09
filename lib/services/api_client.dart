import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';

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

class ApiClient {
  final String baseUrl;
  String? _token;
  final http.Client _http = http.Client();

  ApiClient(this.baseUrl);

  String? get token => _token;
  set token(String? t) => _token = t;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'User-Agent': 'hosting-flutter/1.0',
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
      if (r.statusCode == 401 || r.statusCode == 403) {
        throw AuthException(r.statusCode, detail, r.request?.url.toString() ?? '');
      }
      throw HostingException(r.statusCode, detail, r.request?.url.toString() ?? '');
    }
    if (r.body.isEmpty) return null;
    final ct = r.headers['content-type'] ?? '';
    if (ct.contains('application/json')) {
      try { return jsonDecode(r.body); } catch (_) { return r.body; }
    }
    return r.body;
  }

  Future<dynamic> _get(String p, {Map<String, dynamic>? q}) async =>
      _decode(await _http.get(_u(p, q), headers: _headers));

  Future<dynamic> _post(String p, {Object? body}) async =>
      _decode(await _http.post(_u(p), headers: {
        ..._headers, 'Content-Type': 'application/json',
      }, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> _put(String p, {Object? body}) async =>
      _decode(await _http.put(_u(p), headers: {
        ..._headers, 'Content-Type': 'application/json',
      }, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> _del(String p, {Map<String, dynamic>? q}) async =>
      _decode(await _http.delete(_u(p, q), headers: _headers));

  // ---- AUTH ----
  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _get('/health'));

  Future<Map<String, dynamic>> login(String u, String p) async {
    final r = await _post('/auth/login', body: {'username': u, 'password': p});
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) _token = m['token'];
    return m;
  }

  Future<Map<String, dynamic>> register(String u, String p, String invite) async {
    final r = await _post('/auth/register',
        body: {'username': u, 'password': p, 'invite': invite});
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) _token = m['token'];
    return m;
  }

  Future<void> logoutAll() => _post('/auth/logout-all');
  Future<void> changePassword(String o, String n) =>
      _post('/me/password', body: {'old_password': o, 'new_password': n});

  Future<User> me() async => User.fromJson(Map<String, dynamic>.from(await _get('/me')));

  // ---- ANNOUNCEMENTS / NOTIFICATIONS ----
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

  // ---- SERVER ----
  Future<ServerResources> serverResources() async =>
      ServerResources.fromJson(Map<String, dynamic>.from(await _get('/server/resources')));
  Future<void> power(String signal) => _post('/server/power', body: {'signal': signal});
  Future<void> setAutoRestart(bool e) => _put('/server/auto-restart', body: {'enabled': e});
  Future<void> sendCommand(String c) => _post('/server/command', body: {'command': c});
  Future<void> reinstall() => _post('/server/reinstall', body: {'confirm': 'REINSTALL'});

  Future<Map<String, dynamic>> startup() async =>
      Map<String, dynamic>.from(await _get('/startup'));
  Future<void> setStartupVar(String k, String v) =>
      _put('/startup/variable', body: {'key': k, 'value': v});

  // ---- FILES ----
  Future<List<FileItem>> listFiles([String dir = '/']) async {
    final l = await _get('/files', q: {'directory': dir}) as List;
    return l.map((e) => FileItem.fromJson(e)).toList();
  }

  Future<String> readFile(String f) async {
    final r = await _get('/files/content', q: {'file': f});
    if (r is Map) return r['content'] as String? ?? '';
    return r.toString();
  }

  Future<void> writeFile(String f, String c) =>
      _post('/files/write', body: {'file': f, 'content': c});

  Future<void> mkdir(String root, String name) =>
      _post('/files/mkdir', body: {'root': root, 'name': name});

  Future<Map<String, dynamic>> filesBatch(String op, List<String> items,
      {String root = '/', String? dest, List<String>? newNames, String? mode}) async {
    final body = <String, dynamic>{'op': op, 'root': root, 'items': items};
    if (dest != null) body['destination'] = dest;
    if (newNames != null) body['new_names'] = newNames;
    if (mode != null) body['mode'] = mode;
    return Map<String, dynamic>.from(await _post('/files/batch', body: body));
  }

  Future<void> deleteFiles(String root, List<String> items) =>
      filesBatch('delete', items, root: root);
  Future<void> rename(String root, List<String> items, List<String> names) =>
      filesBatch('rename', items, root: root, newNames: names);
  Future<void> move(String root, List<String> items, String dest) =>
      filesBatch('move', items, root: root, dest: dest);
  Future<void> compress(String root, List<String> items) =>
      filesBatch('compress', items, root: root);
  Future<void> extract(String root, List<String> items) =>
      filesBatch('extract', items, root: root);
  Future<void> chmod(String root, List<String> items, String mode) =>
      filesBatch('chmod', items, root: root, mode: mode);

  Future<String> downloadUrl(String file) async {
    final r = await _get('/files/download', q: {'file': file});
    return (r as Map)['url'] as String;
  }

  Future<Map<String, dynamic>> uploadSmall(File local, String dir,
      {String? name}) async {
    final req = http.MultipartRequest('POST', _u('/files/upload', {'directory': dir}));
    req.headers.addAll(_headers);
    req.files.add(await http.MultipartFile.fromPath('f', local.path,
        filename: name ?? local.uri.pathSegments.last));
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    return Map<String, dynamic>.from(_decode(r) ?? {});
  }

  // ---- BOTS ----
  Future<BotList> botsList() async =>
      BotList.fromJson(Map<String, dynamic>.from(await _get('/bots')));

  Future<void> botsDeploy() => _post('/bots/deploy');

  Future<BotInfo> botStatus(String f) async =>
      BotInfo.fromJson(Map<String, dynamic>.from(await _get('/bots/$f/status')));

  Future<void> botStart(String f) => _post('/bots/$f/start');
  Future<void> botStop(String f) => _post('/bots/$f/stop');
  Future<void> botRestart(String f) => _post('/bots/$f/restart');

  Future<Map<String, dynamic>> botLogs(String f, {int lines = 200}) async =>
      Map<String, dynamic>.from(await _get('/bots/$f/logs', q: {'lines': lines}));

  Future<void> botLogsClear(String f) => _del('/bots/$f/logs');

  Future<Map<String, dynamic>> botCrashes(String f) async =>
      Map<String, dynamic>.from(await _get('/bots/$f/crashes'));

  Future<void> botSetPolicy(String f, String mode, int delay, int max) =>
      _put('/bots/$f/policy', body: {'mode': mode, 'delay': delay, 'max_fast_crashes': max});

  Future<void> botSetEnv(String f, String k, String v) =>
      _put('/bots/$f/env', body: {'key': k, 'value': v});

  Future<void> botDeleteEnv(String f, String k) => _del('/bots/$f/env/$k');

  Future<void> botRemove(String f, {bool deleteFile = false}) =>
      _del('/bots/$f', q: {'delete_file': deleteFile});

  // ---- BACKUPS ----
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

  // ---- ADMIN ----
  Future<AdminStats> adminStats() async =>
      AdminStats.fromJson(Map<String, dynamic>.from(await _get('/admin/stats')));

  Future<List<Map<String, dynamic>>> adminRequests({String status = 'pending'}) async {
    final r = await _get('/admin/requests', q: {'status': status});
    return ((r as Map)['requests'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> adminApprove(int uid, {int? days}) =>
      _post('/admin/requests/$uid/approve', body: {if (days != null) 'days': days});

  Future<void> adminReject(int uid, String reason) =>
      _post('/admin/requests/$uid/reject', body: {'reason': reason});

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

  // ---- WEBSOCKET ----
  Future<WebSocket> connectEvents({String? bot}) async {
    final ws = baseUrl.replaceFirst('http', 'ws');
    final url = '$ws/ws/events?token=$_token${bot != null ? '&bot=$bot' : ''}';
    return WebSocket.connect(url);
  }

  void dispose() => _http.close();
}
