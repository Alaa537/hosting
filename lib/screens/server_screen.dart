import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});
  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  ServerResources? _r;
  bool _loading = true;
  String? _err;
  Timer? _t;

  @override
  void initState() { super.initState(); _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load()); }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await context.read<AuthProvider>().api!.serverResources();
      if (!mounted) return;
      setState(() { _r = r; _err = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  Future<void> _power(String sig, {bool danger = false, String? confirmMsg}) async {
    if (danger && !await confirm(context, 'Confirm', msg: confirmMsg, danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.power(sig);
      if (mounted) snack(context, 'Signal "$sig" sent');
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _command() async {
    final c = await promptText(context, 'Send command', hint: 'say Hello');
    if (c == null || c.isEmpty) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.sendCommand(c);
      if (mounted) snack(context, 'Command sent');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _autoRestart() async {
    final auth = context.read<AuthProvider>();
    try {
      final cur = auth.user?.autoRestart ?? false;
      await auth.api!.setAutoRestart(!cur);
      await auth.refreshMe();
      if (mounted) snack(context, 'Auto-restart ${!cur ? "enabled" : "disabled"}');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _startupVars() async {
    try {
      final data = await context.read<AuthProvider>().api!.startup();
      if (!mounted) return;
      final vars = (data['variables'] as List? ?? []).cast<Map>();
      await showModalBottomSheet(context: context,
        backgroundColor: C.surface, isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(expand: false,
          initialChildSize: .6, maxChildSize: .9,
          builder: (_, ctrl) => ListView(
            controller: ctrl, padding: const EdgeInsets.all(16),
            children: [
              const Text('Startup variables',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(data['command'] ?? '',
                  style: const TextStyle(color: C.muted, fontSize: 11)),
              const Divider(height: 24),
              ...vars.map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(v['key'] ?? '', style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
                subtitle: Text('${v['value'] ?? ''}',
                    style: const TextStyle(color: C.muted, fontSize: 11),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit, color: C.primary, size: 18),
                onTap: () async {
                  final n = await promptText(context, 'Edit ${v['key']}',
                      initial: '${v['value'] ?? ''}');
                  if (n != null && mounted) {
                    try {
                      await context.read<AuthProvider>().api!
                          .setStartupVar(v['key'], n);
                      if (mounted) {
                        Navigator.pop(context);
                        snack(context, 'Updated');
                      }
                    } catch (e) {
                      if (mounted) snack(context, e.toString(), error: true);
                    }
                  }
                },
              )),
            ],
          )));
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _reinstall() async {
    if (!await confirm(context, 'Reinstall server?',
        msg: 'This WILL WIPE all server files and start fresh.\n\nAre you absolutely sure?',
        danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.reinstall();
      if (mounted) snack(context, 'Reinstall started');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server'),
        actions: [IconButton(onPressed: _load,
            icon: const Icon(Icons.refresh, color: C.primary))]),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : RefreshIndicator(onRefresh: _load, color: C.primary,
          backgroundColor: C.surface,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_err != null) _errCard(),
            if (_r != null) ...[
              _statsCard(_r!),
              const SizedBox(height: 16),
              SectionCard(title: 'Power control', child: Wrap(spacing: 8, runSpacing: 8, children: [
                _action(Icons.play_arrow, 'Start', C.success, () => _power('start')),
                _action(Icons.restart_alt, 'Restart', C.warning, () => _power('restart')),
                _action(Icons.stop, 'Stop', C.info, () => _power('stop')),
                _action(Icons.power_settings_new, 'Kill', C.danger,
                    () => _power('kill', danger: true,
                        confirmMsg: 'Force kill the server process?')),
              ])),
              const SizedBox(height: 14),
              SectionCard(title: 'Actions', child: Column(children: [
                _listAction(Icons.terminal, 'Send console command', _command),
                _listAction(Icons.autorenew, 'Toggle auto-restart', _autoRestart),
                _listAction(Icons.tune, 'Startup variables', _startupVars),
                _listAction(Icons.warning_amber_rounded, 'Reinstall server', _reinstall,
                    danger: true),
              ])),
            ],
            const SizedBox(height: 30),
          ]),
        )),
    );
  }

  Widget _errCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.danger.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.danger.withValues(alpha: .4)),
    ),
    child: Row(children: [
      const Icon(Icons.wifi_off, color: C.danger, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(_err!, style: const TextStyle(color: C.danger, fontSize: 12))),
    ]),
  );

  Widget _statsCard(ServerResources r) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: C.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: stateColor(r.state), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(r.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        Text(r.state.toUpperCase(),
            style: TextStyle(color: stateColor(r.state),
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.timer_outlined, size: 14, color: C.muted),
        const SizedBox(width: 4),
        Text(fTime(r.uptimeSeconds), style: const TextStyle(color: C.muted, fontSize: 12)),
      ]),
      const SizedBox(height: 18),
      _bar('CPU', r.cpu, null, null),
      const SizedBox(height: 12),
      _bar('MEM', r.memPercent, r.memUsed, r.memLimit),
      const SizedBox(height: 12),
      _bar('DISK', r.diskPercent, r.diskUsed, r.diskLimit),
      const SizedBox(height: 14),
      Row(children: [
        _net('▼', fSize(r.netRx), C.success),
        const SizedBox(width: 20),
        _net('▲', fSize(r.netTx), C.accent),
      ]),
    ]),
  );

  Widget _bar(String label, double? pct, int? used, int? limit) {
    final v = pct ?? 0;
    final c = v < 75 ? C.success : v < 90 ? C.warning : C.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(width: 42, child: Text(label,
            style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (v / 100).clamp(0, 1),
            minHeight: 6, backgroundColor: C.border,
            valueColor: AlwaysStoppedAnimation(c)))),
        const SizedBox(width: 10),
        SizedBox(width: 44, child: Text('${v.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      if (limit != null && limit > 0) Padding(
        padding: const EdgeInsets.only(left: 42, top: 3),
        child: Text('${fSize(used)} / ${fSize(limit)}',
            style: const TextStyle(color: C.muted, fontSize: 10)),
      ),
    ]);
  }

  Widget _net(String a, String v, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(a, style: TextStyle(color: c, fontSize: 14)),
    const SizedBox(width: 4),
    Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  Widget _action(IconData ic, String label, Color color, VoidCallback onTap) {
    return Material(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color,
                fontWeight: FontWeight.w700, fontSize: 13)),
          ]))));
  }

  Widget _listAction(IconData ic, String t, VoidCallback onTap, {bool danger = false}) {
    return ListTile(contentPadding: EdgeInsets.zero,
      leading: Icon(ic, color: danger ? C.danger : C.primary),
      title: Text(t, style: TextStyle(
          fontWeight: FontWeight.w600, fontSize: 14,
          color: danger ? C.danger : null)),
      trailing: const Icon(Icons.chevron_right, color: C.muted),
      onTap: onTap);
  }
}
