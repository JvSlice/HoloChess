import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const HoloApp());
}

const String gameVersion = 'v0.7.4-responsive-layout-fix';

class HoloApp extends StatelessWidget {
  const HoloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Holo Chess',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF071019),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58F3FF),
          secondary: Color(0xFFFF5A93),
          surface: Color(0xFF0B1623),
        ),
      ),
      home: const GamePage(),
    );
  }
}

enum PlayerSide { cyan, red }
enum GameMode { vsAI, local }
enum Difficulty { easy, medium, hard }
enum UnitType { brute, striker, mystic, tentacle }

extension PlayerSideX on PlayerSide {
  Color get color =>
      this == PlayerSide.cyan ? const Color(0xFF58F3FF) : const Color(0xFFFF5A93);

  String get label => this == PlayerSide.cyan ? 'Player 1' : 'Player 2';

  PlayerSide get opponent =>
      this == PlayerSide.cyan ? PlayerSide.red : PlayerSide.cyan;
}

extension GameModeX on GameMode {
  String get label => this == GameMode.vsAI ? 'VS AI' : 'Local 2P';
}

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  double get mistakeChance {
    switch (this) {
      case Difficulty.easy:
        return 0.35;
      case Difficulty.medium:
        return 0.15;
      case Difficulty.hard:
        return 0.05;
    }
  }
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
  String toString() => '($ring,$sector)';
}

class Unit {
  final UnitType type;
  final PlayerSide owner;
  int hp;
  bool abilityUsedThisTurn;

  Unit(
    this.type,
    this.owner,
    this.hp, {
    this.abilityUsedThisTurn = false,
  });

  Unit copy() {
    return Unit(
      type,
      owner,
      hp,
      abilityUsedThisTurn: abilityUsedThisTurn,
    );
  }

  int get maxHp {
    switch (type) {
      case UnitType.brute:
        return 12;
      case UnitType.striker:
        return 8;
      case UnitType.mystic:
        return 10;
      case UnitType.tentacle:
        return 9;
    }
  }

  int get atk {
    switch (type) {
      case UnitType.brute:
        return 4;
      case UnitType.striker:
        return 3;
      case UnitType.mystic:
        return 2;
      case UnitType.tentacle:
        return 3;
    }
  }

  int get move {
    switch (type) {
      case UnitType.brute:
        return 1;
      case UnitType.striker:
        return 2;
      case UnitType.mystic:
        return 1;
      case UnitType.tentacle:
        return 1;
    }
  }

  int get range {
    switch (type) {
      case UnitType.brute:
        return 1;
      case UnitType.striker:
        return 1;
      case UnitType.mystic:
        return 2;
      case UnitType.tentacle:
        return 2;
    }
  }

  String get name {
    switch (type) {
      case UnitType.brute:
        return 'Brute';
      case UnitType.striker:
        return 'Striker';
      case UnitType.mystic:
        return 'Mystic';
      case UnitType.tentacle:
        return 'Tentacle';
    }
  }

  String get description {
    switch (type) {
      case UnitType.brute:
        return 'Heavy front-line monster. High HP and big damage.';
      case UnitType.striker:
        return 'Fast attacker that repositions well.';
      case UnitType.mystic:
        return 'Floating ranged support creature.';
      case UnitType.tentacle:
        return 'Control unit with mid-range pressure.';
    }
  }

  String get abilityName {
    switch (type) {
      case UnitType.brute:
        return 'Shockwave';
      case UnitType.striker:
        return 'Sprint';
      case UnitType.mystic:
        return 'Heal';
      case UnitType.tentacle:
        return 'Beam Lash';
    }
  }

  String get abilityDescription {
    switch (type) {
      case UnitType.brute:
        return 'After moving, deal 1 damage to all adjacent enemies.';
      case UnitType.striker:
        return 'Move one extra space this turn.';
      case UnitType.mystic:
        return 'After moving, heal 2 HP.';
      case UnitType.tentacle:
        return 'After moving, hit nearest enemy in range 3 for 1 damage.';
    }
  }

