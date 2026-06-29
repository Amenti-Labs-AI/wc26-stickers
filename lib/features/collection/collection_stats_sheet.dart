import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/album_group.dart';
import '../../core/app_theme.dart';
import 'collection_providers.dart';

const _topChartLimit = 12;

Future<void> showCollectionStatsSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.88;
      return SizedBox(
        height: height,
        child: const _CollectionStatsSheet(),
      );
    },
  ).whenComplete(() => FocusManager.instance.primaryFocus?.unfocus());
}

class _CollectionStatsSheet extends ConsumerWidget {
  const _CollectionStatsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teamCollectionStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load stats: $e'),
        ),
      ),
      data: (stats) {
        final groupStats = AlbumGroupStats.fromTeamStats(stats);
        return DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection stats',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Tap a chart bar for team details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: Theme.of(context).textTheme.labelLarge,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Swaps'),
                Tab(text: 'Need'),
                Tab(text: 'Complete'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(stats: stats, groupStats: groupStats),
                  _MetricBarTab(
                    stats: stats,
                    groupStats: groupStats,
                    metric: _ChartMetric.swaps,
                  ),
                  _MetricBarTab(
                    stats: stats,
                    groupStats: groupStats,
                    metric: _ChartMetric.need,
                  ),
                  _CompletionTab(stats: stats, groupStats: groupStats),
                ],
              ),
            ),
          ],
        ),
        );
      },
    );
  }
}

