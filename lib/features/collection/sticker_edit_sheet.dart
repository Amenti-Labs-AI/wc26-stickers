import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _need = widget.sticker.isNeed(widget.scannedMissing);
    _swaps = widget.sticker.swapCount;
  }

  Future<void> _persist() async {
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

  void _setNeed(bool need) {
    if (_need == need) return;
    setState(() {
      _need = need;
      if (need) _swaps = 0;
    });
    _persist();
  }

  void _adjustSwaps(int delta) {
    if (_need) return;
    final next = (_swaps + delta).clamp(0, 998);
    if (next == _swaps) return;
    setState(() => _swaps = next);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sticker = widget.sticker;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saving)
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
              onSelectionChanged:
                  _saving ? null : (s) => _setNeed(s.first),
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
                      color: _need ? scheme.onSurface.withValues(alpha: 0.38) : null,
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
          ],
        ),
      ),
    );
  }
}
