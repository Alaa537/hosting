import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(title: 'Connection', child: Column(children: [
          KVRow(k: 'Base URL', v: Text(auth.baseUrl,
              style: const TextStyle(fontSize: 12))),
          KVRow(k: 'Token', v: Text(auth.api?.token != null ? 'saved' : 'none',
              style: TextStyle(color: auth.api?.token != null ? C.success : C.muted))),
        ])),
        const SizedBox(height: 14),
        SectionCard(title: 'Actions', child: Column(children: [
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link, color: C.primary),
            title: const Text('Change API base URL',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: C.muted),
            onTap: () => _changeBase(context, auth)),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password, color: C.primary),
            title: const Text('Change my password',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: C.muted),
            onTap: () => _changePassword(context, auth)),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: C.warning),
            title: const Text('Log out all sessions (server-side)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: C.muted),
            onTap: () => _logoutAll(context, auth)),
        ])),
        const SizedBox(height: 20),
      ])),
    );
  }

  Future<void> _changeBase(BuildContext ctx, AuthProvider auth) async {
    final n = await promptText(ctx, 'New base URL', initial: auth.baseUrl);
    if (n == null || n.trim().isEmpty || !ctx.mounted) return;
    if (!await confirm(ctx, 'Change server URL?',
        msg: 'You will be signed out and must log in again.')) return;
    if (!ctx.mounted) return;
    await auth.setBase(n.trim());
  }

  Future<void> _changePassword(BuildContext ctx, AuthProvider auth) async {
    final o = await promptText(ctx, 'Old password', obscure: true);
    if (o == null || !ctx.mounted) return;
    final n = await promptText(ctx, 'New password', obscure: true);
    if (n == null || n.length < 8) {
      if (ctx.mounted) snack(ctx, 'Password must be at least 8 characters', error: true);
      return;
    }
    if (!ctx.mounted) return;
    try {
      await auth.api!.changePassword(o, n);
      if (ctx.mounted) {
        snack(ctx, 'Password changed — signing out');
        await auth.logout();
      }
    } catch (e) { if (ctx.mounted) snack(ctx, e.toString(), error: true); }
  }

  Future<void> _logoutAll(BuildContext ctx, AuthProvider auth) async {
    if (!await confirm(ctx, 'Invalidate every session?', danger: true)) return;
    if (!ctx.mounted) return;
    try {
      await auth.logoutAll();
      await auth.logout();
    } catch (e) { if (ctx.mounted) snack(ctx, e.toString(), error: true); }
  }
}
