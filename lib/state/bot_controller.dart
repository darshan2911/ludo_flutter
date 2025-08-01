import 'dart:math';
import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/gestures.dart';
import 'package:ludo_flame/state/game_state.dart';
import 'package:ludo_flame/state/player.dart';
import 'package:ludo_flame/state/token_manager.dart';
import 'package:ludo_flame/component/ui_components/token.dart';
import 'package:ludo_flame/state/audio_manager.dart';

enum BotDifficulty { easy, medium, hard }

class BotController {
  static final BotController instance = BotController._internal();
  BotController._internal();

  BotDifficulty difficulty = BotDifficulty.medium;
  final Random _random = Random();

  /// Main bot move execution - finds dice and calls common roll logic
  Future<void> makeMove(Player botPlayer) async {
    print('DEBUG: BotController.makeMove called for ${botPlayer.playerId}');
    await Future.delayed(Duration(milliseconds: 400)); // Simulate thinking time

    try {
      // Find the dice component that belongs to this specific player
      final dice = _findDiceComponent(botPlayer);
      if (dice != null) {
        print(
          'DEBUG: Found dice for player ${botPlayer.playerId}, executing roll',
        );
        await (dice as dynamic).executeDiceRoll(withAnimation: true);
      } else {
        print(
          'DEBUG: No dice found for player ${botPlayer.playerId}, switching to next player',
        );
        GameState().switchToNextPlayer();
      }
    } catch (e) {
      print('Bot move error: $e');
      GameState().switchToNextPlayer();
    }
  }

  /// Find the dice component for the current player
  Component? _findDiceComponent(Player botPlayer) {
    final ludoGame = GameState().ludoBoard?.parent?.parent;
    if (ludoGame == null) return null;

    final world = ludoGame.children.firstWhere(
      (c) => c.runtimeType.toString() == 'World',
    );

    // Get the appropriate controller based on player
    Component? controller;
    try {
      if (botPlayer.playerId == 'BP') {
        controller = world.children.firstWhere(
          (c) => c.runtimeType.toString().contains('LowerController'),
        );
      } else if (botPlayer.playerId == 'YP') {
        controller = world.children.firstWhere(
          (c) => c.runtimeType.toString().contains('LowerController'),
        );
      } else if (botPlayer.playerId == 'RP') {
        controller = world.children.firstWhere(
          (c) => c.runtimeType.toString().contains('UpperController'),
        );
      } else if (botPlayer.playerId == 'GP') {
        controller = world.children.firstWhere(
          (c) => c.runtimeType.toString().contains('UpperController'),
        );
      }
    } catch (e) {
      print('DEBUG: Error finding controller: $e');
      return null;
    }

    if (controller == null) return null;
    return _findPlayerDiceRecursively(controller, botPlayer);
  }

  /// Recursively find LudoDice component that belongs to the specific player
  Component? _findPlayerDiceRecursively(
    Component component,
    Player targetPlayer,
  ) {
    if (component.runtimeType.toString() == 'LudoDice') {
      // Check if this dice belongs to the target player
      final dice = component as dynamic;
      if (dice.player?.playerId == targetPlayer.playerId) {
        return component;
      }
    }

    for (var child in component.children) {
      var result = _findPlayerDiceRecursively(child, targetPlayer);
      if (result != null) return result;
    }

    return null;
  }

  /// Choose best token after dice is rolled (called from game logic)
  Token? chooseBestTokenForMove(Player botPlayer, int diceValue) {
    List<Token> movableTokens = _getMovableTokens(botPlayer, diceValue);

    if (movableTokens.isEmpty) return null;

    return _chooseBestToken(movableTokens, diceValue, botPlayer);
  }

  /// Simulate token tap for bot after dice roll
  Future<void> simulateTokenTap(Player botPlayer, int diceValue) async {
    print(
      'DEBUG: simulateTokenTap called for ${botPlayer.playerId} with dice value $diceValue',
    );

    print("extra turns:${botPlayer.extraTurns}");

    // Check for three consecutive sixes - if so, end turn immediately
    if (botPlayer.hasRolledThreeConsecutiveSixes()) {
      print('DEBUG: Bot rolled three consecutive sixes, ending turn');
      await botPlayer.resetExtraTurns();
      GameState().switchToNextPlayer();
      return;
    }

    await Future.delayed(Duration(milliseconds: 300)); // Thinking time

    Token? bestToken = chooseBestTokenForMove(botPlayer, diceValue);
    if (bestToken != null) {
      print(
        'DEBUG: Bot chose token ${bestToken.tokenId} at position ${bestToken.positionId}',
      );
      
      // Play step sound for bot move
      AudioManager.playStepSound();
      
      // Create a mock TapDownEvent for the bot
      final mockEvent = TapDownEvent(
        1, // deviceId
        bestToken.findGame()!, // game
        TapDownDetails(
          globalPosition: bestToken.position.toOffset(),
          localPosition: bestToken.position.toOffset(),
        ),
      );
      bestToken.onTapDown(mockEvent);
    } else {
      print('DEBUG: Bot could not find a token to move');
    }
  }

