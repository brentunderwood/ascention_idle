import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Model for a card pack configuration.
/// You can later add more packs with different images / names.
class CardPackConfig {
  final String id;
  final String name;

  const CardPackConfig({
    required this.id,
    required this.name,
  });
}

/// Main widget for the Rebirth tab.
/// Shows subtabs: Store, Deck, Collection.
class RebirthScreen extends StatelessWidget {
  final double currentGold;

  const RebirthScreen({
    super.key,
    required this.currentGold,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Store'),
              Tab(text: 'Deck'),
              Tab(text: 'Collection'),
              Tab(text: 'Pickaxe'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                RebirthStoreTab(currentGold: currentGold),
                const _DeckTabPlaceholder(),
                const _CollectionTabPlaceholder(),
                const _PickaxeTabPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Store tab for Rebirth.
class RebirthStoreTab extends StatelessWidget {
  final double currentGold;

  const RebirthStoreTab({
    super.key,
    required this.currentGold,
  });

  @override
  Widget build(BuildContext context) {
    const packs = [
      CardPackConfig(
        id: 'lux_aurea',
        name: 'Lux Aurea',
      ),
      CardPackConfig(
        id: 'vita_aurum',
        name: 'Vita Aurum',
      ),
    ];

    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rebirth Store',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Gold: ${currentGold.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Multiple pack tiles, reusable via CardPackConfig + RebirthPackTile
            ...packs.map(
                  (pack) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RebirthPackTile(config: pack),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single card-pack widget with:
/// - Name above
/// - Simple rectangular image "card"
/// - Left/right arrows to change level (1–10)
/// - Cost (10^level)
/// - Info button below
class RebirthPackTile extends StatefulWidget {
  final CardPackConfig config;

  const RebirthPackTile({
    super.key,
    required this.config,
  });

  @override
  State<RebirthPackTile> createState() => _RebirthPackTileState();
}

class _RebirthPackTileState extends State<RebirthPackTile> {
  static const int _minLevel = 0;
  static const int _maxLevel = 10;

  int _currentLevel = _minLevel;

  void _previousLevel() {
    setState(() {
      if (_currentLevel > _minLevel) {
        _currentLevel--;
      }
    });
  }

  void _nextLevel() {
    setState(() {
      if (_currentLevel < _maxLevel) {
        _currentLevel++;
      }
    });
  }

  double get _cost {
    // cost = 10^level
    return math.pow(10, _currentLevel).toDouble();
  }

  String get _costText {
    if (_cost >= 1e6) {
      return _cost.toStringAsExponential(2);
    }
    return _cost.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pack name
            Text(
              widget.config.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Arrow + card image
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _previousLevel,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),

                // Real card image (falls back to placeholder if asset is missing)
                Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.8),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/card_pack_lux_aurea.png',
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
                              'Missing\nImage',
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
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _nextLevel,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.white,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Level + cost
            Text(
              'Level $_currentLevel',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cost: $_costText',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),

            const SizedBox(height: 12),

            // Info button
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(widget.config.name),
                      content: Text(
                        'Info about ${widget.config.name} (Level $_currentLevel)\n'
                            'Cost: $_costText gold.\n\n'
                            'Detailed effects will be added later.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Info'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for the Deck subtab.
class _DeckTabPlaceholder extends StatelessWidget {
  const _DeckTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Deck management coming soon...',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black54,
              offset: Offset(1, 1),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Placeholder for the Collection subtab.
class _CollectionTabPlaceholder extends StatelessWidget {
  const _CollectionTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Card collection coming soon...',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black54,
              offset: Offset(1, 1),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Placeholder for the Pickaxe subtab.
class _PickaxeTabPlaceholder extends StatelessWidget {
  const _PickaxeTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Card collection coming soon...',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 4,
              color: Colors.black54,
              offset: Offset(1, 1),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
