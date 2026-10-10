import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class LogViewer extends StatefulWidget {
  final List<String> lines;
  final String? title;
  final double height;

  const LogViewer({
    super.key,
    required this.lines,
    this.title,
    this.height = 320,
  });

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  final _scroll = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Color _color(String line) {
    final u = line.toUpperCase();
    if (u.contains('TRACEBACK') || u.contains('CRITICAL') || u.contains('FATAL')) {
      return const Color(0xFFFF5F5F);
    }
    if (u.contains('ERROR') || u.contains('FAIL')) {
      return const Color(0xFFFF7B7B);
    }
    if (u.contains('WARN') || u.contains('DEPRECAT')) {
      return const Color(0xFFFFD75F);
    }
    if (u.contains('INFO')) return const Color(0xFF5FAFFF);
    if (u.contains('DEBUG')) return const Color(0xFF808080);
    if (u.contains('SUCCESS') || u.contains('STARTED')) {
      return const Color(0xFF5FFF87);
    }
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: C.border)),
          ),
          child: Row(children: [
            const Icon(Icons.terminal, color: C.primary, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text(
              widget.title ?? 'Logs',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            )),
            Text('${widget.lines.length} lines',
                style: const TextStyle(color: C.muted, fontSize: 10)),
            const SizedBox(width: 4),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 16,
              icon: Icon(
                _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                color: _autoScroll ? C.success : C.muted,
              ),
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 16,
              icon: const Icon(Icons.copy, color: C.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.lines.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Logs copied'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
          ]),
        ),
        // body
        SizedBox(
          height: widget.height,
          child: widget.lines.isEmpty
              ? const Center(child: Text('No output yet',
                  style: TextStyle(color: C.muted, fontSize: 11,
                      fontFamily: 'monospace')))
              : Scrollbar(
                  controller: _scroll,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.lines.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText(
                        widget.lines[i],
                        style: TextStyle(
                          color: _color(widget.lines[i]),
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
