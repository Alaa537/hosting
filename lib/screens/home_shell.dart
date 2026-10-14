import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/banner_widget.dart';
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
  static const _tabs = [
    DashboardScreen(),
    ServerScreen(),
    FilesScreen(),
    AppScreen(),      // ← كان BotsScreen
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bs = context.watch<AuthProvider>().bootstrap_;
    final banners = bs?.banners ?? const [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          if (banners.isNotEmpty)
            ...banners.map((b) => BannerStrip(banner: b)),
          Expanded(child: IndexedStack(index: _i, children: _tabs)),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          backgroundColor: C.surface,
          indicatorColor: C.primary.withValues(alpha: .15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: C.muted),
                selectedIcon: Icon(Icons.dashboard, color: C.primary), label: 'لوحة'),
            NavigationDestination(
                icon: Icon(Icons.dns_outlined, color: C.muted),
                selectedIcon: Icon(Icons.dns, color: C.primary), label: 'سيرفر'),
            NavigationDestination(
                icon: Icon(Icons.folder_outlined, color: C.muted),
                selectedIcon: Icon(Icons.folder, color: C.primary), label: 'ملفات'),
            NavigationDestination(
                icon: Icon(Icons.rocket_launch_outlined, color: C.muted),
                selectedIcon: Icon(Icons.rocket_launch, color: C.primary), label: 'تطبيقي'),
            NavigationDestination(
                icon: Icon(Icons.menu, color: C.muted),
                selectedIcon: Icon(Icons.menu, color: C.primary), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}
