import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../state/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Perfil del motorizado', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 22),
      Card(color: AppTheme.surface, child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
        _row(Icons.person_outline, 'Nombre', user.name),
        _row(Icons.badge_outlined, 'Usuario', user.username),
        _row(Icons.security_outlined, 'Rol', 'Motorizado (6)'),
        _row(Icons.toggle_on_outlined, 'Estado', user.estado ?? 'activo'),
      ]))),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: () => ref.read(authProvider.notifier).logout(), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Cerrar sesión')),
    ]));
  }
  Widget _row(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(icon, color: AppTheme.purpleLight), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.textMuted)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]))]));
}