  /// Get all tokens that can move with the given dice value
  List<Token> _getMovableTokens(Player botPlayer, int diceValue) {
    List<Token> movableTokens = [];

    for (Token token in botPlayer.tokens) {
      if (_canTokenMove(token, diceValue, botPlayer)) {
        movableTokens.add(token);
      }
    }

    return movableTokens;
  }

  /// Check if a specific token can move
  bool _canTokenMove(Token token, int diceValue, Player botPlayer) {
    // Token in base can only move with 6
    if (token.isInBase()) {
      return diceValue == 6;
    }

    // Token on board - check if move is valid
    if (token.isOnBoard()) {
      List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
      int currentIndex = tokenPath.indexOf(token.positionId);

      if (currentIndex == -1) return false;

      int newIndex = currentIndex + diceValue;

      // Check if move goes beyond finish
      return newIndex < tokenPath.length;
    }

    return false;
  }

  /// Strategic token selection using condition-based logic
  Token _chooseBestToken(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    if (diceValue == 6) {
      return _chooseTokenForSix(movableTokens, botPlayer);
    } else {
      return _chooseTokenForNonSix(movableTokens, diceValue, botPlayer);
    }
  }

  /// Choose token when dice value is 6
  Token _chooseTokenForSix(List<Token> movableTokens, Player botPlayer) {
    // Priority 1: Capture opponent
    Token? captureToken = _findCaptureToken(movableTokens, 6, botPlayer);
    if (captureToken != null) return captureToken;

    // Priority 2: Victory move
    Token? victoryToken = _findVictoryToken(movableTokens, 6, botPlayer);
    if (victoryToken != null) return victoryToken;

    // Priority 3: Get piece out of base
    Token? baseToken = _findBaseToken(movableTokens);
    if (baseToken != null) return baseToken;

    // Priority 4: Normal move (any remaining token)
    return movableTokens.first;
  }

  /// Choose token when dice value is 1-5
  Token _chooseTokenForNonSix(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    // Single token - always move it
    if (movableTokens.length == 1) {
      return movableTokens.first;
    }

    // Multiple tokens - apply priority logic
    // Priority 1: Capture opponent
    Token? captureToken = _findCaptureToken(
      movableTokens,
      diceValue,
      botPlayer,
    );
    if (captureToken != null) return captureToken;

    // Priority 2: Victory move
    Token? victoryToken = _findVictoryToken(
      movableTokens,
      diceValue,
      botPlayer,
    );
    if (victoryToken != null) return victoryToken;

    // Priority 3: Safest token
    Token? safestToken = _findSafestToken(movableTokens, diceValue, botPlayer);
    if (safestToken != null) return safestToken;

    // Priority 4: Token closest to home
    return _findClosestToHomeToken(movableTokens, botPlayer);
  }

  /// Find token that can capture opponent
  Token? _findCaptureToken(
    List<Token> tokens,
    int diceValue,
    Player botPlayer,
  ) {
    print('DEBUG: Checking ${tokens.length} tokens for capture opportunities with dice $diceValue');
    
    for (Token token in tokens) {
      if (_wouldCaptureOpponent(token, diceValue, botPlayer)) {
        print('DEBUG: Found capture opportunity with token ${token.tokenId}');
        return token;
      }
    }
    print('DEBUG: No capture opportunities found');
    return null;
  }

  /// Find token that can reach victory/home
  Token? _findVictoryToken(
    List<Token> tokens,
    int diceValue,
    Player botPlayer,
  ) {
    for (Token token in tokens) {
      if (_wouldReachVictory(token, diceValue, botPlayer)) {
        return token;
      }
    }
    return null;
  }

  /// Find token in base (for dice value 6)
  Token? _findBaseToken(List<Token> tokens) {
    for (Token token in tokens) {
      if (token.isInBase()) {
        return token;
      }
    }
    return null;
  }

  /// Find safest token to move
  Token? _findSafestToken(List<Token> tokens, int diceValue, Player botPlayer) {
    for (Token token in tokens) {
      if (_isSafeMove(token, diceValue, botPlayer)) {
        return token;
      }
    }
    return null;
  }

  /// Find token closest to home
  Token _findClosestToHomeToken(List<Token> tokens, Player botPlayer) {
    Token closestToken = tokens.first;
    int maxProgress = _getTokenProgress(closestToken, botPlayer);

    for (Token token in tokens) {
      int progress = _getTokenProgress(token, botPlayer);
      if (progress > maxProgress) {
        maxProgress = progress;
        closestToken = token;
      }
    }
    return closestToken;
  }

