import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/album_breakdown.dart';
import '../../data/models/sticker.dart';

Future<void> showVendorListingSheet({
  required BuildContext context,
  required Iterable<Sticker> needStickers,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.75;
      return SizedBox(
        height: height,
        child: _VendorListingSheet(needStickers: needStickers),
      );
    },
  ).whenComplete(() => FocusManager.instance.primaryFocus?.unfocus());
}

class _VendorListingSheet extends StatefulWidget {
  const _VendorListingSheet({required this.needStickers});

  final Iterable<Sticker> needStickers;

  @override
  State<_VendorListingSheet> createState() => _VendorListingSheetState();
}

class _VendorListingSheetState extends State<_VendorListingSheet> {
  final _controller = TextEditingController();
  List<String>? _matches;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkListing() {
    FocusManager.instance.primaryFocus?.unfocus();
    final matches = needCodesInVendorListing(
      _controller.text,
      widget.needStickers,
    );
    setState(() {
      _matches = matches;
      _controller.clear();
    });
  }

  void _pasteAnother() {
    setState(() => _matches = null);
  }

  void _copyMatches() {
    final text = _matches!.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _matches!.isEmpty
              ? 'Nothing to copy'
              : '${_matches!.length} matches copied',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showingResult = _matches != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Check vendor listing',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (!showingResult) ...[
            Text(
              'Paste seller\'s list',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'MEX1 - 4\nSCO12 - 1',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _controller.text.trim().isEmpty ? null : _checkListing,
              child: const Text('Check listing'),
            ),
          ] else ...[
            Text(
              _matches!.isEmpty
                  ? 'No matches in your need list'
                  : '${_matches!.length} matches from your need list',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _matches!.isEmpty
                    ? Center(
                        child: Text(
                          'No matches in your need list',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _matches!.join('\n'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _matches!.isEmpty ? null : _copyMatches,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _pasteAnother,
                    child: const Text('Paste another'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