  String get shortLetter {
    switch (type) {
      case UnitType.brute:
        return 'B';
      case UnitType.striker:
        return 'S';
      case UnitType.mystic:
        return 'M';
      case UnitType.tentacle:
        return 'T';
    }
  }
}

class GameState {
  static const int ringCount = 3;
  static const int sectorCount = 8;

  final Map<BoardPos, Unit> units;
  PlayerSide turn;
  bool gameOver;
  PlayerSide? winner;
  String status;
  int cyanScore;
  int redScore;

  GameState({
    required this.units,
    required this.turn,
    required this.gameOver,
    required this.winner,
    required this.status,
    required this.cyanScore,
    required this.redScore,
  });

  factory GameState.initial() {
    final units = <BoardPos, Unit>{};

    units[const BoardPos(2, 7)] = Unit(UnitType.brute, PlayerSide.cyan, 12);
    units[const BoardPos(2, 0)] = Unit(UnitType.striker, PlayerSide.cyan, 8);
    units[const BoardPos(2, 1)] = Unit(UnitType.mystic, PlayerSide.cyan, 10);
    units[const BoardPos(1, 0)] = Unit(UnitType.tentacle, PlayerSide.cyan, 9);

    units[const BoardPos(2, 3)] = Unit(UnitType.brute, PlayerSide.red, 12);
    units[const BoardPos(2, 4)] = Unit(UnitType.striker, PlayerSide.red, 8);
    units[const BoardPos(2, 5)] = Unit(UnitType.mystic, PlayerSide.red, 10);
    units[const BoardPos(1, 4)] = Unit(UnitType.tentacle, PlayerSide.red, 9);

    return GameState(
      units: units,
      turn: PlayerSide.cyan,
      gameOver: false,
      winner: null,
      status: 'Player 1 to move',
      cyanScore: 0,
      redScore: 0,
    );
  }

  GameState copy() {
    final newUnits = <BoardPos, Unit>{};
    for (final entry in units.entries) {
      newUnits[entry.key] = entry.value.copy();
    }

    return GameState(
      units: newUnits,
      turn: turn,
      gameOver: gameOver,
      winner: winner,
      status: status,
      cyanScore: cyanScore,
      redScore: redScore,
    );
  }

  Unit? unitAt(BoardPos pos) => units[pos];

  bool isOccupied(BoardPos pos) => units.containsKey(pos);

  void move(BoardPos from, BoardPos to) {
    final unit = units.remove(from);
    if (unit != null) {
      units[to] = unit;
    }
  }

  void damage(BoardPos target, int amount, {PlayerSide? source}) {
    final unit = units[target];
    if (unit == null) return;

    unit.hp -= amount;
    if (unit.hp <= 0) {
      units.remove(target);
      if (source == PlayerSide.cyan) {
        cyanScore += unit.maxHp + unit.atk;
      } else if (source == PlayerSide.red) {
        redScore += unit.maxHp + unit.atk;
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
    turn = turn.opponent;
    status = '${turn.label} to move';
  }
}

class Rules {
  static int wrapSector(int sector) {
    return (sector % GameState.sectorCount + GameState.sectorCount) %
        GameState.sectorCount;
  }

  static List<BoardPos> adjacent(BoardPos pos) {
    return <BoardPos>[
      BoardPos(pos.ring, wrapSector(pos.sector + 1)),
      BoardPos(pos.ring, wrapSector(pos.sector - 1)),
      if (pos.ring > 0) BoardPos(pos.ring - 1, pos.sector),
      if (pos.ring < GameState.ringCount - 1) BoardPos(pos.ring + 1, pos.sector),
    ];
  }

  static int distance(BoardPos start, BoardPos end) {
    if (start == end) return 0;

    final queue = <BoardPos>[start];
    final distances = <BoardPos, int>{start: 0};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDistance = distances[current]!;
      for (final next in adjacent(current)) {
        if (distances.containsKey(next)) continue;
        distances[next] = currentDistance + 1;
        if (next == end) return distances[next]!;
        queue.add(next);
      }
    }

    return 999;
  }

  static List<BoardPos> getMoves(GameState state, Unit unit, BoardPos start) {
    final visited = <BoardPos, int>{start: 0};
    final queue = <BoardPos>[start];
    final result = <BoardPos>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final dist = visited[current]!;
      if (dist >= unit.move) continue;

      for (final next in adjacent(current)) {
        if (state.isOccupied(next)) continue;
        if (visited.containsKey(next)) continue;
        visited[next] = dist + 1;
        result.add(next);
        queue.add(next);
      }
    }

    return result.toList();
  }

