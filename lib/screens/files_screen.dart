import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});
  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String? _content;
  bool _loading = true;
  String? _err;
  bool _hasReqs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api!;
      final c = await api.appRead();
      bool hasReqs = false;
      try {
        final st = await api.appStatus();
        hasReqs = st.app.requirements;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _content = c;
        _hasReqs = hasReqs;
        _err = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    if (_content == null) return;
    final ctrl = TextEditingController(text: _content);
    final result = await showDialog<String>(
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
              const Expanded(
                child: Text('app.py',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: C.muted),
              ),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: ctrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'اكتب الكود هنا…',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.muted,
                    side: const BorderSide(color: C.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, ctrl.text),
                  child: const Text('حفظ'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (result == null || result == _content || !mounted) return;
    try {
      await context.read<AuthProvider>().api!.appWrite(result);
      if (mounted) {
        snack(context, 'تم الحفظ');
        snack(context, 'أعد التشغيل لتطبيق التغييرات');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['py'],
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

      final addReq = await confirm(context, 'إضافة requirements.txt؟');
      File? req;
      if (addReq) {
        final r = await FilePicker.platform.pickFiles(withData: false);
        if (r != null && r.files.isNotEmpty) {
          final rp = r.files.single.path;
          if (rp != null) req = File(rp);
        }
      }
      if (!mounted) return;

      snackInfo(context, 'جاري الرفع…');
      final api = context.read<AuthProvider>().api!;
      final resp = await api.appUpload(file, requirements: req);

      if (mounted) {
        snack(context, 'تم الرفع');
        if (resp['needs_restart'] == true) {
          snackInfo(context, 'أعد التشغيل لتطبيق التغييرات');
        }
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'فشل: ${friendlyError(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملفات البوت'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: C.primary),
          ),
          IconButton(
            onPressed: _upload,
            icon: const Icon(Icons.upload_file, color: C.primary),
          ),
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit, color: C.primary),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        backgroundColor: C.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.edit),
        label: const Text('تعديل',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: C.primary),
      );
    }
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: C.danger, size: 48),
              const SizedBox(height: 12),
              Text(_err!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.danger)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('إعادة')),
            ],
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // app.py card
      _fileCard(
        icon: Icons.code,
        title: 'app.py',
        subtitle: '${_content?.length ?? 0} حرف · ملف البوت',
        color: C.primary,
        onTap: _edit,
        onUpload: _upload,
      ),
      const SizedBox(height: 12),

      // requirements.txt card
      _fileCard(
        icon: Icons.description_outlined,
        title: 'requirements.txt',
        subtitle: _hasReqs ? '✅ موجود' : 'يُرفع مع app.py',
        color: _hasReqs ? C.success : C.accent,
        onTap: () => snack(context,
            'يُرفع مع app.py من زر الرفع أعلى الشاشة'),
        onUpload: null,
      ),

      const SizedBox(height: 20),

      // Info card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.primary.withValues(alpha: .25)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: C.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'الوضع الحالي: تطبيق واحد فقط (app.py).\n'
              'ارفع ملفات .py إضافية داخل app.py كـ modules.',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 20),

      // Preview
      if (_content != null && _content!.isNotEmpty) ...[
        Row(children: [
          const Text('معاينة app.py',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${_content!.length} bytes',
              style: const TextStyle(
                  color: C.muted,
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.border),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              _content!.length > 20000
                  ? '${_content!.substring(0, 20000)}\n\n… (اقتصاص)'
                  : _content!,
              language: 'python',
              theme: monokaiSublimeTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 90),
    ]);
  }

  Widget _fileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onUpload,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: C.muted, fontSize: 11)),
        trailing: onUpload != null
            ? IconButton(
                onPressed: onUpload,
                icon: Icon(Icons.upload_file, color: color, size: 20),
              )
            : const Icon(Icons.chevron_right, color: C.muted),
        onTap: onTap,
      ),
    );
  }
}
