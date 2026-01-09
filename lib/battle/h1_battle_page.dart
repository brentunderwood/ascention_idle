import 'package:flutter/material.dart';

class BattlePage extends StatelessWidget {
  final VoidCallback onBattleEnded;

  final String opponentName;
  final int opponentLevel;

  /// 0.0 = opponent winning, 1.0 = player winning
  final double victoryProgress;

  final double opponentPrivateGold;
  final double playerPrivateGold;

  final double sharedGold;
  final double sharedAntimatter;
  final double sharedCombustion;
  final double sharedDeath;
  final double sharedLife;
  final double sharedQuintessence;

  final String opponentCurrentCardLabel;
  final String playerCurrentCardLabel;

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
    this.opponentCurrentCardLabel = 'Opponent Card',
    this.playerCurrentCardLabel = 'Your Card',
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
  Widget build(BuildContext context) {
    final vp = victoryProgress.clamp(0.0, 1.0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _InfoBar(
              opponentName: opponentName,
              opponentLevel: opponentLevel,
              onSurrender: onSurrender ?? onBattleEnded,
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
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                          child: _SectionCard(
                            title: "Opponent's Private Gold",
                            child: _BigValueText(_fmt(opponentPrivateGold)),
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
                                      _ResourceRow('Gold', sharedGold),
                                      _ResourceRow('Antimatter', sharedAntimatter),
                                      _ResourceRow('Combustion', sharedCombustion),
                                      _ResourceRow('Death', sharedDeath),
                                      _ResourceRow('Life', sharedLife),
                                      _ResourceRow('Quintessence', sharedQuintessence),
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
                            child: _BigValueText(_fmt(playerPrivateGold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // RIGHT SIDE (cards + draw button)
                  SizedBox(
                    width: 190,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _StandaloneCard(
                                label: opponentCurrentCardLabel,
                                aspect: _cardAspect,
                                maxHeight: _cardMaxHeight,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _StandaloneCard(
                                    label: playerCurrentCardLabel,
                                    aspect: _cardAspect,
                                    maxHeight: _cardMaxHeight,
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
                                      onPressed: onPlayerDraw,
                                      child: const Text('Draw'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                    speedMultiplier: speedMultiplier,
                    onMinus: onSpeedDown,
                    onPlus: onSpeedUp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(2)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }
}

class _StandaloneCard extends StatelessWidget {
  final String label;
  final double aspect;
  final double maxHeight;

  const _StandaloneCard({
    required this.label,
    required this.aspect,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(label, textAlign: TextAlign.center),
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

class _BigValueText extends StatelessWidget {
  final String text;
  const _BigValueText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  final String label;
  final double value;
  const _ResourceRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(BattlePage._fmt(value),
              style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final label =
        'Speed x${speedMultiplier.toStringAsFixed(speedMultiplier == speedMultiplier.roundToDouble() ? 0 : 1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove)),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}
