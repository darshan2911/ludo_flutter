import 'dart:math';
import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/gestures.dart';
import 'package:ludo_flame/state/game_state.dart';
import 'package:ludo_flame/state/player.dart';
import 'package:ludo_flame/state/token_manager.dart';
import 'package:ludo_flame/component/ui_components/token.dart';
import 'package:ludo_flame/component/ui_components/ludo_dice.dart';

enum BotDifficulty { easy, medium, hard }

class BotController {
  static final BotController instance = BotController._internal();
  BotController._internal();

  BotDifficulty difficulty = BotDifficulty.medium;
  final Random _random = Random();

  /// Main bot move execution - finds dice and calls common roll logic
  Future<void> makeMove(Player botPlayer) async {
    print('DEBUG: BotController.makeMove called for ${botPlayer.playerId}');
    await Future.delayed(Duration(milliseconds: 800)); // Simulate thinking time

    try {
      // Find the dice component that belongs to this specific player
      final dice = _findDiceComponent(botPlayer);
      if (dice != null) {
        print('DEBUG: Found dice for player ${botPlayer.playerId}, executing roll');
        await (dice as dynamic).executeDiceRoll(withAnimation: true);
      } else {
        print('DEBUG: No dice found for player ${botPlayer.playerId}, switching to next player');
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

    final world = ludoGame.children.firstWhere((c) => c.runtimeType.toString() == 'World');
    
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
  Component? _findPlayerDiceRecursively(Component component, Player targetPlayer) {
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
    print('DEBUG: simulateTokenTap called for ${botPlayer.playerId} with dice value $diceValue');
    await Future.delayed(Duration(milliseconds: 500)); // Thinking time
    
    Token? bestToken = chooseBestTokenForMove(botPlayer, diceValue);
    if (bestToken != null) {
      print('DEBUG: Bot chose token ${bestToken.tokenId} at position ${bestToken.positionId}');
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

  /// Strategic token selection based on difficulty and game situation
  Token _chooseBestToken(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    switch (difficulty) {
      case BotDifficulty.easy:
        return _chooseTokenEasy(movableTokens);
      case BotDifficulty.medium:
        return _chooseTokenMedium(movableTokens, diceValue, botPlayer);
      case BotDifficulty.hard:
        return _chooseTokenHard(movableTokens, diceValue, botPlayer);
    }
  }

  /// Easy difficulty: Basic strategy with some randomness
  Token _chooseTokenEasy(List<Token> movableTokens) {
    // Priority 1: Always capture if possible (40% chance to follow)
    if (_random.nextDouble() < 0.4) {
      Token? captureToken = _findCaptureMove(movableTokens, GameState().diceNumber, GameState().currentPlayer);
      if (captureToken != null) return captureToken;
    }
    
    // Priority 2: Move to home if very close (50% chance to follow)
    if (_random.nextDouble() < 0.5) {
      Token? homeToken = _findHomeMove(movableTokens, GameState().diceNumber, GameState().currentPlayer);
      if (homeToken != null) return homeToken;
    }
    
    // Priority 3: Get out of base with 6 (60% chance to follow)
    if (GameState().diceNumber == 6 && _random.nextDouble() < 0.6) {
      try {
        Token baseToken = movableTokens.firstWhere((t) => t.isInBase());
        return baseToken;
      } catch (e) {}
    }
    
    // Priority 4: Prefer tokens not in base (40% chance)
    if (_random.nextDouble() < 0.4) {
      List<Token> nonBaseTokens = movableTokens.where((t) => !t.isInBase()).toList();
      if (nonBaseTokens.isNotEmpty) {
        return nonBaseTokens[_random.nextInt(nonBaseTokens.length)];
      }
    }
    
    // Fallback: Random selection
    return movableTokens[_random.nextInt(movableTokens.length)];
  }

  /// Medium difficulty: Strategic selection with multiple priorities
  Token _chooseTokenMedium(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    // Priority 1: Capture opponent token (always do this)
    Token? captureToken = _findCaptureMove(movableTokens, diceValue, botPlayer);
    if (captureToken != null) return captureToken;

    // Priority 2: Enter home area if possible (high priority)
    Token? homeToken = _findHomeMove(movableTokens, diceValue, botPlayer);
    if (homeToken != null) return homeToken;

    // Priority 3: Move token to safety if currently vulnerable
    Token? safetyToken = _findSafetyMove(movableTokens, diceValue, botPlayer);
    if (safetyToken != null) return safetyToken;

    // Priority 4: Move token out of base with 6 (but not if too many tokens out)
    if (diceValue == 6) {
      int tokensOnBoard = botPlayer.tokens.where((t) => t.isOnBoard()).length;
      if (tokensOnBoard < 3) { // Don't overcrowd the board
        try {
          Token baseToken = movableTokens.firstWhere((t) => t.isInBase());
          return baseToken;
        } catch (e) {}
      }
    }

    // Priority 5: Move furthest token (progress strategy)
    return _findFurthestToken(movableTokens, botPlayer);
  }

  /// Hard difficulty: Advanced strategic AI with lookahead and risk assessment
  Token _chooseTokenHard(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    Map<Token, double> tokenScores = {};

    for (Token token in movableTokens) {
      double score = _evaluateTokenMoveAdvanced(token, diceValue, botPlayer);
      tokenScores[token] = score;
    }

    // Sort by score and add minimal randomness to maintain strategic play
    List<MapEntry<Token, double>> sortedEntries = tokenScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Pick from top 2 moves with weighted probability (more focused than medium)
    if (sortedEntries.length >= 2) {
      double rand = _random.nextDouble();
      if (rand < 0.8) return sortedEntries[0].key; // Best move 80%
      return sortedEntries[1].key; // Second best 20%
    }

    return sortedEntries.first.key;
  }

  /// Advanced evaluation for hard difficulty with comprehensive risk assessment
  double _evaluateTokenMoveAdvanced(Token token, int diceValue, Player botPlayer) {
    double score = 0.0;

    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int currentIndex = tokenPath.indexOf(token.positionId);

    if (currentIndex == -1) return -1000; // Invalid move

    int newIndex = currentIndex + diceValue;
    if (newIndex >= tokenPath.length) return -1000; // Beyond finish

    String newPositionId = tokenPath[newIndex];

    // Base score: exponential progress toward home (rewards tokens closer to finish)
    score += (newIndex * newIndex * 2); // Quadratic scoring for progress

    // PRIORITY 1: Capture opponent (highest priority)
    if (_wouldCaptureOpponent(newPositionId, botPlayer)) {
      score += 800; // Increased from 500
      // Extra bonus if capturing token close to home
      Token? capturedToken = _getOpponentTokenAt(newPositionId, botPlayer);
      if (capturedToken != null) {
        List<String> opponentPath = GameState().getTokenPath(capturedToken.playerId);
        int opponentProgress = opponentPath.indexOf(capturedToken.positionId);
        if (opponentProgress > 40) score += 300; // High value target
      }
    }

    // PRIORITY 2: Defensive play - avoid vulnerable positions
    if (_isHighRiskPosition(newPositionId, botPlayer)) {
      score -= 400; // Heavy penalty for high-risk moves
    } else if (_isVulnerablePosition(newPositionId, botPlayer)) {
      score -= 200; // Moderate penalty for vulnerable positions
    }

    // PRIORITY 3: Safe play - reward safe positions
    if (_isSafeSpot(newPositionId)) {
      score += 250;
      // Extra bonus if moving from vulnerable to safe
      if (!token.isInBase() && _isVulnerablePosition(token.positionId, botPlayer)) {
        score += 200; // Escape bonus
      }
    }

    // PRIORITY 4: Home stretch (very high value)
    if (newPositionId.endsWith('F')) {
      score += 1200; // Increased from 1000
    } else if (_isNearHome(newPositionId, botPlayer)) {
      score += 400; // Bonus for approaching home
    }

    // PRIORITY 5: Strategic base exit (only when safe)
    if (token.isInBase() && diceValue == 6) {
      // Check if starting position is safe
      String startPosition = tokenPath[0];
      if (_isSafeSpot(startPosition) || !_isVulnerablePosition(startPosition, botPlayer)) {
        score += 350;
      } else {
        score += 100; // Lower bonus if starting position is risky
      }
      
      // Penalty if too many tokens already out (avoid overcrowding)
      int tokensOnBoard = botPlayer.tokens.where((t) => t.isOnBoard()).length;
      if (tokensOnBoard >= 3) score -= 150;
    }

    // PRIORITY 6: Blocking strategy - block opponent progress
    if (_wouldBlockOpponent(newPositionId, botPlayer)) {
      score += 300;
    }

    // PRIORITY 7: Formation play - keep tokens together for protection
    if (_hasNearbyFriendlyToken(newPositionId, botPlayer)) {
      score += 100;
    }

    // PRIORITY 8: Endgame optimization
    if (_isEndgamePhase(botPlayer)) {
      // In endgame, prioritize getting remaining tokens home
      int tokensInHome = botPlayer.tokens.where((t) => t.positionId.endsWith('F')).length;
      if (tokensInHome >= 2) {
        score += (newIndex * 5); // Extra progress bonus in endgame
      }
    }

    return score;
  }

  /// Find token that can capture opponent
  Token? _findCaptureMove(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    for (Token token in movableTokens) {
      if (!token.isInBase()) {
        List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
        int currentIndex = tokenPath.indexOf(token.positionId);

        if (currentIndex != -1) {
          int newIndex = currentIndex + diceValue;
          if (newIndex < tokenPath.length) {
            String newPositionId = tokenPath[newIndex];
            if (_wouldCaptureOpponent(newPositionId, botPlayer)) {
              return token;
            }
          }
        }
      }
    }
    return null;
  }

  /// Check if position would capture opponent token
  bool _wouldCaptureOpponent(String positionId, Player botPlayer) {
    List<Token> allTokens = TokenManager().allTokens;

    for (Token token in allTokens) {
      if (token.playerId != botPlayer.playerId &&
          token.positionId == positionId &&
          !token.isInBase() &&
          !_isSafeSpot(positionId)) {
        return true;
      }
    }
    return false;
  }

  /// Find token that can move to safety
  Token? _findSafetyMove(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    for (Token token in movableTokens) {
      if (!token.isInBase()) {
        List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
        int currentIndex = tokenPath.indexOf(token.positionId);

        if (currentIndex != -1) {
          int newIndex = currentIndex + diceValue;
          if (newIndex < tokenPath.length) {
            String newPositionId = tokenPath[newIndex];
            if (_isSafeSpot(newPositionId) && !_isSafeSpot(token.positionId)) {
              return token;
            }
          }
        }
      }
    }
    return null;
  }

  /// Find token that can enter home
  Token? _findHomeMove(
    List<Token> movableTokens,
    int diceValue,
    Player botPlayer,
  ) {
    for (Token token in movableTokens) {
      if (!token.isInBase()) {
        List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
        int currentIndex = tokenPath.indexOf(token.positionId);

        if (currentIndex != -1) {
          int newIndex = currentIndex + diceValue;
          if (newIndex < tokenPath.length) {
            String newPositionId = tokenPath[newIndex];
            if (newPositionId.endsWith('F')) {
              // Final home position
              return token;
            }
          }
        }
      }
    }
    return null;
  }

  /// Find the token furthest along the path
  Token _findFurthestToken(List<Token> movableTokens, Player botPlayer) {
    Token furthestToken = movableTokens.first;
    int maxProgress = -1;

    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);

    for (Token token in movableTokens) {
      int progress = token.isInBase()
          ? -1
          : tokenPath.indexOf(token.positionId);
      if (progress > maxProgress) {
        maxProgress = progress;
        furthestToken = token;
      }
    }

    return furthestToken;
  }

  /// Check if position is a safe spot
  bool _isSafeSpot(String positionId) {
    // Starting positions (safe)
    List<String> startingSpots = ['R10', 'B04', 'G21', 'Y42'];
    
    // Home entrance positions (safe)
    List<String> homeSpots = ['RF', 'BF', 'GF', 'YF'];
    
    // Star positions (safe) - typically every 13th position
    List<String> starSpots = [
      'R22', 'R02', 'R50', 'G02', 'G25', 'G10', 
      'B23', 'B01', 'B15', 'Y30', 'Y51', 'Y12'
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

  /// Check if position is high-risk (multiple opponents can reach)
  bool _isHighRiskPosition(String positionId, Player botPlayer) {
    if (_isSafeSpot(positionId)) return false;

    int threateningOpponents = 0;
    for (Player opponent in GameState().players) {
      if (opponent.playerId != botPlayer.playerId && !opponent.hasWon) {
        for (Token opponentToken in opponent.tokens) {
          if (_canOpponentReach(opponentToken, positionId, opponent)) {
            threateningOpponents++;
            break; // Count each opponent only once
          }
        }
      }
    }
    return threateningOpponents >= 2;
  }

  /// Get opponent token at specific position
  Token? _getOpponentTokenAt(String positionId, Player botPlayer) {
    for (Token token in TokenManager().allTokens) {
      if (token.playerId != botPlayer.playerId && 
          token.positionId == positionId && 
          !token.isInBase()) {
        return token;
      }
    }
    return null;
  }

  /// Check if position is near home stretch
  bool _isNearHome(String positionId, Player botPlayer) {
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int currentIndex = tokenPath.indexOf(positionId);
    return currentIndex >= tokenPath.length - 10; // Last 10 positions
  }

  /// Check if move would block opponent progress
  bool _wouldBlockOpponent(String positionId, Player botPlayer) {
    // Check if this position is on opponent's critical path
    for (Player opponent in GameState().players) {
      if (opponent.playerId != botPlayer.playerId && !opponent.hasWon) {
        List<String> opponentPath = GameState().getTokenPath(opponent.playerId);
        // Check if position is on opponent's home stretch
        int pathIndex = opponentPath.indexOf(positionId);
        if (pathIndex >= opponentPath.length - 15 && pathIndex != -1) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if there's a friendly token nearby for protection
  bool _hasNearbyFriendlyToken(String positionId, Player botPlayer) {
    List<String> tokenPath = GameState().getTokenPath(botPlayer.playerId);
    int targetIndex = tokenPath.indexOf(positionId);
    if (targetIndex == -1) return false;

    for (Token friendlyToken in botPlayer.tokens) {
      if (friendlyToken.isOnBoard()) {
        int friendlyIndex = tokenPath.indexOf(friendlyToken.positionId);
        if (friendlyIndex != -1 && 
            (friendlyIndex - targetIndex).abs() <= 3 && 
            friendlyIndex != targetIndex) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if game is in endgame phase
  bool _isEndgamePhase(Player botPlayer) {
    int tokensInHome = botPlayer.tokens.where((t) => t.positionId.endsWith('F')).length;
    return tokensInHome >= 1; // Endgame when at least 1 token is home
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