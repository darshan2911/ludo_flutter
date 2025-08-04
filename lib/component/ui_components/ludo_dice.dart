import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame/geometry.dart';
import 'package:ludo_flame/ludo.dart';
// user files
import 'dice_face_component.dart';
import '../../state/game_state.dart';
import '../../state/audio_manager.dart';
import '../../state/player.dart';
import '../../state/bot_controller.dart';
import '../../ludo_board.dart';
import 'token.dart';
// import '../../ludo_flame.dart';

class LudoDice extends PositionComponent with TapCallbacks {
  static const double borderRadiusFactor =
      0.2; // Precomputed factor for border radius
  static const double innerSizeFactor =
      0.9; // Precomputed factor for inner size

  // final gameState = GameState();
  final double faceSize; // size of the square
  late final double borderRadius; // radius of the curved edges
  late final double innerRectangleWidth; // width of the inner rectangle
  late final double innerRectangleHeight; // height of the inner rectangle

  late final RectangleComponent innerRectangle; // inner rectangle component
  late final DiceFaceComponent diceFace; // The dice face showing dots

  final Player player;

  void playSound() async {
    AudioManager.playDiceSound();
  }

  @override
  void onTapDown(TapDownEvent event) async {
    // Disable manual tapping for bot players
    if (player.isBot) {
      print('DEBUG: Manual dice tap blocked for bot player ${player.playerId}');
      return;
    }
    await executeDiceRoll(withAnimation: true);
  }

