// battle_page.dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'battle_logic.dart'; // adjust import path to wherever battle_logic.dart lives
import '../cards/game_card_face.dart';
import '../cards/card_catalog.dart';

class BattlePage extends StatefulWidget {
  final VoidCallback onBattleEnded;

  final String opponentName;
  final int opponentLevel;

  /// 0.0 = opponent winning, 1.0 = player winning
  final double victoryProgress;

  // Initial values only; live display reads from BattleLogic.
  final double opponentPrivateGold;
  final double playerPrivateGold;

  final double sharedGold;
  final double sharedAntimatter;
  final double sharedCombustion;
  final double sharedDeath;
  final double sharedLife;
  final double sharedQuintessence;

  final VoidCallback? onSurrender;
  final VoidCallback? onPlayerDraw;
  final VoidCallback? onSpeedDown;
  final VoidCallback? onSpeedUp;

  final double speedMultiplier;

  const BattlePage({
    super.key,
    required this.onBattleEnded,
    this.opponentName = 'Opponent',
    this.opponentLevel = 1,
    this.victoryProgress = 0.5,
    this.opponentPrivateGold = 0,
    this.playerPrivateGold = 0,
    this.sharedGold = 0,
    this.sharedAntimatter = 0,
    this.sharedCombustion = 0,
    this.sharedDeath = 0,
    this.sharedLife = 0,
    this.sharedQuintessence = 0,
    this.onSurrender,
    this.onPlayerDraw,
    this.onSpeedDown,
    this.onSpeedUp,
    this.speedMultiplier = 1.0,
  });

  // 🔒 Single source of truth for card sizing
  static const double _cardAspect = 0.70;
  static const double _cardMaxHeight = 190;

  @override
  State<BattlePage> createState() => _BattlePageState();

  static String _fmt(double v) {
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(2)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }
}

class _BattlePageState extends State<BattlePage> {
  bool _purchaseInFlight = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await BattleLogic.instance.init();

    // Provide live speed multiplier to the 1s ticker.
    BattleLogic.instance.configure_speed_provider(() => widget.speedMultiplier);

    // Seed initial values ONLY if this is a fresh state (all zeros).
    // (If you already set these elsewhere, you can remove this section.)
    await BattleLogic.instance.set_opp_private_gold(
      BattleLogic.instance.get_opp_private_gold() == 0.0
          ? widget.opponentPrivateGold
          : BattleLogic.instance.get_opp_private_gold(),
    );
    await BattleLogic.instance.set_player_private_gold(
      BattleLogic.instance.get_player_private_gold() == 0.0
          ? widget.playerPrivateGold
          : BattleLogic.instance.get_player_private_gold(),
    );

    await BattleLogic.instance.set_shared_gold(
      BattleLogic.instance.get_shared_gold() == 0.0 ? widget.sharedGold : BattleLogic.instance.get_shared_gold(),
    );
    await BattleLogic.instance.set_shared_antimatter(
      BattleLogic.instance.get_shared_antimatter() == 0.0
          ? widget.sharedAntimatter
          : BattleLogic.instance.get_shared_antimatter(),
    );
    await BattleLogic.instance.set_shared_combustion(
      BattleLogic.instance.get_shared_combustion() == 0.0
          ? widget.sharedCombustion
          : BattleLogic.instance.get_shared_combustion(),
    );
    await BattleLogic.instance.set_shared_death(
      BattleLogic.instance.get_shared_death() == 0.0 ? widget.sharedDeath : BattleLogic.instance.get_shared_death(),
    );
    await BattleLogic.instance.set_shared_life(
      BattleLogic.instance.get_shared_life() == 0.0 ? widget.sharedLife : BattleLogic.instance.get_shared_life(),
    );
    await BattleLogic.instance.set_shared_quintessence(
      BattleLogic.instance.get_shared_quintessence() == 0.0
          ? widget.sharedQuintessence
          : BattleLogic.instance.get_shared_quintessence(),
    );

