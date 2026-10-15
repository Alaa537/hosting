import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../models/app_models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';
import 'live_console_screen.dart';
import 'files_screen.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});
  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  AppStatus? _st;
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final st = await context.read<AuthProvider>().api!.appStatus();
      if (!mounted) return;
      setState(() { _st = st; _err = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _start() async {
    try { await context.read<AuthProvider>().api!.appStart();
      if (mounted) { snack(context, 'بدأ التشغيل'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _restart() async {
    try { await context.read<AuthProvider>().api!.appRestart();
      if (mounted) { snack(context, 'إعادة التشغيل'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _stop() async {
    if (!await confirm(context, 'إيقاف التطبيق؟')) return;
    if (!mounted) return;
    try { await context.read<AuthProvider>().api!.appStop();
      if (mounted) { snack(context, 'تم الإيقاف'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _kill() async {
    if (!await confirm(context, 'إجبار الإيقاف (Kill)؟', danger: true)) return;
    if (!mounted) return;
    try { await context.read<AuthProvider>().api!.appKill();
      if (mounted) { snack(context, 'تم الإيقاف'); _load(); }
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _command() async {
    final c = await promptText(context, 'أرسل أمر للتطبيق');
    if (c == null || c.isEmpty || !mounted) return;
    try { await context.read<AuthProvider>().api!.appCommand(c);
      if (mounted) snack(context, 'تم الإرسال');
    } catch (e) { if (mounted) snack(context, friendlyError(e), error: true); }
  }

  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['py'], withData: false);
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
      final r = await context.read<AuthProvider>().api!
          .appUpload(file, requirements: req);
      if (mounted) {
        snack(context, 'تم الرفع');
        if (r['needs_restart'] == true) {
          snackInfo(context, 'أعد التشغيل لتطبيق التغييرات');
        }
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'فشل: ${friendlyError(e)}', error: true);
    }
  }

  Future<void> _edit() async {
    try {
      final original = await context.read<AuthProvider>().api!.appRead();
      if (!mounted) return;
      final ctrl = TextEditingController(text: original);
      final edited = await showDialog<String>(context: context, builder: (_) => Dialog(
        backgroundColor: C.bg,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.code, color: C.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('app.py',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
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
              child: TextField(
                controller: ctrl, maxLines: null, expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5,
                    color: Colors.white, height: 1.5),
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: 'اكتب الكود هنا…'),
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
                child: const Text('إلغاء'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text),
                child: const Text('حفظ'),
              )),
            ]),
          ]),
        ),
      ));
      if (edited == null || edited == original || !mounted) return;
      await context.read<AuthProvider>().api!.appWrite(edited);
      if (mounted) {
        snack(context, 'تم الحفظ');
        snackInfo(context, 'أعد التشغيل لتطبيق التغييرات');
      }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوتي'),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh, color: C.primary)),
        ],
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
                if (_st != null) ...[
                  _statusCard(_st!),
                  const SizedBox(height: 14),
                  SectionCard(title: 'التحكم',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      _action(Icons.play_arrow, 'تشغيل', C.success, _start),
                      _action(Icons.restart_alt, 'إعادة', C.warning, _restart),
                      _action(Icons.stop, 'إيقاف', C.info, _stop),
                      _action(Icons.power_settings_new, 'Kill', C.danger, _kill),
                    ])),
                  const SizedBox(height: 14),
                  SectionCard(title: 'الأدوات', child: Column(children: [
                    _listAction(Icons.terminal, 'LOG BOT',
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const LiveConsoleScreen()))),
                    _listAction(Icons.upload_file, 'رفع app.py جديد', _upload),
                    _listAction(Icons.edit_document, 'تعديل app.py', _edit),
                    _listAction(Icons.folder_outlined, 'إدارة الملفات',
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const FilesScreen()))),
                  ])),
                ],
                const SizedBox(height: 30),
              ]),
            )),
    );
  }

  Widget _statusCard(AppStatus st) {
    final c = stateColor(st.state);
    final r = st.resources;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(st.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text(st.state.toUpperCase(),
              style: TextStyle(color: c, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 14, color: C.muted),
          const SizedBox(width: 4),
          Text(fTime(st.uptimeSeconds),
              style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 18),
        _bar('CPU', r.cpuPercent, null, null, suffix: '%'),
        const SizedBox(height: 12),
        _bar('MEM', r.memoryPercent, r.memoryBytes, r.memoryLimit),
        const SizedBox(height: 12),
        _bar('DISK', r.diskPercent, r.diskBytes, r.diskLimit),
        const SizedBox(height: 14),
        Row(children: [
          _net('▼', fSize(r.rxBytes), C.success),
          const SizedBox(width: 20),
          _net('▲', fSize(r.txBytes), C.accent),
        ]),
        const SizedBox(height: 16),
        Divider(color: C.border),
        const SizedBox(height: 8),
        Row(children: [
          Icon(st.app.exists ? Icons.check_circle : Icons.cancel,
              color: st.app.exists ? C.success : C.danger, size: 16),
          const SizedBox(width: 6),
          Text('app.py ${st.app.exists ? "موجود" : "غير موجود"}',
              style: TextStyle(
                  color: st.app.exists ? C.success : C.danger,
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(fSize(st.app.size),
              style: const TextStyle(color: C.muted, fontSize: 11,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(st.app.requirements ? Icons.check_circle : Icons.circle_outlined,
              color: st.app.requirements ? C.success : C.muted, size: 16),
          const SizedBox(width: 6),
          Text('requirements.txt',
              style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _bar(String label, double? pct, int? used, int? limit, {String suffix = ''}) {
    final v = pct ?? 0;
    final c = v < 75 ? C.success : v < 90 ? C.warning : C.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(width: 42, child: Text(label,
            style: const TextStyle(color: C.muted, fontSize: 11,
                fontWeight: FontWeight.w700))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (v / 100).clamp(0, 1),
              minHeight: 6, backgroundColor: C.border,
              valueColor: AlwaysStoppedAnimation(c)))),
        const SizedBox(width: 10),
        SizedBox(width: 52, child: Text('${v.toStringAsFixed(1)}$suffix',
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

  Widget _net(String a, String v, Color c) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(a, style: TextStyle(color: c, fontSize: 14)),
        const SizedBox(width: 4),
        Text(v, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600)),
      ]);

  Widget _action(IconData ic, String label, Color color, VoidCallback onTap) {
    return Material(color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
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
      title: Text(t, style: TextStyle(fontSize: 13.5,
          color: danger ? C.danger : null, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: C.muted, size: 18),
      onTap: onTap);
}
