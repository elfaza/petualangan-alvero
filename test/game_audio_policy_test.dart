import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petualangan_alvero/audio/game_audio_policy.dart';

void main() {
  test('Alvero effects mix without requesting Android audio focus', () {
    final context = createAlveroEffectsAudioContext();

    expect(context.android.audioFocus, AndroidAudioFocus.none);
  });
}
