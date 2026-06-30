import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/parallel_kind.dart';
import '../../data/models/sticker.dart';
import 'collection_providers.dart';

Future<void> showStickerEditSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Sticker sticker,
  required Set<String> scannedMissing,
  required Future<void> Function() onSaved,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _StickerEditSheet(
      sticker: sticker,
      scannedMissing: scannedMissing,
      ref: ref,
      onSaved: onSaved,
    ),
  ).whenComplete(() => FocusManager.instance.primaryFocus?.unfocus());
}

class _StickerEditSheet extends StatefulWidget {
  const _StickerEditSheet({
    required this.sticker,
    required this.scannedMissing,
    required this.ref,
    required this.onSaved,
  });

  final Sticker sticker;
  final Set<String> scannedMissing;
  final WidgetRef ref;
  final Future<void> Function() onSaved;

  @override
  State<_StickerEditSheet> createState() => _StickerEditSheetState();
}

class _StickerEditSheetState extends State<_StickerEditSheet> {
  late bool _need;
  late int _swaps;
  late Map<ParallelKind, int> _parallels;
  bool _saving = false;
  bool _savingParallels = false;

  @override
  void initState() {
    super.initState();
    _need = widget.sticker.isNeed(widget.scannedMissing);
    _swaps = widget.sticker.swapCount;
    _parallels = Map<ParallelKind, int>.from(widget.sticker.parallelCounts);
  }

  Future<void> _persistState() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.ref.read(collectionNotifierProvider.notifier).applyStickerState(
            widget.sticker.code,
            need: _need,
            swaps: _need ? 0 : _swaps,
          );
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persistParallels() async {
    if (_savingParallels) return;
    setState(() => _savingParallels = true);
    try {
      await widget.ref
          .read(collectionNotifierProvider.notifier)
          .applyParallelCounts(widget.sticker.code, _parallels);
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _savingParallels = false);
    }
  }

  void _setNeed(bool need) {
    if (_need == need) return;
    setState(() {
      _need = need;
      if (need) _swaps = 0;
    });
    _persistState();
  }

  void _adjustSwaps(int delta) {
    if (_need) return;
    final next = (_swaps + delta).clamp(0, 998);
    if (next == _swaps) return;
    setState(() => _swaps = next);
    _persistState();
  }

  void _adjustParallel(ParallelKind kind, int delta) {
    final current = _parallels[kind] ?? 0;
    final next = (current + delta).clamp(0, 999);
    if (next == current) return;
    setState(() {
      if (next == 0) {
        _parallels.remove(kind);
      } else {
        _parallels[kind] = next;
      }
    });
    _persistParallels();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sticker = widget.sticker;
    final supportsParallels = stickerSupportsParallels(sticker);
    final isBusy = _saving || _savingParallels;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isBusy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    borderRadius: BorderRadius.circular(1),
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              Text(sticker.code, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                sticker.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text('Status', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Owned')),
                  ButtonSegment(value: true, label: Text('Need')),
                ],
                selected: {_need},
                onSelectionChanged: _saving ? null : (s) => _setNeed(s.first),
              ),
              const SizedBox(height: 20),
              Text('Swaps', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _saving || _need || _swaps <= 0
                        ? null
                        : () => _adjustSwaps(-1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$_swaps',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: _need
                            ? scheme.onSurface.withValues(alpha: 0.38)
                            : null,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _saving || _need || _swaps >= 998
                        ? null
                        : () => _adjustSwaps(1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_need)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Swaps apply only when Owned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (supportsParallels) ...[
                const SizedBox(height: 20),
                Text('Parallels', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'Parallels count as swaps, not album completion.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final kind in ParallelKind.orderedByRarity)
                  _ParallelCountRow(
                    kind: kind,
                    count: _parallels[kind] ?? 0,
                    onDecrement: () => _adjustParallel(kind, -1),
                    onIncrement: () => _adjustParallel(kind, 1),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallelCountRow extends StatelessWidget {
  const _ParallelCountRow({
    required this.kind,
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  final ParallelKind kind;
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: kind.borderColor,
              shape: BoxShape.circle,
              border: kind == ParallelKind.black
                  ? Border.all(color: Colors.white24)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.displayLabel, style: theme.textTheme.bodyMedium),
                Text(
                  kind.oddsLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: count <= 0 ? null : onDecrement,
            icon: const Icon(Icons.remove_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton.filledTonal(
            onPressed: count >= 999 ? null : onIncrement,
            icon: const Icon(Icons.add_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
