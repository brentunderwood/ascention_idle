import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utilities/alerts.dart';
import 'cards/player_collection_repository.dart';

/// Centralized tutorial manager.
/// - Tracks which tutorial steps have been shown (via SharedPreferences).
/// - Ensures ONLY ONE tutorial dialog is visible at a time.
/// - All game code just calls these hook methods; logic lives here.
class TutorialManager {
  TutorialManager._();
  static final TutorialManager instance = TutorialManager._();

  SharedPreferences? _prefs;

  /// Global guard: if true, a tutorial dialog is currently visible.
  bool _isShowingTutorialDialog = false;

  // Keys for prefs
  static const _kStep1Welcome = 'tutorial_step1_welcome';
  static const _kStep2FirstGoldPiece = 'tutorial_step2_first_gold_piece';
  static const _kStep3StoreIntro = 'tutorial_step3_store_intro';
  static const _kStep4DeckTabPrompt = 'tutorial_step4_deck_tab_prompt';
  static const _kStep5DeckExplain = 'tutorial_step5_deck_explain';
  static const _kStep6CardInDeckExplain = 'tutorial_step6_card_in_deck_explain';

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> _isStepDone(String key) async {
    await _ensurePrefs();
    return _prefs!.getBool(key) ?? false;
  }

  Future<void> _markStepDone(String key) async {
    await _ensurePrefs();
    await _prefs!.setBool(key, true);
  }

  /// Core helper that enforces:
  /// - Only one tutorial dialog at a time.
  /// - Only show once per key.
  Future<void> _showTutorialOnce(
      BuildContext context,
      String key,
      String message,
      ) async {
    // If a tutorial is already on the screen, just ignore this request.
    if (_isShowingTutorialDialog) return;

    // Only show once.
    if (await _isStepDone(key)) return;

    _isShowingTutorialDialog = true;
    try {
      await alert_user(
        context,
        message,
        title: 'Tutorial',
      );
      await _markStepDone(key);
    } finally {
      _isShowingTutorialDialog = false;
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC HOOKS
  // ---------------------------------------------------------------------------

  /// 1) When the player first enters the main game screen.
  ///
  /// Call this once after the first frame of IdleGameScreen.
  Future<void> onMainScreenFirstShown(BuildContext context) async {
    const message =
        'Welcome to Ascention Idle! An idle game where you collect cards with '
        'unique abilities to help you gather resources from the world around '
        'you. Start by mining some gold ore from this big rock. You may find '
        'something special.';
    await _showTutorialOnce(context, _kStep1Welcome, message);
  }

  /// 2) Whenever gold ore changes. We only care about crossing 101 ore
  /// for the first time. Can be safely called many times.
  Future<void> onGoldOreChanged(
      BuildContext context,
      double goldOre,
      ) async {
    if (goldOre < 101) return;
    if (await _isStepDone(_kStep2FirstGoldPiece)) return;

    const message =
        'Congratulations, you managed to mine a solid gold piece from that '
        'boulder. Gold is the main currency in this game and for now there '
        'are 2 ways to get it: by uncovering gold nuggets like that one, and '
        'by collecting a large amount of ore.\n\n'
        'You can\'t spend them right away, though. You have to rebirth first. '
        'Rebirthing will reset all of your mining stats, but allow you to '
        'collect the gold you have earned.\n\n'
        'Go ahead and click the rebirth button, then navigate to the rebirth '
        'shop where you can spend it.';
    await _showTutorialOnce(context, _kStep2FirstGoldPiece, message);
  }

  /// 3 & 4) Called when the Rebirth tab's "Store" subtab is shown.
  ///
  /// Handles:
  /// 3. Store intro (after step 2 finished).
  /// 4. "Now that you have a card..." (after you own at least 1 card).
  Future<void> onRebirthStoreShown(BuildContext context) async {
    // Step 3: Store intro
    final step2Done = await _isStepDone(_kStep2FirstGoldPiece);
    final step3Done = await _isStepDone(_kStep3StoreIntro);
    final step4Done = await _isStepDone(_kStep4DeckTabPrompt);

    if (step2Done && !step3Done) {
      const message =
          'Here you can buy card packs. Each card pack has a chance of '
          'containing 1 card. The more expensive the card pack you buy, the '
          'more likely you are to get a rare card.\n\n'
          'Why don\'t you buy one of the level 0 card packs now.';
      await _showTutorialOnce(context, _kStep3StoreIntro, message);
      return; // Only show one tutorial message per visit.
    }

    // Step 4: After step 3, once you actually own at least 1 card.
    if (step3Done && !step4Done) {
      await PlayerCollectionRepository.instance.init();
      final hasAnyCard =
          PlayerCollectionRepository.instance.allOwnedCards.isNotEmpty;
      if (!hasAnyCard) return;

      const message =
          'Now that you have a card, click on the deck tab at the top of the screen.';
      await _showTutorialOnce(context, _kStep4DeckTabPrompt, message);
      return;
    }
  }

  /// 5) Called when the "Deck" subtab inside Rebirth is shown.
  ///
  /// Only fires after step 4 has been shown.
  Future<void> onDeckTabShown(BuildContext context) async {
    final step4Done = await _isStepDone(_kStep4DeckTabPrompt);
    final step5Done = await _isStepDone(_kStep5DeckExplain);

    if (!step4Done || step5Done) return;

    const message =
        'Here you can see all of the cards you have found. Click on the one '
        'you just got in order to see its details, then add it to your deck '
        'by clicking the button on the bottom of the card info page.';
    await _showTutorialOnce(context, _kStep5DeckExplain, message);
  }

  /// 6) Called after a card has been successfully added to a deck.
  Future<void> onCardAddedToDeck(BuildContext context) async {
    final step5Done = await _isStepDone(_kStep5DeckExplain);
    final step6Done = await _isStepDone(_kStep6CardInDeckExplain);

    if (!step5Done || step6Done) return;

    const message =
        'When you add a card to your deck, you won\'t be able to use it right '
        'away. But the next time you rebirth, all of your deck cards will be '
        'available to you via the upgrades tab.\n\n'
        'You can spend some of your ore in order to trigger their effects. '
        'Each card is unique and many of them have effects that work well with '
        'each other, so choose carefully.';
    await _showTutorialOnce(context, _kStep6CardInDeckExplain, message);
  }
}