enum _ChartMetric { swaps, need }

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.stats,
    required this.groupStats,
  });

  final List<TeamCollectionStat> stats;
  final AlbumGroupStats groupStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owned = stats.fold<int>(0, (sum, s) => sum + s.owned);
    final need = stats.fold<int>(0, (sum, s) => sum + s.need);
    final swaps = stats.fold<int>(0, (sum, s) => sum + s.swaps);
    final total = stats.fold<int>(0, (sum, s) => sum + s.total);
    final completeTeams = groupStats.nationalTeamsComplete;
    final nationalTeamCount = groupStats.nationalTeamCount;

    final pieSections = <PieChartSectionData>[];
    if (owned > 0) {
      pieSections.add(
        PieChartSectionData(
          value: owned.toDouble(),
          color: AppTheme.owned,
          title: '${_pct(owned, total)}%',
          radius: 58,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }
    if (need > 0) {
      pieSections.add(
        PieChartSectionData(
          value: need.toDouble(),
          color: AppTheme.missing,
          title: '${_pct(need, total)}%',
          radius: 52,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SizedBox(
          height: 220,
          child: pieSections.isEmpty
              ? Center(
                  child: Text(
                    'No collection data yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 42,
                    sections: pieSections,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {},
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LegendChip(color: AppTheme.owned, label: 'Owned ($owned)'),
            _LegendChip(color: AppTheme.missing, label: 'Need ($need)'),
            _LegendChip(color: scheme.tertiary, label: 'Swaps ($swaps)'),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Album progress',
                value: '${_pct(owned, total)}%',
                subtitle: '$owned / $total stickers',
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Teams complete',
                value: '$completeTeams',
                subtitle: 'of $nationalTeamCount teams',
                color: AppTheme.owned,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          label: 'Total swaps',
          value: '$swaps',
          subtitle: 'extra copies across national teams',
          color: scheme.tertiary,
        ),
      ],
    );
  }
}

class _MetricBarTab extends StatelessWidget {
  const _MetricBarTab({
    required this.stats,
    required this.groupStats,
    required this.metric,
  });

  final List<TeamCollectionStat> stats;
  final AlbumGroupStats groupStats;
  final _ChartMetric metric;

  @override
  Widget build(BuildContext context) {
    final national = AlbumGroupStats.nationalTeamsOnly(stats);
    final filtered = national.where((s) => _value(s) > 0).toList()
      ..sort((a, b) => _value(b).compareTo(_value(a)));
    final top = filtered.take(_topChartLimit).toList();
    final nationalTotal = filtered.fold<double>(0, (sum, s) => sum + _value(s));
    final color = metric == _ChartMetric.swaps ? AppTheme.owned : AppTheme.missing;
    final title =
        metric == _ChartMetric.swaps ? 'Swaps by team' : 'Need by team';
    final empty =
        metric == _ChartMetric.swaps ? 'No swaps yet' : 'No need stickers';
    final sectionSwaps = metric == _ChartMetric.swaps
        ? groupStats.fwcSwaps + groupStats.cocaColaSwaps
        : 0.0;
    final sectionNeed = metric == _ChartMetric.need
        ? groupStats.fwcNeed + groupStats.cocaColaNeed
        : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _ChartHeader(
          title: title,
          subtitle: nationalTotal > 0
              ? '${nationalTotal.toStringAsFixed(0)} national teams · top ${top.length}'
              : null,
        ),
        const SizedBox(height: 16),
        if (top.isEmpty)
          _EmptyChart(message: empty)
        else
          _TeamBarChart(
            teams: top,
            valueFor: _value,
            barColor: color,
            maxY: top.map(_value).reduce((a, b) => a > b ? a : b).toDouble(),
            valueLabel: (v) => v.toStringAsFixed(0),
          ),
        if (filtered.length > _topChartLimit) ...[
          const SizedBox(height: 12),
          Text(
            '+ ${filtered.length - _topChartLimit} more national teams',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        if (metric == _ChartMetric.swaps &&
            (groupStats.fwcSwaps > 0 || groupStats.cocaColaSwaps > 0)) ...[
          const SizedBox(height: 24),
          _ChartHeader(
            title: 'Album sections',
            subtitle: '${sectionSwaps.toStringAsFixed(0)} swaps',
          ),
          const SizedBox(height: 12),
          if (groupStats.fwcSwaps > 0)
            _SectionStatCard(
              title: 'FIFA World Cup',
              value: '${groupStats.fwcSwaps} swaps',
              color: Theme.of(context).colorScheme.tertiary,
            ),
          if (groupStats.cocaColaSwaps > 0) ...[
            if (groupStats.fwcSwaps > 0) const SizedBox(height: 8),
            _SectionStatCard(
              title: 'Coca-Cola',
              value: '${groupStats.cocaColaSwaps} swaps',
              color: AppTheme.missing,
            ),
          ],
        ],
        if (metric == _ChartMetric.need &&
            (groupStats.fwcNeed > 0 || groupStats.cocaColaNeed > 0)) ...[
          const SizedBox(height: 24),
          _ChartHeader(
            title: 'Album sections',
            subtitle: '$sectionNeed stickers',
          ),
          const SizedBox(height: 12),
          if (groupStats.fwcNeed > 0)
            _SectionStatCard(
              title: 'FIFA World Cup',
              value: '${groupStats.fwcNeed} need',
              color: Theme.of(context).colorScheme.tertiary,
            ),
          if (groupStats.cocaColaNeed > 0) ...[
            if (groupStats.fwcNeed > 0) const SizedBox(height: 8),
            _SectionStatCard(
              title: 'Coca-Cola',
              value: '${groupStats.cocaColaNeed} need',
              color: AppTheme.missing,
            ),
          ],
        ],
      ],
    );
  }

  double _value(TeamCollectionStat s) =>
      (metric == _ChartMetric.swaps ? s.swaps : s.need).toDouble();
}

class _CompletionTab extends StatelessWidget {
  const _CompletionTab({
    required this.stats,
    required this.groupStats,
  });

  final List<TeamCollectionStat> stats;
  final AlbumGroupStats groupStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final national = AlbumGroupStats.nationalTeamsOnly(stats);
    final completed = national.where((s) => s.need == 0 && s.total > 0).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final incomplete = national.where((s) => s.need > 0).toList()
      ..sort((a, b) {
        final cmp = a.completionPercent.compareTo(b.completionPercent);
        return cmp != 0 ? cmp : a.label.compareTo(b.label);
      });
    final lowest = incomplete.take(_topChartLimit).toList();
    final avg = national.isEmpty
        ? 0.0
        : national.map((s) => s.completionPercent).reduce((a, b) => a + b) /
            national.length;
    final fwc = _statForCode(stats, fwcTeamCode);
    final cc = _statForCode(stats, cocaColaTeamCode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _ChartHeader(
          title: 'Teams complete',
          subtitle:
              '${groupStats.nationalTeamsComplete} of ${groupStats.nationalTeamCount} national teams',
        ),
        const SizedBox(height: 12),
        if (completed.isEmpty)
          Text(
            'No national teams complete yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: completed
                .map(
                  (team) => _CompletedTeamChip(
                    teamCode: team.teamCode,
                    label: team.label,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 24),
        _ChartHeader(
          title: 'Lowest completion',
          subtitle:
              'Avg ${avg.toStringAsFixed(0)}% · ${groupStats.nationalTeamCount} national teams',
        ),
        const SizedBox(height: 16),
        if (lowest.isEmpty)
          const _EmptyChart(message: 'All national teams complete')
        else
          _TeamBarChart(
            teams: lowest,
            valueFor: (s) => s.completionPercent,
            barColor: scheme.primary,
            maxY: 100,
            valueLabel: (v) => '${v.toStringAsFixed(0)}%',
          ),
        if (incomplete.length > _topChartLimit) ...[
          const SizedBox(height: 12),
          Text(
            '+ ${incomplete.length - _topChartLimit} more incomplete teams',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        if (fwc != null || cc != null) ...[
          const SizedBox(height: 24),
          const _ChartHeader(title: 'Album sections'),
          const SizedBox(height: 12),
          if (fwc != null)
            _SectionStatCard(
              title: 'FIFA World Cup',
              value: _completionLabel(fwc),
              color: scheme.tertiary,
            ),
          if (cc != null) ...[
            if (fwc != null) const SizedBox(height: 8),
            _SectionStatCard(
              title: 'Coca-Cola',
              value: _completionLabel(cc),
              color: AppTheme.missing,
            ),
          ],
        ],
      ],
    );
  }

  TeamCollectionStat? _statForCode(List<TeamCollectionStat> stats, String code) {
    for (final s in stats) {
      if (s.teamCode == code) return s;
    }
    return null;
  }

  String _completionLabel(TeamCollectionStat stat) {
    if (stat.need == 0 && stat.total > 0) return 'Complete · ${stat.total}/${stat.total}';
    return '${stat.owned}/${stat.total} (${stat.completionPercent.toStringAsFixed(0)}%)';
  }
}

class _CompletedTeamChip extends StatelessWidget {
  const _CompletedTeamChip({
    required this.teamCode,
    required this.label,
  });

  final String teamCode;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Chip(
        label: Text(
          teamCode,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        backgroundColor: AppTheme.owned.withValues(alpha: 0.14),
        side: BorderSide(color: AppTheme.owned.withValues(alpha: 0.35)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TeamBarChart extends StatelessWidget {
  const _TeamBarChart({
    required this.teams,
    required this.valueFor,
    required this.barColor,
    required this.maxY,
    required this.valueLabel,
  });

  final List<TeamCollectionStat> teams;
  final double Function(TeamCollectionStat) valueFor;
  final Color barColor;
  final double maxY;
  final String Function(double) valueLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;

    return AspectRatio(
      aspectRatio: 1.1,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < teams.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: valueFor(teams[i]),
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        barColor.withValues(alpha: 0.75),
                        barColor,
                      ],
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: chartMaxY / 4,
                getTitlesWidget: (value, meta) => Text(
                  valueLabel(value),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= teams.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      teams[i].teamCode,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final team = teams[group.x];
                return BarTooltipItem(
                  '${team.label}\n${team.teamCode}: ${valueLabel(rod.toY)}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _SectionStatCard extends StatelessWidget {
  const _SectionStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _pct(int part, int total) {
  if (total == 0) return '0';
  return ((part / total) * 100).toStringAsFixed(0);
}
