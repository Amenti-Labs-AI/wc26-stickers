import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/album_breakdown.dart';
import '../../core/app_info.dart';
import '../../core/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/sticker.dart';
import '../collection/collection_providers.dart';
import 'vendor_listing_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(collectionStatsProvider);
    final needAsync = ref.watch(scannedMissingByTeamProvider);
    final swapsAsync = ref.watch(swapsByTeamProvider);
    final parallelsAsync = ref.watch(parallelsByTeamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth / constraints.maxHeight > 1.35;
        final heroHeight = wide
            ? (constraints.maxHeight * 0.30).clamp(96.0, 132.0)
            : constraints.maxHeight * 0.30;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: statsAsync.when(
                data: (stats) => AlbumProgressHero(
                  stats: stats,
                  compact: wide,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.page),
                  child: Center(child: _HeroLoadingMark()),
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
                    parallelsAsync: parallelsAsync,
                    totalSwaps: stats.duplicates,
                    ownedCount: stats.owned,
                    totalStickers: stats.total,
                  ),
                  loading: () =>
                      const Center(child: _HeroLoadingMark(size: 56)),
                  error: (_, __) => _HomeSummaryBody(
                    needAsync: needAsync,
                    swapsAsync: swapsAsync,
                    parallelsAsync: parallelsAsync,
                    totalSwaps: 0,
                    ownedCount: 0,
                    totalStickers: 0,
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
    ref.invalidate(parallelsByTeamProvider);
    ref.invalidate(scannedMissingCodesProvider);
    ref.invalidate(parallelInventoryStatsProvider);
  }
}

class _HomeSummaryBody extends ConsumerWidget {
  const _HomeSummaryBody({
    required this.needAsync,
    required this.swapsAsync,
    required this.parallelsAsync,
    required this.totalSwaps,
    required this.ownedCount,
    required this.totalStickers,
  });

  final AsyncValue<Map<String, List<Sticker>>> needAsync;
  final AsyncValue<Map<String, List<Sticker>>> swapsAsync;
  final AsyncValue<Map<String, List<Sticker>>> parallelsAsync;
  final int totalSwaps;
  final int ownedCount;
  final int totalStickers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final need = needAsync.valueOrNull ?? const {};
    final swaps = swapsAsync.valueOrNull ?? const {};
    final parallels = parallelsAsync.valueOrNull ?? const {};
    final needBreakdown = AlbumNeedBreakdown.from(need);
    final swapBreakdown = AlbumSwapBreakdown.from(swaps);
    final parallelBreakdown = AlbumParallelBreakdown.from(parallels);
    final hasNeed = needBreakdown.total > 0;
    final hasSwapData = swapBreakdown.totalSwaps > 0 || totalSwaps > 0;
    final hasParallels = parallelBreakdown.totalParallels > 0;

