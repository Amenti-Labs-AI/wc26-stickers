import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/album_group.dart';
import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/sticker_search_query.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
import 'collection_providers.dart';
import 'collection_stats_sheet.dart';
import 'sticker_team_grid.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  StickerQuery _buildQuery(StickerFilter filter) {
    return StickerQuery(
      search: _searchController.text,
      filter: filter,
    );
  }

  bool _isCollectionFiltered(StickerFilter filter) {
    if (filter != StickerFilter.all) return true;
    return _searchController.text.trim().isNotEmpty;
  }

  String _emptyTitle(StickerFilter filter) {
    switch (filter) {
      case StickerFilter.scannedMissing:
        return 'No need stickers match your search';
      case StickerFilter.duplicates:
        return 'No swaps match your search';
      case StickerFilter.parallels:
        return 'No parallels match your search';
      case StickerFilter.all:
      case StickerFilter.owned:
      case StickerFilter.missing:
        return 'No stickers found';
    }
  }

  String _emptySubtitle(StickerFilter filter) {
    switch (filter) {
      case StickerFilter.scannedMissing:
        return 'Need stickers appear here after a page scan or manual mark';
      case StickerFilter.duplicates:
        return 'Mark duplicates in Collection to track swaps';
      case StickerFilter.parallels:
        return 'Add parallels from a sticker’s edit sheet';
      case StickerFilter.all:
      case StickerFilter.owned:
      case StickerFilter.missing:
        return 'Try a different team code or sticker code';
    }
  }

  String _teamSubtitle({
    required StickerFilter filter,
    required int ownedCount,
    required int needCount,
    required int stickerCount,
    required List<Sticker> stickers,
  }) {
    switch (filter) {
      case StickerFilter.scannedMissing:
        return '$needCount need';
      case StickerFilter.duplicates:
        final swaps =
            stickers.fold<int>(0, (sum, s) => sum + s.swapCount);
        return '$swaps swaps';
      case StickerFilter.parallels:
        final parallels =
            stickers.fold<int>(0, (sum, s) => sum + s.parallelSwapCount);
        return '$parallels parallels';
      case StickerFilter.all:
      case StickerFilter.owned:
      case StickerFilter.missing:
        return '$ownedCount/$stickerCount owned';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannedAsync = ref.watch(scannedMissingCodesProvider);
    final scanned = scannedAsync.valueOrNull ?? const {};
    final filter = ref.watch(collectionFilterProvider);
    final teamSort = ref.watch(collectionTeamSortProvider);
    final needAsync = ref.watch(scannedMissingByTeamProvider);
    final swapsAsync = ref.watch(swapsByTeamProvider);
    final parallelsAsync = ref.watch(parallelsByTeamProvider);
    final hasNeed = (needAsync.valueOrNull?.isNotEmpty ?? false) ||
        scanned.isNotEmpty;
    final hasSwaps = swapsAsync.valueOrNull?.isNotEmpty ?? false;
    final hasParallels = parallelsAsync.valueOrNull?.isNotEmpty ?? false;

    // Drop unavailable filters if Home deep-linked to an empty set.
    if (filter == StickerFilter.scannedMissing && !hasNeed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(collectionFilterProvider) == StickerFilter.scannedMissing) {
          ref.read(collectionFilterProvider.notifier).state = StickerFilter.all;
        }
      });
    } else if (filter == StickerFilter.duplicates && !hasSwaps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(collectionFilterProvider) == StickerFilter.duplicates) {
          ref.read(collectionFilterProvider.notifier).state = StickerFilter.all;
        }
      });
    } else if (filter == StickerFilter.parallels && !hasParallels) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(collectionFilterProvider) == StickerFilter.parallels) {
          ref.read(collectionFilterProvider.notifier).state = StickerFilter.all;
        }
      });
    }

    final activeFilter = switch (filter) {
      StickerFilter.scannedMissing when !hasNeed => StickerFilter.all,
      StickerFilter.duplicates when !hasSwaps => StickerFilter.all,
      StickerFilter.parallels when !hasParallels => StickerFilter.all,
      _ => filter,
    };

    final query = _buildQuery(activeFilter);
    final expandTeams = _isCollectionFiltered(activeFilter);
    final groupedAsync = ref.watch(groupedStickersProvider(query));

    final segments = <ButtonSegment<StickerFilter>>[
      const ButtonSegment(
        value: StickerFilter.all,
        label: Text('All'),
        icon: Icon(Icons.grid_view_rounded, size: 18),
      ),
      if (hasNeed)
        const ButtonSegment(
          value: StickerFilter.scannedMissing,
          label: Text('Need'),
          icon: Icon(Icons.bookmark_add_rounded, size: 18),
        ),
      if (hasSwaps)
        const ButtonSegment(
          value: StickerFilter.duplicates,
          label: Text('Swaps'),
          icon: Icon(Icons.swap_horiz_rounded, size: 18),
        ),
      if (hasParallels)
        const ButtonSegment(
          value: StickerFilter.parallels,
          label: Text('Parallels'),
          icon: Icon(Icons.layers_rounded, size: 18),
        ),
    ];

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
                decoration: InputDecoration(
                  hintText: 'Team code (BRA)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  counterText: '',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {});
                          },
                        ),
                      PopupMenuButton<CollectionTeamSort>(
                        tooltip: 'Sort teams',
                        initialValue: teamSort,
                        onSelected: (value) {
                          ref.read(collectionTeamSortProvider.notifier).state =
                              value;
                        },
                        itemBuilder: (context) => [
                          CheckedPopupMenuItem(
                            value: CollectionTeamSort.albumOrder,
                            checked: teamSort == CollectionTeamSort.albumOrder,
                            child: const Text('Album order'),
                          ),
                          CheckedPopupMenuItem(
                            value: CollectionTeamSort.alphabetical,
                            checked:
                                teamSort == CollectionTeamSort.alphabetical,
                            child: const Text('A–Z by team'),
                          ),
                        ],
                        icon: Icon(
                          teamSort == CollectionTeamSort.alphabetical
                              ? Icons.sort_by_alpha_rounded
                              : Icons.sort_rounded,
                        ),
                      ),
                    ],
                  ),
                  suffixIconConstraints: const BoxConstraints(minHeight: 48),
                ),
                maxLength: 3,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                inputFormatters: const [TeamCodeSearchFormatter(maxLength: 3)],
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              if (segments.length > 1) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<StickerFilter>(
                    segments: segments,
                    selected: {activeFilter},
                    onSelectionChanged: (s) {
                      ref.read(collectionFilterProvider.notifier).state =
                          s.first;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (activeFilter == StickerFilter.all)
          CollectionStatsEntry(
            onTap: () => showCollectionStatsSheet(context: context, ref: ref),
          ),
        Expanded(
          child: groupedAsync.when(
            data: (grouped) {
              final scanned = scannedAsync.valueOrNull ?? const {};
              final teamKeys = grouped.keys.toList()
                ..sort((a, b) {
                  final left = grouped[a]!.first;
                  final right = grouped[b]!.first;
                  return switch (teamSort) {
                    CollectionTeamSort.albumOrder =>
                      compareStickersByAlbumOrder(left, right),
                    CollectionTeamSort.alphabetical =>
                      compareStickersByTeamName(left, right),
                  };
                });

              if (teamKeys.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      AppEmptyState(
                        icon: activeFilter == StickerFilter.scannedMissing
                            ? Icons.bookmark_add_rounded
                            : activeFilter == StickerFilter.duplicates
                                ? Icons.swap_horiz_rounded
                                : activeFilter == StickerFilter.parallels
                                    ? Icons.layers_rounded
                                    : Icons.search_off_rounded,
                        title: _emptyTitle(activeFilter),
                        subtitle: _emptySubtitle(activeFilter),
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
                    final teamName = stickers.first.teamSectionTitle;
                    final ownedCount =
                        stickers.where((s) => !s.isNeed(scanned)).length;
                    final needCount =
                        stickers.where((s) => s.isNeed(scanned)).length;

                    final subtitle = _teamSubtitle(
                      filter: activeFilter,
                      ownedCount: ownedCount,
                      needCount: needCount,
                      stickerCount: stickers.length,
                      stickers: stickers,
                    );
                    final albumPage = albumPageNumber(stickers);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            key: ValueKey(
                              '$teamCode-$expandTeams-${query.search}-$activeFilter',
                            ),
                            initiallyExpanded: expandTeams,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    teamName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                if (albumPage != null) ...[
                                  const SizedBox(width: 8),
                                  _AlbumPageBanner(page: albumPage),
                                ],
                              ],
                            ),
                            subtitle: Text('$teamCode · $subtitle'),
                            children: [
                              TeamStickerGrid(
                                stickers: stickers,
                                scannedMissing: scanned,
                                ref: ref,
                                onChanged: _refresh,
                              ),
                            ],
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
    ref.invalidate(swapsByTeamProvider);
    ref.invalidate(parallelsByTeamProvider);
    ref.invalidate(teamCollectionStatsProvider);
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(parallelInventoryStatsProvider);
    ref.invalidate(groupedStickersProvider);
    ref.invalidate(stickersProvider);
  }
}

class _AlbumPageBanner extends StatelessWidget {
  const _AlbumPageBanner({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Page $page',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
      ),
    );
  }
}
