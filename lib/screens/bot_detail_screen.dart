import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';
import '../widgets/log_viewer.dart';

class BotDetailScreen extends StatefulWidget {
  final String fname;
  const BotDetailScreen({super.key, required this.fname});
  @override
  State<BotDetailScreen> createState() => _BotDetailScreenState();
}

class _BotDetailScreenState extends State<BotDetailScreen> {
  BotInfo? _st;
  bool _loading = true;
  Timer? _t;
  WebSocket? _ws;
  final List<String> _live = [];
  bool _streaming = false;
  final int _maxLines = 500;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    _stopStream();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await context.read<AuthProvider>().api!.botStatus(widget.fname);
      if (!mounted) return;
      setState(() { _st = st; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _startStream() async {
    if (_streaming) return;
    setState(() { _live.clear(); _streaming = true; });
    try {
      final api = context.read<AuthProvider>().api!;
      final ws = await api.connectEvents(bot: widget.fname);
      _ws = ws;
      ws.listen((data) {
        try {
          final ev = jsonDecode(data as String);
          if (ev['type'] == 'log') {
            final line = (ev['data'] ?? '').toString().trimRight();
            if (line.isNotEmpty) {
              if (!mounted) return;
              setState(() {
                _live.add(line);
                if (_live.length > _maxLines) _live.removeAt(0);
              });
            }
          }
        } catch (_) {}
      }, onDone: () { if (mounted) setState(() => _streaming = false); },
         onError: (_) { if (mounted) setState(() => _streaming = false); });
    } catch (e) {
      if (mounted) { snack(context, friendlyError(e), error: true);
        setState(() => _streaming = false); }
    }
  }

  void _stopStream() {
    _ws?.close();
    _ws = null;
    _streaming = false;
  }

  Future<void> _act(String action) async {
    final api = context.read<AuthProvider>().api!;
    try {
      switch (action) {
        case 'start': await api.botStart(widget.fname); break;
        case 'stop': await api.botStop(widget.fname); break;
        case 'restart': await api.botRestart(widget.fname); break;
      }
      _load();
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _showLogs() async {
    try {
      final r = await context.read<AuthProvider>().api!.botLogs(widget.fname, lines: 500);
      final lines = (r['lines'] as List? ?? []).cast<String>();
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => Dialog(
        backgroundColor: C.bg,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: LogViewer(lines: lines, title: 'Recent logs', height: 500),
        ),
      ));
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _showCrashes() async {
    try {
      final r = await context.read<AuthProvider>().api!.botCrashes(widget.fname);
      if (!mounted) return;
      final lines = const JsonEncoder.withIndent('  ').convert(r).split('\n');
      await showDialog(context: context, builder: (_) => Dialog(
        backgroundColor: C.bg,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: LogViewer(lines: lines, title: 'Crash history', height: 500),
        ),
      ));
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _clearLogs() async {
    if (!await confirm(context, 'حذف السجلات؟', danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.botLogsClear(widget.fname);
      if (mounted) { snack(context, 'تم'); setState(() => _live.clear()); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _setPolicy() async {
    final mode = await showModalBottomSheet<String>(context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('سياسة إعادة التشغيل',
            style: TextStyle(fontWeight: FontWeight.w700))),
        const Divider(height: 1),
        ...['always', 'on-failure', 'never'].map((m) => ListTile(
          leading: Icon(m == 'always' ? Icons.autorenew :
              m == 'on-failure' ? Icons.warning_amber : Icons.block,
              color: C.primary),
          title: Text(m),
          onTap: () => Navigator.pop(context, m))),
      ])));
    if (mode == null || !mounted) return;
    final delay = await promptInt(context, 'تأخير إعادة التشغيل (ثواني)', initial: 5);
    if (delay == null || !mounted) return;
    final mx = await promptInt(context, 'أقصى انهيارات سريعة', initial: 5);
    if (mx == null || !mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .botSetPolicy(widget.fname, mode, delay, mx);
      if (mounted) { snack(context, 'تم'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _setEnv() async {
    final k = await promptText(context, 'اسم المتغير');
    if (k == null || k.isEmpty || !mounted) return;
    final v = await promptText(context, 'القيمة');
    if (v == null || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.botSetEnv(widget.fname, k, v);
      if (mounted) { snack(context, 'تم'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _deleteEnv() async {
    final k = await promptText(context, 'المفتاح المراد حذفه');
    if (k == null || k.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.botDeleteEnv(widget.fname, k);
      if (mounted) { snack(context, 'تم'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _removeBot() async {
    if (!await confirm(context, 'حذف ${widget.fname}؟', danger: true)) return;
    if (!mounted) return;
    final df = await confirm(context, 'حذف الملف أيضاً؟');
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .botRemove(widget.fname, deleteFile: df);
      if (mounted) { snack(context, 'تم الحذف'); Navigator.pop(context); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fname),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: C.primary)),
          IconButton(onPressed: _removeBot,
              icon: const Icon(Icons.delete_outline, color: C.danger)),
        ]),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : ListView(padding: const EdgeInsets.all(16), children: [
            if (_st != null) ...[
              _statusCard(_st!),
              const SizedBox(height: 14),
              SectionCard(title: 'التحكم', child: Wrap(spacing: 8, runSpacing: 8, children: [
                _action(Icons.play_arrow, 'تشغيل', C.success, () => _act('start')),
                _action(Icons.restart_alt, 'إعادة', C.warning, () => _act('restart')),
                _action(Icons.stop, 'إيقاف', C.info, () => _act('stop')),
              ])),
              const SizedBox(height: 14),
              SectionCard(
                title: 'سجل مباشر',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_streaming ? 'streaming…' : 'متوقف',
                      style: TextStyle(color: _streaming ? C.success : C.muted,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _streaming ? () => setState(_stopStream) : _startStream,
                    icon: Icon(_streaming ? Icons.stop_circle : Icons.play_circle,
                        color: _streaming ? C.danger : C.success),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
                child: LogViewer(lines: _live, title: widget.fname, height: 260),
              ),
              const SizedBox(height: 14),
              SectionCard(title: 'المزيد', child: Column(children: [
                _listAction(Icons.list_alt, 'عرض السجلات الأخيرة', _showLogs),
                _listAction(Icons.bug_report_outlined, 'سجل الانهيارات', _showCrashes),
                _listAction(Icons.cleaning_services_outlined, 'مسح السجلات', _clearLogs,
                    danger: true),
                _listAction(Icons.autorenew, 'سياسة إعادة التشغيل', _setPolicy),
                _listAction(Icons.vpn_key_outlined, 'إضافة متغير بيئة', _setEnv),
                _listAction(Icons.key_off_outlined, 'حذف متغير بيئة', _deleteEnv),
              ])),
            ],
            const SizedBox(height: 30),
          ]),
    ));
  }

  Widget _statusCard(BotInfo b) {
    final c = stateColor(b.state);
    return SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(stateIcon(b.state), style: TextStyle(color: c, fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(b.state.toUpperCase(),
            style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900,
                letterSpacing: 1))),
      ]),
      const SizedBox(height: 12),
      KVRow(k: 'PID', v: Text('${b.pid ?? '—'}')),
      KVRow(k: 'Uptime', v: Text(fTime(b.uptime))),
      KVRow(k: 'CPU', v: Text('${b.cpu?.toStringAsFixed(1) ?? '—'}%')),
      KVRow(k: 'RAM', v: Text(fSize(b.rss))),
      KVRow(k: 'Threads', v: Text('${b.threads ?? '—'}')),
      KVRow(k: 'Restarts', v: Text('${b.restarts}')),
      KVRow(k: 'Crashes', v: Text('${b.crashCount}')),
      KVRow(k: 'Last exit', v: Text('${b.lastExitCode ?? '—'}')),
      if (b.envKeys.isNotEmpty)
        KVRow(k: 'Env keys', v: Text(b.envKeys.join(', '),
            style: const TextStyle(fontSize: 11))),
    ]));
  }

  Widget _action(IconData ic, String label, Color color, VoidCallback onTap) {
    return Material(color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color,
                fontWeight: FontWeight.w700, fontSize: 13)),
          ]))));
  }

  Widget _listAction(IconData ic, String t, VoidCallback onTap, {bool danger = false}) =>
    ListTile(contentPadding: EdgeInsets.zero,
      leading: Icon(ic, color: danger ? C.danger : C.primary, size: 20),
      title: Text(t, style: TextStyle(fontSize: 13,
          color: danger ? C.danger : null, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: C.muted, size: 18),
      onTap: onTap);
}
