import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});
  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  List<BackupInfo> _items = [];
  int? _limit;
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<AuthProvider>().api!.backups();
      if (!mounted) return;
      setState(() {
        _items = (r['backups'] as List? ?? [])
            .map((e) => BackupInfo.fromJson(e)).toList();
        _limit = r['limit'] as int?;
        _err = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    final n = await promptText(context, 'Backup name (blank for auto)');
    if (n == null || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.backupCreate(n);
      if (mounted) { snack(context, 'Backup started'); _load(); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  Future<void> _policy() async {
    try {
      final p = await context.read<AuthProvider>().api!.backupPolicyGet();
      if (!mounted) return;
      final enabled = await confirm(context, 'Enable auto-backup?',
          msg: 'Current: ${p['enabled'] == true ? "enabled" : "disabled"}\n'
              'Interval: ${p['interval_hours']}h\n'
              'Keep: ${p['keep']}');
      if (!mounted) return;
      final hours = await promptInt(context, 'Interval (hours)',
          initial: (p['interval_hours'] as num?)?.toInt() ?? 24);
      if (hours == null || !mounted) return;
      final keep = await promptInt(context, 'How many to keep',
          initial: (p['keep'] as num?)?.toInt() ?? 3);
      if (keep == null || !mounted) return;
      await context.read<AuthProvider>().api!.backupPolicySet(enabled, hours, keep);
      if (mounted) snack(context, 'Policy saved');
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  void _actions(BackupInfo b) {
    showModalBottomSheet(context: context, backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(b.name.isEmpty ? b.uuid.substring(0, 8) : b.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${fSize(b.bytes)} · ${fDate(b.createdAt)}')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.restore, color: C.warning),
          title: const Text('Restore'),
          onTap: () async { Navigator.pop(context); await _restore(b); }),
async { Navigator.pop(context); await _url(b); }),
async { Navigator.pop(context); await _lock(b); }),
        ListTile(leading: const Icon(Icons.delete_outline, color: C.danger),
          title: const Text('Delete', style: TextStyle(color: C.danger)),
          onTap: () async { Navigator.pop(context); await _delete(b); }),
      ])));
  }

  Future<void> _restore(BackupInfo b) async {
    if (!await confirm(context, 'Restore backup?',
        msg: 'This will overwrite your current server state.', danger: true)) return;
    if (!mounted) return;
    final tr = await confirm(context, 'Truncate files first?');
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.backupRestore(b.uuid, truncate: tr);
      if (mounted) snack(context, 'Restore started');
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }



  Future<void> _delete(BackupInfo b) async {
    if (!await confirm(context, 'Delete backup?', danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.backupDelete(b.uuid);
      if (mounted) { snack(context, 'Deleted'); _load(); }
    } catch (e) { if (mounted) snack(context, e.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backups'), actions: [
        IconButton(onPressed: _policy, icon: const Icon(Icons.tune, color: C.primary)),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: C.primary)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create, backgroundColor: C.primary, foregroundColor: Colors.black,
        icon: const Icon(Icons.add), label: const Text('New',
            style: TextStyle(fontWeight: FontWeight.w700))),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : _err != null
          ? Center(child: Text(_err!, style: const TextStyle(color: C.danger)))
          : RefreshIndicator(onRefresh: _load, color: C.primary,
              backgroundColor: C.surface,
              child: _items.isEmpty
                ? ListView(children: const [SizedBox(height: 100),
                    EmptyState(icon: Icons.backup_outlined,
                        title: 'No backups yet',
                        subtitle: 'Tap + to create your first backup')])
                : ListView.builder(padding: const EdgeInsets.all(16),
                    itemCount: _items.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0 && _limit != null) return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Limit: $_limit backups',
                            style: const TextStyle(color: C.muted, fontSize: 12)));
                      final b = _items[i - 1];
                      return _card(b);
                    }),
            )),
    );
  }

  Widget _card(BackupInfo b) {
    final c = b.state == 'done' ? C.success
        : b.state == 'running' ? C.warning : C.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(width: 42, height: 42,
          decoration: BoxDecoration(color: c.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(b.locked ? Icons.lock : Icons.backup, color: c, size: 20)),
        title: Text(b.name.isEmpty ? b.uuid.substring(0, 8) : b.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(b.state, style: TextStyle(color: c, fontSize: 11,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Text(fSize(b.bytes), style: const TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(width: 10),
            Expanded(child: Text(fDate(b.createdAt),
                style: const TextStyle(color: C.muted, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
          ])),
        onTap: () => _actions(b),
      ),
    );
  }
}
