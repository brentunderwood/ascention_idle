import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainCampaignTab extends StatefulWidget {
  final VoidCallback? onBattleStarted;

  const MainCampaignTab({
    super.key,
    this.onBattleStarted,
  });

  @override
  State<MainCampaignTab> createState() => _MainCampaignTabState();
}

class _MainCampaignTabState extends State<MainCampaignTab> {
  // Persistence keys
  static const String kCampaignHighestUnlockedKey = 'campaign_highest_unlocked';
  static const String kCampaignDefeatedKey = 'campaign_defeated_indices';
  static const String kCampaignSeedKey = 'campaign_map_seed_v1';

  // Example opponents (replace later)
  final List<_OpponentNode> _opponents = const [
    _OpponentNode(
      id: 'slime_scout',
      name: 'Slime Scout',
      subtitle: 'Level 1 • Easy',
      icon: Icons.bubble_chart,
    ),
    _OpponentNode(
      id: 'crypt_raider',
      name: 'Crypt Raider',
      subtitle: 'Level 2 • Normal',
      icon: Icons.shield,
    ),
    _OpponentNode(
      id: 'bone_mage',
      name: 'Bone Mage',
      subtitle: 'Level 3 • Normal',
      icon: Icons.auto_fix_high,
    ),
    _OpponentNode(
      id: 'infernal_knight',
      name: 'Infernal Knight',
      subtitle: 'Level 4 • Hard',
      icon: Icons.local_fire_department,
    ),
    _OpponentNode(
      id: 'abyss_wyrm',
      name: 'Abyss Wyrm',
      subtitle: 'Level 5 • Boss',
      icon: Icons.waves,
    ),
  ];

  int _highestUnlocked = 0;
  final Set<int> _defeated = <int>{};
  int _seed = 0;
  bool _loaded = false;

  // Visibility:
  // - <= highestUnlocked opaque
  // - next 3 translucent
  // - rest hidden
  int get _maxVisibleIndex =>
      (_highestUnlocked + 3).clamp(0, _opponents.length - 1);

  // Layout constants
  static const double _nodeRadius = 18;
  static const double _topPad = 56;
  static const double _bottomPad = 180;
  static const double _spacingY = 165;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final highest = prefs.getInt(kCampaignHighestUnlockedKey) ?? 0;
    final defeatedStrings =
        prefs.getStringList(kCampaignDefeatedKey) ?? const <String>[];

    int seed = prefs.getInt(kCampaignSeedKey) ?? 0;
    if (seed == 0) {
      final r = math.Random();
      seed =
      ((r.nextInt(1 << 31)) ^ DateTime.now().millisecondsSinceEpoch) &
      0x7fffffff;
      if (seed == 0) seed = 133742069;
      await prefs.setInt(kCampaignSeedKey, seed);
    }

    final parsedDefeated = <int>{};
    for (final s in defeatedStrings) {
      final v = int.tryParse(s);
      if (v != null && v >= 0 && v < _opponents.length) {
        parsedDefeated.add(v);
      }
    }

    if (!mounted) return;
    setState(() {
      _highestUnlocked = highest.clamp(0, _opponents.length - 1);
      _defeated
        ..clear()
        ..addAll(parsedDefeated);
      _seed = seed;
      _loaded = true;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kCampaignHighestUnlockedKey, _highestUnlocked);
    await prefs.setStringList(
      kCampaignDefeatedKey,
      _defeated.map((e) => e.toString()).toList(),
    );
  }

  void _markDefeated(int index) {
    setState(() {
      _defeated.add(index);
      if (index >= _highestUnlocked && _highestUnlocked < _opponents.length - 1) {
        _highestUnlocked = index + 1;
      }
    });
    _saveProgress();
  }

  double _nodeOpacityForIndex(int index) {
    if (index <= _highestUnlocked) return 1.0;
    if (index <= _highestUnlocked + 3) return 0.35;
    return 0.0;
  }

  bool _isNodeTappable(int index) => index <= _highestUnlocked + 3;

