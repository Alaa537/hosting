import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';
import 'bot_detail_screen.dart';

class BotsScreen extends StatefulWidget {
  const BotsScreen({super.key});
  @override
  State<BotsScreen> createState() => _BotsScreenState();
}

class _BotsScreenState extends State<BotsScreen> {
  BotList? _data;
  ServerResources? _server;
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api!;
      final bots = await api.botsList();
      ServerResources? srv;
      try { srv = await api.serverResources(); } catch (_) {}
      if (!mounted) return;
      setState(() { _data = bots; _server = srv; _err = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = friendlyError(e); _loading = false; });
    }
  }

  String _effectiveState(BotInfo b) {
    if (b.state == 'launcher_offline' && _server?.state == 'running') {
      return 'running';
    }
    return b.state;
  }

  Future<void> _deploy() async {
    try {
      snackInfo(context, 'جاري النشر…');
      await context.read<AuthProvider>().api!.botsDeploy();
      if (mounted) { snack(context, 'تم'); _load(); }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _addBot() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['py'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) snack(context, 'الملف غير موجود', error: true);
      return;
    }
    if (!mounted) return;
    final name = await promptText(context, 'اسم البوت (اتركه فارغاً لنفس الاسم)');
    if (name == null || !mounted) return;
    try {
      snackInfo(context, 'جاري رفع البوت…');
      await context.read<AuthProvider>().api!
          .botsAdd(file, name: name);
      if (mounted) { snack(context, 'تم رفع البوت'); _load(); }
    } catch (e) {
      if (mounted) snack(context, 'فشل: ${friendlyError(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bots'), actions: [
        IconButton(onPressed: _deploy,
            icon: const Icon(Icons.cloud_upload_outlined, color: C.primary)),
        IconButton(onPressed: _load,
            icon: const Icon(Icons.refresh, color: C.primary)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBot,
        backgroundColor: C.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('بوت جديد',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : _err != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text(_err!, textAlign: TextAlign.center,
                  style: const TextStyle(color: C.danger))))
          : RefreshIndicator(onRefresh: _load, color: C.primary,
              backgroundColor: C.surface,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_data != null) _launcherBadge(_data!),
                const SizedBox(height: 12),
                if (_data == null || _data!.bots.isEmpty)
                  const EmptyState(icon: Icons.smart_toy_outlined,
                      title: 'لا يوجد بوتات',
                      subtitle: 'اضغط + لإضافة بوت .py')
                else
                  ..._data!.bots.map((b) => _botCard(b)),
                const SizedBox(height: 90),
              ]),
            )),
    );
  }

  Widget _launcherBadge(BotList d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: (d.launcherAlive ? C.success : C.warning).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (d.launcherAlive ? C.success : C.warning)
          .withValues(alpha: .4)),
    ),
    child: Row(children: [
      Icon(d.launcherAlive ? Icons.check_circle : Icons.schedule,
          color: d.launcherAlive ? C.success : C.warning, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(
          d.launcherAlive ? 'Launcher يعمل' : 'Launcher غير متصل — جاري المحاولة…',
          style: TextStyle(color: d.launcherAlive ? C.success : C.warning,
              fontWeight: FontWeight.w700, fontSize: 12))),
      Text('${d.bots.length} bots',
          style: const TextStyle(color: C.muted, fontSize: 11)),
    ]),
  );

  Widget _botCard(BotInfo b) {
    final state = _effectiveState(b);
    final color = stateColor(state);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => BotDetailScreen(fname: b.file)))
            .then((_) => _load()),
        child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(stateIcon(state), style: TextStyle(color: color, fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(b.file,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(state.toUpperCase(),
                    style: TextStyle(color: color,
                        fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _stat(Icons.memory, '${b.cpu?.toStringAsFixed(1) ?? '—'}%'),
              const SizedBox(width: 16),
              _stat(Icons.data_usage, fSize(b.rss)),
              const SizedBox(width: 16),
              _stat(Icons.timer_outlined, fTime(b.uptime)),
              const Spacer(),
              if (b.restarts > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.refresh, size: 12, color: C.muted),
                const SizedBox(width: 2),
                Text('${b.restarts}', style: const TextStyle(
                    color: C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(width: 10),
              if (b.crashCount > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber, size: 12, color: C.warning),
                const SizedBox(width: 2),
                Text('${b.crashCount}', style: const TextStyle(
                    color: C.warning, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _stat(IconData i, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(i, size: 12, color: C.muted),
    const SizedBox(width: 4),
    Text(v, style: const TextStyle(color: C.muted, fontSize: 11,
        fontWeight: FontWeight.w600)),
  ]);
}
