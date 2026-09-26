import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZazuDriverApp()));
}

class ZazuDriverApp extends ConsumerStatefulWidget {
  const ZazuDriverApp({super.key});
  @override
  ConsumerState<ZazuDriverApp> createState() => _ZazuDriverAppState();
}

class _ZazuDriverAppState extends ConsumerState<ZazuDriverApp> {
  bool restored = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authProvider.notifier).restore();
      if (mounted) setState(() => restored = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZAZU Driver',
      theme: AppTheme.dark,
      // Calendarios y diálogos del sistema en español.
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: !restored
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.authenticated
          ? const HomeShell()
          : const LoginScreen(),
    );
  }
}
