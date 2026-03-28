import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  runApp(const DejairkApp());
}

class DejairkApp extends StatelessWidget {
  const DejairkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dejairk: Holo Grid',
      debugShowCheckedModeBanner: false,
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

/// ===============================================================
/// VERSION NOTE
/// Change this when you push meaningful gameplay updates.
/// Visible in the UI so you can confirm deploys.
/// ===============================================================
const String gameVersion = 'v0.5.0-round-combat';

/// ===============================================================
/// CORE ENUMS
/// ===============================================================

enum PlayerSide { cyan, red }

enum Difficulty { easy, medium, hard }

enum GameMode { vsAI, local }

enum UnitType {
  brute,
  striker,
  mystic,
  tentacle,
}

enum TurnAction {
  moveAttack,
  attackOnly,
  moveAbility,
}

enum InteractionPhase {
  idle,
  choosingMove,
  choosingAttackTarget,
  choosingAbilityMove,
}

extension PlayerSideX on PlayerSide {
  PlayerSide get opponent =>
      this == PlayerSide.cyan ? PlayerSide.red : PlayerSide.cyan;

  String get label => this == PlayerSide.cyan ? 'Cyan' : 'Red';

  Color get color =>
      this == PlayerSide.cyan ? const Color(0xFF58F3FF) : const Color(0xFFFF5A93);
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

  double get randomMistakeChance {
    switch (this) {
      case Difficulty.easy:
        return 0.32;
      case Difficulty.medium:
        return 0.12;
      case Difficulty.hard:
        return 0.03;
    }
  }
}

extension GameModeX on GameMode {
  String get label {
    switch (this) {
      case GameMode.vsAI:
        return 'VS AI';
      case GameMode.local:
        return 'Local 2P';
    }
  }
}

extension TurnActionX on TurnAction {
  String get label {
    switch (this) {
      case TurnAction.moveAttack:
        return 'Move + Attack';
      case TurnAction.attackOnly:
        return 'Attack Only';
      case TurnAction.moveAbility:
        return 'Move + Ability';
    }
  }
}

/// ===============================================================
/// ROUND BOARD POSITION
/// ring   = distance from center
/// sector = slice around the circle
/// ===============================================================

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

/// ===============================================================
/// UNIT DATA
/// Main balance point:
/// hp / atk / range / move
/// ===============================================================

class Unit {
  final String id;
  final PlayerSide owner;
  final UnitType type;

  int hp;
  final int maxHp;
  final int atk;
  final int range;
  final int move;

  Unit({
    required this.id,
    required this.owner,
    required this.type,
    required this.hp,
    required this.maxHp,
    required this.atk,
    required this.range,
    required this.move,
  });

  Unit copy() {
    return Unit(
      id: id,
      owner: owner,
      type: type,
      hp: hp,
      maxHp: maxHp,
      atk: atk,
      range: range,
      move: move,
    );
  }

  bool get isAlive => hp > 0;

  String get shortName {
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

  static Unit make(PlayerSide owner, UnitType type, int serial) {
    switch (type) {
      case UnitType.brute:
        return Unit(
          id: '${owner.name}_brute_$serial',
          owner: owner,
          type: type,
          hp: 8,
          maxHp: 8,
          atk: 3,
          range: 1,
          move: 1,
        );
      case UnitType.striker:
        return Unit(
          id: '${owner.name}_striker_$serial',
          owner: owner,
          type: type,
          hp: 5,
          maxHp: 5,
          atk: 2,
          range: 1,
          move: 2,
        );
      case UnitType.mystic:
        return Unit(
          id: '${owner.name}_mystic_$serial',
          owner: owner,
          type: type,
          hp: 6,
          maxHp: 6,
          atk: 2,
          range: 2,
          move: 1,
        );
      case UnitType.tentacle:
        return Unit(
          id: '${owner.name}_tentacle_$serial',
          owner: owner,
          type: type,
          hp: 5,
          maxHp: 5,
          atk: 2,
          range: 2,
          move: 1,
        );
    }
  }
}

/// ===============================================================
/// GAME STATE
/// Board shape:
/// 3 rings x 8 sectors = 24 spaces
/// Easy hack point:
/// change ringCount / sectorCount to grow the board
/// ===============================================================

class GameState {
  static const int ringCount = 3;
  static const int sectorCount = 8;

  final Map<BoardPos, Unit> units;
  PlayerSide turn;
  String status;
  bool gameOver;
  PlayerSide? winner;
  int cyanScore;
  int redScore;

