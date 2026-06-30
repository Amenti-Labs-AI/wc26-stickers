import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/parallel_kind.dart';
import '../../core/sticker_rarity.dart';
import '../../data/models/sticker.dart';
import 'sticker_edit_sheet.dart';

class TeamStickerGrid extends StatelessWidget {
  const TeamStickerGrid({
    super.key,
    required this.stickers,
    required this.scannedMissing,
    required this.ref,
    required this.onChanged,
  });

  final List<Sticker> stickers;
  final Set<String> scannedMissing;
  final WidgetRef ref;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: stickers.length,
        itemBuilder: (context, index) {
          final sticker = stickers[index];
          return StickerSlotCard(
            sticker: sticker,
            isNeed: sticker.isNeed(scannedMissing),
            onTap: () => showStickerEditSheet(
              context: context,
              ref: ref,
              sticker: sticker,
              scannedMissing: scannedMissing,
              onSaved: onChanged,
            ),
          );
        },
      ),
    );
  }
}

class StickerSlotCard extends StatelessWidget {
  const StickerSlotCard({
    super.key,
    required this.sticker,
    required this.isNeed,
    required this.onTap,
  });

  final Sticker sticker;
  final bool isNeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rarity = rarityFor(sticker);
    final ownedColor = AppTheme.owned;
    final needColor = AppTheme.missing;
    final bgColor = isNeed
        ? needColor.withValues(alpha: 0.14)
        : ownedColor.withValues(alpha: 0.14);
    final borderColor = isNeed ? needColor : ownedColor;
    final swaps = sticker.swapCount;
    final parallelKinds = sticker.topParallelKinds;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor.withValues(alpha: 0.65), width: 1.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    4,
                    8,
                    4,
                    parallelKinds.isNotEmpty ? 18 : 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${sticker.slotNumber}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isNeed ? needColor : ownedColor,
                              height: 1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sticker.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                      ),
                      if (rarity != null) ...[
                        const SizedBox(height: 4),
                        _RarityDot(rarity: rarity, scheme: scheme),
                      ],
                    ],
                  ),
                ),
              ),
              if (swaps > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: ownedColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '×$swaps',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                    ),
                  ),
                ),
              if (parallelKinds.isNotEmpty)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: _ParallelBanner(
                    kinds: parallelKinds,
                    counts: sticker.parallelCounts,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallelBanner extends StatelessWidget {
  const _ParallelBanner({
    required this.kinds,
    required this.counts,
  });

  final List<ParallelKind> kinds;
  final Map<ParallelKind, int> counts;

  static const _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final visible = kinds.reversed.take(_maxVisible).toList().reversed.toList();
    final overflow = kinds.length - visible.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final kind in visible) ...[
          _ParallelChip(
            kind: kind,
            count: counts[kind] ?? 0,
          ),
          if (kind != visible.last || overflow > 0) const SizedBox(width: 2),
        ],
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$overflow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }
}

class _ParallelChip extends StatelessWidget {
  const _ParallelChip({
    required this.kind,
    required this.count,
  });

  final ParallelKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 1 ? '×$count' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: kind.borderColor,
        borderRadius: BorderRadius.circular(4),
        border: kind == ParallelKind.black
            ? Border.all(color: Colors.white24, width: 0.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: kind.chipForeground(Theme.of(context).colorScheme),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _RarityDot extends StatelessWidget {
  const _RarityDot({required this.rarity, required this.scheme});

  final StickerRarity rarity;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: rarity.chipBackground(scheme),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rarity.chipLabel,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: rarity.chipForeground(scheme),
          height: 1.2,
        ),
      ),
    );
  }
}
