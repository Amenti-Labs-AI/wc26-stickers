import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/models/collection_start_mode.dart';
import 'features/collection/collection_providers.dart';
import 'features/collection/collection_screen.dart';
import 'features/home/home_screen.dart';
import 'features/scan_page/scan_page_screen.dart';
import 'features/settings/collection_start_sheet.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Warm DB + Home providers during the native splash so the first frame
  // is content, not a spinner.
  final setupComplete =
      await AppDatabase.instance.hasCompletedCollectionSetup();
  final container = ProviderContainer();
  if (setupComplete) {
    await Future.wait([
      container.read(collectionStatsProvider.future),
      container.read(scannedMissingByTeamProvider.future),
      container.read(swapsByTeamProvider.future),
      container.read(parallelsByTeamProvider.future),
    ]);
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PaniniApp(initialSetupComplete: setupComplete),
    ),
  );
}

class PaniniApp extends StatelessWidget {
  const PaniniApp({super.key, required this.initialSetupComplete});

  final bool initialSetupComplete;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      theme: AppTheme.light(),
      home: HomeShell(initialSetupComplete: initialSetupComplete),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.initialSetupComplete});

  final bool initialSetupComplete;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = [
    _TabInfo('Home', Icons.home_outlined, Icons.home),
    _TabInfo(
      'Collection',
      Icons.collections_bookmark_outlined,
      Icons.collections_bookmark,
    ),
    _TabInfo('Scan', Icons.document_scanner_outlined, Icons.document_scanner),
    _TabInfo('Settings', Icons.settings_outlined, Icons.settings),
  ];

  late bool _setupComplete = widget.initialSetupComplete;

  @override
  void initState() {
    super.initState();
    if (!_setupComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runFirstLaunchSetup());
    }
  }

  Future<void> _runFirstLaunchSetup() async {
    CollectionStartMode? mode;
    while (mode == null && mounted) {
      mode = await showCollectionStartChooser(
        context,
        title: 'How do you want to start?',
        subtitle: 'You can change this later in Settings → Reset collection.',
        allowCancel: false,
      );
    }
    if (mode == null || !mounted) return;

    await AppDatabase.instance.applyCollectionStartMode(mode);
    _invalidateCollection(ref);
    if (!mounted) return;
    setState(() => _setupComplete = true);
  }

  void _invalidateCollection(WidgetRef ref) {
    ref.invalidate(stickersProvider);
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(scannedMissingCodesProvider);
    ref.invalidate(scannedMissingByTeamProvider);
    ref.invalidate(swapsByTeamProvider);
    ref.invalidate(parallelsByTeamProvider);
    ref.invalidate(groupedStickersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(shellTabIndexProvider);
    final isScanTab = index == 2;
    final tab = _tabs[index];

    // First-launch chooser sits on top; shell still builds underneath.
    return Stack(
      children: [
        Scaffold(
          appBar: isScanTab
              ? null
              : AppBar(
                  title: Text(tab.label),
                  actions: [
                    if (index == 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Image.asset(
                          'assets/branding/wc26_logo.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          color: Theme.of(context).colorScheme.onSurface,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                  ],
                ),
          body: IndexedStack(
            index: index,
            children: [
              const HomeScreen(),
              const CollectionScreen(),
              ScanPageScreen(active: index == 2),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) =>
                ref.read(shellTabIndexProvider.notifier).state = i,
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
        ),
        if (!_setupComplete)
          const ModalBarrier(dismissible: false, color: Colors.black54),
      ],
    );
  }
}

class _TabInfo {
  const _TabInfo(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
