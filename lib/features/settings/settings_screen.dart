import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/missing_stickers_codec.dart';
import '../../data/database/app_database.dart';
import '../../ml/scan_engine.dart';
import '../collection/collection_providers.dart';
import 'collection_start_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/branding/wc26_logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppInfo.appName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'World Cup 2026 sticker album · ${AppInfo.stickerCount} stickers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Unofficial fan app — not affiliated with Panini or FIFA.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const AppSectionHeader('Publisher'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openWebsite(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/branding/amenti_logo_mark.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppInfo.companyName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppInfo.websiteHost,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const AppSectionHeader('Instructions'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.tune_rounded,
                  color: scheme.primary,
                ),
                title: const Text('Collection modes'),
                subtitle: const Text('Scan for gaps vs empty start'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showModeInstructions(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.document_scanner_outlined,
                  color: scheme.primary,
                ),
                title: const Text('Scanning'),
                subtitle: const Text('Camera, Need & owned overlays'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showScanInstructions(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const AppSectionHeader('Data'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.upload_file_rounded, color: scheme.primary),
                title: const Text('Export collection'),
                subtitle: const Text('Copy a backup code'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportCollection(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.download_rounded, color: scheme.primary),
                title: const Text('Import collection'),
                subtitle: const Text('Paste a backup code'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importCollection(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const AppSectionHeader('Danger zone'),
        Card(
          color: scheme.errorContainer.withValues(alpha: 0.25),
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
            title: Text(
              'Reset collection',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Wipe data and start over',
              style: TextStyle(
                color: scheme.onErrorContainer.withValues(alpha: 0.85),
              ),
            ),
            onTap: () => _reset(context, ref),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }

  void _showModeInstructions(BuildContext context) {
    final engine = ScanEngine.portraitOcr;
    _showInstructionsSheet(
      context,
      title: engine.modesTitle,
      bullets: engine.modeBullets,
    );
  }

  void _showScanInstructions(BuildContext context) {
    final engine = ScanEngine.portraitOcr;
    _showInstructionsSheet(
      context,
      title: engine.displayName,
      bullets: engine.scanBullets,
      showOverlayLegend: true,
    );
  }

  void _showInstructionsSheet(
    BuildContext context, {
    required String title,
    required List<String> bullets,
    bool showOverlayLegend = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (showOverlayLegend) ...[
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _OverlayLegendChip(
                          color: Color(0xFFFF5252),
                          label: 'Red · Need',
                        ),
                        _OverlayLegendChip(
                          color: Color(0xFFFFC107),
                          label: 'Yellow · Owned',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final line in bullets) _InstructionBullet(line: line),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(AppInfo.websiteUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${AppInfo.websiteUrl}')),
    );
  }

  Future<void> _exportCollection(BuildContext context) async {
    final json = await AppDatabase.instance.exportCollectionBackupJson();
    final code = encodeCollectionBackup(json);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export backup', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Includes owned, swaps, need, and parallels.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy code'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: code,
                        subject: 'WC26 collection backup',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importCollection(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;

    final pasted = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => const _ImportBackupSheet(),
    );

    if (pasted == null || pasted.isEmpty) return;
    if (!context.mounted) return;

    late final String json;
    try {
      json = decodeBackupPayload(pasted);
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid backup: ${e.message}')),
      );
      return;
    }

    final isFull = isCollectionBackupJson(json);

    if (isFull) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace collection?'),
          content: const Text(
            'Replaces owned, swaps, need, and parallels. Cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace all'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        final result = await AppDatabase.instance.importCollectionBackupJson(
          json,
          replace: true,
        );
        _invalidateMissingProviders(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${result.collectionCount} stickers, '
                '${result.missingCount} need, '
                '${result.parallelCount} parallels',
              ),
            ),
          );
        }
      } on FormatException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid backup: ${e.message}')),
          );
        }
      }
      return;
    }

    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import need list?'),
        content: const Text(
          'Legacy need-only backup. Merge or replace Need. Owned and '
          'parallels stay as-is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace need'),
          ),
        ],
      ),
    );
    if (replace == null) return;

    try {
      final count = await AppDatabase.instance.importMissingStickersJson(
        json,
        replace: replace,
      );
      _invalidateMissingProviders(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count need sticker codes')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup: ${e.message}')),
        );
      }
    }
  }

  void _invalidateMissingProviders(WidgetRef ref) {
    ref.invalidate(stickersProvider);
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(scannedMissingCodesProvider);
    ref.invalidate(scannedMissingByTeamProvider);
    ref.invalidate(swapsByTeamProvider);
    ref.invalidate(parallelsByTeamProvider);
    ref.invalidate(groupedStickersProvider);
    ref.invalidate(parallelInventoryStatsProvider);
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final mode = await showCollectionStartChooser(
      context,
      title: 'Reset collection',
      subtitle: 'Wipes Need, swaps, and parallels, then starts fresh.',
      allowCancel: true,
    );
    if (mode == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Confirm reset'),
          content: Text(
            'Reset with “${mode.title}”? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    await AppDatabase.instance.resetCollection(mode);
    _invalidateMissingProviders(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collection reset: ${mode.title}')),
      );
    }
  }
}

class _InstructionBullet extends StatelessWidget {
  const _InstructionBullet({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Icon(
              Icons.circle,
              size: 6,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(line, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _OverlayLegendChip extends StatelessWidget {
  const _OverlayLegendChip({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its [TextEditingController] so dismiss animation cannot hit a disposed controller.
class _ImportBackupSheet extends StatefulWidget {
  const _ImportBackupSheet();

  @override
  State<_ImportBackupSheet> createState() => _ImportBackupSheetState();
}

class _ImportBackupSheetState extends State<_ImportBackupSheet> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Import backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a collection (wc26:c2:) or legacy need (wc26:1:) code.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Paste code',
                border: OutlineInputBorder(),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final text = data?.text?.trim();
                if (text != null && text.isNotEmpty) {
                  _controller.text = text;
                }
              },
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Paste from clipboard'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