    if (!hasNeed && !hasSwapData && !hasParallels) {
      final emptyCollection = ownedCount == 0 && totalStickers > 0;
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
                    emptyCollection
                        ? Icons.inventory_2_outlined
                        : Icons.check_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      emptyCollection
                          ? 'Empty collection — mark stickers owned in Collection as you get them.'
                          : 'No need list, swaps, or parallels yet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
        4,
        AppSpacing.page,
        AppSpacing.section,
      ),
      children: [
        if (hasNeed) ...[
          _HomeFilterRow(
            icon: Icons.bookmark_add_rounded,
            title: 'Need',
            subtitle: _needSubtitle(needBreakdown),
            accent: Theme.of(context).colorScheme.primary,
            onOpen: () =>
                openCollectionFilter(ref, StickerFilter.scannedMissing),
            onCopy: () {
              final text = formatNeedExportFromTeams(needBreakdown.allEntries);
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Need list copied')),
              );
            },
            onShare: () => SharePlus.instance.share(
              ShareParams(
                text: formatNeedExportFromTeams(needBreakdown.allEntries),
                subject: 'WC26 need list',
              ),
            ),
            onCheckListings: () {
              showVendorListingSheet(
                context: context,
                needStickers: needBreakdown.allEntries.expand((e) => e.value),
              );
            },
          ),
          if (hasSwapData || hasParallels) const SizedBox(height: 10),
        ],
        if (hasSwapData) ...[
          _HomeFilterRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Swaps',
            subtitle: _swapsSubtitle(swapBreakdown, totalSwaps),
            accent: AppTheme.owned,
            loading: swapsAsync.isLoading && swapsAsync.valueOrNull == null,
            onOpen: () => openCollectionFilter(ref, StickerFilter.duplicates),
            onCopy: swapBreakdown.totalSwaps == 0 && totalSwaps == 0
                ? null
                : () {
                    final text =
                        formatSwapsExportFromTeams(swapBreakdown.allEntries);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Swaps list copied')),
                    );
                  },
            onShare: swapBreakdown.totalSwaps == 0 && totalSwaps == 0
                ? null
                : () => SharePlus.instance.share(
                      ShareParams(
                        text: formatSwapsExportFromTeams(
                          swapBreakdown.allEntries,
                        ),
                        subject: 'WC26 swaps list',
                      ),
                    ),
          ),
          if (hasParallels) const SizedBox(height: 10),
        ],
        if (hasParallels)
          _HomeFilterRow(
            icon: Icons.layers_rounded,
            title: 'Parallels',
            subtitle: _parallelsSubtitle(parallelBreakdown),
            accent: Theme.of(context).colorScheme.secondary,
            loading:
                parallelsAsync.isLoading && parallelsAsync.valueOrNull == null,
            onOpen: () => openCollectionFilter(ref, StickerFilter.parallels),
            onCopy: () {
              final text =
                  formatParallelsExportFromTeams(parallelBreakdown.allEntries);
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Parallels list copied')),
              );
            },
            onShare: () => SharePlus.instance.share(
              ShareParams(
                text: formatParallelsExportFromTeams(
                  parallelBreakdown.allEntries,
                ),
                subject: 'WC26 parallels list',
              ),
            ),
          ),
      ],
    );
  }

  String _needSubtitle(AlbumNeedBreakdown b) {
    final parts = <String>[];
    if (b.nationalTeamStickerCount > 0) {
      parts.add(
        '${b.nationalTeamStickerCount} stickers · ${b.nationalTeamGroupCount} teams',
      );
    }
    if (b.fwcCount > 0) parts.add('${b.fwcCount} FWC');
    if (b.cocaColaCount > 0) parts.add('${b.cocaColaCount} CC');
    if (parts.isEmpty) return '${b.total} stickers';
    return parts.join(' · ');
  }

  String _swapsSubtitle(AlbumSwapBreakdown b, int totalSwaps) {
    final display = b.totalSwaps > 0 ? b.totalSwaps : totalSwaps;
    if (display == 0) return 'Mark duplicates in Collection';
    final parts = <String>['$display swaps'];
    if (b.nationalTeamGroupCount > 0) {
      parts.add('${b.nationalTeamGroupCount} teams');
    }
    if (b.fwcSwapCount > 0) parts.add('${b.fwcSwapCount} FWC');
    if (b.cocaColaSwapCount > 0) parts.add('${b.cocaColaSwapCount} CC');
    return parts.join(' · ');
  }

  String _parallelsSubtitle(AlbumParallelBreakdown b) {
    final parts = <String>['${b.totalParallels} parallels'];
    if (b.nationalTeamGroupCount > 0) {
      parts.add('${b.nationalTeamGroupCount} teams');
    }
    if (b.fwcParallelCount > 0) parts.add('${b.fwcParallelCount} FWC');
    if (b.cocaColaParallelCount > 0) {
      parts.add('${b.cocaColaParallelCount} CC');
    }
    return parts.join(' · ');
  }
}

