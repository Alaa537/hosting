import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class LiveConsoleScreen extends StatefulWidget {
  const LiveConsoleScreen({super.key});
  @override
  State<LiveConsoleScreen> createState() => _LiveConsoleScreenState();
}

class _LiveConsoleScreenState extends State<LiveConsoleScreen> {
  final List<_LogLine> _lines = [];
  final _scroll = ScrollController();
  final _cmd = TextEditingController();
  WebSocket? _ws;
  bool _streaming = false;
  bool _autoScroll = true;
  static const int _maxLines = 800;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ws?.close();
    _scroll.dispose();
    _cmd.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_streaming) return;
    setState(() { _streaming = true; });
    try {
      final api = context.read<AuthProvider>().api!;
      final ws = await api.connectEvents();
      _ws = ws;
      ws.listen((data) {
        try {
          final ev = jsonDecode(data as String);
          final t = ev['type'];
          if (t == 'log') {
            final line = (ev['data'] ?? '').toString().trimRight();
            if (line.isNotEmpty) _add(line, logColor(line));
          } else if (t == 'status') {
            _add('— status: ${ev['data']} —', C.accent);
          }
        } catch (_) {}
      }, onDone: () { if (mounted) setState(() => _streaming = false); },
         onError: (e) { if (mounted) { setState(() => _streaming = false);
           _add('stream error: $e', C.danger); } });
    } catch (e) {
      if (mounted) {
        setState(() => _streaming = false);
        _add('failed to connect: $e', C.danger);
      }
    }
  }

  void _stop() {
    _ws?.close();
    _ws = null;
    setState(() => _streaming = false);
  }

  void _add(String text, Color color) {
    if (!mounted) return;
    setState(() {
      _lines.add(_LogLine(text, color));
      if (_lines.length > _maxLines) _lines.removeAt(0);
    });
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _send() async {
    final c = _cmd.text.trim();
    if (c.isEmpty) return;
    _cmd.clear();
    _add('> $c', C.primary);
    try {
      await context.read<AuthProvider>().api!.appCommand(c);
    } catch (e) {
      _add('send failed: $e', C.danger);
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _lines.map((l) => l.text).join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم النسخ'), duration: Duration(seconds: 1),
      behavior: SnackBarBehavior.floating));
  }

  void _clear() => setState(() => _lines.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وحدة التحكم المباشرة'),
        actions: [
          IconButton(onPressed: _streaming ? _stop : _start,
              icon: Icon(_streaming ? Icons.stop_circle : Icons.play_circle,
                  color: _streaming ? C.danger : C.success)),
          IconButton(onPressed: () => setState(() => _autoScroll = !_autoScroll),
              icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                  color: _autoScroll ? C.success : C.muted)),
          IconButton(onPressed: _copy, icon: const Icon(Icons.copy, color: C.primary)),
          IconButton(onPressed: _clear, icon: const Icon(Icons.cleaning_services, color: C.muted)),
        ],
      ),
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: C.surface,
          child: Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(
                color: _streaming ? C.success : C.muted,
                shape: BoxShape.circle,
              )),
            const SizedBox(width: 8),
            Text(_streaming ? 'متصل' : 'غير متصل',
                style: TextStyle(color: _streaming ? C.success : C.muted,
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_lines.length} سطر',
                style: const TextStyle(color: C.muted, fontSize: 11,
                    fontFamily: 'monospace')),
          ]),
        ),
        Expanded(child: Container(
          color: const Color(0xFF0D0D14),
          child: _lines.isEmpty
            ? const Center(child: Text('في انتظار الإخراج…',
                style: TextStyle(color: C.muted, fontFamily: 'monospace',
                    fontSize: 12)))
            : Scrollbar(
                controller: _scroll,
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(10),
                  itemCount: _lines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: SelectableText(
                      _lines[i].text,
                      style: TextStyle(
                        color: _lines[i].color,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
        )),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: C.surface,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _cmd,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اكتب أمراً…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: C.primary, size: 20)),
              ),
              onSubmitted: (_) => _send(),
            )),
          ]),
        ),
      ])),
    );
  }
}

class _LogLine {
  final String text;
  final Color color;
  _LogLine(this.text, this.color);
}
