import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/screens/garage_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/home_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/play_hub_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/settings_screen.dart';
import 'package:naza_one/naza_rev_recall/screens/stats_screen.dart';
import 'package:naza_one/naza_rev_recall/widgets/neon_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const pages = [
    HomeScreen(),
    GarageScreen(),
    PlayHubScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBackground(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          backgroundColor: Colors.transparent,
          indicatorColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.25),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.garage_rounded),
              label: 'Garage',
            ),
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_rounded),
              label: 'Play',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
