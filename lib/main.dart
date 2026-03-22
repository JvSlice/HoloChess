import 'dart:math';
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

enum PlayerSide { cyan, red }
enum UnitType { core, lancer, blinker }
enum Difficulty { easy, medium, hard }

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

  int get searchDepth {
    switch (this) {
      case Difficulty.easy:
        return 1;
      case Difficulty.medium:
        return 2;
      case Difficulty.hard:
        return 3;
    }
  }

  double get mistakeChance {
    switch (this) {
      case Difficulty.easy:
        return 0.35;
      case Difficulty.medium:
        return 0.14;
      case Difficulty.hard:
        return 0.05;
    }
  }
}

class BoardPos {
  final int row;
  final int col;

  const BoardPos(this.row, this.col);

  bool inside(int size) => row >= 0 && row < size && col >= 0 && col < size;

  @override
  bool operator ==(Object other) =>
      other is BoardPos && row == other.row && col == other.col;

  @override
  int get hashCode => Object.hash(row, col);
}

class Piece {
  final PlayerSide side;
  final UnitType type;

  const Piece({required this.side, required this.type});

  Piece copy() => Piece(side: side, type: type);

  int get value {
    switch (type) {
      case UnitType.core:
        return 100;
      case UnitType.lancer:
        return 9;
      case UnitType.blinker:
        return 5;
    }
  }

  String get name {
    switch (type) {
      case UnitType.core:
        return 'Core';
      case UnitType.lancer:
        return 'Lancer';
      case UnitType.blinker:
        return 'Blinker';
    }
  }

  String get glyph {
    switch (type) {
      case UnitType.core:
        return 'C';
      case UnitType.lancer:
        return 'L';
      case UnitType.blinker:
        return 'B';
    }
  }
}

class GameMove {
  final BoardPos from;
  final BoardPos to;

  const GameMove({required this.from, required this.to});
}

class GameState {
  static const int size = 5;

  List<List<Piece?>> board;
  PlayerSide turn;
  int cyanScore;
  int redScore;
  bool gameOver;
  PlayerSide? winner;
  String status;

  GameState({
    required this.board,
    required this.turn,
    required this.cyanScore,
    required this.redScore,
    required this.gameOver,
    required this.winner,
    required this.status,
  });

  factory GameState.initial() {
    final board = List.generate(size, (_) => List<Piece?>.filled(size, null));

    // Red side
    board[0][0] = const Piece(side: PlayerSide.red, type: UnitType.lancer);
    board[0][1] = const Piece(side: PlayerSide.red, type: UnitType.blinker);
    board[0][2] = const Piece(side: PlayerSide.red, type: UnitType.core);
    board[0][3] = const Piece(side: PlayerSide.red, type: UnitType.blinker);
    board[0][4] = const Piece(side: PlayerSide.red, type: UnitType.lancer);

    // Cyan side
    board[4][0] = const Piece(side: PlayerSide.cyan, type: UnitType.lancer);
    board[4][1] = const Piece(side: PlayerSide.cyan, type: UnitType.blinker);
    board[4][2] = const Piece(side: PlayerSide.cyan, type: UnitType.core);
    board[4][3] = const Piece(side: PlayerSide.cyan, type: UnitType.blinker);
    board[4][4] = const Piece(side: PlayerSide.cyan, type: UnitType.lancer);

    return GameState(
      board: board,
      turn: PlayerSide.cyan,
      cyanScore: 0,
      redScore: 0,
      gameOver: false,
      winner: null,
      status: 'Your turn',
    );
  }

  GameState clone() {
    return GameState(
      board: List.generate(
        size,
        (r) => List.generate(size, (c) => board[r][c]?.copy()),
      ),
      turn: turn,
      cyanScore: cyanScore,
      redScore: redScore,
      gameOver: gameOver,
      winner: winner,
      status: status,
    );
  }

  Piece? at(BoardPos pos) => board[pos.row][pos.col];

  void set(BoardPos pos, Piece? piece) {
    board[pos.row][pos.col] = piece;
  }

  BoardPos? findCore(PlayerSide side) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final p = board[r][c];
        if (p != null && p.side == side && p.type == UnitType.core) {
          return BoardPos(r, c);
        }
      }
    }
    return null;
  }
}

class Rules {
  static List<GameMove> allLegalMoves(GameState state, PlayerSide side) {
    final result = <GameMove>[];
    for (int r = 0; r < GameState.size; r++) {
      for (int c = 0; c < GameState.size; c++) {
        final pos = BoardPos(r, c);
        final piece = state.at(pos);
        if (piece != null && piece.side == side) {
          result.addAll(movesForPiece(state, pos));
        }
      }
    }
    return result;
  }