  static List<BoardPos> getAbilityMoves(GameState state, Unit unit, BoardPos start) {
    final movement = unit.type == UnitType.striker ? unit.move + 1 : unit.move;
    final visited = <BoardPos, int>{start: 0};
    final queue = <BoardPos>[start];
    final result = <BoardPos>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final dist = visited[current]!;
      if (dist >= movement) continue;

      for (final next in adjacent(current)) {
        if (state.isOccupied(next)) continue;
        if (visited.containsKey(next)) continue;
        visited[next] = dist + 1;
        result.add(next);
        queue.add(next);
      }
    }

    return result.toList();
  }

  static List<BoardPos> getTargets(GameState state, Unit unit, BoardPos from) {
    return state.units.entries
        .where((e) => e.value.owner != unit.owner)
        .where((e) => distance(from, e.key) <= unit.range)
        .map((e) => e.key)
        .toList();
  }

  static void performAbility(GameState state, Unit unit, BoardPos from, BoardPos to) {
    state.move(from, to);
    unit.abilityUsedThisTurn = true;

    switch (unit.type) {
      case UnitType.brute:
        for (final adj in adjacent(to)) {
          final target = state.unitAt(adj);
          if (target != null && target.owner != unit.owner) {
            state.damage(adj, 1, source: unit.owner);
          }
        }
        break;
      case UnitType.striker:
        break;
      case UnitType.mystic:
        state.heal(to, 2);
        break;
      case UnitType.tentacle:
        final enemies = state.units.entries
            .where((e) => e.value.owner != unit.owner)
            .where((e) => distance(to, e.key) <= 3)
            .toList();

        if (enemies.isNotEmpty) {
          enemies.sort((a, b) => distance(to, a.key).compareTo(distance(to, b.key)));
          state.damage(enemies.first.key, 1, source: unit.owner);
        }
        break;
    }
  }
}

class AiChoice {
  final BoardPos from;
  final BoardPos? moveTo;
  final BoardPos? target;
  final bool useAbility;

  AiChoice({
    required this.from,
    required this.moveTo,
    required this.target,
    required this.useAbility,
  });
}

class CinematicAI {
  final Difficulty difficulty;
  final math.Random random = math.Random();

  CinematicAI(this.difficulty);

  AiChoice? choose(GameState state) {
    final actions = <AiChoice>[];

    final aiUnits =
        state.units.entries.where((e) => e.value.owner == PlayerSide.red).toList();

    for (final entry in aiUnits) {
      final from = entry.key;
      final unit = entry.value;

      final directTargets = Rules.getTargets(state, unit, from);
      for (final target in directTargets) {
        actions.add(
          AiChoice(from: from, moveTo: null, target: target, useAbility: false),
        );
      }

      final moves = Rules.getMoves(state, unit, from);
      for (final moveTo in moves) {
        final sim = state.copy();
        final simUnit = sim.unitAt(from)!;
        sim.move(from, moveTo);
        final afterTargets = Rules.getTargets(sim, simUnit, moveTo);

        if (afterTargets.isEmpty) {
          actions.add(
            AiChoice(from: from, moveTo: moveTo, target: null, useAbility: false),
          );
        } else {
          for (final target in afterTargets) {
            actions.add(
              AiChoice(from: from, moveTo: moveTo, target: target, useAbility: false),
            );
          }
        }
      }

      if (!unit.abilityUsedThisTurn) {
        final abilityMoves = Rules.getAbilityMoves(state, unit, from);
        for (final moveTo in abilityMoves) {
          actions.add(
            AiChoice(from: from, moveTo: moveTo, target: null, useAbility: true),
          );
        }
      }
    }

    if (actions.isEmpty) return null;

    if (random.nextDouble() < difficulty.mistakeChance) {
      return actions[random.nextInt(actions.length)];
    }

    AiChoice? bestChoice;
    double bestScore = -999999;

    for (final action in actions) {
      final score = _scoreAction(state, action);
      if (score > bestScore) {
        bestScore = score;
        bestChoice = action;
      }
    }

    return bestChoice;
  }

