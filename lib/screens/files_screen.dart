import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/code_viewer.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _path = '/';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _err;
  Set<String> _selected = {};

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final l = await context
          .read<AuthProvider>()
          .api!
          .listFiles(directory: _path);
      if (!mounted) return;
      l.sort((a, b) {
        final af = a['is_file'] == true;
        final bf = b['is_file'] == true;
        if (af != bf) return af ? 1 : -1;
        return (a['name'] ?? '').toString().toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase());
      });
      setState(() {
        _items = l;
        _err = null;
        _loading = false;
        _selected = {};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = friendlyError(e);
        _loading = false;
      });
    }
  }

  // ============ Navigation ============
  void _enter(Map<String, dynamic> item) {
    if (_selectionMode) { _toggleSelect(item); return; }
    final isFile = item['is_file'] == true;
    if (isFile) {
      _openFile(item);
    } else {
      final name = item['name'] as String;
      setState(() => _path = _path.endsWith('/') ? '$_path$name' : '$_path/$name');
      _load();
    }
  }

  void _up() {
    if (_path == '/' || _path.isEmpty) return;
    final parts = _path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    setState(() => _path = '/' + parts.join('/'));
    _load();
  }

  void _toggleSelect(Map<String, dynamic> item) {
    final name = item['name'] as String;
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  // ============ File Actions ============
  Future<void> _openFile(Map<String, dynamic> item) async {
    final name = item['name'] as String;
    final mime = (item['mimetype'] ?? '').toString();
    final isText = mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('yaml') ||
        mime.contains('xml') ||
        mime.contains('python') ||
        mime.contains('javascript');

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: C.border,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(_fileIcon(name), color: C.primary),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${fSize(item['size'])} · $mime',
                style: const TextStyle(color: C.muted, fontSize: 11)),
          ),
          const Divider(height: 1),
          if (isText)
            _sheet(Icons.visibility_outlined, 'عرض', 'view'),
          if (isText)
            _sheet(Icons.edit_outlined, 'تعديل', 'edit'),
          _sheet(Icons.download_outlined, 'تنزيل', 'download'),
          _sheet(Icons.share_outlined, 'مشاركة الرابط', 'share'),
          _sheet(Icons.drive_file_rename_outline, 'إعادة تسمية', 'rename'),
          _sheet(Icons.drive_file_move_outline, 'نقل', 'move'),
          _sheet(Icons.lock_outline, 'تغيير الصلاحيات', 'chmod'),
          _sheet(Icons.delete_outline, 'حذف', 'delete', danger: true),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;

    final api = context.read<AuthProvider>().api!;
    final full = _join(_path, name);

    try {
      switch (action) {
        case 'view':
          final r = await api.readFileRaw(full);
          if (mounted) _showCode(name, r['content']?.toString() ?? '', editable: false);
          break;
        case 'edit':
          final r = await api.readFileRaw(full);
          if (!mounted) return;
          final edited = await _showCode(name, r['content']?.toString() ?? '', editable: true);
          if (edited != null && mounted) {
            await api.writeFileRaw(full, edited);
            if (mounted) snack(context, 'تم الحفظ');
          }
          break;
        case 'download':
          await _download(full, name);
          break;
        case 'share':
          final url = await api.downloadUrl(full);
          if (mounted) {
            await Clipboard.setData(ClipboardData(text: url));
            snack(context, 'تم نسخ الرابط');
          }
          break;
        case 'rename':
          final n = await promptText(context, 'الاسم الجديد', initial: name);
          if (n != null && n != name && mounted) {
            await api.renameFile(_path, name, n);
            if (mounted) { snack(context, 'تم'); _load(); }
          }
          break;
        case 'move':
          final d = await promptText(context, 'نقل إلى', hint: '/');
          if (d != null && d.isNotEmpty && mounted) {
            await api.moveFiles(_path, [name], d);
            if (mounted) { snack(context, 'تم'); _load(); }
          }
          break;
        case 'chmod':
          final m = await promptText(context, 'الوضع (مثال 644)', initial: '644');
          if (m != null && m.isNotEmpty && mounted) {
            await api.chmodFiles(_path, [name], m);
            if (mounted) { snack(context, 'تم'); _load(); }
          }
          break;
        case 'delete':
          if (await confirm(context, 'حذف "$name"؟', danger: true)) {
            if (!mounted) return;
            await api.deleteFiles(_path, [name]);
            if (mounted) { snack(context, 'تم الحذف'); _load(); }
          }
          break;
      }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Widget _sheet(IconData i, String t, String v, {bool danger = false}) =>
      ListTile(
        leading: Icon(i, color: danger ? C.danger : C.primary),
        title: Text(t, style: TextStyle(color: danger ? C.danger : null)),
        onTap: () => Navigator.pop(context, v),
      );

  // ============ View/Edit code ============
  Future<String?> _showCode(String name, String content,
      {bool editable = false}) async {
    final ctrl = TextEditingController(text: content);
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: C.bg,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .85),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.code, color: C.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 15))),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: C.muted)),
            ]),
            const SizedBox(height: 8),
            Expanded(child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.border),
              ),
              padding: const EdgeInsets.all(12),
              child: editable
                  ? TextField(
                      controller: ctrl, maxLines: null, expands: true,
                      style: const TextStyle(fontFamily: 'monospace',
                          fontSize: 12.5, color: Colors.white, height: 1.5),
                      decoration: const InputDecoration(
                          border: InputBorder.none),
                    )
                  : SingleChildScrollView(
                      child: CodeViewer(code: content, filename: name,
                          showCopy: true),
                    ),
            )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.muted,
                  side: const BorderSide(color: C.border),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(editable ? 'إلغاء' : 'إغلاق'),
              )),
              if (editable) ...[
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, ctrl.text),
                  child: const Text('حفظ'),
                )),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  // ============ Actions ============
  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) return;
      final p = result.files.single.path;
      if (p == null) return;
      final f = File(p);
      if (!await f.exists()) {
        if (mounted) snack(context, 'الملف غير موجود', error: true);
        return;
      }
      if (!mounted) return;
      snackInfo(context, 'جاري الرفع…');
      await context.read<AuthProvider>().api!.uploadFile(f, directory: _path);
      if (mounted) {
        snack(context, 'تم الرفع');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'فشل: ${friendlyError(e)}', error: true);
    }
  }

  Future<void> _newFolder() async {
    final name = await promptText(context, 'اسم المجلد');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.createFolder(_path, name);
      if (mounted) { snack(context, 'تم الإنشاء'); _load(); }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _search() async {
    final q = await promptText(context, 'بحث عن ملف');
    if (q == null || q.isEmpty || !mounted) return;
    try {
      final r = await context
          .read<AuthProvider>()
          .api!
          .searchFiles(q, directory: _path, maxDepth: 4);
      final results = (r['results'] as List? ?? []).cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (results.isEmpty) {
        snackInfo(context, 'لا نتائج');
        return;
      }
      // عرض النتائج
      await showModalBottomSheet(
        context: context,
        backgroundColor: C.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .6,
          maxChildSize: .9,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              Text('نتائج البحث (${results.length})',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...results.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_fileIcon(r['name'] ?? ''),
                    color: C.primary),
                title: Text(r['path'] ?? '',
                    style: const TextStyle(fontSize: 13,
                        fontFamily: 'monospace')),
                subtitle: Text(fSize(r['size']),
                    style: const TextStyle(color: C.muted, fontSize: 11)),
              )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _download(String full, String name) async {
    try {
      final api = context.read<AuthProvider>().api!;
      final url = await api.downloadUrl(full);
      snackInfo(context, 'جاري التنزيل…');
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/$name');
      final res = await http.get(Uri.parse(url));
      await out.writeAsBytes(res.bodyBytes);
      if (!mounted) return;
      await Share.shareXFiles([XFile(out.path)], text: name);
    } catch (e) {
      if (mounted) snack(context, 'فشل التنزيل: ${friendlyError(e)}',
          error: true);
    }
  }

  Future<void> _bulkDelete() async {
    if (!await confirm(context, 'حذف ${_selected.length} عنصر؟', danger: true)) return;
    if (!mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .deleteFiles(_path, _selected.toList());
      if (mounted) { snack(context, 'تم الحذف'); _load(); }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _bulkMove() async {
    final d = await promptText(context, 'نقل ${_selected.length} عنصر إلى', hint: '/');
    if (d == null || d.isEmpty || !mounted) return;
    try {
      await context.read<AuthProvider>().api!
          .moveFiles(_path, _selected.toList(), d);
      if (mounted) { snack(context, 'تم'); _load(); }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  // ============ Helpers ============
  String _join(String a, String b) => a.endsWith('/') ? '$a$b' : '$a/$b';

  IconData _fileIcon(String n) {
    final e = n.split('.').last.toLowerCase();
    switch (e) {
      case 'zip': case 'tar': case 'gz': case 'rar': case '7z':
        return Icons.archive;
      case 'py': case 'js': case 'dart': case 'sh': case 'java':
      case 'kt': case 'c': case 'cpp': case 'go': case 'rs':
        return Icons.code;
      case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp':
        return Icons.image;
      case 'mp4': case 'mkv': case 'mov': case 'avi':
        return Icons.videocam;
      case 'mp3': case 'wav': case 'ogg':
        return Icons.music_note;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'json': case 'yml': case 'yaml': case 'xml':
        return Icons.data_object;
      case 'md': case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode
          ? _selectionAppBar()
          : _normalAppBar(),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              onPressed: _upload,
              backgroundColor: C.primary,
              foregroundColor: Colors.black,
              child: const Icon(Icons.upload),
            ),
    );
  }

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الملفات', style: TextStyle(fontSize: 16)),
        Text(_path, style: const TextStyle(color: C.muted, fontSize: 10,
            fontWeight: FontWeight.normal)),
      ]),
      actions: [
        IconButton(
            onPressed: _path == '/' ? null : _up,
            icon: Icon(Icons.arrow_upward,
                color: _path == '/' ? C.muted : C.primary)),
        IconButton(
            onPressed: _newFolder,
            icon: const Icon(Icons.create_new_folder_outlined,
                color: C.primary)),
        IconButton(
            onPressed: _search,
            icon: const Icon(Icons.search, color: C.primary)),
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: C.primary)),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    return AppBar(
      backgroundColor: C.surfaceHi,
      leading: IconButton(
          onPressed: () => setState(() => _selected.clear()),
          icon: const Icon(Icons.close)),
      title: Text('${_selected.length} محدد',
          style: const TextStyle(fontSize: 16)),
      actions: [
        IconButton(
            onPressed: _bulkMove,
            icon: const Icon(Icons.drive_file_move_outline)),
        IconButton(
            onPressed: _bulkDelete,
            icon: const Icon(Icons.delete_outline, color: C.danger)),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.primary));
    }
    if (_err != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: C.danger, size: 48),
            const SizedBox(height: 12),
            Text(_err!, textAlign: TextAlign.center,
                style: const TextStyle(color: C.danger)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('إعادة')),
          ],
        ),
      ));
    }
    if (_items.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64,
              color: C.muted.withValues(alpha: .4)),
          const SizedBox(height: 12),
          const Text('المجلد فارغ',
              style: TextStyle(color: C.muted, fontSize: 14)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _upload,
            icon: const Icon(Icons.upload, color: C.primary),
            label: const Text('رفع ملف',
                style: TextStyle(color: C.primary)),
          ),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: C.primary,
      backgroundColor: C.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) => _tile(_items[i]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final isFile = item['is_file'] == true;
    final selected = _selected.contains(name);
    final color = isFile ? C.primary : C.accent;
    final icon = isFile ? _fileIcon(name) : Icons.folder;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? C.primary.withValues(alpha: .12)
            : C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected
                ? C.primary.withValues(alpha: .6)
                : C.border),
      ),
      child: ListTile(
        onLongPress: () => _toggleSelect(item),
        onTap: () => _enter(item),
        leading: _selectionMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => _toggleSelect(item),
                activeColor: C.primary,
              )
            : Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isFile
              ? '${fSize(item['size'])} · ${item['mimetype'] ?? '—'}'
              : 'مجلد',
          style: const TextStyle(color: C.muted, fontSize: 10),
        ),
        trailing: _selectionMode
            ? null
            : const Icon(Icons.chevron_right, color: C.muted, size: 18),
      ),
    );
  }
}