  static List<GameMove> movesForPiece(GameState state, BoardPos from) {
    final piece = state.at(from);
    if (piece == null) return [];

    switch (piece.type) {
      case UnitType.core:
        return _coreMoves(state, from, piece.side);
      case UnitType.lancer:
        return _lancerMoves(state, from, piece.side);
      case UnitType.blinker:
        return _blinkerMoves(state, from, piece.side);
    }
  }

  static List<GameMove> _coreMoves(GameState state, BoardPos from, PlayerSide side) {
    final moves = <GameMove>[];

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final to = BoardPos(from.row + dr, from.col + dc);
        if (!to.inside(GameState.size)) continue;
        final target = state.at(to);
        if (target == null || target.side != side) {
          moves.add(GameMove(from: from, to: to));
        }
      }
    }

    return moves;
  }

  static List<GameMove> _lancerMoves(
      GameState state, BoardPos from, PlayerSide side) {
    final moves = <GameMove>[];
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];

    for (final d in dirs) {
      int r = from.row + d[0];
      int c = from.col + d[1];
      while (BoardPos(r, c).inside(GameState.size)) {
        final to = BoardPos(r, c);
        final target = state.at(to);

        if (target == null) {
          moves.add(GameMove(from: from, to: to));
        } else {
          if (target.side != side) {
            moves.add(GameMove(from: from, to: to));
          }
          break;
        }

        r += d[0];
        c += d[1];
      }
    }

    return moves;
  }

  static List<GameMove> _blinkerMoves(
      GameState state, BoardPos from, PlayerSide side) {
    final moves = <GameMove>[];
    const offsets = [
      [2, 1],
      [2, -1],
      [-2, 1],
      [-2, -1],
      [1, 2],
      [1, -2],
      [-1, 2],
      [-1, -2],
    ];

    for (final o in offsets) {
      final to = BoardPos(from.row + o[0], from.col + o[1]);
      if (!to.inside(GameState.size)) continue;
      final target = state.at(to);
      if (target == null || target.side != side) {
        moves.add(GameMove(from: from, to: to));
      }
    }

    return moves;
  }

  static bool applyMove(GameState state, GameMove move) {
    if (state.gameOver) return false;

    final piece = state.at(move.from);
    if (piece == null) return false;
    if (piece.side != state.turn) return false;

    final legal = movesForPiece(state, move.from);
    if (!legal.any((m) => m.to == move.to)) return false;

    final target = state.at(move.to);

    if (target != null) {
      if (piece.side == PlayerSide.cyan) {
        state.cyanScore += target.value;
      } else {
        state.redScore += target.value;
      }
    }

    state.set(move.to, piece);
    state.set(move.from, null);

    final enemyCore = state.findCore(piece.side.opponent);
    if (enemyCore == null) {
      state.gameOver = true;
      state.winner = piece.side;
      state.status = '${piece.side.label} wins by capturing the Core!';
      return true;
    }

    state.turn = state.turn.opponent;

    final nextMoves = allLegalMoves(state, state.turn);
    if (nextMoves.isEmpty) {
      state.gameOver = true;
      state.winner = piece.side;
      state.status = '${piece.side.label} wins: opponent has no legal moves!';
      return true;
    }

    state.status = state.turn == PlayerSide.cyan ? 'Your turn' : 'AI thinking...';
    return true;
  }
}

class HoloAI {
  final Difficulty difficulty;
  final Random _random = Random();

  HoloAI(this.difficulty);

