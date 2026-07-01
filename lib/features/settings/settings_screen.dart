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
                  child: Image.asset(
                    'assets/branding/amenti_logo_mark.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
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
                        'Offline · Global edition · ${AppInfo.stickerCount} stickers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
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
        const AppSectionHeader('About'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.apartment_rounded, color: scheme.primary),
                title: const Text(AppInfo.companyName),
                subtitle: const Text('Publisher'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.language_rounded, color: scheme.primary),
                title: const Text(AppInfo.websiteHost),
                subtitle: const Text('Visit Amenti Labs'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _openWebsite(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                title: const Text('How scanning works'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showScanInfo(context),
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
                title: const Text('Export need list'),
                subtitle: const Text('Shareable backup code (no file access)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportMissingList(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.download_rounded, color: scheme.primary),
                title: const Text('Import need list'),
                subtitle: const Text('Paste backup code from another device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importMissingList(context, ref),
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
              style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Clear owned counts — cannot be undone',
              style: TextStyle(color: scheme.onErrorContainer.withValues(alpha: 0.85)),
            ),
            onTap: () => _reset(context, ref),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }

  void _showScanInfo(BuildContext context) {
    final engine = ScanEngine.portraitOcr;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(engine.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final line in engine.detailBullets)
                  Padding(
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
                        Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
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

  Future<void> _exportMissingList(BuildContext context) async {
    final json = await AppDatabase.instance.exportMissingStickersJson();
    final code = encodeMissingStickers(json);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Backup code', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Copy or share this code to transfer your need list. '
                  'Import it on another device under Settings → Import need list.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  code,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Backup code copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Share.share(
                          code,
                          subject: 'WC26 need stickers backup',
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _importMissingList(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    if (!context.mounted) return;

    final pasted = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Import backup code',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste a wc26: backup code or raw JSON from a previous export.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'wc26:1:…',
                    border: OutlineInputBorder(),
                  ),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      controller.text = data.text!.trim();
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('Paste from clipboard'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx, text);
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    if (pasted == null || pasted.isEmpty) return;
    if (!context.mounted) return;

    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import need list?'),
        content: const Text(
          'Choose whether to merge with your current need list '
          'or replace it entirely.',
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
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
    if (replace == null) return;

    try {
      final json = decodeMissingStickers(pasted);
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
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset collection?'),
        content: const Text(
          'Restores all stickers to owned and clears need list.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.resetCollection();
    _invalidateMissingProviders(ref);
  }
}