  double _scoreAction(GameState state, AiChoice action) {
    final sim = state.copy();
    final unit = sim.unitAt(action.from);
    if (unit == null) return -999999;

    double score = 0;
    BoardPos finalPos = action.from;

    if (action.useAbility) {
      if (action.moveTo == null) return -999999;
      Rules.performAbility(sim, unit, action.from, action.moveTo!);
      finalPos = action.moveTo!;
      score += 5;
    } else {
      if (action.moveTo != null) {
        sim.move(action.from, action.moveTo!);
        finalPos = action.moveTo!;
      }
      if (action.target != null) {
        final movedUnit = sim.unitAt(finalPos);
        if (movedUnit != null) {
          final before = sim.unitAt(action.target!);
          final beforeHp = before?.hp ?? 0;
          sim.damage(action.target!, movedUnit.atk, source: movedUnit.owner);
          final after = sim.unitAt(action.target!);

          score += movedUnit.atk * 8;
          if (after == null) {
            score += 80 + beforeHp * 2;
          }
        }
      }
    }

    score += _boardValue(sim);
    score += _personalityBonus(sim, unit, finalPos, action);
    score += random.nextDouble() * 4;

    return score;
  }

  double _boardValue(GameState state) {
    double score = 0;

    for (final entry in state.units.entries) {
      final pos = entry.key;
      final unit = entry.value;

      double value = 0;
      value += unit.hp * 7;
      value += unit.atk * 8;
      value += unit.range * 5;
      value += unit.move * 4;
      value += (GameState.ringCount - 1 - pos.ring) * 2;

      if (unit.owner == PlayerSide.red) {
        score += value;
      } else {
        score -= value;
      }
    }

    score += state.redScore * 2.5;
    score -= state.cyanScore * 2.5;

    return score;
  }