    // Apply offline progress (elapsed is floored in BattleLogic now) + ensure ticker continues.
    await BattleLogic.instance.handle_battle_screen_open();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vp = widget.victoryProgress.clamp(0.0, 1.0);

    // surrender truly resets the battle state.
    Future<void> handleSurrender() async {
      await BattleLogic.instance.clear_game_state();
      final cb = widget.onSurrender ?? widget.onBattleEnded;
      cb();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _InfoBar(
              opponentName: widget.opponentName,
              opponentLevel: widget.opponentLevel,
              onSurrender: handleSurrender,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _VictoryBar(progress: vp),
            ),
            Expanded(
              child: Row(
                children: [
                  // LEFT SIDE (resources)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: BattleLogic.instance,
                      builder: (context, _) {
                        final logic = BattleLogic.instance;

                        final oppGold = logic.get_opp_private_gold();
                        final oppGoldPs = logic.get_opp_private_gold_per_sec();

                        final playerGold = logic.get_player_private_gold();
                        final playerGoldPs = logic.get_player_private_gold_per_sec();

                        final sharedGold = logic.get_shared_gold();
                        final sharedGoldPs = logic.get_shared_gold_per_sec();

                        final sharedAnti = logic.get_shared_antimatter();
                        final sharedAntiPs = logic.get_shared_antimatter_per_sec();

                        final sharedComb = logic.get_shared_combustion();
                        final sharedCombPs = logic.get_shared_combustion_per_sec();

                        final sharedDeath = logic.get_shared_death();
                        final sharedDeathPs = logic.get_shared_death_per_sec();

                        final sharedLife = logic.get_shared_life();
                        final sharedLifePs = logic.get_shared_life_per_sec();

                        final sharedQuint = logic.get_shared_quintessence();
                        final sharedQuintPs = logic.get_shared_quintessence_per_sec();

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                              child: _SectionCard(
                                title: "Opponent's Private Gold",
                                child: _ValueAndRateText(
                                  valueText: BattlePage._fmt(oppGold),
                                  perSecText: '${BattlePage._fmt(oppGoldPs)}/s',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: _SectionCard(
                                      title: 'Shared Resources',
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ResourceRow2('Gold', sharedGold, sharedGoldPs),
                                          _ResourceRow2('Antimatter', sharedAnti, sharedAntiPs),
                                          _ResourceRow2('Combustion', sharedComb, sharedCombPs),
                                          _ResourceRow2('Death', sharedDeath, sharedDeathPs),
                                          _ResourceRow2('Life', sharedLife, sharedLifePs),
                                          _ResourceRow2('Quintessence', sharedQuint, sharedQuintPs),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                              child: _SectionCard(
                                title: "Your Private Gold",
                                child: _ValueAndRateText(
                                  valueText: BattlePage._fmt(playerGold),
                                  perSecText: '${BattlePage._fmt(playerGoldPs)}/s',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // RIGHT SIDE (cards + draw button)
                  SizedBox(
                    width: 190,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      child: AnimatedBuilder(
                        animation: BattleLogic.instance,
                        builder: (context, _) {
                          final logic = BattleLogic.instance;

                          final playerCard = logic.get_player_current_card_sync();
                          final oppCard = logic.get_opp_current_card_sync();

                          final oppCost = (oppCard == null) ? null : logic.get_card_cost_sync(oppCard);
                          final playerCost = (playerCard == null) ? null : logic.get_card_cost_sync(playerCard);

                          final playerPurchasable = logic.check_purchasable_player(playerCard);

                          String costLabel(GameCard? c, int? cost) {
                            if (c == null || cost == null) return '';
                            final units = c.costUnits.isEmpty ? '' : ' ${c.costUnits}';
                            return 'Cost: $cost$units';
                          }

                          Future<void> tryPurchase() async {
                            if (_purchaseInFlight) return;
                            if (!playerPurchasable) return;
                            setState(() => _purchaseInFlight = true);
                            try {
                              await logic.purchase_player_current_card();
                            } finally {
                              if (mounted) setState(() => _purchaseInFlight = false);
                            }
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _StandaloneCard(
                                        card: oppCard,
                                        aspect: BattlePage._cardAspect,
                                        maxHeight: BattlePage._cardMaxHeight,
                                        rotate180: true,
                                        greyedOut: false,
                                        onTap: null, // opponent card NOT tappable
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        costLabel(oppCard, oppCost),
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        costLabel(playerCard, playerCost),
                                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _StandaloneCard(
                                        card: playerCard,
                                        aspect: BattlePage._cardAspect,
                                        maxHeight: BattlePage._cardMaxHeight,
                                        rotate180: false,
                                        greyedOut: !playerPurchasable,
                                        onTap: tryPurchase, // ✅ player card tappable
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 110,
                                        height: 34,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          onPressed: widget.onPlayerDraw,
                                          child: const Text('Draw'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: _SpeedAdjuster(
                    speedMultiplier: widget.speedMultiplier,
                    onMinus: widget.onSpeedDown,
                    onPlus: widget.onSpeedUp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays the actual card art via GameCardFace if card != null.
/// Shows a placeholder frame if null.
class _StandaloneCard extends StatelessWidget {
  final GameCard? card;
  final double aspect;
  final double maxHeight;
  final bool rotate180;
  final bool greyedOut;
  final Future<void> Function()? onTap;

  const _StandaloneCard({
    required this.card,
    required this.aspect,
    required this.maxHeight,
    required this.rotate180,
    required this.greyedOut,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              Widget content;
              if (card == null) {
                content = Container(
                  width: w,
                  height: h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Text('—'),
                );
              } else {
                Widget face = GameCardFace(
                  card: card!,
                  width: w,
                  height: h,
                  overlay: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv ${card!.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                if (rotate180) {
                  face = Transform.rotate(angle: pi, child: face);
                }

                if (greyedOut) {
                  face = ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ]),
                    child: Opacity(opacity: 0.45, child: face),
                  );
                }

                content = face;
              }

              // Only wrap with a gesture detector if onTap is provided.
              if (onTap == null) return content;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async => await onTap!(),
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VictoryBar extends StatelessWidget {
  final double progress;
  const _VictoryBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final green = (progress * 1000).round().clamp(0, 1000);
    final red = ((1 - progress) * 1000).round().clamp(0, 1000);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            Expanded(flex: green, child: Container(color: Colors.green)),
            Expanded(flex: red, child: Container(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final String opponentName;
  final int opponentLevel;
  final VoidCallback onSurrender;

  const _InfoBar({
    required this.opponentName,
    required this.opponentLevel,
    required this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$opponentName • Lv $opponentLevel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: onSurrender,
              child: const Text('Surrender'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ValueAndRateText extends StatelessWidget {
  final String valueText;
  final String perSecText;

  const _ValueAndRateText({
    required this.valueText,
    required this.perSecText,
  });

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(valueText, style: big),
        ),
        const SizedBox(width: 10),
        Text(
          perSecText,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResourceRow2 extends StatelessWidget {
  final String label;
  final double value;
  final double perSec;

  const _ResourceRow2(this.label, this.value, this.perSec);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodyMedium;
    final b = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t)),
          Text(BattlePage._fmt(value), style: b),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              '${BattlePage._fmt(perSec)}/s',
              textAlign: TextAlign.right,
              style: t,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedAdjuster extends StatelessWidget {
  final double speedMultiplier;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _SpeedAdjuster({
    required this.speedMultiplier,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
            tooltip: 'Slower',
          ),
          Text(
            '${speedMultiplier.toStringAsFixed(speedMultiplier == speedMultiplier.roundToDouble() ? 0 : 2)}x',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add),
            tooltip: 'Faster',
          ),
        ],
      ),
    );
  }
}
