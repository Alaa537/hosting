import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

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
  final List<_LogLine> _live = [];
  bool _streaming = false;
  ScrollController _scroll = ScrollController();
  final int _maxLines = 400;

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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await context.read<AuthProvider>().api!.botStatus(widget.fname);
      if (!mounted) return;
      setState(() { _st = st; _loading = false; });
    } catch (e) {
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
                _live.add(_LogLine(line, logColor(line)));
                if (_live.length > _maxLines) _live.removeAt(0);
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scroll.hasClients) {
                  _scroll.jumpTo(_scroll.position.maxScrollExtent);
                }
              });
            }
          }
        } catch (_) {}
      }, onDone: () { if (mounted) setState(() => _streaming = false); },
         onError: (_) { if (mounted) setState(() => _streaming = false); });
    } catch (e) {
      if (mounted) { snack(context, 'Stream error: $e', error: true); setState(() => _streaming = false); }
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
        case 'start': await api.botStart(widget.fname); snack(context, 'Started'); break;
        case 'stop': await api.botStop(widget.fname); snack(context, 'Stopped'); break;
        case 'restart': await api.botRestart(widget.fname); snack(context, 'Restarted'); break;
      }
      _load();
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _showLogs() async {
    try {
      final r = await context.read<AuthProvider>().api!.botLogs(widget.fname, lines: 300);
      final lines = (r['lines'] as List? ?? []).cast<String>();
      if (!mounted) return;
      _showTextDialog('Recent logs', lines.join('\n'));
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _showCrashes() async {
    try {
      final r = await context.read<AuthProvider>().api!.botCrashes(widget.fname);
      if (!mounted) return;
      _showTextDialog('Crash history', const JsonEncoder.withIndent('  ').convert(r));
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  void _showTextDialog(String title, String content) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: double.maxFinite,
        child: SingleChildScrollView(child: SelectableText(content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11)))),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Close'))],
    ));
  }

  Future<void> _clearLogs() async {
    if (!await confirm(context, 'Clear logs?', danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.botLogsClear(widget.fname);
      if (mounted) snack(context, 'Cleared');
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _setPolicy() async {
    final mode = await showModalBottomSheet<String>(context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Restart policy',
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
    final delay = await promptInt(context, 'Restart delay (seconds)', initial: 5);
    if (delay == null || !mounted) return;
    final mx = await promptInt(context, 'Max fast crashes', initial: 5);
    if (mx == null || !mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .botSetPolicy(widget.fname, mode, delay, mx);
      if (mounted) { snack(context, 'Policy saved'); _load(); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _setEnv() async {
    final k = await promptText(context, 'Environment key');
    if (k == null || k.isEmpty || !mounted) return;
    final v = await promptText(context, 'Value for $k');
    if (v == null || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.botSetEnv(widget.fname, k, v);
      if (mounted) { snack(context, 'Env set'); _load(); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _deleteEnv() async {
    final k = await promptText(context, 'Key to delete');
    if (k == null || k.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.botDeleteEnv(widget.fname, k);
      if (mounted) { snack(context, 'Env removed'); _load(); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _removeBot() async {
    if (!await confirm(context, 'Remove ${widget.fname}?', danger: true)) return;
    if (!mounted) return;
    final df = await confirm(context, 'Also delete the bot file?');
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .botRemove(widget.fname, deleteFile: df);
      if (mounted) { snack(context, 'Bot removed'); Navigator.pop(context); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
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
              SectionCard(title: 'Control', child: Wrap(spacing: 8, runSpacing: 8, children: [
                _action(Icons.play_arrow, 'Start', C.success, () => _act('start')),
                _action(Icons.restart_alt, 'Restart', C.warning, () => _act('restart')),
                _action(Icons.stop, 'Stop', C.info, () => _act('stop')),
              ])),
              const SizedBox(height: 14),
              SectionCard(title: 'Live logs', trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_streaming ? 'streaming…' : 'stopped',
                    style: TextStyle(color: _streaming ? C.success : C.muted,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _streaming ? () => setState(_stopStream) : _startStream,
                  icon: Icon(_streaming ? Icons.stop_circle : Icons.play_circle,
                      color: _streaming ? C.danger : C.success),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                ),
              ]), child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                padding: const EdgeInsets.all(10),
                child: _live.isEmpty
                  ? const Center(child: Text('No output',
                      style: TextStyle(color: C.muted, fontSize: 11,
                          fontFamily: 'monospace')))
                  : ListView.builder(controller: _scroll,
                      itemCount: _live.length,
                      itemBuilder: (_, i) => Text(_live[i].text,
                        style: TextStyle(color: _live[i].color,
                            fontSize: 11, fontFamily: 'monospace', height: 1.35)),
                    ),
              )),
              const SizedBox(height: 14),
              SectionCard(title: 'More', child: Column(children: [
                _listAction(Icons.list_alt, 'Recent logs (last 300)', _showLogs),
                _listAction(Icons.bug_report_outlined, 'Crash history', _showCrashes),
                _listAction(Icons.cleaning_services_outlined, 'Clear logs', _clearLogs,
                    danger: true),
                _listAction(Icons.autorenew, 'Set restart policy', _setPolicy),
                _listAction(Icons.vpn_key_outlined, 'Set environment variable', _setEnv),
                _listAction(Icons.key_off_outlined, 'Delete environment variable', _deleteEnv),
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

class _LogLine {
  final String text;
  final Color color;
  _LogLine(this.text, this.color);
}