  /// Check if token would capture opponent
  bool _wouldCaptureOpponent(Token token, int diceValue, Player botPlayer) {
    // Skip base tokens for non-6 dice values
    if (token.isInBase() && diceValue != 6) return false;
    
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int currentIndex = token.isInBase() ? -1 : tokenPath.indexOf(token.positionId);
    
    int newIndex;
    if (token.isInBase() && diceValue == 6) {
      newIndex = 0; // First position on board
    } else {
      if (currentIndex == -1) return false;
      newIndex = currentIndex + diceValue;
    }
    
    if (newIndex >= tokenPath.length) return false;

    String newPositionId = tokenPath[newIndex];
    bool canCapture = _getOpponentTokenAt(newPositionId, botPlayer) != null;
    
    if (canCapture) {
      print('DEBUG: Token ${token.tokenId} can capture at position $newPositionId');
    }
    
    return canCapture;
  }

  /// Check if token would reach victory/home
  bool _wouldReachVictory(Token token, int diceValue, Player botPlayer) {
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int currentIndex = tokenPath.indexOf(token.positionId);
    if (currentIndex == -1) return false;

    int newIndex = currentIndex + diceValue;
    if (newIndex >= tokenPath.length) return false;

    String newPositionId = tokenPath[newIndex];
    return newPositionId.endsWith('F');
  }

  /// Check if move is safe
  bool _isSafeMove(Token token, int diceValue, Player botPlayer) {
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int currentIndex = tokenPath.indexOf(token.positionId);
    if (currentIndex == -1) return false;

    int newIndex = currentIndex + diceValue;
    if (newIndex >= tokenPath.length) return false;

    String newPositionId = tokenPath[newIndex];
    return _isSafeSpot(newPositionId) ||
        !_isVulnerablePosition(newPositionId, botPlayer);
  }

  /// Get token progress (distance from start)
  int _getTokenProgress(Token token, Player botPlayer) {
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    return tokenPath.indexOf(token.positionId);
  }

  /// Check if position is a safe spot
  bool _isSafeSpot(String positionId) {
    // Starting positions (safe)
    List<String> startingSpots = ['R10', 'B04', 'G21', 'Y42'];

    // Home entrance positions (safe)
    List<String> homeSpots = ['RF', 'BF', 'GF', 'YF'];

    // Star positions (safe) - typically every 13th position
    List<String> starSpots = [
      'R22',
      'R02',
      'R50',
      'G02',
      'G25',
      'G10',
      'B23',
      'B01',
      'B15',
      'Y30',
      'Y51',
      'Y12',
    ];

    return startingSpots.contains(positionId) ||
        homeSpots.contains(positionId) ||
        starSpots.contains(positionId);
  }

  /// Check if position is vulnerable to attack
  bool _isVulnerablePosition(String positionId, Player botPlayer) {
    if (_isSafeSpot(positionId)) return false;

    // Check if any opponent can reach this position in next 1-6 moves
    for (Player opponent in GameState().players) {
      if (opponent.playerId != botPlayer.playerId && !opponent.hasWon) {
        for (Token opponentToken in opponent.tokens) {
          if (_canOpponentReach(opponentToken, positionId, opponent)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Get opponent token at specific position
  Token? _getOpponentTokenAt(String positionId, Player botPlayer) {
    for (Token token in TokenManager().allTokens) {
      if (token.playerId != botPlayer.playerId &&
          token.positionId == positionId &&
          !token.isInBase() &&
          _canCaptureAtPosition(positionId)) {
        print('DEBUG: Found capturable opponent token ${token.tokenId} at $positionId');
        return token;
      }
    }
    return null;
  }
  
  /// Check if position allows capturing (not safe spots like stars or starting positions)
  bool _canCaptureAtPosition(String positionId) {
    // Starting positions are safe from capture
    List<String> startingSpots = ['R10', 'B04', 'G21', 'Y42'];
    
    // Star positions are safe from capture
    List<String> starSpots = [
      'R22', 'R02', 'R50',
      'G02', 'G25', 'G10', 
      'B23', 'B01', 'B15',
      'Y30', 'Y51', 'Y12',
    ];
    
    // Home positions are safe (but tokens rarely get captured there anyway)
    List<String> homeSpots = ['RF', 'BF', 'GF', 'YF'];
    
    return !startingSpots.contains(positionId) && 
           !starSpots.contains(positionId) && 
           !homeSpots.contains(positionId);
  }

  /// Check if opponent token can reach target position
  bool _canOpponentReach(
    Token opponentToken,
    String targetPosition,
    Player opponent,
  ) {
    if (opponentToken.isInBase()) return false;

    List<String> opponentPath = GameState().getTokenPath(opponent.playerId);
    int currentIndex = opponentPath.indexOf(opponentToken.positionId);

    if (currentIndex == -1) return false;

    // Check if opponent can reach target in 1-6 moves
    for (int diceValue = 1; diceValue <= 6; diceValue++) {
      int newIndex = currentIndex + diceValue;
      if (newIndex < opponentPath.length &&
          opponentPath[newIndex] == targetPosition) {
        return true;
      }
    }
    return false;
  }

  /// Set bot difficulty
  void setBotDifficulty(BotDifficulty newDifficulty) {
    difficulty = newDifficulty;
    print('Bot difficulty set to: $newDifficulty');
  }

  /// Get current difficulty
  BotDifficulty getBotDifficulty() => difficulty;
}