  /// Common dice roll logic used by both human and bot players
  Future<void> executeDiceRoll({bool withAnimation = true}) async {
    if (!player.enableDice ||
        !player.isCurrentTurn ||
        player != GameState().currentPlayer) {
      return; // Exit if the player cannot roll the dice
    }

    // Disable dice to prevent multiple taps
    final world = parent?.parent?.parent?.parent?.parent;
    GameState().hidePointer();
    player.enableDice = false;

    playSound();

    // Apply dice animation only if requested
    if (withAnimation) {
      _applyAdvancedDiceRollEffect();
      await Future.delayed(const Duration(milliseconds: 450));
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Roll the dice and update the dice face
    GameState().diceNumber = Random().nextInt(6) + 1;
    diceFace.updateDiceValue(GameState().diceNumber);

    await Future.delayed(const Duration(milliseconds: 300));

    if (world is! World) return; // Ensure the world is available

    // Handle dice roll based on the number
    final handleRoll = GameState().diceNumber == 6
        ? _handleSixRoll
        : _handleNonSixRoll;
    handleRoll(
      world,
      GameState().ludoBoard as LudoBoard,
      GameState().diceNumber,
    );
  }

  Future<void> _applyAdvancedDiceRollEffect() async {
    addAll([
      // Slight shake before roll
      SequenceEffect([
        MoveByEffect(Vector2(4, 0), EffectController(duration: 0.04)),
        MoveByEffect(Vector2(-8, 0), EffectController(duration: 0.04)),
        MoveByEffect(Vector2(4, 0), EffectController(duration: 0.04)),
      ]),

      // Rotation effect (3 full spins, medium speed)
      RotateEffect.by(
        3 * tau, // 3 full 360° rotations
        EffectController(
          duration: 0.9, // medium speed
          curve: Curves.easeOutBack, // smooth with slight bounce
        ),
      ),

      // Scale punch effect (quick shrink + back to normal)
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(0.92),
          EffectController(duration: 0.1, curve: Curves.easeInOut),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.1, curve: Curves.easeInOut),
        ),
      ]),
    ]);
  }

  // Apply a 360-degree rotation effect to the dice
  FutureOr<void> _applyDiceRollEffect() {
    add(
      RotateEffect.by(
        tau, // Full 360-degree rotation (2π radians)
        EffectController(
          duration: 0.3, // Reduced duration
          curve: Curves.linear, // Simpler curve
        ),
      ),
    );
    return Future.value();
  }

  // Handle logic when the player rolls a 6
  void _handleSixRoll(World world, LudoBoard ludoBoard, int diceNumber) async {
    print(
      'DEBUG: _handleSixRoll called for player ${player.playerId}, isBot: ${player.isBot}',
    );
    player.grantAnotherTurn();

    if (player.hasRolledThreeConsecutiveSixes()) {
      await Future.delayed(Duration(seconds: 1));
      GameState().switchToNextPlayer();
      return;
    }
    // Filter tokens once and reuse the lists
    final tokensInBase = player.tokens
        .where((token) => token.state == TokenState.inBase)
        .toList();

    final tokensOnBoard = player.tokens
        .where((token) => token.state == TokenState.onBoard)
        .toList();

    final movableTokens = tokensOnBoard
        .where((token) => token.spaceToMove())
        .toList();

    final allMovableTokens = [...movableTokens, ...tokensInBase];
    print(
      'DEBUG: Player ${player.playerId} has ${allMovableTokens.length} movable tokens (${tokensInBase.length} in base, ${movableTokens.length} on board)',
    );

    // if only one token can move, move it
    if (allMovableTokens.length == 1) {
      print('DEBUG: Moving single token for player ${player.playerId}');
      if (allMovableTokens.first.state == TokenState.inBase) {
        moveOutOfBase(
          world: world,
          token: allMovableTokens.first,
          tokenPath: GameState().getTokenPath(player.playerId),
        );
      } else if (allMovableTokens.first.state == TokenState.onBoard) {
        _moveForwardSingleToken(
          world,
          ludoBoard,
          diceNumber,
          allMovableTokens.first,
        );
      }
      return;
    } else if (allMovableTokens.length > 1) {
      print(
        'DEBUG: Multiple tokens can move for player ${player.playerId}, enabling manual selection',
      );
      _enableManualTokenSelection(world, tokensInBase, tokensOnBoard);
    } else if (allMovableTokens.isEmpty) {
      print('DEBUG: No movable tokens for player ${player.playerId}');
      await Future.delayed(Duration(seconds: 1));
      GameState().switchToNextPlayer();
      return;
    }
  }

  // Handle logic for non-six dice rolls
  void _handleNonSixRoll(
    World world,
    LudoBoard ludoBoard,
    int diceNumber,
  ) async {
    player.extraTurns = 0;
    final tokensOnBoard = player.tokens
        .where((token) => token.state == TokenState.onBoard)
        .toList();

    // if no tokens on board, switch to next player
    if (tokensOnBoard.isEmpty) {
      await Future.delayed(Duration(seconds: 1));
      GameState().switchToNextPlayer();
      return;
    }

    final movableTokens = tokensOnBoard
        .where((token) => token.spaceToMove())
        .toList();
    final tokensInBase = player.tokens
        .where((token) => token.state == TokenState.inBase)
        .toList();

    // if only one token can move, move it
    if (movableTokens.length == 1) {
      _moveForwardSingleToken(
        world,
        ludoBoard,
        diceNumber,
        movableTokens.first,
      );
      return;
    } else if (movableTokens.length > 1) {
      _enableManualTokenSelection(world, tokensInBase, tokensOnBoard);
    } else if (movableTokens.isEmpty) {
      await Future.delayed(Duration(seconds: 1));
      GameState().switchToNextPlayer();
      return;
    }
  }

  // Enable manual selection if multiple tokens can move
  void _enableManualTokenSelection(
    World world,
    List<Token> tokensInBase,
    List<Token> tokensOnBoard,
  ) {
    GameState().hidePointer();
    player.enableDice = false;

    // Enable tokens for both human and bot players
    for (var token in player.tokens) {
      token.enableToken = true;
    }

    // Set game state flags
    if (tokensInBase.isNotEmpty && tokensOnBoard.isNotEmpty) {
      GameState().enableMoveFromBoth();
      addTokenTrail(tokensInBase, tokensOnBoard);
    } else if (tokensInBase.isNotEmpty) {
      GameState().enableMoveFromBase();
      addTokenTrail(tokensInBase, tokensOnBoard);
    } else if (tokensOnBoard.isNotEmpty) {
      addTokenTrail(tokensInBase, tokensOnBoard);
      GameState().enableMoveOnBoard();
    }

    // If this is a bot player, let bot choose the token
    if (player.isBot) {
      print('DEBUG: Bot player detected, calling simulateTokenTap');
      BotController.instance.simulateTokenTap(player, GameState().diceNumber);
      return;
    }

    print('DEBUG: Human player, manual token selection enabled');
  }

  // Move the token forward on the board
  void _moveForwardSingleToken(
    World world,
    LudoBoard ludoBoard,
    int diceNumber,
    Token token,
  ) {
    moveForward(
      world: world,
      token: token,
      tokenPath: GameState().getTokenPath(player.playerId),
      diceNumber: diceNumber,
    );
  }

  LudoDice({required this.faceSize, required this.player}) {
    // Pre-calculate values to avoid repeated calculations
    final double borderRadiusValue = faceSize * borderRadiusFactor;
    final double innerWidth = faceSize * innerSizeFactor;
    final double innerHeight = faceSize * innerSizeFactor;
    final Vector2 innerSize = Vector2(innerWidth, innerHeight);
    final Vector2 innerPosition = Vector2(
      (faceSize - innerWidth) / 2, // Center horizontally
      (faceSize - innerHeight) / 2, // Center vertically
    );

    // Assign pre-calculated values
    borderRadius = borderRadiusValue;
    innerRectangleWidth = innerWidth;
    innerRectangleHeight = innerHeight;

    // Initialize the size of the component
    size = Vector2.all(faceSize);

    // Set the anchor to center for center rotation
    anchor = Anchor.center;

    // Initialize the dice face component
    diceFace = DiceFaceComponent(faceSize: innerWidth, diceValue: 6);

    // Initialize the inner rectangle component
    final innerRectangle = RoundedRectangle(
      size: innerSize,
      position: innerPosition,
      paint: Paint()..color = Colors.white,
      borderRadius: 15.0, // Customize corner radius
      children: [diceFace],
    );

    // Add the inner rectangle to this component
    add(innerRectangle);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Create paint for the square
    final paint = Paint()
      ..color = Color(0xFFD6D6D6)
      ..style = PaintingStyle.fill;

    // Define the rounded rectangle
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(borderRadius);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Draw the rounded rectangle
    canvas.drawRRect(rrect, paint);
  }
}

class RoundedRectangle extends PositionComponent {
  final Paint paint;
  final double borderRadius;

  RoundedRectangle({
    required Vector2 size,
    required this.paint,
    this.borderRadius = 10.0, // Default corner radius
    super.position,
    super.children,
  }) : super(size: size);

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    canvas.drawRRect(rrect, paint);
    super.render(canvas);
  }
}
