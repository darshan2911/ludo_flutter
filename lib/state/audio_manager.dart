import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static AudioPool? _diceSoundPool;
  static AudioPool? _stepSoundPool;

  /// Initialize both dice and step sound pools
  static Future<void> initialize() async {
    _diceSoundPool ??= await AudioPool.createFromAsset(
      path: 'audio/dice.mp3',
      maxPlayers: 3,
    );

    _stepSoundPool ??= await AudioPool.createFromAsset(
      path: 'audio/step_sound.wav',
      maxPlayers: 5, // more players for rapid token steps
    );
  }

  static Future<StopFunction> playDiceSound({double volume = 1.0}) async {
    return await _diceSoundPool!.start(volume: volume);
  }

  static Future<StopFunction> playStepSound({double volume = 1.0}) async {
    return await _stepSoundPool!.start(volume: volume);
  }

  static Future<void> dispose() async {
    await _diceSoundPool?.dispose();
    _diceSoundPool = null;

    await _stepSoundPool?.dispose();
    _stepSoundPool = null;
  }
}
