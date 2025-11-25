import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DECK MANAGEMENT TAB
///
/// Drawer-style navigation:
///  - Hamburger icon at top-left to expand/retract the drawer
///  - Drawer contains:
///       * "Deck" label
///       * "Deck 1"
///       * "+ New" (same style as deck tab, opens unlock dialog)
///       * Deck 2..N
///       * small gap
///       * "Collection" label + tile
///
/// Main area:
///  - Shows either current deck placeholder or collection placeholder.
class DeckManagementTab extends StatefulWidget {
  final double currentGold;
  final ValueChanged<double> onSpendGold;

  const DeckManagementTab({
    super.key,
    required this.currentGold,
    required this.onSpendGold,
  });

  @override
  State<DeckManagementTab> createState() => _DeckManagementTabState();
}

class _DeckManagementTabState extends State<DeckManagementTab> {
  static const String _deckSlotCountKey = 'rebirth_deck_slot_count';
  static const String _deckSelectedViewKey = 'rebirth_deck_selected_view';

  int _deckSlotCount = 1; // starts with 1 deck by default
  String _selectedViewId = 'deck_1'; // 'deck_1'...'deck_N' or 'collection'
  bool _loaded = false;
  bool _drawerOpen = true; // controls drawer visibility

  @override
  void initState() {
    super.initState();
    _loadDeckPrefs();
  }

  Future<void> _loadDeckPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCount = prefs.getInt(_deckSlotCountKey);
    final storedView = prefs.getString(_deckSelectedViewKey);

    setState(() {
      _deckSlotCount =
      (storedCount != null && storedCount >= 1) ? storedCount : 1;
      _selectedViewId = storedView != null ? storedView : 'deck_1';
      _loaded = true;
    });
  }

  Future<void> _saveDeckPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deckSlotCountKey, _deckSlotCount);
    await prefs.setString(_deckSelectedViewKey, _selectedViewId);
  }

  bool get _showingCollection => _selectedViewId == 'collection';

  void _selectDeck(int index) {
    setState(() {
      _selectedViewId = 'deck_${index + 1}';
    });
    _saveDeckPrefs();
  }

  void _selectCollection() {
    setState(() {
      _selectedViewId = 'collection';
    });
    _saveDeckPrefs();
  }

  double _deckSlotCost() {
    // cost = 100 ^ [current number of deck slots]
    // deckSlotCount = 1 => cost 100^1 = 100 for second slot
    return math.pow(100, _deckSlotCount).toDouble();
  }

  Future<void> _addDeckSlot() async {
    if (_deckSlotCount >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 10 deck slots reached.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cost = _deckSlotCost();

    setState(() {
      _deckSlotCount += 1;
      _selectedViewId = 'deck_$_deckSlotCount';
    });
    await _saveDeckPrefs();

    widget.onSpendGold(cost);
  }

  Future<void> _showAddDeckSlotDialog() async {
    if (_deckSlotCount >= 10) {
      // Max reached; simple info dialog
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Maximum Deck Slots'),
          content: const Text('You have already unlocked all 10 deck slots.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final cost = _deckSlotCost();

    if (widget.currentGold < cost) {
      // Insufficient funds dialog with only "Insufficient funds" button
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot unlock deck slot'),
          content: Text(
            'You need ${cost.toStringAsFixed(0)} gold to unlock a new deck slot.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Insufficient funds'),
            ),
          ],
        ),
      );
      return;
    }

    // Confirmation dialog (yes/no)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlock new deck slot?'),
        content: Text(
          'Spend ${cost.toStringAsFixed(0)} gold to unlock a new deck slot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _addDeckSlot();
    }
  }

  Widget _buildDeckTile({
    required String label,
    required bool selected,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.amberAccent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerContent() {
    final deckLabelStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    final sideHeaderStyle = TextStyle(
      fontSize: 14,
      color: Colors.grey.shade300,
      fontWeight: FontWeight.w600,
    );

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Deck', style: deckLabelStyle),
          const SizedBox(height: 8),

          // Scrollable drawer list: Deck 1, +New, Deck 2..N, Collection
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- Deck 1 ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: _buildDeckTile(
                      label: 'Deck 1',
                      selected: _selectedViewId == 'deck_1',
                      icon: Icons.layers,
                      onTap: () => _selectDeck(0),
                    ),
                  ),

                  // --- "+ New" tile, styled like deck tile, directly under Deck 1 ---
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: _buildDeckTile(
                      label: '+ New',
                      selected: false,
                      icon: Icons.layers, // same icon to match deck style
                      onTap: _showAddDeckSlotDialog,
                    ),
                  ),

                  // --- Additional deck slots (Deck 2..N) below "+ New" ---
                  for (int i = 1; i < _deckSlotCount; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: _buildDeckTile(
                        label: 'Deck ${i + 1}',
                        selected: _selectedViewId == 'deck_${i + 1}',
                        icon: Icons.layers,
                        onTap: () => _selectDeck(i),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Collection label + tile just below +New (with small gap)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Collection', style: sideHeaderStyle),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _selectCollection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showingCollection
                              ? Colors.white.withOpacity(0.25)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.collections_bookmark,
                              size: 18,
                              color: Colors.lightBlueAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Collection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainArea() {
    if (_showingCollection) {
      // Placeholder for collection view
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Collection view will show all cards you own.\n(Coming soon...)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // Some deck is selected
      final deckIndex =
          int.tryParse(_selectedViewId.replaceFirst('deck_', '')) ?? 1;

      // Placeholder for per-deck grid
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: Text(
            'Cards for Deck $deckIndex will be displayed here\n'
                'in a grid layout (Coming soon...)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top row with drawer toggle + title
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _drawerOpen ? Icons.menu_open : Icons.menu,
                    color: Colors.white,
                  ),
                  tooltip:
                  _drawerOpen ? 'Hide deck drawer' : 'Show deck drawer',
                  onPressed: () {
                    setState(() {
                      _drawerOpen = !_drawerOpen;
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Decks & Collection',
                  style: TextStyle(
                    fontSize: 18,
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
              ],
            ),
            const SizedBox(height: 8),

            // Main row: optional drawer + main area
            Expanded(
              child: Row(
                children: [
                  if (_drawerOpen) _buildDrawerContent(),
                  if (_drawerOpen) const SizedBox(width: 12),
                  Expanded(child: _buildMainArea()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
