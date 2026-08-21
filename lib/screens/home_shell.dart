import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/zazu_header.dart';
import 'earnings_screen.dart';
import 'map_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const pages = [
    OrdersScreen(),
    ScannerScreen(),
    MapScreen(),
    EarningsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final index = ref.watch(homeTabIndexProvider);
    final showHeader = index != 1 && index != 2;
    ref.watch(locationTrackingProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            if (showHeader) ZazuHeader(name: user.name),
            Expanded(
              child: IndexedStack(index: index, children: pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected:
              (value) => ref.read(homeTabIndexProvider.notifier).state = value,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Escáner',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Rutas',
            ),
            NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Ingresos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
