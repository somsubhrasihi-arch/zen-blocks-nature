import 'package:zen_blocks/game_audio.dart';

class FakeAudioBackend implements AudioBackend {
  final cues = <SoundCue>[];
  final musicStates = <bool>[];
  int stops = 0;
  bool disposed = false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> music(bool playing) async { musicStates.add(playing); }
  @override
  Future<void> effect(SoundCue cue) async { cues.add(cue); }
  @override
  Future<void> stopEffects() async { stops++; }
  @override
  Future<void> dispose() async { disposed = true; }
}
