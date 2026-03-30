import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const HoloApp());
}

class HoloApp extends StatelessWidget {
  const HoloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Holo Chess',
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

/// Change this whenever you push a meaningful update.
const String gameVersion = "v0.4.0-monsters-abilities";

/// ===============================================================
/// CORE TYPES
/// ===============================================================

enum Player { one, two }

enum UnitType { brute, striker, mystic, tentacle }

extension PlayerColor on Player {
  Color get color => this == Player.one ? Colors.cyanAccent : Colors.redAccent;
  String get label => this == Player.one ? "Player 1" : "Player 2";
}

class BoardPos {
  final int ring;
  final int sector;

  const BoardPos(this.ring, this.sector);

  @override
  bool operator ==(Object other) =>
      other is BoardPos && other.ring == ring && other.sector == sector;

  @override
  int get hashCode => Object.hash(ring, sector);

  @override
  String toString() => "($ring,$sector)";
}

class Unit {
  final UnitType type;
  final Player owner;
  int hp;
  bool abilityUsedThisTurn;

  Unit(
    this.type,
    this.owner,
    this.hp, {
    this.abilityUsedThisTurn = false,
  });

  int get maxHp => switch (type) {
        UnitType.brute => 12,
        UnitType.striker => 8,
        UnitType.mystic => 10,
        UnitType.tentacle => 9,
      };

  int get atk => switch (type) {
        UnitType.brute => 4,
        UnitType.striker => 3,
        UnitType.mystic => 2,
        UnitType.tentacle => 3,
      };

  int get range => switch (type) {
        UnitType.brute => 1,
        UnitType.striker => 1,
        UnitType.mystic => 2,
        UnitType.tentacle => 2,
      };

  int get move => switch (type) {
        UnitType.brute => 1,
        UnitType.striker => 2,
        UnitType.mystic => 1,
        UnitType.tentacle => 1,
      };

  String get name => switch (type) {
        UnitType.brute => "Brute",
        UnitType.striker => "Striker",
        UnitType.mystic => "Mystic",
        UnitType.tentacle => "Tentacle",
      };

  String get description => switch (type) {
        UnitType.brute => "Heavy front-line monster. Big HP and damage.",
        UnitType.striker => "Fast attacker. Good at repositioning.",
        UnitType.mystic => "Floating ranged support creature.",
        UnitType.tentacle => "Control unit with mid-range pressure.",
      };

  String get abilityName => switch (type) {
        UnitType.brute => "Shockwave",
        UnitType.striker => "Sprint",
        UnitType.mystic => "Heal",
        UnitType.tentacle => "Beam Lash",
      };

  String get abilityDescription => switch (type) {
        UnitType.brute =>
          "Damages all adjacent enemies after moving into place.",
        UnitType.striker =>
          "Moves one extra space this turn.",
        UnitType.mystic =>
          "Heals itself after moving.",
        UnitType.tentacle =>
          "Hits the nearest enemy in extended range after moving.",
      };
}

/// ===============================================================
/// GAME STATE
/// ===============================================================

class GameState {
  static const int ringCount = 3;
  static const int sectorCount = 8;

  final Map<BoardPos, Unit> units = {};
  Player turn = Player.one;
  bool gameOver = false;
  Player? winner;
  String status = "Player 1 to move";

  int playerOneScore = 0;
  int playerTwoScore = 0;

  GameState() {
    // ------------------------------------------------------------
    // Starting layout.
    // Easy hack point:
    // change unit types or positions here.
    // ------------------------------------------------------------
    units[const BoardPos(2, 0)] = Unit(UnitType.brute, Player.one, 12);
    units[const BoardPos(2, 2)] = Unit(UnitType.striker, Player.one, 8);
    units[const BoardPos(2, 4)] = Unit(UnitType.mystic, Player.one, 10);
    units[const BoardPos(2, 6)] = Unit(UnitType.tentacle, Player.one, 9);

    units[const BoardPos(0, 0)] = Unit(UnitType.brute, Player.two, 12);
    units[const BoardPos(0, 2)] = Unit(UnitType.striker, Player.two, 8);
    units[const BoardPos(0, 4)] = Unit(UnitType.mystic, Player.two, 10);
    units[const BoardPos(0, 6)] = Unit(UnitType.tentacle, Player.two, 9);
  }