class _HomeFilterRow extends StatelessWidget {
  const _HomeFilterRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onOpen,
    this.onCopy,
    this.onShare,
    this.onCheckListings,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onCheckListings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 28,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                if (onCheckListings != null)
                  TextButton.icon(
                    onPressed: onCheckListings,
                    icon: const Icon(Icons.storefront_rounded, size: 18),
                    label: const Text('Check listings'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 24),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumProgressHero extends StatelessWidget {
  const AlbumProgressHero({
    super.key,
    required this.stats,
    this.compact = false,
  });

  final CollectionStats stats;

  /// Wide / landscape: short bar, no side strips, smaller cup.
  final bool compact;

  static const _gold = Color(0xFFE8A317);

  @override
  Widget build(BuildContext context) {
    final pctLabel = stats.percent.round();

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.tight,
        bottom: 8,
        left: compact ? AppSpacing.page : 0,
        right: compact ? AppSpacing.page : 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideW = compact
              ? 0.0
              : (constraints.maxHeight * 0.22).clamp(56.0, 88.0);
          final cupW = compact
              ? (constraints.maxHeight * 0.85).clamp(72.0, 100.0)
              : (constraints.maxHeight * 0.42).clamp(110.0, 140.0);

          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 18 : 24),
              child: ColoredBox(
                color: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact)
                      _HeroSideStrip(
                        width: sideW,
                        asset: 'assets/branding/panini_cover_side_left.png',
                        fadeInnerRight: true,
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 14 : 12,
                          compact ? 10 : 14,
                          4,
                          compact ? 10 : 14,
                        ),
                        child: compact
                            ? _HeroTextCompact(
                                pctLabel: pctLabel,
                                owned: stats.owned,
                                total: stats.total,
                              )
                            : _HeroTextPortrait(
                                pctLabel: pctLabel,
                                owned: stats.owned,
                                total: stats.total,
                              ),
                      ),
                    ),
                    SizedBox(
                      width: cupW,
                      child: _HeroCup(compact: compact),
                    ),
                    if (!compact)
                      _HeroSideStrip(
                        width: sideW,
                        asset: 'assets/branding/panini_cover_side_right.png',
                        fadeInnerRight: false,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroTextPortrait extends StatelessWidget {
  const _HeroTextPortrait({
    required this.pctLabel,
    required this.owned,
    required this.total,
  });

  final int pctLabel;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: ColoredBox(
                color: const Color(0xFF1A1A1A),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/branding/wc26_logo.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppInfo.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF3D3D3D),
                      fontWeight: FontWeight.w700,
                      fontSize: 16.5,
                      height: 1.1,
                      letterSpacing: -0.25,
                    ),
              ),
            ),
          ],
        ),
        const Spacer(flex: 2),
        Text(
          '$pctLabel%',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AlbumProgressHero._gold,
                fontWeight: FontWeight.w800,
                height: 0.92,
                letterSpacing: -1.4,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '$owned of $total stickers',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF737373),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

class _HeroTextCompact extends StatelessWidget {
  const _HeroTextCompact({
    required this.pctLabel,
    required this.owned,
    required this.total,
  });

  final int pctLabel;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: const Color(0xFF1A1A1A),
            child: Padding(
              padding: const EdgeInsets.all(3.5),
              child: Image.asset(
                'assets/branding/wc26_logo.png',
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppInfo.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF3D3D3D),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$owned of $total stickers',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pctLabel%',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AlbumProgressHero._gold,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
        ),
      ],
    );
  }
}

class _HeroSideStrip extends StatelessWidget {
  const _HeroSideStrip({
    required this.width,
    required this.asset,
    required this.fadeInnerRight,
  });

  final double width;
  final String asset;
  final bool fadeInnerRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: fadeInnerRight
              ? const [
                  Colors.white,
                  Colors.white,
                  Color(0x00FFFFFF),
                ]
              : const [
                  Color(0x00FFFFFF),
                  Colors.white,
                  Colors.white,
                ],
          stops: fadeInnerRight
              ? const [0.0, 0.55, 1.0]
              : const [0.0, 0.45, 1.0],
        ).createShader(bounds),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: fadeInnerRight ? Alignment.centerRight : Alignment.centerLeft,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Gold arc spinner with a faint cup silhouette for Home loading states.
class _HeroLoadingMark extends StatefulWidget {
  const _HeroLoadingMark({this.size = 48});

  final double size;

  @override
  State<_HeroLoadingMark> createState() => _HeroLoadingMarkState();
}