  Future<void> _openBattleSheet(BuildContext context, int index) async {
    if (!_isNodeTappable(index)) return;

    final opp = _opponents[index];
    final alreadyDefeated = _defeated.contains(index);

    widget.onBattleStarted?.call();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Icon(opp.icon)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opp.name,
                              style: Theme.of(ctx).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(opp.subtitle,
                              style: Theme.of(ctx).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alreadyDefeated
                      ? 'Replay this opponent as many times as you like.'
                      : (index == _highestUnlocked
                      ? 'Defeat this opponent to unlock the next levels.'
                      : 'This level is previewable (transparent). Defeat the current level to permanently unlock it.'),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.sports_mma),
                        label: const Text('Start Battle'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.verified),
                        label: Text(
                            alreadyDefeated ? 'Mark Won Again' : 'Mark Defeated'),
                        onPressed: () {
                          _markDefeated(index);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------
  // Campaign path (BOTTOM -> TOP)
  // --------------------------
  List<Offset> _computeNodePositions({
    required Size size,
    required int count,
    required _IslandMap map,
    required double fullMapWidthPx,
  }) {
    // Step rule: 10..20 units (unless we must cross water, then longer allowed)
    final minStepPx = 10.0 * map.tilePx;
    final maxStepPx = 20.0 * map.tilePx;
    final targetStepPx = 15.0 * map.tilePx;

    // 1) Build an order that "hits every land mass" (square), mostly moving upward,
    //    minimizing distance, never self-intersecting.
    final polyline = _buildNonCrossingLandMassPath(
      map: map,
      worldSize: size,
      startWorld: Offset(fullMapWidthPx * 0.5, size.height - _bottomPad),
    );

    // 2) Sample node positions along this polyline from bottom -> top
    //    with target spacing, snapping to land when possible.
    final positions = <Offset>[];
    if (polyline.isEmpty) {
      // Fallback: keep something sane.
      for (int i = 0; i < count; i++) {
        final y = (size.height - _bottomPad) - i * _spacingY;
        positions.add(Offset(fullMapWidthPx * 0.5, y.clamp(_topPad, size.height - _bottomPad)));
      }
      return positions;
    }

    Offset current = _snapToLandOrNearby(polyline.first, map);
    positions.add(_ensureClearLand(current, map, fallback: polyline.first));

    int segIndex = 0;
    double segT = 0.0;
    double carried = 0.0;

    Offset segStart = polyline[0];
    Offset segEnd = polyline.length > 1 ? polyline[1] : polyline[0];
    double segLen = (segEnd - segStart).distance;

    int safety = 0;
    while (positions.length < count && safety++ < 20000) {
      // Advance along polyline by the amount needed to reach targetStep,
      // but keep within [minStep,maxStep] when we can.
      final last = positions.last;
      final want = targetStepPx;

      Offset? candidate;

      // Walk forward along the polyline until we've advanced "want" distance.
      double need = want;
      while (need > 0.0 && segIndex < polyline.length - 1) {
        if (segLen < 0.0001) {
          segIndex++;
          if (segIndex >= polyline.length - 1) break;
          segStart = polyline[segIndex];
          segEnd = polyline[segIndex + 1];
          segLen = (segEnd - segStart).distance;
          segT = 0.0;
          continue;
        }

        final remainingOnSeg = segLen * (1.0 - segT);
        if (need <= remainingOnSeg) {
          segT += need / segLen;
          final p = Offset.lerp(segStart, segEnd, segT)!;
          candidate = p;
          need = 0.0;
        } else {
          // consume segment
          need -= remainingOnSeg;
          segIndex++;
          if (segIndex >= polyline.length - 1) {
            candidate = segEnd;
            break;
          }
          segStart = polyline[segIndex];
          segEnd = polyline[segIndex + 1];
          segLen = (segEnd - segStart).distance;
          segT = 0.0;
        }
      }

      candidate ??= polyline.last;

      // Enforce "10..20 units unless crossing water".
      // We'll try to find a land point within maxStep; if we can't, we allow longer.
      Offset next = candidate;

      // Try to snap to land near the candidate (small perpendicular scan).
      next = _snapToLandOrNearby(next, map);

      // If still water, push forward along the polyline until we hit land
      // (this is the "can be longer if it needs to cross water" rule).
      if (!map.isLandAtWorld(next)) {
        next = _pushForwardUntilLand(
          start: candidate,
          map: map,
          polyline: polyline,
          startSegIndex: segIndex,
          startSegT: segT,
          maxExtraPx: 200.0 * map.tilePx, // generous; only used when crossing water
        );
      }

      // Distance check. If it's too short, nudge forward a bit.
      double d = (next - last).distance;
      if (d < minStepPx) {
        // Nudge forward along polyline by (minStep - d)
        next = _advanceAlongPolyline(
          polyline: polyline,
          fromPoint: candidate,
          additionalPx: (minStepPx - d),
          map: map,
        );
        next = _snapToLandOrNearby(next, map);
      }

      // If it's too long and it's not obviously a water-crossing, try to pull back.
      d = (next - last).distance;
      if (d > maxStepPx) {
        // If the straight segment between them is mostly land, we should compress.
        // Otherwise, allow long (water crossing).
        if (_mostlyLandBetween(last, next, map)) {
          next = _advanceAlongPolyline(
            polyline: polyline,
            fromPoint: last,
            additionalPx: maxStepPx,
            map: map,
          );
          next = _snapToLandOrNearby(next, map);
        }
      }

      next = _ensureClearLand(next, map, fallback: candidate);

      // Keep strictly "forward" bottom->top (non-increasing y), with a tiny tolerance.
      if (next.dy > last.dy + 2.0) {
        // Force it slightly upward.
        next = Offset(next.dx, last.dy - 2.0);
        next = _snapToLandOrNearby(next, map);
        next = _ensureClearLand(next, map, fallback: candidate);
      }

      positions.add(next);
    }

    // If we somehow didn't fill, pad upward.
    while (positions.length < count) {
      final last = positions.last;
      final p = Offset(last.dx, (last.dy - minStepPx).clamp(_topPad, size.height - _bottomPad));
      positions.add(_ensureClearLand(_snapToLandOrNearby(p, map), map, fallback: p));
    }

    return positions;
  }

  List<Offset> _buildNonCrossingLandMassPath({
    required _IslandMap map,
    required Size worldSize,
    required Offset startWorld,
  }) {
    // Build centers for each land mass (square).
    final centers = <Offset>[];
    for (final r in map.squaresUnits) {
      final cUnits = Offset(r.center.dx, r.center.dy);
      centers.add(Offset(cUnits.dx * map.tilePx, cUnits.dy * map.tilePx));
    }
    if (centers.isEmpty) return <Offset>[];

    // Choose start = closest center to our desired startWorld (bottom-ish).
    centers.sort((a, b) => (a - startWorld).distance.compareTo((b - startWorld).distance));
    final start = centers.first;

    final unvisited = <Offset>{...centers};
    unvisited.remove(start);

    final path = <Offset>[start];
    final segments = <_Seg>[];

    Offset cur = start;

    int safety = 0;
    while (unvisited.isNotEmpty && safety++ < 20000) {
      // Prefer forward (upward): target.dy < cur.dy
      final forward = <Offset>[];
      final backward = <Offset>[];
      for (final p in unvisited) {
        if (p.dy <= cur.dy) {
          forward.add(p);
        } else {
          backward.add(p);
        }
      }

      List<Offset> candidates;
      if (forward.isNotEmpty) {
        candidates = forward..sort((a, b) => (a - cur).distance.compareTo((b - cur).distance));
      } else {
        // Only allow doubling back if necessary.
        candidates = backward..sort((a, b) => (a - cur).distance.compareTo((b - cur).distance));
      }

      Offset? chosen;
      for (final next in candidates) {
        final newSeg = _Seg(cur, next);

        // Never cross itself
        bool crosses = false;
        for (final s in segments) {
          // Allow touching at endpoints with the most recent segment only (adjacent).
          if (s.a == cur || s.b == cur) continue;
          if (_segmentsIntersect(s.a, s.b, newSeg.a, newSeg.b)) {
            crosses = true;
            break;
          }
        }
        if (crosses) continue;

        chosen = next;
        break;
      }

      if (chosen == null) {
        // If everything would cross, try a slightly perturbed target (still "hit" that land mass),
        // by moving toward the center of its square a bit.
        // If still impossible, break (we'll at least have a non-crossing partial path).
        break;
      }

      segments.add(_Seg(cur, chosen));
      path.add(chosen);
      unvisited.remove(chosen);
      cur = chosen;
    }

    // Always finish by heading toward the top a bit so the path is clearly bottom->top.
    final topAnchor = Offset(cur.dx, _topPad);
    if ((topAnchor - cur).distance > 1.0) {
      // Only add if it doesn't cross.
      final newSeg = _Seg(cur, topAnchor);
      bool crosses = false;
      for (final s in segments) {
        if (s.a == cur || s.b == cur) continue;
        if (_segmentsIntersect(s.a, s.b, newSeg.a, newSeg.b)) {
          crosses = true;
          break;
        }
      }
      if (!crosses) path.add(topAnchor);
    }

    return path;
  }

  Offset _ensureClearLand(Offset p, _IslandMap map, {required Offset fallback}) {
    // Ensure land + a small neighborhood for nodes.
    if (map.isLandAtWorld(p) && map.isClearLandForNode(p, radiusPx: 18)) return p;

    // Spiral search near p for a clear land patch.
    final ts = map.tilePx;
    for (int r = 1; r <= 8; r++) {
      final double rr = r * ts * 1.2;
      for (int i = 0; i < 24; i++) {
        final a = (i / 24.0) * math.pi * 2.0;
        final q = Offset(p.dx + math.cos(a) * rr, p.dy + math.sin(a) * rr);
        if (map.isLandAtWorld(q) && map.isClearLandForNode(q, radiusPx: 18)) return q;
      }
    }

    // Worst-case: just return fallback (even if it's water), so UI doesn't crash.
    return fallback;
  }

  Offset _snapToLandOrNearby(Offset p, _IslandMap map) {
    if (map.isLandAtWorld(p)) return p;

    // Try perpendicular + small local grid search to snap onto nearby land.
    final ts = map.tilePx;
    for (int r = 1; r <= 10; r++) {
      final double rr = r * ts;
      // sample 16 points around
      for (int i = 0; i < 16; i++) {
        final a = (i / 16.0) * math.pi * 2.0;
        final q = Offset(p.dx + math.cos(a) * rr, p.dy + math.sin(a) * rr);
        if (map.isLandAtWorld(q)) return q;
      }
    }
    return p;
  }

  Offset _pushForwardUntilLand({
    required Offset start,
    required _IslandMap map,
    required List<Offset> polyline,
    required int startSegIndex,
    required double startSegT,
    required double maxExtraPx,
  }) {
    // Walk forward along the polyline up to maxExtraPx, return first land point.
    double advanced = 0.0;

    int segIndex = startSegIndex;
    double segT = startSegT;

    Offset segStart = polyline[segIndex.clamp(0, polyline.length - 1)];
    Offset segEnd = polyline[(segIndex + 1).clamp(0, polyline.length - 1)];
    double segLen = (segEnd - segStart).distance;

    // If start is behind polyline state, just begin from start point toward the next vertex.
    Offset cur = start;

    while (advanced <= maxExtraPx && segIndex < polyline.length - 1) {
      // Sample along current segment in small increments.
      const int steps = 24;
      for (int i = 1; i <= steps; i++) {
        final t = (i / steps);
        final p = Offset.lerp(cur, segEnd, t)!;
        advanced += (p - cur).distance;
        cur = p;
        if (map.isLandAtWorld(cur)) return cur;
        if (advanced > maxExtraPx) return start;
      }

      segIndex++;
      if (segIndex >= polyline.length - 1) break;
      segStart = polyline[segIndex];
      segEnd = polyline[segIndex + 1];
      segLen = (segEnd - segStart).distance;
      if (segLen < 0.0001) continue;
      cur = segStart;
    }

    return start;
  }

  Offset _advanceAlongPolyline({
    required List<Offset> polyline,
    required Offset fromPoint,
    required double additionalPx,
    required _IslandMap map,
  }) {
    // Find nearest segment to "fromPoint" (cheap: just scan).
    int bestSeg = 0;
    double bestDist = double.infinity;
    double bestT = 0.0;

    for (int i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final ab = b - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (ab2 < 1e-6) continue;
      final ap = fromPoint - a;
      double t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
      t = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      final d = (proj - fromPoint).distance;
      if (d < bestDist) {
        bestDist = d;
        bestSeg = i;
        bestT = t;
      }
    }

    int segIndex = bestSeg;
    double segT = bestT;

    Offset segStart = polyline[segIndex];
    Offset segEnd = polyline[segIndex + 1];
    double segLen = (segEnd - segStart).distance;

    double need = additionalPx;

    while (need > 0 && segIndex < polyline.length - 1) {
      if (segLen < 1e-6) {
        segIndex++;
        if (segIndex >= polyline.length - 1) break;
        segStart = polyline[segIndex];
        segEnd = polyline[segIndex + 1];
        segLen = (segEnd - segStart).distance;
        segT = 0.0;
        continue;
      }

      final remainingOnSeg = segLen * (1.0 - segT);
      if (need <= remainingOnSeg) {
        segT += need / segLen;
        return Offset.lerp(segStart, segEnd, segT)!;
      } else {
        need -= remainingOnSeg;
        segIndex++;
        if (segIndex >= polyline.length - 1) return polyline.last;
        segStart = polyline[segIndex];
        segEnd = polyline[segIndex + 1];
        segLen = (segEnd - segStart).distance;
        segT = 0.0;
      }
    }

    return polyline.last;
  }

  bool _mostlyLandBetween(Offset a, Offset b, _IslandMap map) {
    // Sample along the straight segment and see if at least ~70% of samples are land.
    const int samples = 24;
    int landCount = 0;
    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final p = Offset.lerp(a, b, t)!;
      if (map.isLandAtWorld(p)) landCount++;
    }
    return landCount >= (samples * 0.70).floor();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        // World height is based on TOTAL campaign length so it stays stable.
        final fullCount = _opponents.length;
        final mapHeight = _topPad + (fullCount - 1) * _spacingY + _bottomPad;

        // Phone width corresponds to 50 units.
        final double unitsVisible = 50.0;
        final double tilePx = constraints.maxWidth / unitsVisible;

        // World width is 100 units.
        const double worldUnitsW = 100.0;
        final double worldWidthPx = worldUnitsW * tilePx;

        final size = Size(worldWidthPx, mapHeight);

        // Generate islands deterministically.
        // IMPORTANT: seed land near the FIRST NODE which is now at the BOTTOM.
        final firstNodeWorld =
        Offset(worldWidthPx * 0.5, mapHeight - _bottomPad);

        final islandMap = _IslandMap.generate(
          seed: _seed,
          tilePx: tilePx,
          worldUnitsW: worldUnitsW.toInt(),
          worldPxSize: size,
          firstNodeWorld: firstNodeWorld,
        );

        // Compute node positions for all nodes (stable), but render only visible.
        final allPositions = _computeNodePositions(
          size: size,
          count: fullCount,
          map: islandMap,
          fullMapWidthPx: worldWidthPx,
        );

        final visibleCount = (_maxVisibleIndex + 1).clamp(1, fullCount);

        return Scrollbar(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _IslandMapPainter(
                          map: islandMap,
                          nodePositions: allPositions,
                          highestUnlocked: _highestUnlocked,
                          maxVisibleIndex: _maxVisibleIndex,
                        ),
                      ),
                    ),
                    for (int i = 0; i < visibleCount; i++)
                      _CampaignNodeOverlay(
                        position: allPositions[i],
                        radius: _nodeRadius,
                        opacity: _nodeOpacityForIndex(i),
                        isDefeated: _defeated.contains(i),
                        isCurrent: i == _highestUnlocked,
                        icon: _opponents[i].icon,
                        title: _opponents[i].name,
                        subtitle: _opponents[i].subtitle,
                        tappable: _isNodeTappable(i),
                        onTap: () => _openBattleSheet(context, i),
                        viewportWidth: constraints.maxWidth,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OpponentNode {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  const _OpponentNode({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

class _CampaignNodeOverlay extends StatelessWidget {
  final Offset position;
  final double radius;
  final double opacity;
  final bool isDefeated;
  final bool isCurrent;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool tappable;
  final VoidCallback onTap;
  final double viewportWidth;

  const _CampaignNodeOverlay({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.isDefeated,
    required this.isCurrent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tappable,
    required this.onTap,
    required this.viewportWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final Color nodeColor =
    isDefeated ? theme.colorScheme.secondary : theme.colorScheme.primary;
    final Color borderColor = theme.colorScheme.surface;

    // Place card to the side depending on where the node is within the viewport width.
    // (This doesn’t know the scroll offset; it’s “good enough” for now.)
    final bool cardOnRight =
        (position.dx % (viewportWidth * 1.0)) < (viewportWidth / 2);
    final Offset cardOffset =
    cardOnRight ? const Offset(28, -22) : const Offset(-248, -22);

    final Widget node = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: nodeColor,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            blurRadius: isCurrent ? 18 : 12,
            spreadRadius: isCurrent ? 2 : 1,
            color: theme.shadowColor.withOpacity(isCurrent ? 0.22 : 0.14),
          ),
        ],
      ),
      child: isDefeated
          ? Icon(Icons.done, size: 16, color: theme.colorScheme.onSecondary)
          : null,
    );

    final Widget card = Material(
      color: theme.cardColor,
      elevation: isCurrent ? 6 : 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isDefeated) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle,
                    size: 16, color: theme.colorScheme.secondary),
              ],
            ],
          ),
        ),
      ),
    );

    return Opacity(
      opacity: opacity,
      child: Stack(
        children: [
          Positioned(
            left: position.dx - radius,
            top: position.dy - radius,
            child: IgnorePointer(
              ignoring: !tappable,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tappable ? onTap : null,
                child: node,
              ),
            ),
          ),
          Positioned(
            left: position.dx + cardOffset.dx,
            top: position.dy + cardOffset.dy,
            child: IgnorePointer(
              ignoring: !tappable,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tappable ? onTap : null,
                child: card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =========================
/// ISLAND MAP (ONLY LAND/WATER)
/// =========================
/// World is 100 units wide.
/// Viewport is 50 units wide (because tilePx is computed from screenWidth/50).
///
/// Islands are axis-aligned squares:
/// - size: 10..100 units
/// - minimum water gap between any two squares: 10 units
/// - any water region containing a >30x30 axis-aligned all-water square must be
///   broken up by stamping a new land square into it.
class _IslandMap {
  final int seed;
  final double tilePx;

  final int worldUnitsW; // 100
  final int worldUnitsH; // derived from height/tilePx

  // Land mask per unit-cell
  final List<bool> land;

  // Squares (in unit coordinates)
  final List<Rect> squaresUnits;

  _IslandMap({
    required this.seed,
    required this.tilePx,
    required this.worldUnitsW,
    required this.worldUnitsH,
    required this.land,
    required this.squaresUnits,
  });

  static _IslandMap generate({
    required int seed,
    required double tilePx,
    required int worldUnitsW,
    required Size worldPxSize,
    required Offset firstNodeWorld,
  }) {
    final worldUnitsH = math.max(60, (worldPxSize.height / tilePx).ceil());

    final land = List<bool>.filled(worldUnitsW * worldUnitsH, false);
    int idx(int x, int y) => y * worldUnitsW + x;
    bool inside(int x, int y) =>
        x >= 0 && y >= 0 && x < worldUnitsW && y < worldUnitsH;

    final rng = math.Random(_mixSeed(seed, 70001));

    final squares = <Rect>[];

    void stampSquare(Rect r) {
      final left = r.left.floor();
      final top = r.top.floor();
      final right = r.right.ceil();
      final bottom = r.bottom.ceil();
      for (int y = top; y < bottom; y++) {
        for (int x = left; x < right; x++) {
          if (!inside(x, y)) continue;
          land[idx(x, y)] = true;
        }
      }
    }

    bool minGapOk(Rect a, Rect b, {required int minGap}) {
      final dx = (b.left > a.right)
          ? (b.left - a.right)
          : (a.left > b.right)
          ? (a.left - b.right)
          : 0.0;
      final dy = (b.top > a.bottom)
          ? (b.top - a.bottom)
          : (a.top > b.bottom)
          ? (a.top - b.bottom)
          : 0.0;

      final gap = math.max(dx, dy);
      return gap >= minGap;
    }

    bool canPlaceSquare(Rect candidate, {required int minGap}) {
      for (final s in squares) {
        if (!minGapOk(candidate, s, minGap: minGap)) return false;
      }
      return true;
    }

    // Seed land under the FIRST campaign node (now bottom-ish).
    final sx = (firstNodeWorld.dx / tilePx).floor().clamp(0, worldUnitsW - 1);
    final sy = (firstNodeWorld.dy / tilePx).floor().clamp(0, worldUnitsH - 1);

    Rect seedSquare = Rect.fromLTWH(
      (sx - 12).toDouble().clamp(0.0, (worldUnitsW - 1).toDouble()),
      (sy - 12).toDouble().clamp(0.0, (worldUnitsH - 1).toDouble()),
      24,
      24,
    );

    seedSquare = Rect.fromLTWH(
      seedSquare.left.clamp(0.0, (worldUnitsW - 24).toDouble()),
      seedSquare.top.clamp(0.0, (worldUnitsH - 24).toDouble()),
      seedSquare.width,
      seedSquare.height,
    );

    squares.add(seedSquare);
    stampSquare(seedSquare);

    const int minGap = 10;

    final target = (6 + (worldUnitsH / 80).floor()).clamp(6, 12);

    int attempts = 0;
    while (squares.length < target && attempts < 12000) {
      attempts++;

      final int size = 10 + rng.nextInt(91); // 10..100
      final int x = rng.nextInt(math.max(1, worldUnitsW - size));
      final int y = rng.nextInt(math.max(1, worldUnitsH - size));

      final candidate = Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        size.toDouble(),
        size.toDouble(),
      );

      if (!canPlaceSquare(candidate, minGap: minGap)) continue;

      squares.add(candidate);
      stampSquare(candidate);
    }

    // Break up any too-large water (any 31x31 all-water window).
    const int waterLimit = 30;
    const int window = waterLimit + 1; // 31
    const int scanStep = 15;

    bool windowHasAnyLand(int wx, int wy) {
      for (int y = wy; y < wy + window; y++) {
        for (int x = wx; x < wx + window; x++) {
          if (inside(x, y) && land[idx(x, y)]) return true;
        }
      }
      return false;
    }

    bool fixWindow(int wx, int wy) {
      final int maxPlace = math.min(30, 100);
      for (int t = 0; t < 120; t++) {
        final int size = 10 + rng.nextInt(maxPlace - 10 + 1);

        final int maxX = (wx + window - size).clamp(0, worldUnitsW - size);
        final int maxY = (wy + window - size).clamp(0, worldUnitsH - size);
        final int minX = wx.clamp(0, worldUnitsW - size);
        final int minY = wy.clamp(0, worldUnitsH - size);

        if (maxX < minX || maxY < minY) continue;

        final int x = minX + rng.nextInt((maxX - minX) + 1);
        final int y = minY + rng.nextInt((maxY - minY) + 1);

        final candidate = Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          size.toDouble(),
          size.toDouble(),
        );

        if (!canPlaceSquare(candidate, minGap: minGap)) continue;

        squares.add(candidate);
        stampSquare(candidate);
        return true;
      }
      return false;
    }

    for (int pass = 0; pass < 4; pass++) {
      bool changed = false;

      final int maxWx = math.max(0, worldUnitsW - window);
      final int maxWy = math.max(0, worldUnitsH - window);

      for (int wy = 0; wy <= maxWy; wy += scanStep) {
        for (int wx = 0; wx <= maxWx; wx += scanStep) {
          if (windowHasAnyLand(wx, wy)) continue;
          if (fixWindow(wx, wy)) changed = true;
        }
      }

      if (!changed) break;
    }

    return _IslandMap(
      seed: seed,
      tilePx: tilePx,
      worldUnitsW: worldUnitsW,
      worldUnitsH: worldUnitsH,
      land: land,
      squaresUnits: squares,
    );
  }

  bool isLandUnit(int x, int y) {
    if (x < 0 || y < 0 || x >= worldUnitsW || y >= worldUnitsH) return false;
    return land[y * worldUnitsW + x];
  }

  bool isLandAtWorld(Offset p) {
    final x = (p.dx / tilePx).floor();
    final y = (p.dy / tilePx).floor();
    return isLandUnit(x, y);
  }

  bool isClearLandForNode(Offset p, {required double radiusPx}) {
    final cx = (p.dx / tilePx).floor();
    final cy = (p.dy / tilePx).floor();
    if (cx < 0 || cy < 0 || cx >= worldUnitsW || cy >= worldUnitsH) {
      return false;
    }

    final r = (radiusPx / tilePx).ceil().clamp(1, 5);
    for (int oy = -r; oy <= r; oy++) {
      for (int ox = -r; ox <= r; ox++) {
        if (!isLandUnit(cx + ox, cy + oy)) return false;
      }
    }
    return true;
  }
}

/// =========================
/// PAINTER
/// =========================
class _IslandMapPainter extends CustomPainter {
  final _IslandMap map;
  final List<Offset> nodePositions;
  final int highestUnlocked;
  final int maxVisibleIndex;

  _IslandMapPainter({
    required this.map,
    required this.nodePositions,
    required this.highestUnlocked,
    required this.maxVisibleIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const water = Color(0xFF7EAAC0);
    const land = Color(0xFFE3C991);
    const ink = Color(0xFF2A2116);

    canvas.drawRect(Offset.zero & size, Paint()..color = water);

    final ts = map.tilePx;
    final paint = Paint()..color = land;

    for (int y = 0; y < map.worldUnitsH; y++) {
      for (int x = 0; x < map.worldUnitsW; x++) {
        if (!map.isLandUnit(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * ts, y * ts, ts + 0.5, ts + 0.5),
          paint,
        );
      }
    }

    // Dashed trail between visible nodes (now bottom->top order in nodePositions)
    for (int i = 0; i < nodePositions.length - 1; i++) {
      if (i + 1 > maxVisibleIndex) break;

      final a = nodePositions[i];
      final b = nodePositions[i + 1];

      final opaque = (i + 1) <= highestUnlocked;
      final alpha = opaque ? 0.55 : 0.22;

      _drawDashedLine(
        canvas,
        a,
        b,
        color: ink.withOpacity(alpha),
        dash: 10,
        gap: 8,
        strokeWidth: 2.1,
      );
    }

    final rect = Offset.zero & size;
    final fog = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.10,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.06),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, fog);
  }

  void _drawDashedLine(
      Canvas canvas,
      Offset start,
      Offset end, {
        required Color color,
        required double dash,
        required double gap,
        required double strokeWidth,
      }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= 0.0001) return;

    final ux = dx / dist;
    final uy = dy / dist;

    double t = 0.0;
    while (t < dist) {
      final t2 = math.min(dist, t + dash);
      canvas.drawLine(
        Offset(start.dx + ux * t, start.dy + uy * t),
        Offset(start.dx + ux * t2, start.dy + uy * t2),
        paint,
      );
      t += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _IslandMapPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.nodePositions != nodePositions ||
        oldDelegate.highestUnlocked != highestUnlocked ||
        oldDelegate.maxVisibleIndex != maxVisibleIndex;
  }
}

/// Small segment helper
class _Seg {
  final Offset a;
  final Offset b;
  const _Seg(this.a, this.b);
}

/// Segment intersection (proper, excluding colinear overlap as "intersect")
bool _segmentsIntersect(Offset p1, Offset p2, Offset q1, Offset q2) {
  bool ccw(Offset a, Offset b, Offset c) {
    return (c.dy - a.dy) * (b.dx - a.dx) > (b.dy - a.dy) * (c.dx - a.dx);
  }

  // Fast reject by bbox
  double minX1 = math.min(p1.dx, p2.dx), maxX1 = math.max(p1.dx, p2.dx);
  double minY1 = math.min(p1.dy, p2.dy), maxY1 = math.max(p1.dy, p2.dy);
  double minX2 = math.min(q1.dx, q2.dx), maxX2 = math.max(q1.dx, q2.dx);
  double minY2 = math.min(q1.dy, q2.dy), maxY2 = math.max(q1.dy, q2.dy);
  if (maxX1 < minX2 || maxX2 < minX1 || maxY1 < minY2 || maxY2 < minY1) {
    return false;
  }

  // General case
  return ccw(p1, q1, q2) != ccw(p2, q1, q2) && ccw(p1, p2, q1) != ccw(p1, p2, q2);
}

/// Deterministic integer mixing (stable across runs).
int _mixSeed(int seed, int index) {
  int x = seed ^ (index * 0x9E3779B9);
  x = (x ^ (x >> 16)) * 0x7feb352d;
  x = (x ^ (x >> 15)) * 0x846ca68b;
  x = x ^ (x >> 16);
  return x & 0x7fffffff;
}
