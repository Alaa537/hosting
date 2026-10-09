import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
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
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<AuthProvider>().api!.botsList();
      if (!mounted) return;
      setState(() { _data = d; _err = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  Future<void> _deploy() async {
    try {
      snackInfo(context, 'Deploying launcher…');
      await context.read<AuthProvider>().api!.botsDeploy();
      if (mounted) { snack(context, 'Launcher deployed'); _load(); }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bots'), actions: [
        IconButton(onPressed: _deploy, icon: const Icon(Icons.cloud_upload_outlined, color: C.primary)),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: C.primary)),
      ]),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : _err != null
          ? Center(child: Text(_err!, style: const TextStyle(color: C.danger)))
          : RefreshIndicator(onRefresh: _load, color: C.primary,
              backgroundColor: C.surface,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (_data != null) _launcherBadge(_data!),
                const SizedBox(height: 12),
                if (_data == null || _data!.bots.isEmpty)
                  const EmptyState(icon: Icons.smart_toy_outlined,
                      title: 'No bots registered',
                      subtitle: 'Add a bot from the web panel')
                else
                  ..._data!.bots.map((b) => _botCard(b)),
                const SizedBox(height: 30),
              ]),
            )),
    );
  }

  Widget _launcherBadge(BotList d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: (d.launcherAlive ? C.success : C.danger).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (d.launcherAlive ? C.success : C.danger)
          .withValues(alpha: .4)),
    ),
    child: Row(children: [
      Icon(d.launcherAlive ? Icons.check_circle : Icons.error_outline,
          color: d.launcherAlive ? C.success : C.danger, size: 18),
      const SizedBox(width: 8),
      Text(d.launcherAlive ? 'Launcher online' : 'Launcher offline',
          style: TextStyle(color: d.launcherAlive ? C.success : C.danger,
              fontWeight: FontWeight.w700, fontSize: 13)),
      const Spacer(),
      Text('${d.bots.length} bots',
          style: const TextStyle(color: C.muted, fontSize: 11)),
    ]),
  );

  Widget _botCard(BotInfo b) {
    final color = stateColor(b.state);
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
              Text(stateIcon(b.state), style: TextStyle(color: color, fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(b.file,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(b.state.toUpperCase(),
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