class _HeroLoadingMarkState extends State<_HeroLoadingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              child!,
              Transform.rotate(
                angle: _spin.value * math.pi * 2,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: const _GoldArcPainter(),
                ),
              ),
            ],
          );
        },
        child: Opacity(
          opacity: 0.38,
          child: Image.asset(
            'assets/branding/wc26_cup.png',
            width: size * 0.42,
            height: size * 0.55,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _GoldArcPainter extends CustomPainter {
  const _GoldArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.08;
    final rect = Offset.zero & size;
    final inset = stroke * 1.1;
    final arcRect = Rect.fromLTRB(
      inset,
      inset,
      rect.width - inset,
      rect.height - inset,
    );
    final paint = Paint()
      ..color = AlbumProgressHero._gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 1.15, false, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldArcPainter oldDelegate) => false;
}

/// World Cup trophy — centerpiece like the Panini album cover.
class _HeroCup extends StatefulWidget {
  const _HeroCup({this.compact = false});

  final bool compact;

  @override
  State<_HeroCup> createState() => _HeroCupState();
}

class _HeroCupState extends State<_HeroCup> with TickerProviderStateMixin {
  /// Soft float + radial glow.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  /// Idle, then bottom→top shine + top crest flow.
  /// Prior 7605ms cycle slowed another 30% → 9887ms.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9887),
  )..repeat();

  late final Animation<double> _glow = CurvedAnimation(
    parent: _breathe,
    curve: Curves.easeInOut,
  );

  late final Animation<double> _lift = Tween<double>(begin: 0, end: -4).animate(
    CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
  );

  static const _shineSweepStart = 0.78;

  /// Continuous ease-out: starts quicker, progressively slows toward the crest
  /// (no piecewise kink). Exponent ~4.7 ≈ prior top slowdown +25%.
  static double _bandProgress(double linear) {
    final t = linear.clamp(0.0, 1.0);
    return 1.0 - math.pow(1.0 - t, 4.7).toDouble();
  }

  /// Soft crest bloom keyed to band height (also progressive).
  static double _topFlowStrength(double bandT) {
    if (bandT < 0.62) return 0.0;
    final local = ((bandT - 0.62) / 0.38).clamp(0.0, 1.0);
    // Ease in as the band arrives, then gently settle — no hard cut.
    if (local < 0.45) {
      return Curves.easeOut.transform(local / 0.45);
    }
    return 1.0 - Curves.easeInOut.transform((local - 0.45) / 0.55) * 0.55;
  }

  @override
  void dispose() {
    _breathe.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final cupW = compact ? 72.0 : 118.0;
    final cupH = compact ? 96.0 : 168.0;
    final peakAlpha = compact ? 0.55 : 0.75;
    final bandHalf = compact ? 0.30 : 0.24;

    return AnimatedBuilder(
      animation: Listenable.merge([_breathe, _shine]),
      builder: (context, child) {
        final glow = 0.10 + (_glow.value * 0.06);
        final t = _shine.value;
        var shineT = 0.0;
        var shineOpacity = 0.0;
        if (t >= _shineSweepStart) {
          shineT = (t - _shineSweepStart) / (1.0 - _shineSweepStart);
          // Longer, softer fade at the end so the crest can settle.
          if (shineT < 0.08) {
            shineOpacity = shineT / 0.08;
          } else if (shineT > 0.82) {
            shineOpacity = (1.0 - shineT) / 0.18;
          } else {
            shineOpacity = 1.0;
          }
          if (compact) shineOpacity *= 0.85;
        }
        final bandT = _bandProgress(shineT);
        final topFlow = _topFlowStrength(bandT);

        return Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, compact ? _lift.value * 0.5 : _lift.value),
            child: SizedBox(
              width: cupW,
              height: cupH,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AlbumProgressHero._gold.withValues(alpha: glow),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SizedBox(
                      width: compact ? 70 : 100,
                      height: compact ? 70 : 100,
                    ),
                  ),
                  child!,
                  if (shineOpacity > 0.01)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: shineOpacity,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              // Band travels bottom → top with continuous deceleration.
                              final centerY = 1.35 - bandT * 2.7;
                              return LinearGradient(
                                begin: Alignment(-0.15, centerY - bandHalf),
                                end: Alignment(0.15, centerY + bandHalf),
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: peakAlpha * 0.4),
                                  Colors.white.withValues(alpha: peakAlpha),
                                  AlbumProgressHero._gold
                                      .withValues(alpha: peakAlpha * 0.6),
                                  Colors.white.withValues(alpha: peakAlpha * 0.4),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.22, 0.45, 0.55, 0.78, 1.0],
                              ).createShader(bounds);
                            },
                            child: Image.asset(
                              'assets/branding/wc26_cup.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (topFlow > 0.01 && shineOpacity > 0.01)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (topFlow * shineOpacity).clamp(0.0, 1.0),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return RadialGradient(
                                center: const Alignment(0, -0.88),
                                radius: 0.42 + topFlow * 0.28,
                                colors: [
                                  Colors.white.withValues(alpha: peakAlpha),
                                  AlbumProgressHero._gold
                                      .withValues(alpha: peakAlpha * 0.75),
                                  AlbumProgressHero._gold
                                      .withValues(alpha: peakAlpha * 0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.28, 0.55, 1.0],
                              ).createShader(bounds);
                            },
                            child: Image.asset(
                              'assets/branding/wc26_cup.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/branding/wc26_cup.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }
}
