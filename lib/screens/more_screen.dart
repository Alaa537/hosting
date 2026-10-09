import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/dialogs.dart';
import 'profile_screen.dart';
import 'backups_screen.dart';
import 'notifications_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  C.primary.withValues(alpha: .15),
                  C.accent.withValues(alpha: .15),
                ]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.primary.withValues(alpha: .3)),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: C.primary.withValues(alpha: .2),
                  child: Text(
                    (user?.username ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: C.primary,
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.username ?? '—',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user?.isAdmin == true ? C.accent : C.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (user?.role ?? 'user').toUpperCase(),
                          style: const TextStyle(color: Colors.black,
                              fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (user != null && user.unreadNotifications > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 8, color: C.accent),
                        const SizedBox(width: 4),
                        Text('${user.unreadNotifications}',
                            style: const TextStyle(color: C.accent,
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 20),
            _tile(context, Icons.person_outline, 'Profile', 'Account details',
                () => _push(context, const ProfileScreen())),
            _tile(context, Icons.backup_outlined, 'Backups', 'Create / restore',
                () => _push(context, const BackupsScreen())),
            _tile(context, Icons.notifications_outlined, 'Notifications', 'Inbox',
                () => _push(context, const NotificationsScreen())),
            if (user?.isAdmin == true)
              _tile(context, Icons.admin_panel_settings_outlined, 'Admin panel',
                  'Users, requests, pool',
                  () => _push(context, const AdminScreen()), accent: true),
            _tile(context, Icons.settings_outlined, 'Settings', 'URL, password',
                () => _push(context, const SettingsScreen())),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: C.danger),
                title: const Text('Sign out',
                    style: TextStyle(color: C.danger, fontWeight: FontWeight.w700)),
                onTap: () async {
                  if (await confirm(context, 'Sign out?',
                      msg: 'This will end your session.', danger: true)) {
                    if (context.mounted) await auth.logout();
                  }
                },
              ),
            ),
            const SizedBox(height: 30),
            Center(child: Column(children: [
              Text('HOSTING',
                  style: TextStyle(color: C.muted.withValues(alpha: .5),
                      fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('v1.0.0 · ${auth.baseUrl}',
                  style: TextStyle(color: C.muted.withValues(alpha: .5), fontSize: 10)),
            ])),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData ic, String title, String sub,
      VoidCallback onTap, {bool accent = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? C.accent.withValues(alpha: .4) : C.border),
      ),
      child: ListTile(
        leading: Icon(ic, color: accent ? C.accent : C.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(sub, style: const TextStyle(color: C.muted, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: C.muted),
        onTap: onTap,
      ),
    );
  }

  void _push(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));
}
