import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cards/game_card_models.dart';
import '../cards/card_catalog.dart';
import '../cards/game_card_face.dart';
import '../cards/card_effects.dart';
import '../cards/info_dialog.dart';
import '../cards/player_collection_repository.dart';

/// Manual pack display order used for:
///  - Collection sorting (by pack, then rank)
///  - Store pack ordering (keep in sync in the store file).
const List<String> kPackDisplayOrder = [
  'vita_orum',
  'lux_aurea',
];

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

  // Deck data persistence
  static const String _decksDataKey = 'rebirth_decks_data';

  // Player-wide deck constraints
  static const String _maxCardsKey = 'rebirth_deck_max_cards';
  static const String _maxCapacityKey = 'rebirth_deck_max_capacity';

  // Active deck for next rebirth (zero-based index)
  static const String _activeDeckIndexKey = 'rebirth_active_deck_index';

  int _deckSlotCount = 1; // starts with 1 deck by default
  String _selectedViewId = 'deck_1';
  bool _loaded = false;

  /// Drawer starts CLOSED whenever this tab is opened.
  bool _drawerOpen = false;

  /// Player-wide constraints (can be increased later by achievements).
  int _maxCards = 1;
  int _maxCapacity = 1;

  /// All decks (one per slot).
  List<_DeckData> _decks = [];

  /// Index of the deck used for next rebirth (0-based).
  int _activeDeckIndexZero = 0;

  /// Player collection (all owned cards).
  List<OwnedCard> _collection = [];

  @override
  void initState() {
    super.initState();
    _loadDeckPrefsAndCollection();
  }

  Future<void> _loadDeckPrefsAndCollection() async {
    final prefs = await SharedPreferences.getInstance();

    final storedCount = prefs.getInt(_deckSlotCountKey);
    final storedView = prefs.getString(_deckSelectedViewKey);

    final storedMaxCards = prefs.getInt(_maxCardsKey);
    final storedMaxCapacity = prefs.getInt(_maxCapacityKey);

    final storedActiveDeckIndex = prefs.getInt(_activeDeckIndexKey);

    // ---------- LOAD PLAYER COLLECTION VIA REPOSITORY ----------
    await PlayerCollectionRepository.instance.init();
    final collection = PlayerCollectionRepository.instance.allOwnedCards;

    // ---------- LOAD DECKS JSON ----------
    final rawDecks = prefs.getString(_decksDataKey);
    List<_DeckData> decks = [];
    if (rawDecks != null && rawDecks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDecks) as List<dynamic>;
        decks = decoded
            .map((e) => _DeckData.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        decks = [];
      }
    }

    int slotCount =
    (storedCount != null && storedCount >= 1) ? storedCount : 1;

    // Ensure we have one _DeckData per slot.
    decks = _ensureDeckListForSlotCount(decks, slotCount);

    int activeIndex = storedActiveDeckIndex ?? 0;
    if (activeIndex < 0 || activeIndex >= slotCount) {
      activeIndex = 0;
    }

    setState(() {
      _deckSlotCount = slotCount;
      _selectedViewId = storedView != null ? storedView : 'deck_1';
      _collection = collection;
      _decks = decks;

      // Respect stored max cards / capacity
      _maxCards = (storedMaxCards != null && storedMaxCards >= 1)
          ? storedMaxCards
          : 1;
      _maxCapacity = (storedMaxCapacity != null && storedMaxCapacity >= 1)
          ? storedMaxCapacity
          : 1;

      _activeDeckIndexZero = activeIndex;
      _loaded = true;
      // _drawerOpen stays false initially so drawer starts closed.
    });
  }

  List<_DeckData> _ensureDeckListForSlotCount(
      List<_DeckData> decks,
      int slotCount,
      ) {
    final Map<String, _DeckData> byId = {
      for (final d in decks) d.id: d,
    };
    final List<_DeckData> result = [];

    for (int i = 0; i < slotCount; i++) {
      final id = 'deck_${i + 1}';
      if (byId.containsKey(id)) {
        result.add(byId[id]!);
      } else {
        result.add(
          _DeckData(
            id: id,
            name: 'Deck ${i + 1}',
            cardIds: [],
          ),
        );
      }
    }
    return result;
  }

  Future<void> _saveDeckPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deckSlotCountKey, _deckSlotCount);
    await prefs.setString(_deckSelectedViewKey, _selectedViewId);

    await prefs.setInt(_maxCardsKey, _maxCards);
    await prefs.setInt(_maxCapacityKey, _maxCapacity);
    await prefs.setInt(_activeDeckIndexKey, _activeDeckIndexZero);

    final encodedDecks =
    jsonEncode(_decks.map((d) => d.toJson()).toList(growable: false));
    await prefs.setString(_decksDataKey, encodedDecks);
  }

  bool get _showingCollection => _selectedViewId == 'collection';

  _DeckData _getOrCreateDeckByIndexZero(int indexZero) {
    while (_decks.length <= indexZero) {
      final id = 'deck_${_decks.length + 1}';
      _decks.add(
        _DeckData(
          id: id,
          name: 'Deck ${_decks.length + 1}',
          cardIds: [],
        ),
      );
    }
    return _decks[indexZero];
  }

  void _selectDeck(int index) {
    setState(() {
      _selectedViewId = 'deck_${index + 1}';
      // Close drawer after navigation selection.
      _drawerOpen = false;
    });
    _saveDeckPrefs();
  }

  void _selectCollection() {
    setState(() {
      _selectedViewId = 'collection';
      // Close drawer after navigation selection.
      _drawerOpen = false;
    });
    _saveDeckPrefs();
  }

  Future<void> _setActiveDeck(int indexZero) async {
    setState(() {
      _activeDeckIndexZero = indexZero;
    });
    await _saveDeckPrefs();

    final deckNumber = indexZero + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deck $deckNumber selected for next rebirth.'),
        duration: const Duration(seconds: 2),
      ),
    );
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
      // Ensure deck list has a new deck entry.
      _decks = _ensureDeckListForSlotCount(_decks, _deckSlotCount);
      // Close drawer after unlocking and selecting the new deck.
      _drawerOpen = false;
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

  Future<void> _showSimpleInfoDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptAddCardToDeck(
      int deckIndexZero,
      GameCard card,
      OwnedCard owned,
      ) async {
    final deck = _getOrCreateDeckByIndexZero(deckIndexZero);
    final deckNumber = deckIndexZero + 1;

    // 1) Check duplicate
    if (deck.cardIds.contains(card.id)) {
      await _showSimpleInfoDialog(
        'Cannot add card',
        'This card is already in Deck $deckNumber.',
      );
      return;
    }

    // 2) Check max cards
    if (deck.cardIds.length >= _maxCards) {
      await _showSimpleInfoDialog(
        'Cannot add card',
        'Deck $deckNumber is full (maximum $_maxCards cards).',
      );
      return;
    }

    // 3) Check capacity by rarity (using rank^2 as value)
    int deckValue = 0;
    for (final id in deck.cardIds) {
      final c = CardCatalog.getById(id);
      if (c != null) {
        deckValue += math.pow(c.rank.abs(), 2).toInt();
      }
    }
    final int cardRarity = card.rank;
    final int newValue = deckValue + cardRarity;

    if (newValue > _maxCapacity) {
      await _showSimpleInfoDialog(
        'Cannot add card',
        'Adding this card would exceed Deck $deckNumber\'s capacity '
            '($_maxCapacity).',
      );
      return;
    }

    // Passed all checks -> add
    setState(() {
      deck.cardIds.add(card.id);
    });
    await _saveDeckPrefs();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${card.name} to Deck $deckNumber.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeCardFromDeck(
      int deckIndexZero,
      GameCard card,
      ) async {
    final deck = _getOrCreateDeckByIndexZero(deckIndexZero);
    final deckNumber = deckIndexZero + 1;

    if (!deck.cardIds.contains(card.id)) {
      await _showSimpleInfoDialog(
        'Cannot remove card',
        'This card is not in Deck $deckNumber.',
      );
      return;
    }

    setState(() {
      deck.cardIds.remove(card.id);
    });
    await _saveDeckPrefs();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${card.name} from Deck $deckNumber.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAddToDeckDialog(GameCard card, OwnedCard owned) async {
    if (_deckSlotCount <= 0) {
      await _showSimpleInfoDialog(
        'No decks available',
        'You do not have any deck slots unlocked yet.',
      );
      return;
    }

    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add to which deck?'),
        children: [
          for (int i = 0; i < _deckSlotCount; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text('Deck ${i + 1}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedIndex == null) return;

    await _attemptAddCardToDeck(selectedIndex, card, owned);
  }

  Future<void> _renameDeck(int indexZero) async {
    final deck = _getOrCreateDeckByIndexZero(indexZero);
    final controller = TextEditingController(text: deck.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Deck'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Deck name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty) {
        setState(() {
          deck.name = newName;
        });
        await _saveDeckPrefs();
      }
    }
  }

  Widget _buildCollectionView() {
    if (_collection.isEmpty) {
      return const Center(
        child: Text(
          'You don\'t own any cards yet.\n'
              'Buy packs in the Store to start your collection!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Build tiles for each owned card: card art + name + level/exp.
    final items = _collection.map((owned) {
      final card = CardCatalog.getById(owned.cardId);
      if (card == null) return null;
      return _OwnedCardDisplayData(
        card: card,
        owned: owned,
      );
    }).whereType<_OwnedCardDisplayData>().toList();

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Your collection data references cards that no longer exist.\n'
              '(No valid cards to display.)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Sort by pack (using manual pack order), then by rank ascending.
    items.sort((a, b) {
      int indexFor(String packId) {
        final idx = kPackDisplayOrder.indexOf(packId);
        return idx == -1 ? kPackDisplayOrder.length : idx;
      }

      final aPackIndex = indexFor(a.card.packId);
      final bPackIndex = indexFor(b.card.packId);

      if (aPackIndex != bPackIndex) {
        return aPackIndex.compareTo(bPackIndex);
      }

      // Same pack -> sort by rank ascending.
      return a.card.rank.compareTo(b.card.rank);
    });

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final data = items[index];

        return GestureDetector(
          onTap: () => showGlobalCardInfoDialog(
            context: context,
            card: data.card,
            owned: data.owned,
            canAddToDeck: true,
            onAddToDeck: () => _showAddToDeckDialog(data.card, data.owned),
          ),
          child: Column(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: GameCardFace(
                    card: data.card,
                    width: 90,
                    height: 140,
                    overlay: Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lv ${data.owned.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.card.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeckView(int deckIndex) {
    final indexZero = deckIndex - 1;
    final deck = _getOrCreateDeckByIndexZero(indexZero);

    // Compute deck value (sum of ranks^2).
    int deckValue = 0;
    for (final id in deck.cardIds) {
      final c = CardCatalog.getById(id);
      if (c != null) {
        deckValue += math.pow(c.rank.abs(), 2).toInt();
      }
    }

    // Map of owned cards by ID for quick lookup
    final Map<String, OwnedCard> ownedById = {
      for (final oc in _collection) oc.cardId: oc,
    };

    final List<_OwnedCardDisplayData> items = [];
    for (final id in deck.cardIds) {
      final card = CardCatalog.getById(id);
      final owned = ownedById[id];
      if (card != null && owned != null) {
        items.add(_OwnedCardDisplayData(card: card, owned: owned));
      }
    }

    Widget body;
    if (deck.cardIds.isEmpty || items.isEmpty) {
      body = Center(
        child: Text(
          'Deck $deckIndex is empty.\nAdd cards from your Collection.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      // Keep insertion order for deck cards (no sorting).
      body = GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.6,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final data = items[index];

          return GestureDetector(
            onTap: () => showGlobalCardInfoDialog(
              context: context,
              card: data.card,
              owned: data.owned,
              canRemoveFromDeck: true,
              onRemoveFromDeck: () =>
                  _removeCardFromDeck(indexZero, data.card),
            ),
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: GameCardFace(
                      card: data.card,
                      width: 90,
                      height: 140,
                      overlay: Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Lv ${data.owned.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.card.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      );
    }

    final isActive = (_activeDeckIndexZero == indexZero);

    // Wrap header + stats row + grid in a Column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Deck name + edit + active selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  deck.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                tooltip: 'Rename deck',
                onPressed: () => _renameDeck(indexZero),
              ),
              TextButton.icon(
                onPressed: isActive ? null : () => _setActiveDeck(indexZero),
                icon: Icon(
                  Icons.star,
                  size: 18,
                  color: isActive ? Colors.amber : Colors.white70,
                ),
                label: Text(
                  isActive ? 'Active' : 'Set Active',
                  style: TextStyle(
                    color: isActive ? Colors.amber : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Text(
                'Cards: ${deck.cardIds.length} / $_maxCards',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Capacity: $deckValue / $_maxCapacity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Divider(
          color: Colors.white24,
          height: 1,
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildMainArea() {
    if (_showingCollection) {
      // Collection view: scrollable grid of owned cards
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildCollectionView(),
      );
    } else {
      // Some deck is selected
      final deckIndex =
          int.tryParse(_selectedViewId.replaceFirst('deck_', '')) ?? 1;

      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildDeckView(deckIndex),
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

            // Main area: content with an overlayed drawer
            Expanded(
              child: Stack(
                children: [
                  // Main content always fills the area.
                  // Also acts as a "click outside to close drawer".
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_drawerOpen) {
                          setState(() {
                            _drawerOpen = false;
                          });
                        }
                      },
                      child: _buildMainArea(),
                    ),
                  ),

                  // Drawer overlays on top instead of resizing the content
                  if (_drawerOpen)
                    Positioned(
                      top: 0,
                      left: 0,
                      bottom: 0,
                      child: _buildDrawerContent(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckTile({
    required String label,
    required bool selected,
    required bool isActive,
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
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              const Icon(
                Icons.star,
                size: 16,
                color: Colors.amber,
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
        // Less transparent / almost opaque drawer
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Deck', style: deckLabelStyle),
          const SizedBox(height: 8),

          // Scrollable drawer list: Deck 1..N, +New, Collection
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // --- Deck 1..N ---
                  for (int i = 0; i < _deckSlotCount; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: _buildDeckTile(
                        label: _decks.length > i
                            ? _decks[i].name
                            : 'Deck ${i + 1}',
                        selected: _selectedViewId == 'deck_${i + 1}',
                        isActive: _activeDeckIndexZero == i,
                        icon: Icons.layers,
                        onTap: () => _selectDeck(i),
                      ),
                    ),

                  // --- "+ New" tile always BELOW the last deck ---
                  if (_deckSlotCount < 10)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: _buildDeckTile(
                        label: '+ New',
                        selected: false,
                        isActive: false,
                        icon: Icons.layers,
                        onTap: _showAddDeckSlotDialog,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Collection label + tile
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
                          horizontal: 8,
                          vertical: 6,
                        ),
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
}

/// Simple helper model to bundle a card template with its owned info.
class _OwnedCardDisplayData {
  final GameCard card;
  final OwnedCard owned;

  _OwnedCardDisplayData({
    required this.card,
    required this.owned,
  });
}

/// Internal deck data: ID + name + list of card IDs in that deck.
class _DeckData {
  final String id;
  String name;
  final List<String> cardIds;

  _DeckData({
    required this.id,
    String? name,
    List<String>? cardIds,
  })  : name = name ?? id,
        cardIds = cardIds ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cards': cardIds,
  };

  factory _DeckData.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'];
    final List<String> ids;
    if (rawCards is List) {
      ids = rawCards.map((e) => e.toString()).toList();
    } else {
      ids = [];
    }
    final id = json['id']?.toString() ?? 'deck_1';
    final name = json['name']?.toString() ?? id;
    return _DeckData(id: id, name: name, cardIds: ids);
  }
}
