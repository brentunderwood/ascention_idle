import 'package:flutter/material.dart';
import 'game_card_models.dart';

/// Reusable widget that renders a card using its background + art.
/// Any time you want to show a GameCard, use this so the layering
/// is always consistent.
class GameCardFace extends StatelessWidget {
  final GameCard card;

  /// Target size for the rendered card.
  final double width;
  final double height;

  /// Relative size of the art image compared to the whole card.
  /// 1.0 = fill in that dimension, 0.5 = half the card, etc.
  final double artWidthFactor;
  final double artHeightFactor;

  /// Relative offsets for the art, as a fraction of card size.
  /// Positive = move right/down, negative = move left/up.
  ///
  /// Example:
  ///   artOffsetXFactor = 0.0, artOffsetYFactor = 0.0   -> centered
  ///   artOffsetYFactor = -0.05                         -> 5% of card height upward
  final double artOffsetXFactor;
  final double artOffsetYFactor;

  /// Optional extra content overlay (for future badges, levels, etc.).
  final Widget? overlay;

  const GameCardFace({
    super.key,
    required this.card,
    this.width = 120,
    this.height = 180,
    this.artWidthFactor = 0.70,
    this.artHeightFactor = 0.70,
    this.artOffsetXFactor = 0.0,
    this.artOffsetYFactor = -0.065,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final cardHeight = constraints.maxHeight;

          // Convert relative factors into actual pixel sizes/offsets.
          final artWidth = cardWidth * artWidthFactor;
          final artHeight = cardHeight * artHeightFactor;
          final dx = cardWidth * artOffsetXFactor;
          final dy = cardHeight * artOffsetYFactor;

          // Use cardHeight as the single scaling reference for star layout,
          // so their size and position are consistent relative to the card.
          final double starSize = cardHeight * 0.10; // ~14% of card height
          final double starTopPadding = cardHeight * 0.06; // 6% from top
          final double starHorizontalPadding = cardHeight * 0.02;

          final int starCount = card.rank.abs();

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background frame
                Image.asset(
                  card.backgroundAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF333333),
                            Color(0xFF777777),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Base\nMissing',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),

                // Main art on top of the background, anchored by
                // relative size + relative offset.
                Transform.translate(
                  offset: Offset(dx, dy),
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: artWidth,
                      height: artHeight,
                      child: Image.asset(
                        card.artAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // If art is missing, at least show the base.
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),

                // Star rarity icons at the top, one per absolute rank.
                if (starCount > 0)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: starTopPadding,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          starCount,
                              (index) => Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: starHorizontalPadding,
                            ),
                            child: Image.asset(
                              'assets/rarity_star.png',
                              width: starSize,
                              height: starSize,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // If star asset is missing, fail silently.
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Optional overlay layer for future UI (e.g. level text).
                if (overlay != null) overlay!,
              ],
            ),
          );
        },
      ),
    );
  }
}