  GameState({
    required this.units,
    required this.turn,
    required this.status,
    required this.gameOver,
    required this.winner,
    required this.cyanScore,
    required this.redScore,
  });

  factory GameState.initial() {
    final units = <BoardPos, Unit>{};

    // Cyan side
    units[const BoardPos(2, 7)] = Unit.make(PlayerSide.cyan, UnitType.brute, 0);
    units[const BoardPos(2, 0)] = Unit.make(PlayerSide.cyan, UnitType.striker, 0);
    units[const BoardPos(2, 1)] = Unit.make(PlayerSide.cyan, UnitType.mystic, 0);
    units[const BoardPos(1, 0)] = Unit.make(PlayerSide.cyan, UnitType.tentacle, 0);

    // Red side
    units[const BoardPos(2, 3)] = Unit.make(PlayerSide.red, UnitType.brute, 0);
    units[const BoardPos(2, 4)] = Unit.make(PlayerSide.red, UnitType.striker, 0);
    units[const BoardPos(2, 5)] = Unit.make(PlayerSide.red, UnitType.mystic, 0);
    units[const BoardPos(1, 4)] = Unit.make(PlayerSide.red, UnitType.tentacle, 0);

    return GameState(
      units: units,
      turn: PlayerSide.cyan,
      status: 'Cyan to move',
      gameOver: false,
      winner: null,
      cyanScore: 0,
      redScore: 0,
    );
  }

  GameState copy() {
    final copiedUnits = <BoardPos, Unit>{};
    for (final entry in units.entries) {
      copiedUnits[entry.key] = entry.value.copy();
    }

    return GameState(
      units: copiedUnits,
      turn: turn,
      status: status,
      gameOver: gameOver,
      winner: winner,
      cyanScore: cyanScore,
      redScore: redScore,
    );
  }

  Unit? unitAt(BoardPos pos) => units[pos];

  bool isOccupied(BoardPos pos) => units.containsKey(pos);

  List<MapEntry<BoardPos, Unit>> unitsFor(PlayerSide side) {
    return units.entries.where((e) => e.value.owner == side).toList();
  }
}

/// ===============================================================
/// ROUND BOARD RULES
/// ===============================================================

class Rules {
  static int wrapSector(int sector) {
    return (sector % GameState.sectorCount + GameState.sectorCount) %
        GameState.sectorCount;
  }

  static List<BoardPos> adjacent(BoardPos pos) {
    final result = <BoardPos>[
      BoardPos(pos.ring, wrapSector(pos.sector + 1)),
      BoardPos(pos.ring, wrapSector(pos.sector - 1)),
    ];

    if (pos.ring > 0) {
      result.add(BoardPos(pos.ring - 1, pos.sector));
    }
    if (pos.ring < GameState.ringCount - 1) {
      result.add(BoardPos(pos.ring + 1, pos.sector));
    }

    return result;
  }

  static int distance(BoardPos start, BoardPos target) {
    if (start == target) return 0;

    final queue = <BoardPos>[start];
    final dist = <BoardPos, int>{start: 0};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDist = dist[current]!;
      for (final next in adjacent(current)) {
        if (!dist.containsKey(next)) {
          dist[next] = currentDist + 1;
          if (next == target) return dist[next]!;
          queue.add(next);
        }
      }
    }

    return 999;
  }

  static List<BoardPos> reachableMoves(
    GameState state,
    BoardPos start,
    Unit unit, {
    int? overrideMove,
  }) {
    final moveValue = overrideMove ?? unit.move;
    final visited = <BoardPos, int>{start: 0};
    final queue = <BoardPos>[start];
    final result = <BoardPos>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentDist = visited[current]!;

      if (currentDist >= moveValue) continue;

      for (final next in adjacent(current)) {
        if (state.isOccupied(next)) continue;
        if (visited.containsKey(next)) continue;

        visited[next] = currentDist + 1;
        result.add(next);
        queue.add(next);
      }
    }

    return result.toList();
  }

  static List<BoardPos> enemiesInRange(
    GameState state,
    BoardPos from,
    Unit attacker, {
    int? overrideRange,
  }) {
    final attackRange = overrideRange ?? attacker.range;
    final result = <BoardPos>[];

    for (final entry in state.units.entries) {
      if (entry.value.owner == attacker.owner) continue;
      if (distance(from, entry.key) <= attackRange) {
        result.add(entry.key);
      }
    }

    return result;
  }

