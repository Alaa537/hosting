import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _path = '/';
  List<FileItem> _items = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await context.read<AuthProvider>().api!.listFiles(_path);
      if (!mounted) return;
      l.sort((a, b) {
        if (a.isFile != b.isFile) return a.isFile ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() { _items = l; _err = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = e.toString(); _loading = false; });
    }
  }

  void _enter(FileItem f) {
    if (f.isFile) { _openFile(f); return; }
    setState(() { _path = _join(_path, f.name); _items = []; });
    _load();
  }

  void _up() {
    if (_path == '/') return;
    final parts = _path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    setState(() { _path = '/' + parts.join('/'); _items = []; });
    _load();
  }

  String _join(String a, String b) =>
      a.endsWith('/') ? '$a$b' : '$a/$b';

  Future<void> _openFile(FileItem f) async {
    final full = _join(_path, f.name);
    final action = await showModalBottomSheet<String>(
      context: context, backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: C.border,
              borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.description_outlined, color: C.primary),
          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${fSize(f.size)} · ${fDate(f.modifiedAt)}',
              style: const TextStyle(color: C.muted, fontSize: 11)),
        ),
        const Divider(height: 1),
        _sheet(Icons.visibility_outlined, 'View content', 'view'),
        _sheet(Icons.download_outlined, 'Download & share', 'download'),
        _sheet(Icons.drive_file_rename_outline, 'Rename', 'rename'),
        _sheet(Icons.drive_file_move_outline, 'Move', 'move'),
        _sheet(Icons.archive_outlined, 'Extract archive', 'extract'),
        _sheet(Icons.lock_outline, 'Change permissions', 'chmod'),
        _sheet(Icons.delete_outline, 'Delete', 'delete', danger: true),
        const SizedBox(height: 8),
      ])),
    );
    if (!mounted || action == null) return;
    final api = context.read<AuthProvider>().api!;
    try {
      switch (action) {
        case 'view':
          final c = await api.readFile(full);
          if (mounted) _showText(context, f.name, c);
          break;
        case 'download':
          await _download(full, f.name);
          break;
        case 'rename':
          final n = await promptText(context, 'Rename', initial: f.name);
          if (n != null && n != f.name && mounted) {
            await api.rename(_path, [f.name], [n]);
            if (mounted) { snack(context, 'Renamed'); _load(); }
          }
          break;
        case 'move':
          final d = await promptText(context, 'Move to directory', hint: '/');
          if (d != null && d.isNotEmpty && mounted) {
            await api.move(_path, [f.name], d);
            if (mounted) { snack(context, 'Moved'); _load(); }
          }
          break;
        case 'extract':
          await api.extract(_path, [f.name]);
          if (mounted) { snack(context, 'Extracted'); _load(); }
          break;
        case 'chmod':
          final m = await promptText(context, 'Mode', initial: '644');
          if (m != null && m.isNotEmpty && mounted) {
            await api.chmod(_path, [f.name], m);
            if (mounted) { snack(context, 'chmod applied'); _load(); }
          }
          break;
        case 'delete':
          if (await confirm(context, 'Delete "${f.name}"?', danger: true)) {
            if (!mounted) return;
            await api.deleteFiles(_path, [f.name]);
            if (mounted) { snack(context, 'Deleted'); _load(); }
          }
          break;
      }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Widget _sheet(IconData i, String t, String v, {bool danger = false}) => ListTile(
    leading: Icon(i, color: danger ? C.danger : C.primary),
    title: Text(t, style: TextStyle(color: danger ? C.danger : null)),
    onTap: () => Navigator.pop(context, v));

  void _showText(BuildContext ctx, String title, String content) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: double.maxFinite,
        child: SingleChildScrollView(child: SelectableText(content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11)))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'))],
    ));
  }

  Future<void> _download(String full, String name) async {
    try {
      final api = context.read<AuthProvider>().api!;
      final url = await api.downloadUrl(full);
      snackInfo(context, 'Downloading $name…');
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/$name');
      final res = await http.get(Uri.parse(url));
      await out.writeAsBytes(res.bodyBytes);
      if (!mounted) return;
      await Share.shareXFiles([XFile(out.path)], text: name);
    } catch (e) {
      if (mounted) snack(context, 'Download failed: $e', error: true);
    }
  }

  Future<void> _upload() async {
    final ctrl = TextEditingController();
    final p = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Upload file'),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Absolute path on phone',
          hintText: '/storage/emulated/0/Download/file.zip')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: C.muted))),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Upload')),
      ],
    ));
    if (p == null || p.isEmpty || !mounted) return;
    final f = File(p);
    if (!await f.exists()) { if (mounted) snack(context, 'File not found', error: true); return; }
    try {
      snackInfo(context, 'Uploading ${f.uri.pathSegments.last}…');
      await context.read<AuthProvider>().api!.uploadSmall(f, _path);
      if (mounted) { snack(context, 'Uploaded'); _load(); }
    } catch (e) {
      if (mounted) snack(context, 'Upload failed: $e', error: true);
    }
  }

  Future<void> _newFolder() async {
    final n = await promptText(context, 'New folder name');
    if (n == null || n.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.mkdir(_path, n);
      if (mounted) { snack(context, 'Folder created'); _load(); }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _compress() async {
    final n = await promptText(context, 'Item to compress');
    if (n == null || n.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.compress(_path, [n]);
      if (mounted) { snack(context, 'Compressed'); _load(); }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Files', style: TextStyle(fontSize: 16)),
          Text(_path, style: const TextStyle(color: C.muted, fontSize: 10,
              fontWeight: FontWeight.normal)),
        ]),
        actions: [
          IconButton(onPressed: _path == '/' ? null : _up,
              icon: Icon(Icons.arrow_upward, color: _path == '/' ? C.muted : C.primary)),
          IconButton(onPressed: _newFolder, icon: const Icon(Icons.create_new_folder_outlined, color: C.primary)),
          IconButton(onPressed: _upload, icon: const Icon(Icons.upload, color: C.primary)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: C.primary)),
        ],
      ),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator(color: C.primary))
        : _err != null
          ? Center(child: Text(_err!, style: const TextStyle(color: C.danger)))
          : RefreshIndicator(onRefresh: _load, color: C.primary,
              backgroundColor: C.surface,
              child: _items.isEmpty
                ? ListView(children: const [SizedBox(height: 100),
                    EmptyState(icon: Icons.folder_open, title: 'Empty folder')])
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _tile(_items[i]),
                  ),
            )),
      floatingActionButton: _items.isEmpty ? null : FloatingActionButton.extended(
        onPressed: _compress,
        backgroundColor: C.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.archive_outlined),
        label: const Text('Compress', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _tile(FileItem f) {
    final color = f.isFile ? C.primary : C.accent;
    final icon = f.isFile ? _fileIcon(f.name) : Icons.folder;
    return Slidable(
      key: ValueKey(f.name),
      endActionPane: ActionPane(motion: const DrawerMotion(), children: [
        SlidableAction(onPressed: (_) => _rename(f), backgroundColor: C.info,
          foregroundColor: Colors.white, icon: Icons.edit, label: 'Rename'),
        SlidableAction(onPressed: (_) => _delete(f), backgroundColor: C.danger,
          foregroundColor: Colors.white, icon: Icons.delete, label: 'Delete'),
      ]),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: ListTile(
          leading: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22)),
          title: Text(f.name, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(f.isFile
              ? '${fSize(f.size)} · ${fDate(f.modifiedAt)}'
              : 'Folder',
              style: const TextStyle(color: C.muted, fontSize: 10)),
          trailing: const Icon(Icons.chevron_right, color: C.muted, size: 18),
          onTap: () => _enter(f),
        ),
      ),
    );
  }

  IconData _fileIcon(String n) {
    final e = n.split('.').last.toLowerCase();
    switch (e) {
      case 'zip': case 'tar': case 'gz': case 'rar': case '7z': return Icons.archive;
      case 'py': case 'js': case 'dart': case 'sh': case 'java': return Icons.code;
      case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp': return Icons.image;
      case 'mp4': case 'mkv': case 'mov': case 'avi': return Icons.videocam;
      case 'mp3': case 'wav': case 'ogg': return Icons.music_note;
      case 'pdf': return Icons.picture_as_pdf;
      case 'json': case 'yml': case 'yaml': case 'txt': case 'md': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Future<void> _rename(FileItem f) async {
    final n = await promptText(context, 'Rename', initial: f.name);
    if (n == null || n == f.name || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.rename(_path, [f.name], [n]);
      if (mounted) { snack(context, 'Renamed'); _load(); }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(FileItem f) async {
    if (!await confirm(context, 'Delete "${f.name}"?', danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!.deleteFiles(_path, [f.name]);
      if (mounted) { snack(context, 'Deleted'); _load(); }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }
}
