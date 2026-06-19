import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/sticker_rarity.dart';
import '../../core/sticker_search_query.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
import 'collection_providers.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _searchController = TextEditingController();
  bool _scannedMissingOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  StickerQuery _buildQuery({required bool hasScannedMissing}) {
    final useScannedFilter = _scannedMissingOnly && hasScannedMissing;
    return StickerQuery(
      search: _searchController.text,
      filter: useScannedFilter ? StickerFilter.scannedMissing : StickerFilter.all,
    );
  }

  bool _isCollectionFiltered({required bool hasScannedMissing}) {
    if (_scannedMissingOnly && hasScannedMissing) return true;
    return _searchController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scannedAsync = ref.watch(scannedMissingCodesProvider);
    final scanned = scannedAsync.valueOrNull ?? const {};
    final hasScannedMissing = scanned.isNotEmpty;

    if (!hasScannedMissing && _scannedMissingOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scannedMissingOnly) {
          setState(() => _scannedMissingOnly = false);
        }
      });
    }

    final query = _buildQuery(hasScannedMissing: hasScannedMissing);
    final expandTeams = _isCollectionFiltered(hasScannedMissing: hasScannedMissing);
    final groupedAsync = ref.watch(groupedStickersProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.tight,
            AppSpacing.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Team code (BRA)',
                  prefixIcon: Icon(Icons.search_rounded),
                  counterText: '',
                ),
                maxLength: 3,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                inputFormatters: const [TeamCodeSearchFormatter(maxLength: 3)],
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              if (hasScannedMissing) ...[
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('All'),
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Scanned missing'),
                      icon: Icon(Icons.document_scanner_outlined, size: 18),
                    ),
                  ],
                  selected: {_scannedMissingOnly},
                  onSelectionChanged: (s) => setState(() => _scannedMissingOnly = s.first),
                ),
              ],
            ],
          ),
        ),
        if (!_scannedMissingOnly) const SwipeHintBanner(),
        Expanded(
          child: groupedAsync.when(
            data: (grouped) {
              final scanned = scannedAsync.valueOrNull ?? const {};
              final teamKeys = grouped.keys.toList()
                ..sort((a, b) {
                  final nameA = grouped[a]!.first.teamName;
                  final nameB = grouped[b]!.first.teamName;
                  final cmp = nameA.compareTo(nameB);
                  return cmp != 0 ? cmp : a.compareTo(b);
                });

              if (teamKeys.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      AppEmptyState(
                        icon: _scannedMissingOnly
                            ? Icons.document_scanner_outlined
                            : Icons.search_off_rounded,
                        title: _scannedMissingOnly
                            ? 'No scanned missing match your search'
                            : 'No stickers found',
                        subtitle: _scannedMissingOnly
                            ? 'Missing stickers appear here after a page scan'
                            : 'Try a different team code or sticker code',
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    4,
                    AppSpacing.page,
                    AppSpacing.section,
                  ),
                  itemCount: teamKeys.length,
                  itemBuilder: (context, i) {
                    final teamCode = teamKeys[i];
                    final stickers = grouped[teamCode]!;
                    final teamName = stickers.first.teamName;
                    final ownedCount = stickers.where((s) => s.isOwned).length;
                    final scannedCount =
                        stickers.where((s) => scanned.contains(s.code)).length;

                    final subtitle = _scannedMissingOnly
                        ? '$scannedCount scanned missing'
                        : '$ownedCount/${stickers.length} owned';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            key: ValueKey('$teamCode-$expandTeams-${query.search}'),
                            initiallyExpanded: expandTeams,
                            title: Text(
                              teamName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text('$teamCode · $subtitle'),
                            children: stickers
                                .map(
                                  (s) => _TeamStickerRow(
                                    key: ValueKey(s.code),
                                    sticker: s,
                                    isScannedMissing: scanned.contains(s.code),
                                    ref: ref,
                                    onChanged: _refresh,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(scannedMissingCodesProvider);
    ref.invalidate(scannedMissingByTeamProvider);
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(groupedStickersProvider);
    ref.invalidate(stickersProvider);
  }
}

class _TeamStickerRow extends StatelessWidget {
  const _TeamStickerRow({
    super.key,
    required this.sticker,
    required this.isScannedMissing,
    required this.ref,
    required this.onChanged,
  });

  final Sticker sticker;
  final bool isScannedMissing;
  final WidgetRef ref;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rarity = rarityFor(sticker);

    return _SwipeMarkTile(
      isScannedMissing: isScannedMissing,
      onMarkOwned: () async {
        await ref.read(collectionNotifierProvider.notifier).markOwned(sticker.code);
        await onChanged();
      },
      onMarkMissing: () async {
        await ref.read(collectionNotifierProvider.notifier).markMissing(sticker.code);
        await onChanged();
      },
      onRemoveScanned: () async {
        await ref.read(collectionNotifierProvider.notifier).markOwned(sticker.code);
        await onChanged();
      },
      child: ListTile(
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: sticker.code,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isScannedMissing ? AppTheme.missing : scheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
              if (rarity != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _RarityChip(rarity: rarity),
                  ),
                ),
              TextSpan(
                text: '  ${sticker.displayName}',
                style: TextStyle(
                  fontWeight: isScannedMissing ? FontWeight.w600 : FontWeight.w400,
                  color: isScannedMissing ? AppTheme.missing : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});

  final StickerRarity rarity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: rarity.chipBackground(scheme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rarity.chipLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: rarity.chipForeground(scheme),
          height: 1.2,
        ),
      ),
    );
  }
}

class _SwipeMarkTile extends StatefulWidget {
  const _SwipeMarkTile({
    required this.isScannedMissing,
    required this.onMarkMissing,
    required this.onMarkOwned,
    required this.onRemoveScanned,
    required this.child,
  });

  final bool isScannedMissing;
  final Future<void> Function() onMarkMissing;
  final Future<void> Function() onMarkOwned;
  final Future<void> Function() onRemoveScanned;
  final Widget child;

  @override
  State<_SwipeMarkTile> createState() => _SwipeMarkTileState();
}

class _SwipeMarkTileState extends State<_SwipeMarkTile> {
  static const _actionWidth = 88.0;

  double _dragOffset = 0;
  bool _busy = false;

  void _snapOpen({required bool left, required bool right}) {
    setState(() {
      if (left) {
        _dragOffset = -_actionWidth;
      } else if (right) {
        _dragOffset = _actionWidth;
      } else {
        _dragOffset = 0;
      }
    });
  }

  void _snapFromDrag() {
    if (_dragOffset <= -_actionWidth / 2) {
      _snapOpen(left: true, right: false);
    } else if (_dragOffset >= _actionWidth / 2) {
      _snapOpen(left: false, right: true);
    } else {
      _snapOpen(left: false, right: false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _dragOffset = 0;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                Material(
                  color: AppTheme.owned,
                  child: InkWell(
                    onTap: _busy ? null : () => _run(widget.onMarkOwned),
                    child: SizedBox(
                      width: _actionWidth,
                      height: kMinInteractiveDimension,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white, size: 22),
                          SizedBox(height: 2),
                          Text(
                            'Owned',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: AppTheme.missing,
                  child: InkWell(
                    onTap: _busy
                        ? null
                        : () => _run(
                              widget.isScannedMissing
                                  ? widget.onRemoveScanned
                                  : widget.onMarkMissing,
                            ),
                    child: SizedBox(
                      width: _actionWidth,
                      height: kMinInteractiveDimension,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isScannedMissing
                                ? Icons.delete_outline_rounded
                                : Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isScannedMissing ? 'Remove' : 'Missing',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _busy
                ? null
                : (details) {
                    setState(() {
                      _dragOffset = (_dragOffset + details.delta.dx)
                          .clamp(-_actionWidth, _actionWidth);
                    });
                  },
            onHorizontalDragEnd: _busy ? null : (_) => _snapFromDrag(),
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: ColoredBox(color: surface, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}