  static void applyDamage(
    GameState state,
    Unit attacker,
    BoardPos defenderPos,
    int damage,
  ) {
    final defender = state.unitAt(defenderPos);
    if (defender == null) return;

    defender.hp -= damage;

    if (defender.hp <= 0) {
      state.units.remove(defenderPos);

      if (attacker.owner == PlayerSide.cyan) {
        state.cyanScore += defender.maxHp + defender.atk;
      } else {
        state.redScore += defender.maxHp + defender.atk;
      }
    }
  }

  static void moveUnit(GameState state, BoardPos from, BoardPos to) {
    final unit = state.unitAt(from);
    if (unit == null) return;
    state.units.remove(from);
    state.units[to] = unit;
  }

  static void endTurn(GameState state) {
    if (state.gameOver) return;

    final cyanAlive = state.units.values.where((u) => u.owner == PlayerSide.cyan);
    final redAlive = state.units.values.where((u) => u.owner == PlayerSide.red);

    if (cyanAlive.isEmpty) {
      state.gameOver = true;
      state.winner = PlayerSide.red;
      state.status = 'Red wins!';
      return;
    }

    if (redAlive.isEmpty) {
      state.gameOver = true;
      state.winner = PlayerSide.cyan;
      state.status = 'Cyan wins!';
      return;
    }

    state.turn = state.turn.opponent;
    state.status = '${state.turn.label} to move';
  }

  static void performAbility(
    GameState state,
    BoardPos origin,
    BoardPos destination,
    Unit unit,
  ) {
    moveUnit(state, origin, destination);

    switch (unit.type) {
      case UnitType.brute:
        for (final pos in adjacent(destination)) {
          final target = state.unitAt(pos);
          if (target != null && target.owner != unit.owner) {
            applyDamage(state, unit, pos, 1);
          }
        }
        break;

      case UnitType.striker:
        // Sprint effect is handled by giving +1 move in UI.
        break;

      case UnitType.mystic:
        unit.hp = math.min(unit.maxHp, unit.hp + 2);
        break;

      case UnitType.tentacle:
        final targets = enemiesInRange(state, destination, unit, overrideRange: 3);
        if (targets.isNotEmpty) {
          targets.sort((a, b) => distance(destination, a).compareTo(distance(destination, b)));
          applyDamage(state, unit, targets.first, 1);
        }
        break;
    }
  }
}

/// ===============================================================
/// SIMPLE AI
/// ===============================================================

class HoloAI {
  final Difficulty difficulty;
  final math.Random _random = math.Random();

  HoloAI(this.difficulty);

  _AiChoice chooseTurn(GameState state) {
    final entries = state.unitsFor(PlayerSide.red);
    if (entries.isEmpty) return _AiChoice.none();

    if (_random.nextDouble() < difficulty.randomMistakeChance) {
      return _randomChoice(state, entries);
    }

    int bestScore = -999999;
    _AiChoice? bestChoice;

    for (final entry in entries) {
      final from = entry.key;
      final unit = entry.value;

      for (final target in Rules.enemiesInRange(state, from, unit)) {
        final sim = state.copy();
        final simUnit = sim.unitAt(from)!;
        Rules.applyDamage(sim, simUnit, target, simUnit.atk);
        Rules.endTurn(sim);
        final score = _evaluate(sim);
        if (score > bestScore) {
          bestScore = score;
          bestChoice = _AiChoice(
            action: TurnAction.attackOnly,
            from: from,
            moveTo: null,
            attackTarget: target,
          );
        }
      }

      final moves = Rules.reachableMoves(state, from, unit);
      for (final moveTo in moves) {
        final sim = state.copy();
        final simUnit = sim.unitAt(from)!;
        Rules.moveUnit(sim, from, moveTo);

        final targets = Rules.enemiesInRange(sim, moveTo, simUnit);
        if (targets.isEmpty) {
          final score = _evaluate(sim);
          if (score > bestScore) {
            bestScore = score;
            bestChoice = _AiChoice(
              action: TurnAction.moveAttack,
              from: from,
              moveTo: moveTo,
              attackTarget: null,
            );
          }
        } else {
          for (final target in targets) {
            final sim2 = sim.copy();
            final simMovedUnit = sim2.unitAt(moveTo)!;
            Rules.applyDamage(sim2, simMovedUnit, target, simMovedUnit.atk);
            Rules.endTurn(sim2);
            final score = _evaluate(sim2);
            if (score > bestScore) {
              bestScore = score;
              bestChoice = _AiChoice(
                action: TurnAction.moveAttack,
                from: from,
                moveTo: moveTo,
                attackTarget: target,
              );
            }
          }
        }
      }

      final abilityMove =
          unit.type == UnitType.striker ? unit.move + 1 : unit.move;
      final abilityMoves = Rules.reachableMoves(
        state,
        from,
        unit,
        overrideMove: abilityMove,
      );

      for (final moveTo in abilityMoves) {
        final sim = state.copy();
        final simUnit = sim.unitAt(from)!;
        Rules.performAbility(sim, from, moveTo, simUnit);
        Rules.endTurn(sim);
        final score = _evaluate(sim);
        if (score > bestScore) {
          bestScore = score;
          bestChoice = _AiChoice(
            action: TurnAction.moveAbility,
            from: from,
            moveTo: moveTo,
            attackTarget: null,
          );
        }
      }
    }

    return bestChoice ?? _randomChoice(state, entries);
  }

