import 'package:audioplayers/audioplayers.dart';

/// Creates an effects-player context that lets game sounds mix with music.
AudioContext createAlveroEffectsAudioContext() => AudioContext(
  android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
);