  Unit? unitAt(BoardPos pos) => units[pos];

  void move(BoardPos from, BoardPos to) {
    final unit = units.remove(from);
    if (unit != null) {
      units[to] = unit;
    }
  }

  void damage(BoardPos target, int amount, {Player? source}) {
    final unit = units[target];
    if (unit == null) return;

    unit.hp -= amount;
    if (unit.hp <= 0) {
      units.remove(target);

      if (source == Player.one) {
        playerOneScore += unit.maxHp + unit.atk;
      } else if (source == Player.two) {
        playerTwoScore += unit.maxHp + unit.atk;
      }
    }
  }

  void heal(BoardPos target, int amount) {
    final unit = units[target];
    if (unit == null) return;
    unit.hp = math.min(unit.maxHp, unit.hp + amount);
  }

  bool checkWin() {
    final aliveOwners = units.values.map((u) => u.owner).toSet();
    if (aliveOwners.length <= 1) {
      gameOver = true;
      winner = aliveOwners.isEmpty ? null : aliveOwners.first;
      return true;
    }
    return false;
  }

  void endTurn() {
    for (final unit in units.values) {
      if (unit.owner == turn) {
        unit.abilityUsedThisTurn = false;
      }
    }
    turn = turn == Player.one ? Player.two : Player.one;
    status = '${turn.label} to move';
  }
}

/// ===============================================================
/// GAME PAGE
/// ===============================================================

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameState state = GameState();

  BoardPos? selected;
  BoardPos? pendingMove;

  List<BoardPos> moves = [];
  List<BoardPos> targets = [];

  bool abilityMode = false;
  bool waitingForPostMoveAttack = false;

  void restartGame() {
    setState(() {
      state = GameState();
      clearSelection();
    });
  }

  void clearSelection() {
    selected = null;
    pendingMove = null;
    moves = [];
    targets = [];
    abilityMode = false;
    waitingForPostMoveAttack = false;
  }

  void select(BoardPos pos) {
    final unit = state.unitAt(pos);
    if (unit == null || unit.owner != state.turn) return;

    setState(() {
      selected = pos;
      pendingMove = null;
      abilityMode = false;
      waitingForPostMoveAttack = false;
      moves = getMoves(unit, pos);
      targets = getTargets(unit, pos);
      state.status = 'Choose move, attack, or ability';
    });
  }

  void startAbilityMode() {
    if (selected == null) return;
    final unit = state.unitAt(selected!);
    if (unit == null) return;
    if (unit.abilityUsedThisTurn) return;

    setState(() {
      abilityMode = true;
      waitingForPostMoveAttack = false;
      moves = getAbilityMoves(unit, selected!);
      targets = [];
      state.status = 'Choose destination for ${unit.abilityName}';
    });
  }

