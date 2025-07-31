import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioManager {
  static final SoLoud _soloud = SoLoud.instance;
  static AudioSource? _diceSoundSource;
  static AudioSource? _stepSoundSource;

  static Future<void> initialize() async {
    await _soloud.init(bufferSize: Platform.isAndroid ? 256 : 1024);
    _diceSoundSource = await _soloud.loadAsset('assets/audio/dice.wav');
    _stepSoundSource = await _soloud.loadAsset('assets/audio/step_sound.wav');
  }

  static void playDiceSound() {
    if (_diceSoundSource != null) {
      _soloud.play(_diceSoundSource!);
    }
  }

  static void playStepSound() {
    if (_stepSoundSource != null) {
      _soloud.play(_stepSoundSource!);
    }
  }

  static Future<void> dispose() async {
    if (_diceSoundSource != null) {
      await _soloud.disposeSource(_diceSoundSource!);
      _diceSoundSource = null;
    }
    if (_stepSoundSource != null) {
      await _soloud.disposeSource(_stepSoundSource!);
      _stepSoundSource = null;
    }
    _soloud.deinit();
  }
}