  _AiChoice _randomChoice(
    GameState state,
    List<MapEntry<BoardPos, Unit>> entries,
  ) {
    final pick = entries[_random.nextInt(entries.length)];
    final from = pick.key;
    final unit = pick.value;

    final attacks = Rules.enemiesInRange(state, from, unit);
    if (attacks.isNotEmpty) {
      return _AiChoice(
        action: TurnAction.attackOnly,
        from: from,
        moveTo: null,
        attackTarget: attacks[_random.nextInt(attacks.length)],
      );
    }

    final moves = Rules.reachableMoves(state, from, unit);
    if (moves.isNotEmpty) {
      return _AiChoice(
        action: TurnAction.moveAbility,
        from: from,
        moveTo: moves[_random.nextInt(moves.length)],
        attackTarget: null,
      );
    }

    return _AiChoice.none();
  }

  int _evaluate(GameState state) {
    if (state.gameOver) {
      if (state.winner == PlayerSide.red) return 100000;
      if (state.winner == PlayerSide.cyan) return -100000;
    }

    int score = 0;

    for (final entry in state.units.entries) {
      final pos = entry.key;
      final unit = entry.value;

      int unitValue = 0;
      unitValue += unit.hp * 8;
      unitValue += unit.atk * 10;
      unitValue += unit.range * 5;
      unitValue += unit.move * 4;
      unitValue += (GameState.ringCount - 1 - pos.ring) * 3;

      score += unit.owner == PlayerSide.red ? unitValue : -unitValue;
    }

    score += state.redScore * 2;
    score -= state.cyanScore * 2;

    return score;
  }
}

class _AiChoice {
  final TurnAction? action;
  final BoardPos? from;
  final BoardPos? moveTo;
  final BoardPos? attackTarget;

  _AiChoice({
    required this.action,
    required this.from,
    required this.moveTo,
    required this.attackTarget,
  });

  factory _AiChoice.none() {
    return _AiChoice(
      action: null,
      from: null,
      moveTo: null,
      attackTarget: null,
    );
  }

  bool get isValid => action != null && from != null;
}