  void tap(BoardPos pos) {
    if (state.gameOver) return;

    final tappedUnit = state.unitAt(pos);

    // Selecting your own unit.
    if (tappedUnit != null && tappedUnit.owner == state.turn) {
      select(pos);
      return;
    }

    if (selected == null) return;
    final unit = state.unitAt(selected!);
    if (unit == null) return;

    // ------------------------------------------------------------
    // Ability flow
    // ------------------------------------------------------------
    if (abilityMode) {
      if (!moves.contains(pos)) return;

      setState(() {
        performAbility(unit, selected!, pos);
        state.checkWin();
        if (!state.gameOver) {
          state.endTurn();
        }
        clearSelection();
      });
      return;
    }

    // ------------------------------------------------------------
    // Direct attack from current location
    // ------------------------------------------------------------
    if (targets.contains(pos) && !waitingForPostMoveAttack) {
      setState(() {
        state.damage(pos, unit.atk, source: unit.owner);
        state.checkWin();
        if (!state.gameOver) {
          state.endTurn();
        }
        clearSelection();
      });
      return;
    }

    // ------------------------------------------------------------
    // Move first
    // ------------------------------------------------------------
    if (moves.contains(pos) && !waitingForPostMoveAttack) {
      final newTargets = getTargetsAfterMove(unit, selected!, pos);

      setState(() {
        pendingMove = pos;
        waitingForPostMoveAttack = true;
        moves = [];
        targets = newTargets;

        if (newTargets.isEmpty) {
          state.move(selected!, pos);
          state.endTurn();
          clearSelection();
        } else {
          state.status = 'Choose target after moving';
        }
      });
      return;
    }

    // ------------------------------------------------------------
    // Attack after moving
    // ------------------------------------------------------------
    if (waitingForPostMoveAttack && pendingMove != null && targets.contains(pos)) {
      setState(() {
        state.move(selected!, pendingMove!);
        state.damage(pos, unit.atk, source: unit.owner);
        state.checkWin();
        if (!state.gameOver) {
          state.endTurn();
        }
        clearSelection();
      });
      return;
    }

    // Tap elsewhere clears current selection.
    setState(() {
      clearSelection();
      state.status = '${state.turn.label} to move';
    });
  }

  // =============================================================
  // CORE ROUND-BOARD MOVEMENT RULES
  // =============================================================

  List<BoardPos> getAdjacent(BoardPos pos) {
    return [
      BoardPos(pos.ring, (pos.sector + 1) % GameState.sectorCount),
      BoardPos(
        pos.ring,
        (pos.sector - 1 + GameState.sectorCount) % GameState.sectorCount,
      ),
      if (pos.ring > 0) BoardPos(pos.ring - 1, pos.sector),
      if (pos.ring < GameState.ringCount - 1) BoardPos(pos.ring + 1, pos.sector),
    ];
  }

  int distance(BoardPos start, BoardPos end) {
    if (start == end) return 0;

    final queue = <BoardPos>[start];
    final distances = <BoardPos, int>{start: 0};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDistance = distances[current]!;

      for (final next in getAdjacent(current)) {
        if (distances.containsKey(next)) continue;

        distances[next] = currentDistance + 1;
        if (next == end) {
          return distances[next]!;
        }
        queue.add(next);
      }
    }

