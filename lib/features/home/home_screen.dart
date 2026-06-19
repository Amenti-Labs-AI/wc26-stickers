import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/missing_stickers_codec.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
import '../collection/collection_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(collectionStatsProvider);
    final scannedByTeamAsync = ref.watch(scannedMissingByTeamProvider);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.section),
        children: [
          statsAsync.when(
            data: (stats) => AlbumProgressHero(stats: stats),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.page),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          scannedByTeamAsync.when(
            data: (byTeam) {
              if (byTeam.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Scan album pages to capture missing stickers',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ScannedMissingPanel(byTeam: byTeam);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(scannedMissingByTeamProvider);
    ref.invalidate(scannedMissingCodesProvider);
  }
}

class AlbumProgressHero extends StatelessWidget {
  const AlbumProgressHero({super.key, required this.stats});

  final CollectionStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = stats.total == 0 ? 0.0 : stats.owned / stats.total;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.lerp(scheme.primary, scheme.tertiary, 0.35)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 6,
                      backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                      color: scheme.tertiary,
                    ),
                    Text(
                      '${stats.percent.round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Album progress',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.owned} of ${stats.total}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AppStatPill(
                          label: 'Scanned missing',
                          value: '${stats.scannedMissing}',
                          accent: scheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        AppStatPill(
                          label: 'Dupes',
                          value: '${stats.duplicates}',
                          accent: scheme.onPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannedMissingPanel extends StatelessWidget {
  const ScannedMissingPanel({super.key, required this.byTeam});

  final Map<String, List<Sticker>> byTeam;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final teams = byTeam.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final total = teams.fold<int>(0, (sum, e) => sum + e.value.length);
    final exportText = _buildExportText(teams);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader('Scanned missing'),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.document_scanner_outlined, color: scheme.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$total stickers · ${teams.length} teams',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                            ),
                            Text(
                              'From live page scan',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onErrorContainer.withValues(alpha: 0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: exportText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Missing list copied')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy list'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _shareBackupCode(context),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share backup'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...teams.map((entry) {
                    final parts = entry.key.split('|');
                    final code = parts[0];
                    final name = parts.length > 1 ? parts[1] : code;
                    final codes = entry.value.map((s) => s.code).join(', ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                          children: [
                            TextSpan(
                              text: '$name ($code): ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: codes),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildExportText(List<MapEntry<String, List<Sticker>>> teams) {
    final buf = StringBuffer('Need:\n');
    for (final entry in teams) {
      final codes = entry.value.map((s) => s.code).join(', ');
      buf.writeln('${entry.key.split('|').first}: $codes');
    }
    return buf.toString().trim();
  }

  Future<void> _shareBackupCode(BuildContext context) async {
    final json = await AppDatabase.instance.exportMissingStickersJson();
    final code = encodeMissingStickers(json);
    await Share.share(code, subject: 'WC26 missing stickers backup');
  }
}
