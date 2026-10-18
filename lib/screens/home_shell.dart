import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/storage.dart';
import '../utils/constants.dart';
import '../widgets/banner_widget.dart';
import '../widgets/mesh_background.dart';
import '../widgets/pulse_icon.dart';
import 'dashboard_screen.dart';
import 'server_screen.dart';
import 'files_screen.dart';
import 'app_screen.dart';
import 'more_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  bool _pendingRestart = false;

  static const _tabs = [
    DashboardScreen(),
    ServerScreen(),
    FilesScreen(),
    AppScreen(),
    MoreScreen(),
  ];

  static const _labels = ['لوحة', 'سيرفر', 'ملفات', 'بوتي', 'المزيد'];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.dns_rounded,
    Icons.folder_rounded,
    Icons.smart_toy_rounded,
    Icons.grid_view_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _checkPending();
  }

  Future<void> _checkPending() async {
    final v = await Store.getPendingRestart();
    if (mounted) setState(() => _pendingRestart = v);
  }

  @override
  Widget build(BuildContext context) {
    final bs = context.watch<AuthProvider>().bootstrap_;
    final banners = bs?.banners ?? const [];

    return Scaffold(
      body: MeshBackground(
        subtle: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_pendingRestart) _restartBanner(),
              if (banners.isNotEmpty)
                ...banners.map((b) => BannerStrip(banner: b)),
              Expanded(
                child: IndexedStack(index: _i, children: _tabs),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: C.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 24,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: C.primary.withValues(alpha: .08),
              blurRadius: 32,
              spreadRadius: 2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_labels.length, (i) {
            final active = _i == i;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _i = i),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? C.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: active
                        ? Border.all(color: C.primary.withValues(alpha: .3))
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseIcon(
                        icon: _icons[i],
                        active: active,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? C.primary : C.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _restartBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: C.warning.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.warning.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: C.warning, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '⚠️ تغييرات معلّقة — أعد التشغيل',
              style: TextStyle(
                  color: C.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                final ctx = context;
                final api = ctx.read<AuthProvider>().api!;
                await api.appRestart();
                await Store.setPendingRestart(false);
                if (mounted) setState(() => _pendingRestart = false);
              } catch (_) {}
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: C.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'إعادة',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