    return 999;
  }

  List<BoardPos> getMoves(Unit unit, BoardPos start) {
    final visited = <BoardPos, int>{start: 0};
    final queue = <BoardPos>[start];
    final result = <BoardPos>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final dist = visited[current]!;

      if (dist >= unit.move) continue;

      for (final next in getAdjacent(current)) {
        if (state.unitAt(next) != null) continue;
        if (visited.containsKey(next)) continue;
        visited[next] = dist + 1;
        result.add(next);
        queue.add(next);
      }
    }

    return result.toList();
  }

  List<BoardPos> getAbilityMoves(Unit unit, BoardPos start) {
    final bonusMove = unit.type == UnitType.striker ? unit.move + 1 : unit.move;
    final visited = <BoardPos, int>{start: 0};
    final queue = <BoardPos>[start];
    final result = <BoardPos>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final dist = visited[current]!;

      if (dist >= bonusMove) continue;

      for (final next in getAdjacent(current)) {
        if (state.unitAt(next) != null) continue;
        if (visited.containsKey(next)) continue;
        visited[next] = dist + 1;
        result.add(next);
        queue.add(next);
      }
    }

    return result.toList();
  }

  List<BoardPos> getTargets(Unit unit, BoardPos pos) {
    return state.units.entries
        .where((e) => e.value.owner != unit.owner)
        .where((e) => distance(pos, e.key) <= unit.range)
        .map((e) => e.key)
        .toList();
  }

  List<BoardPos> getTargetsAfterMove(Unit unit, BoardPos from, BoardPos to) {
    return state.units.entries
        .where((e) => e.value.owner != unit.owner)
        .where((e) => distance(to, e.key) <= unit.range)
        .map((e) => e.key)
        .toList();
  }

  // =============================================================
  // ABILITIES
  // =============================================================

  void performAbility(Unit unit, BoardPos from, BoardPos to) {
    state.move(from, to);
    unit.abilityUsedThisTurn = true;

    switch (unit.type) {
      case UnitType.brute:
        // Shockwave: damage all adjacent enemies for 1.
        for (final adj in getAdjacent(to)) {
          final target = state.unitAt(adj);
          if (target != null && target.owner != unit.owner) {
            state.damage(adj, 1, source: unit.owner);
          }
        }
        break;

      case UnitType.striker:
        // Sprint: handled by +1 movement in getAbilityMoves.
        break;

      case UnitType.mystic:
        // Heal: recover 2 HP after moving.
        state.heal(to, 2);
        break;

      case UnitType.tentacle:
        // Beam Lash: nearest enemy in extended range 3 takes 1 damage.
        final possibleTargets = state.units.entries
            .where((e) => e.value.owner != unit.owner)
            .where((e) => distance(to, e.key) <= 3)
            .toList();

        if (possibleTargets.isNotEmpty) {
          possibleTargets.sort(
            (a, b) => distance(to, a.key).compareTo(distance(to, b.key)),
          );
          state.damage(possibleTargets.first.key, 1, source: unit.owner);
        }
        break;
    }
  }

  Offset getOffset(BoardPos pos, double boardSize) {
    final center = Offset(boardSize / 2, boardSize / 2);
    final radiusStep = boardSize * 0.38 / GameState.ringCount;
    final r = (pos.ring + 1) * radiusStep;
    final angle = (2 * math.pi / GameState.sectorCount) * pos.sector - math.pi / 2;

    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  }

  Widget _choiceChip({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF173447),
      backgroundColor: const Color(0xFF0B1623),
      side: BorderSide(
        color: selected ? Colors.cyanAccent : Colors.white24,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.cyanAccent : Colors.white70,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _scoreBlock(String label, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$score',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String selectedText() {
    if (selected == null) return 'None';
    final unit = state.unitAt(selected!);
    if (unit == null) return 'None';
    return '${unit.name} @ ${selected.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedUnit = selected != null ? state.unitAt(selected!) : null;
    final isWide = MediaQuery.of(context).size.width >= 1000;
    const boardSize = 360.0;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HoloBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isWide
                  ? Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              _buildTopBar(),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Center(
                                  child: SizedBox(
                                    width: boardSize,
                                    height: boardSize,
                                    child: Stack(
                                      children: [
                                        CustomPaint(
                                          size: const Size(boardSize, boardSize),
                                          painter: RoundBoardPainter(),
                                        ),
                                        ...List.generate(GameState.ringCount, (ring) {
                                          return List.generate(GameState.sectorCount, (sector) {
                                            final pos = BoardPos(ring, sector);
                                            final offset = getOffset(pos, boardSize);
                                            final unit = state.unitAt(pos);

                                            final isSelected = selected == pos;
                                            final isMove = moves.contains(pos);
                                            final isTarget = targets.contains(pos);

                                            return Positioned(
                                              left: offset.dx - 30,
                                              top: offset.dy - 30,
                                              width: 60,
                                              height: 60,
                                              child: GestureDetector(
                                                onTap: () => unit != null &&
                                                        unit.owner == state.turn
                                                    ? select(pos)
                                                    : tap(pos),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isSelected
                                                        ? const Color(0x2247F1FF)
                                                        : isMove
                                                            ? const Color(0x22FFD56A)
                                                            : isTarget
                                                                ? const Color(0x33FF5A93)
                                                                : Colors.transparent,
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? Colors.cyanAccent
                                                          : isMove
                                                              ? const Color(0xFFFFD56A)
                                                              : isTarget
                                                                  ? Colors.redAccent
                                                                  : Colors.transparent,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: unit == null
                                                      ? const SizedBox.shrink()
                                                      : Center(child: BeastToken(unit: unit)),
                                                ),
                                              ),
                                            );
                                          });
                                        }).expand((e) => e),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedUnit != null) ...[
                                const SizedBox(height: 12),
                                _buildSelectedUnitPanel(selectedUnit),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildControlsPanel(selectedUnit),
                                const SizedBox(height: 8),
                                HoloPanel(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _scoreBlock(
                                        'Player 1',
                                        state.playerOneScore,
                                        Colors.cyanAccent,
                                      ),
                                      _scoreBlock(
                                        'Player 2',
                                        state.playerTwoScore,
                                        Colors.redAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(boardSize, boardSize),
                                    painter: RoundBoardPainter(),
                                  ),
                                  ...List.generate(GameState.ringCount, (ring) {
                                    return List.generate(GameState.sectorCount, (sector) {
                                      final pos = BoardPos(ring, sector);
                                      final offset = getOffset(pos, boardSize);
                                      final unit = state.unitAt(pos);

                                      final isSelected = selected == pos;
                                      final isMove = moves.contains(pos);
                                      final isTarget = targets.contains(pos);

                                      return Positioned(
                                        left: offset.dx - 30,
                                        top: offset.dy - 30,
                                        width: 60,
                                        height: 60,
                                        child: GestureDetector(
                                          onTap: () => unit != null &&
                                                  unit.owner == state.turn
                                              ? select(pos)
                                              : tap(pos),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? const Color(0x2247F1FF)
                                                  : isMove
                                                      ? const Color(0x22FFD56A)
                                                      : isTarget
                                                          ? const Color(0x33FF5A93)
                                                          : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.cyanAccent
                                                    : isMove
                                                        ? const Color(0xFFFFD56A)
                                                        : isTarget
                                                            ? Colors.redAccent
                                                            : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: unit == null
                                                ? const SizedBox.shrink()
                                                : Center(child: BeastToken(unit: unit)),
                                          ),
                                        ),
                                      );
                                    });
                                  }).expand((e) => e),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (selectedUnit != null) ...[
                          const SizedBox(height: 10),
                          _buildSelectedUnitPanel(selectedUnit),
                        ],
                        const SizedBox(height: 10),
                        HoloPanel(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _scoreBlock(
                                'Player 1',
                                state.playerOneScore,
                                Colors.cyanAccent,
                              ),
                              _scoreBlock(
                                'Player 2',
                                state.playerTwoScore,
                                Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                        if (showControls) ...[
                          const SizedBox(height: 8),
                          _buildControlsPanel(selectedUnit),
                        ],
                      ],
                    ),
            ),
          ),
          if (state.gameOver)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: HoloPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.winner == null
                                ? 'Match Over'
                                : '${state.winner!.label} Wins',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(state.status),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: restartGame,
                            child: const Text('Play Again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return HoloPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "HOLO CHESS",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  state.status,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const Text(
                  gameVersion,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          HoloIconMiniButton(
            icon: Icons.help_outline,
            onPressed: _showHowToPlay,
          ),
          const SizedBox(width: 6),
          HoloIconMiniButton(
            icon: Icons.refresh,
            onPressed: restartGame,
          ),
          const SizedBox(width: 6),
          HoloIconMiniButton(
            icon: showControls ? Icons.expand_less : Icons.tune,
            onPressed: () {
              setState(() {
                showControls = !showControls;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedUnitPanel(Unit selectedUnit) {
    return HoloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedUnit.name,
            style: TextStyle(
              fontSize: 18,
              color: selectedUnit.owner.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(selectedUnit.description),
          const SizedBox(height: 6),
          Text(
            "HP: ${selectedUnit.hp}/${selectedUnit.maxHp}   ATK: ${selectedUnit.atk}   RNG: ${selectedUnit.range}   MOV: ${selectedUnit.move}",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            "Ability: ${selectedUnit.abilityName} — ${selectedUnit.abilityDescription}",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(Unit? selectedUnit) {
    return HoloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Controls',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Turn: ${state.turn.label}'),
          const SizedBox(height: 4),
          Text('Selected: ${selectedText()}'),
          const SizedBox(height: 10),
          if (selectedUnit != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _choiceChip(
                  text: 'Ability',
                  selected: abilityMode,
                  onTap: startAbilityMode,
                ),
                _choiceChip(
                  text: 'Clear',
                  selected: false,
                  onTap: () {
                    setState(() {
                      clearSelection();
                      state.status = '${state.turn.label} to move';
                    });
                  },
                ),
              ],
            ),
          const SizedBox(height: 12),
          const Text(
            'Legend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Yellow = move'),
          const SizedBox(height: 4),
          const Text('Red = attack target'),
          const SizedBox(height: 4),
          const Text('Blue = selected unit'),
        ],
      ),
    );
  }

  void _showHowToPlay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0B1623),
        title: const Text('How to Play'),
        content: const SingleChildScrollView(
          child: Text(
            'Tap a unit.\n\n'
            'The board shows:\n'
            '• yellow = where it can move\n'
            '• red = enemies it can attack now\n\n'
            'Actions:\n'
            '• tap a red enemy = attack now\n'
            '• tap a yellow move = move first, then attack if possible\n'
            '• tap Ability in controls = use that unit’s special move\n\n'
            'Abilities:\n'
            '• Brute = shockwave adjacent enemies\n'
            '• Striker = move one extra space\n'
            '• Mystic = heal self\n'
            '• Tentacle = beam nearest enemy in longer range\n\n'
            'Win by eliminating the other side.\n',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// ROUND BOARD
/// ===============================================================

class RoundBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width * 0.42;

    final fill = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x2200E7FF),
          Color(0x1100E7FF),
          Color(0x0300E7FF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final outerGlow = Paint()
      ..color = const Color(0x3358F3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    final line = Paint()
      ..color = const Color(0xAA58F3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, maxRadius, fill);
    canvas.drawCircle(center, maxRadius, outerGlow);

    final ringStep = maxRadius / GameState.ringCount;
    for (int r = 1; r <= GameState.ringCount; r++) {
      canvas.drawCircle(center, ringStep * r, line);
    }

    final sectorStep = 2 * math.pi / GameState.sectorCount;
    for (int s = 0; s < GameState.sectorCount; s++) {
      final angle = -math.pi / 2 + s * sectorStep;
      final end = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      canvas.drawLine(center, end, line);
    }

    final centerGlow = Paint()
      ..color = const Color(0x6658F3FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    canvas.drawCircle(center, size.width * 0.03, centerGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ===============================================================
/// MONSTER TOKENS
/// Clearer silhouettes + small letters for readability.
/// ===============================================================

class BeastToken extends StatelessWidget {
  final Unit unit;

  const BeastToken({super.key, required this.unit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: BeastTokenPainter(unit: unit),
      ),
    );
  }
}

class BeastTokenPainter extends CustomPainter {
  final Unit unit;

  BeastTokenPainter({required this.unit});

  @override
  void paint(Canvas canvas, Size size) {
    final color = unit.owner.color;
    final center = size.center(Offset.zero);

    final glow = Paint()
      ..color = color.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final line = Paint()
      ..color = color.withOpacity(0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1;

    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.30),
          color.withOpacity(0.10),
          color.withOpacity(0.02),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.30));

    canvas.drawCircle(center, size.width * 0.33, glow);
    canvas.drawCircle(center, size.width * 0.29, fill);

    _drawBase(canvas, size, line);

    switch (unit.type) {
      case UnitType.brute:
        _drawBrute(canvas, size, line);
        break;
      case UnitType.striker:
        _drawStriker(canvas, size, line);
        break;
      case UnitType.mystic:
        _drawMystic(canvas, size, line);
        break;
      case UnitType.tentacle:
        _drawTentacle(canvas, size, line);
        break;
    }

    _drawEyes(canvas, size, color);
    _drawLetter(canvas, size);
    _drawHpBar(canvas, size);
  }

  void _drawBase(Canvas canvas, Size size, Paint line) {
    final c = size.center(Offset.zero);

    switch (unit.type) {
      case UnitType.brute:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: c.translate(0, size.height * 0.18),
              width: size.width * 0.34,
              height: size.height * 0.10,
            ),
            const Radius.circular(6),
          ),
          line,
        );
        break;

      case UnitType.striker:
        final diamond = Path()
          ..moveTo(c.dx, c.dy + size.height * 0.10)
          ..lineTo(c.dx + size.width * 0.16, c.dy + size.height * 0.18)
          ..lineTo(c.dx, c.dy + size.height * 0.26)
          ..lineTo(c.dx - size.width * 0.16, c.dy + size.height * 0.18)
          ..close();
        canvas.drawPath(diamond, line);
        break;

      case UnitType.mystic:
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(0, size.height * 0.18),
            width: size.width * 0.32,
            height: size.height * 0.12,
          ),
          line,
        );
        break;

      case UnitType.tentacle:
        canvas.drawArc(
          Rect.fromCenter(
            center: c.translate(0, size.height * 0.18),
            width: size.width * 0.34,
            height: size.height * 0.18,
          ),
          0.2,
          math.pi - 0.4,
          false,
          line,
        );
        break;
    }
  }

  void _drawBrute(Canvas canvas, Size size, Paint line) {
    final c = size.center(Offset.zero);

    final head = Path()
      ..moveTo(c.dx - size.width * 0.18, c.dy + size.height * 0.06)
      ..quadraticBezierTo(
        c.dx - size.width * 0.22,
        c.dy - size.height * 0.02,
        c.dx - size.width * 0.10,
        c.dy - size.height * 0.18,
      )
      ..lineTo(c.dx, c.dy - size.height * 0.24)
      ..lineTo(c.dx + size.width * 0.10, c.dy - size.height * 0.18)
      ..quadraticBezierTo(
        c.dx + size.width * 0.22,
        c.dy - size.height * 0.02,
        c.dx + size.width * 0.18,
        c.dy + size.height * 0.06,
      );

    canvas.drawPath(head, line);

    canvas.drawLine(
      Offset(c.dx - size.width * 0.08, c.dy - size.height * 0.16),
      Offset(c.dx - size.width * 0.22, c.dy - size.height * 0.26),
      line,
    );
    canvas.drawLine(
      Offset(c.dx + size.width * 0.08, c.dy - size.height * 0.16),
      Offset(c.dx + size.width * 0.22, c.dy - size.height * 0.26),
      line,
    );

    canvas.drawLine(
      Offset(c.dx - size.width * 0.10, c.dy - size.height * 0.02),
      Offset(c.dx + size.width * 0.10, c.dy - size.height * 0.02),
      line,
    );
  }

  void _drawStriker(Canvas canvas, Size size, Paint line) {
    final c = size.center(Offset.zero);

    final body = Path()
      ..moveTo(c.dx, c.dy - size.height * 0.26)
      ..lineTo(c.dx + size.width * 0.10, c.dy - size.height * 0.04)
      ..lineTo(c.dx, c.dy + size.height * 0.10)
      ..lineTo(c.dx - size.width * 0.10, c.dy - size.height * 0.04)
      ..close();

    canvas.drawPath(body, line);

    canvas.drawLine(
      Offset(c.dx - size.width * 0.04, c.dy - size.height * 0.10),
      Offset(c.dx - size.width * 0.22, c.dy - size.height * 0.20),
      line,
    );
    canvas.drawLine(
      Offset(c.dx + size.width * 0.04, c.dy - size.height * 0.10),
      Offset(c.dx + size.width * 0.22, c.dy - size.height * 0.20),
      line,
    );

    canvas.drawLine(
      Offset(c.dx - size.width * 0.03, c.dy + size.height * 0.02),
      Offset(c.dx - size.width * 0.18, c.dy + size.height * 0.14),
      line,
    );
    canvas.drawLine(
      Offset(c.dx + size.width * 0.03, c.dy + size.height * 0.02),
      Offset(c.dx + size.width * 0.18, c.dy + size.height * 0.14),
      line,
    );
  }

  void _drawMystic(Canvas canvas, Size size, Paint line) {
    final c = size.center(Offset.zero);

    canvas.drawCircle(c.translate(0, -size.height * 0.12), size.width * 0.08, line);
    canvas.drawCircle(c.translate(-size.width * 0.11, 0), size.width * 0.07, line);
    canvas.drawCircle(c.translate(size.width * 0.11, 0), size.width * 0.07, line);

    canvas.drawLine(
      Offset(c.dx, c.dy - size.height * 0.02),
      Offset(c.dx, c.dy + size.height * 0.14),
      line,
    );
  }

  void _drawTentacle(Canvas canvas, Size size, Paint line) {
    final c = size.center(Offset.zero);

    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, -size.height * 0.06),
        width: size.width * 0.26,
        height: size.height * 0.20,
      ),
      math.pi,
      math.pi,
      false,
      line,
    );

    final tendrils = [
      (-0.10, 0.02, -0.16, 0.22),
      (0.00, 0.02, 0.00, 0.25),
      (0.10, 0.02, 0.16, 0.22),
    ];

    for (final t in tendrils) {
      final path = Path()
        ..moveTo(c.dx + size.width * t.$1, c.dy + size.height * t.$2)
        ..quadraticBezierTo(
          c.dx + size.width * ((t.$1 + t.$3) / 2),
          c.dy + size.height * 0.15,
          c.dx + size.width * t.$3,
          c.dy + size.height * t.$4,
        );
      canvas.drawPath(path, line);
    }
  }

  void _drawEyes(Canvas canvas, Size size, Color color) {
    final c = size.center(Offset.zero);

    final eyeGlow = Paint()
      ..color = color.withOpacity(0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final eyeFill = Paint()..color = Colors.white.withOpacity(0.95);

    switch (unit.type) {
      case UnitType.brute:
      case UnitType.striker:
        final left = c.translate(-size.width * 0.05, -size.height * 0.08);
        final right = c.translate(size.width * 0.05, -size.height * 0.08);
        canvas.drawCircle(left, 2.4, eyeGlow);
        canvas.drawCircle(right, 2.4, eyeGlow);
        canvas.drawCircle(left, 1.3, eyeFill);
        canvas.drawCircle(right, 1.3, eyeFill);
        break;

      case UnitType.mystic:
        final top = c.translate(0, -size.height * 0.12);
        canvas.drawCircle(top, 2.6, eyeGlow);
        canvas.drawCircle(top, 1.4, eyeFill);
        break;

      case UnitType.tentacle:
        final eye = c.translate(0, -size.height * 0.08);
        canvas.drawCircle(eye, 2.6, eyeGlow);
        canvas.drawCircle(eye, 1.4, eyeFill);
        break;
    }
  }

  void _drawLetter(Canvas canvas, Size size) {
    final text = switch (unit.type) {
      UnitType.brute => 'B',
      UnitType.striker => 'S',
      UnitType.mystic => 'M',
      UnitType.tentacle => 'T',
    };

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.60),
    );
  }

  void _drawHpBar(Canvas canvas, Size size) {
    final width = size.width * 0.42;
    final left = (size.width - width) / 2;
    final top = size.height * 0.82;

    final bg = Paint()..color = Colors.black54;
    final fg = Paint()..color = Colors.white.withOpacity(0.95);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, 4),
        const Radius.circular(2),
      ),
      bg,
    );

    final fillWidth = width * (unit.hp / unit.maxHp).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, fillWidth, 4),
        const Radius.circular(2),
      ),
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant BeastTokenPainter oldDelegate) {
    return oldDelegate.unit.type != unit.type ||
        oldDelegate.unit.owner != unit.owner ||
        oldDelegate.unit.hp != unit.hp;
  }
}

/// ===============================================================
/// UI HELPERS
/// ===============================================================

class HoloPanel extends StatelessWidget {
  final Widget child;

  const HoloPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.cyanAccent),
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.25),
      ),
      child: child,
    );
  }
}

class HoloIconMiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const HoloIconMiniButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyanAccent),
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.25),
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: 20),
      ),
    );
  }
}

class HoloBackdrop extends StatelessWidget {
  const HoloBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black);
  }
}
