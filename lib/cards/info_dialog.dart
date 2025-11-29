import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_card_models.dart';
import 'game_card_face.dart';
import 'card_effects.dart';

/// Shared EXP-to-next-level formula used across the app.
int expToNextLevel(int level) {
  // Same as store logic: (level + 1)^3
  return math.pow(level + 1, 3).toInt();
}

String _formatBig(double v) {
  if (v == 0) return '0';
  if (v.abs() >= 1e6 || v.abs() < 0.001) {
    return v.toStringAsExponential(2);
  }
  return v.toStringAsFixed(2);
}

/// Global card info dialog used everywhere (Decks, Collection, Upgrades, etc.).
///
/// Parameters:
/// - [canAddToDeck] + [onAddToDeck]:
///     show an "Add to Deck" button (Collection view).
/// - [canRemoveFromDeck] + [onRemoveFromDeck]:
///     show a "Remove from Deck" button (Deck view).
Future<void> showGlobalCardInfoDialog({
  required BuildContext context,
  required GameCard card,
  required OwnedCard owned,
  bool canAddToDeck = false,
  bool canRemoveFromDeck = false,
  VoidCallback? onAddToDeck,
  VoidCallback? onRemoveFromDeck,
}) async {
  final baseCost =
  CardEffects.baseCost(rank: card.rank, level: owned.level);
  final scalingFactor =
  CardEffects.costScalingFactor(level: owned.level);
  final int nextLevelExp = expToNextLevel(owned.level);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${card.name} (Lv ${owned.level})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Larger card image
            GameCardFace(
              card: card,
              width: 180,
              height: 260,
            ),
            const SizedBox(height: 12),

            // EXP info
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Experience: ${owned.experience} / $nextLevelExp',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 4),

            // Cost info
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Base cost: ${_formatBig(baseCost)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Scaling factor: ${_formatBig(scalingFactor)}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Long description
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                card.longDescription,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        if (canAddToDeck && onAddToDeck != null)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onAddToDeck();
            },
            child: const Text('Add to Deck'),
          ),
        if (canRemoveFromDeck && onRemoveFromDeck != null)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onRemoveFromDeck();
            },
            child: const Text('Remove from Deck'),
          ),
      ],
    ),
  );
}