  double _personalityBonus(
    GameState sim,
    Unit unit,
    BoardPos finalPos,
    AiChoice action,
  ) {
    double score = 0;

    final enemies =
        sim.units.entries.where((e) => e.value.owner == PlayerSide.cyan).toList();

    int nearestEnemyDistance = 99;
    for (final enemy in enemies) {
      final d = Rules.distance(finalPos, enemy.key);
      if (d < nearestEnemyDistance) {
        nearestEnemyDistance = d;
      }
    }

    switch (unit.type) {
      case UnitType.brute:
        score += (GameState.ringCount - 1 - finalPos.ring) * 8;
        score += math.max(0, 5 - nearestEnemyDistance) * 6;
        if (action.useAbility) {
          int adjacentEnemies = 0;
          for (final pos in Rules.adjacent(finalPos)) {
            final target = sim.unitAt(pos);
            if (target != null && target.owner == PlayerSide.cyan) {
              adjacentEnemies++;
            }
          }
          score += adjacentEnemies * 20;
        }
        break;

      case UnitType.striker:
        score += finalPos.ring * 4;
        if (action.target != null) score += 10;
        if (action.useAbility) score += 12;
        break;

      case UnitType.mystic:
        if (unit.hp < unit.maxHp && action.useAbility) {
          score += 28;
        }
        score += math.min(nearestEnemyDistance.toDouble(), 3) * 5;
        if (action.target != null) score += 8;
        break;

      case UnitType.tentacle:
        if (nearestEnemyDistance >= 2 && nearestEnemyDistance <= 3) {
          score += 18;
        }
        if (action.useAbility) score += 16;
        break;
    }

    return score;
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameState state = GameState.initial();

  GameMode mode = GameMode.vsAI;
  Difficulty difficulty = Difficulty.medium;

  bool showControls = false;
  bool aiBusy = false;
  bool abilityMode = false;
  bool waitingForPostMoveAttack = false;

  BoardPos? selected;
  BoardPos? pendingMove;

  List<BoardPos> moves = [];
  List<BoardPos> targets = [];

  void restartGame() {
    setState(() {
      state = GameState.initial();
      clearSelection();
      aiBusy = false;
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
    if (unit == null || unit.owner != state.turn || aiBusy) return;

    setState(() {
      selected = pos;
      pendingMove = null;
      abilityMode = false;
      waitingForPostMoveAttack = false;
      moves = Rules.getMoves(state, unit, pos);
      targets = Rules.getTargets(state, unit, pos);
      state.status = 'Choose move, attack, or ability';
    });
  }

  void startAbilityMode() {
    if (selected == null || aiBusy) return;
    final unit = state.unitAt(selected!);
    if (unit == null || unit.abilityUsedThisTurn) return;

    setState(() {
      abilityMode = true;
      waitingForPostMoveAttack = false;
      moves = Rules.getAbilityMoves(state, unit, selected!);
      targets = [];
      state.status = 'Choose destination for ${unit.abilityName}';
    });
  }

  void tap(BoardPos pos) {
    if (state.gameOver || aiBusy) return;

    final tappedUnit = state.unitAt(pos);

    if (tappedUnit != null && tappedUnit.owner == state.turn) {
      select(pos);
      return;
    }

    if (selected == null) return;
    final unit = state.unitAt(selected!);
    if (unit == null) return;

    if (abilityMode) {
      if (!moves.contains(pos)) return;

      setState(() {
        Rules.performAbility(state, unit, selected!, pos);
        state.checkWin();
        if (!state.gameOver) {
          state.endTurn();
        }
        clearSelection();
      });
      _maybeRunAi();
      return;
    }

    if (targets.contains(pos) && !waitingForPostMoveAttack) {
      setState(() {
        state.damage(pos, unit.atk, source: unit.owner);
        state.checkWin();
        if (!state.gameOver) {
          state.endTurn();
        }
        clearSelection();
      });
      _maybeRunAi();
      return;
    }

    if (moves.contains(pos) && !waitingForPostMoveAttack) {
      final sim = state.copy();
      final simUnit = sim.unitAt(selected!)!;
      sim.move(selected!, pos);
      final newTargets = Rules.getTargets(sim, simUnit, pos);

      setState(() {
        pendingMove = pos;
        waitingForPostMoveAttack = true;
        moves = [];
        targets = newTargets;

        if (newTargets.isEmpty) {
          state.move(selected!, pos);
          if (!state.gameOver) {
            state.endTurn();
          }
          clearSelection();
        } else {
          state.status = 'Choose target after moving';
        }
      });

      if (selected == null) {
        _maybeRunAi();
      }
      return;
    }

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
      _maybeRunAi();
      return;
    }

    setState(() {
      clearSelection();
      state.status = '${state.turn.label} to move';
    });
  }

  Future<void> _maybeRunAi() async {
    if (state.gameOver) return;
    if (mode != GameMode.vsAI) return;
    if (state.turn != PlayerSide.red) return;

    await _runAiTurn();
  }

  Future<void> _runAiTurn() async {
    setState(() {
      aiBusy = true;
      state.status = 'AI thinking...';
    });

    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted || state.gameOver) {
      if (mounted) {
        setState(() {
          aiBusy = false;
        });
      }
      return;
    }

    final ai = CinematicAI(difficulty);
    final choice = ai.choose(state);

    if (choice == null) {
      setState(() {
        state.gameOver = true;
        state.winner = PlayerSide.cyan;
        state.status = 'Player 1 wins!';
        aiBusy = false;
      });
      return;
    }

    setState(() {
      final unit = state.unitAt(choice.from);
      if (unit == null) {
        aiBusy = false;
        return;
      }

      if (choice.useAbility) {
        if (choice.moveTo != null) {
          Rules.performAbility(state, unit, choice.from, choice.moveTo!);
        }
      } else {
        BoardPos finalPos = choice.from;
        if (choice.moveTo != null) {
          state.move(choice.from, choice.moveTo!);
          finalPos = choice.moveTo!;
        }
        if (choice.target != null) {
          final attacker = state.unitAt(finalPos);
          if (attacker != null) {
            state.damage(choice.target!, attacker.atk, source: attacker.owner);
          }
        }
      }

      state.checkWin();
      if (!state.gameOver) {
        state.endTurn();
      }

      aiBusy = false;
      clearSelection();
    });
  }

  Offset getOffset(BoardPos pos, double boardSize) {
    final center = Offset(boardSize / 2, boardSize / 2);
    final radiusStep = boardSize * 0.38 / GameState.ringCount;
    final radius = (pos.ring + 1) * radiusStep;
    final angle = (2 * math.pi / GameState.sectorCount) * pos.sector - math.pi / 2;

    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
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

  Widget _buildTopBar() {
    return HoloPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOLO CHESS',
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
            'HP: ${selectedUnit.hp}/${selectedUnit.maxHp}   ATK: ${selectedUnit.atk}   RNG: ${selectedUnit.range}   MOV: ${selectedUnit.move}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Ability: ${selectedUnit.abilityName} — ${selectedUnit.abilityDescription}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPanelSlot(Unit? selectedUnit) {
    return SizedBox(
      height: 120,
      child: selectedUnit == null
          ? const HoloPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Unit',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap a unit to see its stats and ability.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            )
          : _buildSelectedUnitPanel(selectedUnit),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _choiceChip(
                text: 'VS AI',
                selected: mode == GameMode.vsAI,
                onTap: () {
                  setState(() {
                    mode = GameMode.vsAI;
                    restartGame();
                  });
                },
              ),
              _choiceChip(
                text: 'Local 2P',
                selected: mode == GameMode.local,
                onTap: () {
                  setState(() {
                    mode = GameMode.local;
                    restartGame();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'AI Difficulty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: Difficulty.values.map((d) {
              return _choiceChip(
                text: d.label,
                selected: difficulty == d,
                onTap: () {
                  setState(() {
                    difficulty = d;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
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
            '• tap Ability = use that unit’s special move\n\n'
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

  @override
  Widget build(BuildContext context) {
    final selectedUnit = selected != null ? state.unitAt(selected!) : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 850;
    final double boardSize = isWide ? 420 : 320;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HoloBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                          size: Size(boardSize, boardSize),
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
                              const SizedBox(height: 12),
                              _buildSelectedPanelSlot(selectedUnit),
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
                                      _scoreBlock('Player 1', state.cyanScore, Colors.cyanAccent),
                                      _scoreBlock('Player 2', state.redScore, Colors.redAccent),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 10),
                          Center(
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: Size(boardSize, boardSize),
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
                          const SizedBox(height: 10),
                          _buildSelectedPanelSlot(selectedUnit),
                          const SizedBox(height: 10),
                          HoloPanel(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _scoreBlock('Player 1', state.cyanScore, Colors.cyanAccent),
                                _scoreBlock('Player 2', state.redScore, Colors.redAccent),
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
}

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

    final path1 = Path()
      ..moveTo(c.dx - size.width * 0.10, c.dy + size.height * 0.02)
      ..quadraticBezierTo(
        c.dx - size.width * 0.13,
        c.dy + size.height * 0.15,
        c.dx - size.width * 0.16,
        c.dy + size.height * 0.22,
      );

    final path2 = Path()
      ..moveTo(c.dx, c.dy + size.height * 0.02)
      ..quadraticBezierTo(
        c.dx,
        c.dy + size.height * 0.15,
        c.dx,
        c.dy + size.height * 0.25,
      );

    final path3 = Path()
      ..moveTo(c.dx + size.width * 0.10, c.dy + size.height * 0.02)
      ..quadraticBezierTo(
        c.dx + size.width * 0.13,
        c.dy + size.height * 0.15,
        c.dx + size.width * 0.16,
        c.dy + size.height * 0.22,
      );

    canvas.drawPath(path1, line);
    canvas.drawPath(path2, line);
    canvas.drawPath(path3, line);
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
    final tp = TextPainter(
      text: TextSpan(
        text: unit.shortLetter,
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