/// ===============================================================
/// MAIN GAME PAGE
/// ===============================================================

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameState state;

  Difficulty difficulty = Difficulty.medium;
  GameMode mode = GameMode.vsAI;
  TurnAction currentAction = TurnAction.moveAttack;

  bool showControls = false;

  BoardPos? selectedPos;
  BoardPos? pendingMoveDestination;
  InteractionPhase phase = InteractionPhase.idle;

  List<BoardPos> highlightedMoves = [];
  List<BoardPos> highlightedTargets = [];

  bool aiBusy = false;

  @override
  void initState() {
    super.initState();
    state = GameState.initial();
  }

  bool get isWide => MediaQuery.of(context).size.width >= 1100;

  void restartGame() {
    setState(() {
      state = GameState.initial();
      selectedPos = null;
      pendingMoveDestination = null;
      phase = InteractionPhase.idle;
      highlightedMoves = [];
      highlightedTargets = [];
      aiBusy = false;
    });
  }

  void clearSelection() {
    selectedPos = null;
    pendingMoveDestination = null;
    phase = InteractionPhase.idle;
    highlightedMoves = [];
    highlightedTargets = [];
  }

  void beginPieceSelection(BoardPos pos) {
    final unit = state.unitAt(pos);
    if (unit == null || unit.owner != state.turn) return;

    setState(() {
      selectedPos = pos;
      pendingMoveDestination = null;

      switch (currentAction) {
        case TurnAction.moveAttack:
          phase = InteractionPhase.choosingMove;
          highlightedMoves = Rules.reachableMoves(state, pos, unit);
          highlightedTargets = [];
          state.status = 'Choose move destination';
          break;
        case TurnAction.attackOnly:
          phase = InteractionPhase.choosingAttackTarget;
          highlightedMoves = [];
          highlightedTargets = Rules.enemiesInRange(state, pos, unit);
          state.status = 'Choose attack target';
          break;
        case TurnAction.moveAbility:
          phase = InteractionPhase.choosingAbilityMove;
          highlightedMoves = Rules.reachableMoves(
            state,
            pos,
            unit,
            overrideMove: unit.type == UnitType.striker ? unit.move + 1 : unit.move,
          );
          highlightedTargets = [];
          state.status = 'Choose ability move';
          break;
      }
    });
  }

  void handleBoardTap(BoardPos tappedPos) {
    if (state.gameOver || aiBusy) return;

    final tappedUnit = state.unitAt(tappedPos);

    if (tappedUnit != null && tappedUnit.owner == state.turn) {
      beginPieceSelection(tappedPos);
      return;
    }

    if (selectedPos == null) return;
    final selectedUnit = state.unitAt(selectedPos!);
    if (selectedUnit == null) return;

    switch (phase) {
      case InteractionPhase.idle:
        return;

      case InteractionPhase.choosingMove:
        if (!highlightedMoves.contains(tappedPos)) return;

        setState(() {
          pendingMoveDestination = tappedPos;
        });

        final sim = state.copy();
        final simUnit = sim.unitAt(selectedPos!)!;
        Rules.moveUnit(sim, selectedPos!, tappedPos);
        final targets = Rules.enemiesInRange(sim, tappedPos, simUnit);

        if (targets.isEmpty) {
          setState(() {
            Rules.moveUnit(state, selectedPos!, tappedPos);
            Rules.endTurn(state);
            clearSelection();
          });
          _maybeRunAi();
        } else {
          setState(() {
            phase = InteractionPhase.choosingAttackTarget;
            highlightedMoves = [];
            highlightedTargets = targets;
            state.status = 'Choose target to attack';
          });
        }
        return;

      case InteractionPhase.choosingAttackTarget:
        if (!highlightedTargets.contains(tappedPos)) return;

        setState(() {
          if (pendingMoveDestination != null) {
            Rules.moveUnit(state, selectedPos!, pendingMoveDestination!);
            final movedUnit = state.unitAt(pendingMoveDestination!)!;
            Rules.applyDamage(state, movedUnit, tappedPos, movedUnit.atk);
          } else {
            final attacker = state.unitAt(selectedPos!)!;
            Rules.applyDamage(state, attacker, tappedPos, attacker.atk);
          }

          Rules.endTurn(state);
          clearSelection();
        });
        _maybeRunAi();
        return;

      case InteractionPhase.choosingAbilityMove:
        if (!highlightedMoves.contains(tappedPos)) return;

        setState(() {
          final caster = state.unitAt(selectedPos!)!;
          Rules.performAbility(state, selectedPos!, tappedPos, caster);
          Rules.endTurn(state);
          clearSelection();
        });
        _maybeRunAi();
        return;
    }
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
      setState(() {
        aiBusy = false;
      });
      return;
    }

    final ai = HoloAI(difficulty);
    final choice = ai.chooseTurn(state);

    if (!choice.isValid) {
      setState(() {
        state.gameOver = true;
        state.winner = PlayerSide.cyan;
        state.status = 'Cyan wins!';
        aiBusy = false;
      });
      return;
    }

    setState(() {
      final unit = state.unitAt(choice.from!);
      if (unit == null) {
        aiBusy = false;
        return;
      }

      switch (choice.action!) {
        case TurnAction.attackOnly:
          if (choice.attackTarget != null) {
            Rules.applyDamage(state, unit, choice.attackTarget!, unit.atk);
          }
          Rules.endTurn(state);
          break;

        case TurnAction.moveAttack:
          if (choice.moveTo != null) {
            Rules.moveUnit(state, choice.from!, choice.moveTo!);
            final movedUnit = state.unitAt(choice.moveTo!)!;
            if (choice.attackTarget != null) {
              Rules.applyDamage(
                state,
                movedUnit,
                choice.attackTarget!,
                movedUnit.atk,
              );
            }
          }
          Rules.endTurn(state);
          break;

        case TurnAction.moveAbility:
          if (choice.moveTo != null) {
            Rules.performAbility(state, choice.from!, choice.moveTo!, unit);
          }
          Rules.endTurn(state);
          break;
      }

      aiBusy = false;
      clearSelection();
    });
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
        color: selected ? const Color(0xFF58F3FF) : Colors.white24,
      ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF58F3FF) : Colors.white70,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _scoreBlock(String name, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.toUpperCase(),
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

  String _selectedText() {
    if (selectedPos == null) return 'None';
    final unit = state.unitAt(selectedPos!);
    if (unit == null) return 'None';
    return '${unit.shortName} @ ${selectedPos!}';
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
                  'DEJAIRK: HOLO GRID',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.status,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                const Text(
                  gameVersion,
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

  Widget _buildControlsPanel({required bool alwaysExpanded}) {
    return HoloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Combat Controls',
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
            'Action This Turn',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: TurnAction.values.map((a) {
              return _choiceChip(
                text: a.label,
                selected: currentAction == a,
                onTap: () {
                  setState(() {
                    currentAction = a;
                    clearSelection();
                  });
                },
              );
            }).toList(),
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
          Text('Mode: ${mode.label}'),
          const SizedBox(height: 4),
          Text('Turn: ${state.turn.label}'),
          const SizedBox(height: 4),
          Text('Selected: ${_selectedText()}'),
          const SizedBox(height: 4),
          Text('Phase: ${phase.name}'),
          const SizedBox(height: 4),
          Text('Game Over: ${state.gameOver ? "Yes" : "No"}'),
          if (state.winner != null) ...[
            const SizedBox(height: 4),
            Text('Winner: ${state.winner!.label}'),
          ],
          if (alwaysExpanded) ...[
            const SizedBox(height: 14),
            const Text(
              'Unit Stats',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Brute  | HP 8 | ATK 3 | RNG 1 | MOV 1 | Shockwave'),
            const SizedBox(height: 6),
            const Text('Striker| HP 5 | ATK 2 | RNG 1 | MOV 2 | Sprint'),
            const SizedBox(height: 6),
            const Text('Mystic | HP 6 | ATK 2 | RNG 2 | MOV 1 | Heal'),
            const SizedBox(height: 6),
            const Text('Tentacl| HP 5 | ATK 2 | RNG 2 | MOV 1 | Beam Lash'),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactFooter() {
    return Column(
      children: [
        HoloPanel(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scoreBlock('Cyan', state.cyanScore, const Color(0xFF58F3FF)),
              _scoreBlock('Red', state.redScore, const Color(0xFFFF5A93)),
            ],
          ),
        ),
        if (showControls) ...[
          const SizedBox(height: 8),
          _buildControlsPanel(alwaysExpanded: false),
        ],
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CombatBoard(
                      state: state,
                      selectedPos: selectedPos,
                      highlightedMoves: highlightedMoves,
                      highlightedTargets: highlightedTargets,
                      onTapCell: handleBoardTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildControlsPanel(alwaysExpanded: true),
                const SizedBox(height: 8),
                HoloPanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _scoreBlock('Cyan', state.cyanScore, const Color(0xFF58F3FF)),
                      _scoreBlock('Red', state.redScore, const Color(0xFFFF5A93)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight * 0.98,
                );
                return SizedBox(
                  width: side,
                  height: side,
                  child: CombatBoard(
                    state: state,
                    selectedPos: selectedPos,
                    highlightedMoves: highlightedMoves,
                    highlightedTargets: highlightedTargets,
                    onTapCell: handleBoardTap,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildCompactFooter(),
      ],
    );
  }

  void _showHowToPlay() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1623),
          title: const Text('How to Play'),
          content: const SingleChildScrollView(
            child: Text(
              'This version uses round holo combat rules.\n\n'
              'Each unit has:\n'
              '• HP = health\n'
              '• ATK = damage dealt\n'
              '• RNG = attack range\n'
              '• MOV = move distance\n\n'
              'Turn options:\n'
              '• Move + Attack\n'
              '• Attack Only\n'
              '• Move + Ability\n\n'
              'Movement uses round-board adjacency:\n'
              '• around the orbit\n'
              '• or along the ray\n'
              '• no diagonals\n\n'
              'Win by eliminating the other side.\n\n'
              'Abilities:\n'
              '• Brute: shockwave nearby enemies\n'
              '• Striker: sprint farther\n'
              '• Mystic: heal self\n'
              '• Tentacle: beam nearest target\n',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HoloBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: isWide ? _buildWideLayout() : _buildCompactLayout(),
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

/// ===============================================================
/// ROUND COMBAT BOARD
/// ===============================================================

class CombatBoard extends StatelessWidget {
  final GameState state;
  final BoardPos? selectedPos;
  final List<BoardPos> highlightedMoves;
  final List<BoardPos> highlightedTargets;
  final void Function(BoardPos) onTapCell;

  const CombatBoard({
    super.key,
    required this.state,
    required this.selectedPos,
    required this.highlightedMoves,
    required this.highlightedTargets,
    required this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: RoundBoardPainter(),
                ),
              ),
              for (int ring = 0; ring < GameState.ringCount; ring++)
                for (int sector = 0; sector < GameState.sectorCount; sector++)
                  _buildCell(side, BoardPos(ring, sector)),
            ],
          ),
        );
      },
    );
  }

  Positioned _buildCell(double side, BoardPos pos) {
    final point = _cellCenter(side, pos);
    final radius = side * 0.055;

    final unit = state.unitAt(pos);
    final isSelected = selectedPos == pos;
    final isMove = highlightedMoves.contains(pos);
    final isTarget = highlightedTargets.contains(pos);

    return Positioned(
      left: point.dx - radius,
      top: point.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onTapCell(pos),
          behavior: HitTestBehavior.opaque,
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
                    ? const Color(0xFF58F3FF)
                    : isMove
                        ? const Color(0xFFFFD56A)
                        : isTarget
                            ? const Color(0xFFFF5A93)
                            : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected || isMove || isTarget
                  ? [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0x4458F3FF)
                            : isMove
                                ? const Color(0x44FFD56A)
                                : const Color(0x44FF5A93),
                        blurRadius: 12,
                      )
                    ]
                  : null,
            ),
            child: unit == null
                ? const SizedBox.shrink()
                : Center(
                    child: BeastToken(unit: unit),
                  ),
          ),
        ),
      ),
    );
  }

  Offset _cellCenter(double side, BoardPos pos) {
    final center = Offset(side / 2, side / 2);
    final maxRadius = side * 0.38;

    // ring 0 near center, ring 2 near outer ring
    final ringStep = maxRadius / GameState.ringCount;
    final radius = ringStep * (pos.ring + 1);

    final angleStep = 2 * math.pi / GameState.sectorCount;
    final angle = -math.pi / 2 + pos.sector * angleStep;

    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }
}

