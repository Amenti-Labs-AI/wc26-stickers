import 'package:flutter/material.dart';

import '../../data/models/collection_start_mode.dart';

/// Chooser for first-launch setup or Settings reset.
Future<CollectionStartMode?> showCollectionStartChooser(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool allowCancel = true,
}) {
  return showModalBottomSheet<CollectionStartMode>(
    context: context,
    isDismissible: allowCancel,
    enableDrag: allowCancel,
    showDragHandle: true,
    builder: (ctx) {
      return PopScope(
        canPop: allowCancel,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final mode in CollectionStartMode.values) ...[
                  _ModeCard(
                    mode: mode,
                    onTap: () => Navigator.pop(ctx, mode),
                  ),
                  const SizedBox(height: 10),
                ],
                if (allowCancel)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});

  final CollectionStartMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = mode == CollectionStartMode.ownedScan;
    return Material(
      color: isPrimary
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mode.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
