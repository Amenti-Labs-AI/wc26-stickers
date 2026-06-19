import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/app_theme.dart';
import 'features/collection/collection_screen.dart';
import 'features/home/home_screen.dart';
import 'features/scan_page/scan_page_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PaniniApp()));
}

class PaniniApp extends StatelessWidget {
  const PaniniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    _TabInfo('Home', Icons.home_outlined, Icons.home),
    _TabInfo('Collection', Icons.collections_bookmark_outlined, Icons.collections_bookmark),
    _TabInfo('Scan', Icons.document_scanner_outlined, Icons.document_scanner),
    _TabInfo('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final isScanTab = _index == 2;
    final tab = _tabs[_index];

    return Scaffold(
      appBar: isScanTab
          ? null
          : AppBar(
              title: Text(tab.label),
              actions: [
                if (_index == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.sports_soccer,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const CollectionScreen(),
          ScanPageScreen(active: _index == 2),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabInfo {
  const _TabInfo(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