  GameMove? chooseMove(GameState state) {
    final moves = Rules.allLegalMoves(state, PlayerSide.red);
    if (moves.isEmpty) return null;

    if (_random.nextDouble() < difficulty.mistakeChance) {
      return moves[_random.nextInt(moves.length)];
    }

    int bestScore = -999999;
    final bestMoves = <GameMove>[];

    for (final move in moves) {
      final next = state.clone();
      next.turn = PlayerSide.red;
      Rules.applyMove(next, move);
      final score = _minimax(
        next,
        depth: difficulty.searchDepth,
        maximizingRed: false,
        alpha: -999999,
        beta: 999999,
      );

      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }

    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  int _minimax(
    GameState state, {
    required int depth,
    required bool maximizingRed,
    required int alpha,
    required int beta,
  }) {
    if (depth == 0 || state.gameOver) {
      return _evaluate(state);
    }

    final side = maximizingRed ? PlayerSide.red : PlayerSide.cyan;
    final moves = Rules.allLegalMoves(state, side);
    if (moves.isEmpty) return _evaluate(state);

    if (maximizingRed) {
      int best = -999999;
      for (final move in moves) {
        final next = state.clone();
        next.turn = side;
        Rules.applyMove(next, move);
        best = max(
          best,
          _minimax(
            next,
            depth: depth - 1,
            maximizingRed: false,
            alpha: alpha,
            beta: beta,
          ),
        );
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 999999;
      for (final move in moves) {
        final next = state.clone();
        next.turn = side;
        Rules.applyMove(next, move);
        best = min(
          best,
          _minimax(
            next,
            depth: depth - 1,
            maximizingRed: true,
            alpha: alpha,
            beta: beta,
          ),
        );
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  int _evaluate(GameState state) {
    if (state.gameOver) {
      if (state.winner == PlayerSide.red) return 100000;
      if (state.winner == PlayerSide.cyan) return -100000;
      return 0;
    }

    int score = 0;

    for (int r = 0; r < GameState.size; r++) {
      for (int c = 0; c < GameState.size; c++) {
        final piece = state.board[r][c];
        if (piece == null) continue;

        final centerBias = 4 - ((r - 2).abs() + (c - 2).abs());
        int value = piece.value * 10 + centerBias;

        if (piece.type == UnitType.blinker) value += 2;
        if (piece.type == UnitType.lancer) value += 1;

        score += piece.side == PlayerSide.red ? value : -value;
      }
    }

    score += state.redScore * 3;
    score -= state.cyanScore * 3;

    score += Rules.allLegalMoves(state, PlayerSide.red).length * 2;
    score -= Rules.allLegalMoves(state, PlayerSide.cyan).length * 2;

    return score;
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GameState state;
  Difficulty difficulty = Difficulty.medium;
  BoardPos? selected;
  List<GameMove> selectedMoves = [];
  bool aiBusy = false;

  @override
  void initState() {
    super.initState();
    state = GameState.initial();
  }

  void restartGame() {
    setState(() {
      state = GameState.initial();
      selected = null;
      selectedMoves = [];
      aiBusy = false;
    });
  }

  void setDifficulty(Difficulty newDifficulty) {
    setState(() {
      difficulty = newDifficulty;
      restartGame();
    });
  }

  void handleTap(BoardPos pos) {
    if (state.gameOver || aiBusy) return;
    if (state.turn != PlayerSide.cyan) return;

    final piece = state.at(pos);

    if (piece != null && piece.side == PlayerSide.cyan) {
      setState(() {
        selected = pos;
        selectedMoves = Rules.movesForPiece(state, pos);
      });
      return;
    }

    if (selected != null) {
      final possible = selectedMoves.where((m) => m.to == pos).toList();
      if (possible.isNotEmpty) {
        setState(() {
          Rules.applyMove(state, possible.first);
          selected = null;
          selectedMoves = [];
        });

        if (!state.gameOver) {
          _runAiTurn();
        }
      } else {
        setState(() {
          selected = null;
          selectedMoves = [];
        });
      }
    }
  }

  Future<void> _runAiTurn() async {
    setState(() {
      aiBusy = true;
      state.status = 'AI thinking...';
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted || state.gameOver) {
      setState(() {
        aiBusy = false;
      });
      return;
    }

    final ai = HoloAI(difficulty);
    final move = ai.chooseMove(state);

    if (move == null) {
      setState(() {
        state.gameOver = true;
        state.winner = PlayerSide.cyan;
        state.status = 'Cyan wins: Red has no legal moves!';
        aiBusy = false;
      });
      return;
    }

    setState(() {
      Rules.applyMove(state, move);
      aiBusy = false;
    });
  }

  bool isTarget(BoardPos pos) => selectedMoves.any((m) => m.to == pos);

  void showHowToPlay() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1623),
          title: const Text('How to Play'),
          content: const SingleChildScrollView(
            child: Text(
              'Goal:\n'
              'Capture the enemy Core, or leave the opponent with no legal moves.\n\n'
              'Pieces:\n'
              '• Core: moves 1 square in any direction\n'
              '• Lancer: slides any distance horizontally or vertically\n'
              '• Blinker: jumps in an L-shape\n\n'
              'Controls:\n'
              'Tap or click one of your Cyan pieces, then tap/click a highlighted square to move.\n\n'
              'Scoring:\n'
              '• Core = 100\n'
              '• Lancer = 9\n'
              '• Blinker = 5\n\n'
              'Tips:\n'
              '• Protect your Core\n'
              '• Use Lancers to control lanes\n'
              '• Use Blinkers for surprise attacks\n'
              '• Controlling the center usually helps',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 950;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HoloBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: wide ? _buildWideLayout() : _buildNarrowLayout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GameBoard(
                      state: state,
                      selected: selected,
                      isMoveTarget: isTarget,
                      onTapCell: handleTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _buildInfoPanel(),
              const SizedBox(height: 16),
              _buildLegendPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: GameBoard(
                state: state,
                selected: selected,
                isMoveTarget: isTarget,
                onTapCell: handleTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoPanel(),
        const SizedBox(height: 12),
        _buildLegendPanel(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: HoloPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEJAIRK: HOLO GRID',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            HoloButton(
              icon: Icons.help_outline,
              label: 'How To Play',
              onPressed: showHowToPlay,
            ),
            const SizedBox(width: 8),
            HoloButton(
              icon: Icons.refresh,
              label: 'Restart',
              onPressed: restartGame,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HoloPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _scoreBlock('Cyan', state.cyanScore, const Color(0xFF58F3FF)),
                    _scoreBlock('Red', state.redScore, const Color(0xFFFF5A93)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            HoloPanel(
              child: Wrap(
                spacing: 6,
                children: Difficulty.values.map((d) {
                  final selected = difficulty == d;
                  return ChoiceChip(
                    label: Text(d.label),
                    selected: selected,
                    onSelected: (_) => setDifficulty(d),
                    selectedColor: const Color(0xFF173447),
                    backgroundColor: const Color(0xFF0B1623),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF58F3FF)
                          : Colors.white24,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF58F3FF) : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
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
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return HoloPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Match Info',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Current Turn: ${state.turn.label}'),
          const SizedBox(height: 6),
          Text('Difficulty: ${difficulty.label}'),
          const SizedBox(height: 6),
          Text('Selected: ${_selectedText()}'),
          const SizedBox(height: 6),
          Text('Game Over: ${state.gameOver ? "Yes" : "No"}'),
          if (state.winner != null) ...[
            const SizedBox(height: 6),
            Text('Winner: ${state.winner!.label}'),
          ],
        ],
      ),
    );
  }

  String _selectedText() {
    if (selected == null) return 'None';
    final piece = state.at(selected!);
    if (piece == null) return 'None';
    return '${piece.name} at (${selected!.row}, ${selected!.col})';
  }

  Widget _buildLegendPanel() {
    return HoloPanel(
      child: Wrap(
        runSpacing: 10,
        spacing: 10,
        children: const [
          LegendTile(
            iconText: 'C',
            title: 'Core',
            subtitle: '1 square any direction',
          ),
          LegendTile(
            iconText: 'L',
            title: 'Lancer',
            subtitle: 'Slides in straight lines',
          ),
          LegendTile(
            iconText: 'B',
            title: 'Blinker',
            subtitle: 'Jumps in an L-shape',
          ),
        ],
      ),
    );
  }
}

class GameBoard extends StatelessWidget {
  final GameState state;
  final BoardPos? selected;
  final bool Function(BoardPos) isMoveTarget;
  final void Function(BoardPos) onTapCell;

  const GameBoard({
    super.key,
    required this.state,
    required this.selected,
    required this.isMoveTarget,
    required this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cellSize = side / GameState.size;

        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x8858F3FF), width: 2),
            gradient: const LinearGradient(
              colors: [
                Color(0x2200E7FF),
                Color(0x1100E7FF),
                Color(0x2200E7FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2258F3FF),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: GridPainter())),
              for (int r = 0; r < GameState.size; r++)
                for (int c = 0; c < GameState.size; c++)
                  Positioned(
                    left: c * cellSize,
                    top: r * cellSize,
                    width: cellSize,
                    height: cellSize,
                    child: _BoardCell(
                      pos: BoardPos(r, c),
                      piece: state.board[r][c],
                      selected: selected == BoardPos(r, c),
                      moveTarget: isMoveTarget(BoardPos(r, c)),
                      onTap: () => onTapCell(BoardPos(r, c)),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _BoardCell extends StatelessWidget {
  final BoardPos pos;
  final Piece? piece;
  final bool selected;
  final bool moveTarget;
  final VoidCallback onTap;

  const _BoardCell({
    required this.pos,
    required this.piece,
    required this.selected,
    required this.moveTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? const Color(0x2247F1FF)
                : moveTarget
                    ? const Color(0x22FFD56A)
                    : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFF58F3FF)
                  : moveTarget
                      ? const Color(0xFFFFD56A)
                      : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected || moveTarget
                ? [
                    BoxShadow(
                      color: selected
                          ? const Color(0x3358F3FF)
                          : const Color(0x33FFD56A),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              if (moveTarget && piece == null)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x88FFD56A),
                    ),
                    child: SizedBox(width: 14, height: 14),
                  ),
                ),
              if (piece != null)
                Center(
                  child: HoloPiece(piece: piece!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HoloPiece extends StatelessWidget {
  final Piece piece;

  const HoloPiece({super.key, required this.piece});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(
        painter: PiecePainter(piece: piece),
      ),
    );
  }
}

class PiecePainter extends CustomPainter {
  final Piece piece;

  PiecePainter({required this.piece});

  @override
  void paint(Canvas canvas, Size size) {
    final color = piece.side.color;
    final center = size.center(Offset.zero);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final ringPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1;

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.48),
          color.withOpacity(0.16),
          color.withOpacity(0.04),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.34));

    canvas.drawCircle(center, size.width * 0.34, glowPaint);
    canvas.drawCircle(center, size.width * 0.30, fillPaint);
    canvas.drawCircle(center, size.width * 0.30, ringPaint);

    switch (piece.type) {
      case UnitType.core:
        _drawCore(canvas, size, color);
        break;
      case UnitType.lancer:
        _drawLancer(canvas, size, color);
        break;
      case UnitType.blinker:
        _drawBlinker(canvas, size, color);
        break;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: piece.glyph,
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: color.withOpacity(0.9), blurRadius: 12),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawCore(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = size.center(Offset.zero);

    canvas.drawCircle(center, size.width * 0.16, p);

    final diamond = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.22)
      ..lineTo(center.dx + size.width * 0.22, center.dy)
      ..lineTo(center.dx, center.dy + size.height * 0.22)
      ..lineTo(center.dx - size.width * 0.22, center.dy)
      ..close();

    canvas.drawPath(diamond, p);
  }

  void _drawLancer(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = size.center(Offset.zero);

    canvas.drawLine(
      Offset(center.dx, size.height * 0.14),
      Offset(center.dx, size.height * 0.86),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.22, center.dy),
      Offset(size.width * 0.78, center.dy),
      p,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width * 0.22, height: size.height * 0.22),
      p,
    );
  }

  void _drawBlinker(Canvas canvas, Size size, Color color) {
    final p = Paint()
      ..color = color.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = size.center(Offset.zero);

    final path = Path()
      ..moveTo(center.dx - size.width * 0.18, center.dy + size.height * 0.18)
      ..lineTo(center.dx - size.width * 0.18, center.dy - size.height * 0.08)
      ..lineTo(center.dx + size.width * 0.05, center.dy - size.height * 0.08)
      ..lineTo(center.dx + size.width * 0.05, center.dy - size.height * 0.23)
      ..lineTo(center.dx + size.width * 0.20, center.dy - size.height * 0.23);

    canvas.drawPath(path, p);
    canvas.drawCircle(center.translate(size.width * 0.15, size.height * 0.14), 5, p);
  }

  @override
  bool shouldRepaint(covariant PiecePainter oldDelegate) {
    return oldDelegate.piece.side != piece.side ||
        oldDelegate.piece.type != piece.type;
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0x2258F3FF)
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final line = Paint()
      ..color = const Color(0xAA58F3FF)
      ..strokeWidth = 1.2;

    final step = size.width / GameState.size;

    for (int i = 1; i < GameState.size; i++) {
      final d = i * step;
      canvas.drawLine(Offset(d, 0), Offset(d, size.height), glow);
      canvas.drawLine(Offset(0, d), Offset(size.width, d), glow);
      canvas.drawLine(Offset(d, 0), Offset(d, size.height), line);
      canvas.drawLine(Offset(0, d), Offset(size.width, d), line);
    }

    final center = size.center(Offset.zero);
    final centerRing = Paint()
      ..color = const Color(0x4458F3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, step * 0.24, centerRing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HoloPanel extends StatelessWidget {
  final Widget child;

  const HoloPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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

class HoloButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const HoloButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return HoloPanel(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF58F3FF)),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class LegendTile extends StatelessWidget {
  final String iconText;
  final String title;
  final String subtitle;

  const LegendTile({
    super.key,
    required this.iconText,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF58F3FF), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2258F3FF),
                blurRadius: 10,
              )
            ],
          ),
          child: Center(
            child: Text(
              iconText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ],
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
