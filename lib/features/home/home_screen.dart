import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/album_breakdown.dart';
import '../../core/app_theme.dart';
import '../../core/missing_stickers_codec.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
import '../collection/collection_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(collectionStatsProvider);
    final needAsync = ref.watch(scannedMissingByTeamProvider);
    final swapsAsync = ref.watch(swapsByTeamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxHeight * 0.42;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: statsAsync.when(
                data: (stats) => AlbumProgressHero(stats: stats),
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: statsAsync.when(
                  data: (stats) => _HomeSummaryBody(
                    needAsync: needAsync,
                    swapsAsync: swapsAsync,
                    totalSwaps: stats.duplicates,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _HomeSummaryBody(
                    needAsync: needAsync,
                    swapsAsync: swapsAsync,
                    totalSwaps: 0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(collectionStatsProvider);
    ref.invalidate(scannedMissingByTeamProvider);
    ref.invalidate(swapsByTeamProvider);
    ref.invalidate(scannedMissingCodesProvider);
  }
}

class _HomeSummaryBody extends StatelessWidget {
  const _HomeSummaryBody({
    required this.needAsync,
    required this.swapsAsync,
    required this.totalSwaps,
  });

  final AsyncValue<Map<String, List<Sticker>>> needAsync;
  final AsyncValue<Map<String, List<Sticker>>> swapsAsync;
  final int totalSwaps;

  @override
  Widget build(BuildContext context) {
    final need = needAsync.valueOrNull ?? const {};
    final swaps = swapsAsync.valueOrNull ?? const {};
    final needBreakdown = AlbumNeedBreakdown.from(need);
    final swapBreakdown = AlbumSwapBreakdown.from(swaps);
    final hasNeed = needBreakdown.total > 0;
    final hasSwapData = swapBreakdown.totalSwaps > 0 || totalSwaps > 0;
    final showSwapsSection = hasNeed || hasSwapData;

    if (!hasNeed && !hasSwapData) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.tight,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Scan album pages to capture need stickers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.section,
      ),
      children: [
        if (hasNeed) _NeedSummarySection(breakdown: needBreakdown),
        if (hasNeed && showSwapsSection) const SizedBox(height: 20),
        if (showSwapsSection)
          _SwapsSummarySection(
            breakdown: swapBreakdown,
            totalSwaps: totalSwaps,
            loading: swapsAsync.isLoading && swapsAsync.valueOrNull == null,
          ),
      ],
    );
  }
}

class AlbumProgressHero extends StatelessWidget {
  const AlbumProgressHero({super.key, required this.stats});

  final CollectionStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = stats.total == 0 ? 0.0 : stats.owned / stats.total;
    final pctLabel = stats.percent.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.tight,
        AppSpacing.page,
        8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          Color.lerp(scheme.primary, const Color(0xFF0D2B6B), 0.55)!,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40,
                    right: -30,
                    child: _DecorOrb(
                      size: 160,
                      color: scheme.onPrimary.withValues(alpha: 0.07),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -40,
                    child: _DecorOrb(
                      size: 200,
                      color: scheme.tertiary.withValues(alpha: 0.12),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: constraints.maxHeight * 0.38,
                    child: _PitchLines(color: scheme.onPrimary.withValues(alpha: 0.06)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sports_soccer_rounded,
                              color: scheme.onPrimary.withValues(alpha: 0.75),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Album progress',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.onPrimary.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              'WC26',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.tertiary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        Text(
                          '$pctLabel%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w800,
                                height: 0.95,
                                letterSpacing: -1.5,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${stats.owned} of ${stats.total} stickers',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onPrimary.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const Spacer(),
                        _AlbumProgressBar(progress: pct, scheme: scheme),
                        const SizedBox(height: 16),
                        _HeroMetricsRow(
                          need: stats.scannedMissing,
                          swaps: stats.duplicates,
                          scheme: scheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DecorOrb extends StatelessWidget {
  const _DecorOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PitchLines extends StatelessWidget {
  const _PitchLines({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 80),
      painter: _PitchLinesPainter(color: color),
    );
  }
}

class _PitchLinesPainter extends CustomPainter {
  _PitchLinesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
    canvas.drawCircle(Offset(size.width / 2, midY), 28, paint);
    canvas.drawLine(Offset(0, 8), Offset(0, size.height - 8), paint);
    canvas.drawLine(
      Offset(size.width, 8),
      Offset(size.width, size.height - 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AlbumProgressBar extends StatelessWidget {
  const _AlbumProgressBar({required this.progress, required this.scheme});

  final double progress;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.onPrimary.withValues(alpha: 0.14)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.tertiary,
                      Color.lerp(scheme.tertiary, scheme.onPrimary, 0.35)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.tertiary.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricsRow extends StatelessWidget {
  const _HeroMetricsRow({
    required this.need,
    required this.swaps,
    required this.scheme,
  });

  final int need;
  final int swaps;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.onPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.18)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetricCell(
                    label: 'Need',
                    value: '$need',
                    scheme: scheme,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: scheme.onPrimary.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _HeroMetricCell(
                    label: 'Swaps',
                    value: '$swaps',
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMetricCell extends StatelessWidget {
  const _HeroMetricCell({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimary.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _NeedSummarySection extends StatelessWidget {
  const _NeedSummarySection({required this.breakdown});

  final AlbumNeedBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exportText = _buildNeedExportText(breakdown.allEntries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummarySectionHeader(
          title: 'Need',
          onCopy: () {
            Clipboard.setData(ClipboardData(text: exportText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Need list copied')),
            );
          },
          onShare: () => _shareNeedBackup(context),
        ),
        if (breakdown.nationalTeamStickerCount > 0)
          _SummaryStatBanner(
            icon: Icons.groups_rounded,
            title: 'Teams',
            line: '${breakdown.nationalTeamStickerCount} stickers · '
                '${breakdown.nationalTeamGroupCount} teams',
            accent: scheme.primary,
            surfaceTint: scheme.primaryContainer.withValues(alpha: 0.35),
          ),
        if (breakdown.fwcCount > 0) ...[
          const SizedBox(height: 8),
          _SummaryStatBanner(
            icon: Icons.emoji_events_rounded,
            title: 'FIFA World Cup',
            line: '${breakdown.fwcCount} stickers',
            accent: scheme.tertiary,
            surfaceTint: scheme.tertiaryContainer.withValues(alpha: 0.45),
          ),
        ],
        if (breakdown.cocaColaCount > 0) ...[
          const SizedBox(height: 8),
          _SummaryStatBanner(
            icon: Icons.local_drink_rounded,
            title: 'Coca-Cola',
            line: '${breakdown.cocaColaCount} stickers',
            accent: AppTheme.missing,
            surfaceTint: scheme.errorContainer.withValues(alpha: 0.35),
          ),
        ],
      ],
    );
  }

  String _buildNeedExportText(List<MapEntry<String, List<Sticker>>> teams) {
    final buf = StringBuffer('Need:\n');
    for (final entry in teams) {
      final codes = entry.value.map((s) => s.code).join(', ');
      buf.writeln('${entry.key}: $codes');
    }
    return buf.toString().trim();
  }

  Future<void> _shareNeedBackup(BuildContext context) async {
    final json = await AppDatabase.instance.exportMissingStickersJson();
    final code = encodeMissingStickers(json);
    await Share.share(code, subject: 'WC26 need stickers backup');
  }
}

class _SwapsSummarySection extends StatelessWidget {
  const _SwapsSummarySection({
    required this.breakdown,
    required this.totalSwaps,
    this.loading = false,
  });

  final AlbumSwapBreakdown breakdown;
  final int totalSwaps;
  final bool loading;

  bool get _hasCategoryBanners =>
      breakdown.nationalTeamSwapCount > 0 ||
      breakdown.fwcSwapCount > 0 ||
      breakdown.cocaColaSwapCount > 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exportText = _buildSwapsExportText(breakdown.allEntries);
    final displayTotal = breakdown.totalSwaps > 0 ? breakdown.totalSwaps : totalSwaps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummarySectionHeader(
          title: 'Swaps',
          onCopy: displayTotal == 0
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: exportText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Swaps list copied')),
                  );
                },
          onShare: displayTotal == 0
              ? null
              : () => Share.share(
                    exportText,
                    subject: 'WC26 swaps list',
                  ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_hasCategoryBanners) ...[
          if (breakdown.nationalTeamSwapCount > 0)
            _SummaryStatBanner(
              icon: Icons.groups_rounded,
              title: 'Teams',
              line: '${breakdown.nationalTeamSwapCount} swaps · '
                  '${breakdown.nationalTeamGroupCount} teams',
              accent: AppTheme.owned,
              surfaceTint: scheme.primaryContainer.withValues(alpha: 0.28),
            ),
          if (breakdown.fwcSwapCount > 0) ...[
            const SizedBox(height: 8),
            _SummaryStatBanner(
              icon: Icons.emoji_events_rounded,
              title: 'FIFA World Cup',
              line: '${breakdown.fwcSwapCount} swaps',
              accent: scheme.tertiary,
              surfaceTint: scheme.tertiaryContainer.withValues(alpha: 0.45),
            ),
          ],
          if (breakdown.cocaColaSwapCount > 0) ...[
            const SizedBox(height: 8),
            _SummaryStatBanner(
              icon: Icons.local_drink_rounded,
              title: 'Coca-Cola',
              line: '${breakdown.cocaColaSwapCount} swaps',
              accent: AppTheme.missing,
              surfaceTint: scheme.errorContainer.withValues(alpha: 0.35),
            ),
          ],
        ] else
          _SummaryStatBanner(
            icon: Icons.swap_horiz_rounded,
            title: displayTotal == 0 ? 'No swaps yet' : 'Total',
            line: displayTotal == 0
                ? 'Mark duplicates in Collection'
                : '$displayTotal swaps',
            accent: displayTotal == 0 ? scheme.onSurfaceVariant : AppTheme.owned,
            surfaceTint: scheme.surfaceContainerHigh,
          ),
      ],
    );
  }

  String _buildSwapsExportText(List<MapEntry<String, List<Sticker>>> teams) {
    final buf = StringBuffer('Swaps:\n');
    for (final entry in teams) {
      final parts = entry.value.map((s) => '${s.code}×${s.swapCount}').join(', ');
      buf.writeln('${entry.key}: $parts');
    }
    return buf.toString().trim();
  }
}

class _SummarySectionHeader extends StatelessWidget {
  const _SummarySectionHeader({
    required this.title,
    required this.onCopy,
    required this.onShare,
  });

  final String title;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatBanner extends StatelessWidget {
  const _SummaryStatBanner({
    required this.icon,
    required this.title,
    required this.line,
    required this.accent,
    required this.surfaceTint,
  });

  final IconData icon;
  final String title;
  final String line;
  final Color accent;
  final Color surfaceTint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