/// ===============================================================
/// MONSTER TOKEN VISUALS
/// ===============================================================

class BeastToken extends StatelessWidget {
  final Unit unit;

  const BeastToken({
    super.key,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
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
      ..color = color.withOpacity(0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final ring = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.35),
          color.withOpacity(0.12),
          color.withOpacity(0.03),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.30));

    canvas.drawCircle(center, size.width * 0.32, glow);
    canvas.drawCircle(center, size.width * 0.29, fill);
    canvas.drawCircle(center, size.width * 0.29, ring);

    switch (unit.type) {
      case UnitType.brute:
        _drawBrute(canvas, size, color);
        break;
      case UnitType.striker:
        _drawStriker(canvas, size, color);
        break;
      case UnitType.mystic:
        _drawMystic(canvas, size, color);
        break;
      case UnitType.tentacle:
        _drawTentacle(canvas, size, color);
        break;
    }

    _drawHpBar(canvas, size);
  }

  void _drawBrute(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final c = size.center(Offset.zero);

    final path = Path()
      ..moveTo(c.dx - size.width * 0.16, c.dy + size.height * 0.10)
      ..quadraticBezierTo(
        c.dx - size.width * 0.22,
        c.dy - size.height * 0.02,
        c.dx - size.width * 0.08,
        c.dy - size.height * 0.18,
      )
      ..lineTo(c.dx, c.dy - size.height * 0.24)
      ..lineTo(c.dx + size.width * 0.08, c.dy - size.height * 0.18)
      ..quadraticBezierTo(
        c.dx + size.width * 0.22,
        c.dy - size.height * 0.02,
        c.dx + size.width * 0.16,
        c.dy + size.height * 0.10,
      );

    canvas.drawPath(path, p);
    canvas.drawLine(
      Offset(c.dx - size.width * 0.11, c.dy - size.height * 0.02),
      Offset(c.dx + size.width * 0.11, c.dy - size.height * 0.02),
      p,
    );
  }

  void _drawStriker(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final c = size.center(Offset.zero);

    final body = Path()
      ..moveTo(c.dx, c.dy - size.height * 0.24)
      ..lineTo(c.dx + size.width * 0.10, c.dy - size.height * 0.04)
      ..lineTo(c.dx, c.dy + size.height * 0.18)
      ..lineTo(c.dx - size.width * 0.10, c.dy - size.height * 0.04)
      ..close();

    canvas.drawPath(body, p);

    canvas.drawLine(
      Offset(c.dx - size.width * 0.05, c.dy - size.height * 0.08),
      Offset(c.dx - size.width * 0.22, c.dy - size.height * 0.20),
      p,
    );
    canvas.drawLine(
      Offset(c.dx + size.width * 0.05, c.dy - size.height * 0.08),
      Offset(c.dx + size.width * 0.22, c.dy - size.height * 0.20),
      p,
    );
  }

  void _drawMystic(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final c = size.center(Offset.zero);

    canvas.drawCircle(c.translate(0, -size.height * 0.06), size.width * 0.09, p);
    canvas.drawCircle(c.translate(-size.width * 0.10, size.height * 0.04), size.width * 0.07, p);
    canvas.drawCircle(c.translate(size.width * 0.10, size.height * 0.04), size.width * 0.07, p);

    canvas.drawLine(
      Offset(c.dx, c.dy - size.height * 0.18),
      Offset(c.dx, c.dy + size.height * 0.16),
      p,
    );
  }

  void _drawTentacle(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final c = size.center(Offset.zero);

    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -size.height * 0.04),
        width: size.width * 0.18,
        height: size.height * 0.16,
      ),
      p,
    );
    

    final t1 = Path()
      ..moveTo(c.dx - size.width * 0.05, c.dy)
      ..quadraticBezierTo(
        c.dx - size.width * 0.18,
        c.dy + size.height * 0.12,
        c.dx - size.width * 0.10,
        c.dy + size.height * 0.22,
      );

    final t2 = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo(
        c.dx,
        c.dy + size.height * 0.14,
        c.dx,
        c.dy + size.height * 0.24,
      );

    final t3 = Path()
      ..moveTo(c.dx + size.width * 0.05, c.dy)
      ..quadraticBezierTo(
        c.dx + size.width * 0.18,
        c.dy + size.height * 0.12,
        c.dx + size.width * 0.10,
        c.dy + size.height * 0.22,
      );

    canvas.drawPath(t1, p);
    canvas.drawPath(t2, p);
    canvas.drawPath(t3, p);
  }

  void _drawHpBar(Canvas canvas, Size size) {
    final width = size.width * 0.42;
    final left = (size.width - width) / 2;
    final top = size.height * 0.80;

    final bg = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;

    final fg = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

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
/// ROUND BOARD PAINTER
/// ===============================================================

class RoundBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width * 0.42;

    final bg = Paint()
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

    final ringPaint = Paint()
      ..color = const Color(0xAA58F3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, maxRadius, bg);
    canvas.drawCircle(center, maxRadius, outerGlow);

    final ringStep = maxRadius / GameState.ringCount;

    for (int r = 1; r <= GameState.ringCount; r++) {
      canvas.drawCircle(center, ringStep * r, ringPaint);
    }

    final sectorStep = 2 * math.pi / GameState.sectorCount;
    for (int s = 0; s < GameState.sectorCount; s++) {
      final angle = -math.pi / 2 + s * sectorStep;
      final end = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      canvas.drawLine(center, end, ringPaint);
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
/// UI HELPERS
/// ===============================================================

class HoloPanel extends StatelessWidget {
  final Widget child;

  const HoloPanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xBB0B1623),
            Color(0xDD102131),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x6658F3FF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2258F3FF),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x6658F3FF), width: 1.1),
            gradient: const LinearGradient(
              colors: [
                Color(0xBB0B1623),
                Color(0xDD102131),
              ],
            ),
          ),
          child: Icon(icon, color: const Color(0xFF58F3FF), size: 20),
        ),
      ),
    );
  }
}

class HoloBackdrop extends StatelessWidget {
  const HoloBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HoloBackdropPainter(),
    );
  }
}

class HoloBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF050A10),
          Color(0xFF071019),
          Color(0xFF09131F),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bg);

    final cyanGlow = Paint()
      ..color = const Color(0x1F58F3FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);

    final redGlow = Paint()
      ..color = const Color(0x1FFF5A93)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 65);

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.20), 130, cyanGlow);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.25), 150, redGlow);

    final gridLine = Paint()
      ..color = const Color(0x0F58F3FF)
      ..strokeWidth = 1;

    for (int i = 0; i < 18; i++) {
      final y = size.height * i / 18;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
