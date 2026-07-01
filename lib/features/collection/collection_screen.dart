import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/sticker_search_query.dart';
import '../../data/database/app_database.dart';
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
  bool _needOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  StickerQuery _buildQuery({required bool hasNeed}) {
    final useNeedFilter = _needOnly && hasNeed;
    return StickerQuery(
      search: _searchController.text,
      filter: useNeedFilter ? StickerFilter.scannedMissing : StickerFilter.all,
    );
  }

  bool _isCollectionFiltered({required bool hasNeed}) {
    if (_needOnly && hasNeed) return true;
    return _searchController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scannedAsync = ref.watch(scannedMissingCodesProvider);
    final scanned = scannedAsync.valueOrNull ?? const {};
    final hasNeed = scanned.isNotEmpty;

    if (!hasNeed && _needOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _needOnly) {
          setState(() => _needOnly = false);
        }
      });
    }

    final query = _buildQuery(hasNeed: hasNeed);
    final expandTeams = _isCollectionFiltered(hasNeed: hasNeed);
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
                decoration: InputDecoration(
                  hintText: 'Team code (BRA)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  counterText: '',
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                maxLength: 3,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                inputFormatters: const [TeamCodeSearchFormatter(maxLength: 3)],
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              if (hasNeed) ...[
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
                      label: Text('Need'),
                      icon: Icon(Icons.checklist_rounded, size: 18),
                    ),
                  ],
                  selected: {_needOnly},
                  onSelectionChanged: (s) => setState(() => _needOnly = s.first),
                ),
              ],
            ],
          ),
        ),
        if (!_needOnly)
          CollectionStatsEntry(
            onTap: () => showCollectionStatsSheet(context: context, ref: ref),
          ),
        Expanded(
          child: groupedAsync.when(
            data: (grouped) {
              final scanned = scannedAsync.valueOrNull ?? const {};
              final teamKeys = grouped.keys.toList()
                ..sort((a, b) {
                  final nameA = grouped[a]!.first.teamSectionTitle;
                  final nameB = grouped[b]!.first.teamSectionTitle;
                  final cmp = nameA.compareTo(nameB);
                  return cmp != 0 ? cmp : a.compareTo(b);
                });

              if (teamKeys.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      AppEmptyState(
                        icon: _needOnly
                            ? Icons.checklist_rounded
                            : Icons.search_off_rounded,
                        title: _needOnly
                            ? 'No need stickers match your search'
                            : 'No stickers found',
                        subtitle: _needOnly
                            ? 'Need stickers appear here after a page scan or manual mark'
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
                    final teamName = stickers.first.teamSectionTitle;
                    final ownedCount = stickers
                        .where((s) => !s.isNeed(scanned))
                        .length;
                    final needCount =
                        stickers.where((s) => s.isNeed(scanned)).length;

                    final subtitle = _needOnly
                        ? '$needCount need'
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
