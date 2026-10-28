import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'game.dart';

enum SoundCue { start, rotate, lock, clear, levelUp, gameOver }

/// Tracks completed game events, rather than treating every score change as a sound.
class GameSoundTracker {
  int _locks = 0, _lines = 0, _level = 1;
  bool _started = false, _over = false;

  List<SoundCue> update(ZenGame game) {
    final cues = <SoundCue>[];
    if (game.started && !_started) cues.add(SoundCue.start);
    if (game.over && !_over) {
      cues.add(SoundCue.gameOver);
    } else if (game.level > _level) {
      cues.add(SoundCue.levelUp);
    } else if (game.lines > _lines) {
      cues.add(SoundCue.clear);
    } else if (game.piecesLocked > _locks) {
      cues.add(SoundCue.lock);
    }
    _locks = game.piecesLocked;
    _lines = game.lines;
    _level = game.level;
    _started = game.started;
    _over = game.over;
    return cues;
  }
}

abstract class AudioBackend {
  Future<void> initialize();
  Future<void> music(bool playing);
  Future<void> effect(SoundCue cue);
  Future<void> stopEffects();
  Future<void> dispose();
}

class DeviceAudioBackend implements AudioBackend {
  AudioPlayer? _music;
  final Map<SoundCue, AudioPlayer> _effects = {};

  @override
  Future<void> initialize() async {
    final music = _music = AudioPlayer();
    await music.setReleaseMode(ReleaseMode.loop);
    await music.setVolume(.28);
    await music.setSource(AssetSource('audio/aurora.mp3'));
    for (final cue in SoundCue.values) {
      final player = _effects[cue] = AudioPlayer();
      await player.setAudioContext(AudioContext(android: const AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none)));
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(.8);
      await player.setSource(AssetSource('audio/${cue.name}.mp3'));
    }
  }

  @override
  Future<void> music(bool playing) async {
    if (playing) { await _music?.resume(); } else { await _music?.pause(); }
  }

  @override
  Future<void> effect(SoundCue cue) async {
    final player = _effects[cue];
    await player?.seek(Duration.zero);
    await player?.resume();
  }

  @override
  Future<void> stopEffects() async {
    for (final player in _effects.values) { await player.pause(); }
  }

  @override
  Future<void> dispose() async {
    await _music?.dispose();
    for (final player in _effects.values) { await player.dispose(); }
    _effects.clear();
  }
}

/// Serializes native playback changes so a late load cannot undo a mute or pause.
class GameAudio {
  GameAudio({AudioBackend? backend}) : _backend = backend ?? DeviceAudioBackend();
  final AudioBackend _backend;
  final GameSoundTracker _tracker = GameSoundTracker();
  Future<void> _queue = Future.value();
  Future<void>? _initialization;
  bool _disposed = false, _playing = false, _effects = false, _audible = false;

  Future<void> _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await (_initialization ??= _backend.initialize());
        await action();
      } catch (error) {
        debugPrint('Audio unavailable: $error');
      }
    });
    return _queue;
  }

  Future<void> prepare() => _enqueue(() async {});

  Future<void> sync(ZenGame game, {required bool musicEnabled,
    required bool effectsEnabled, required bool foreground}) {
    final cues = _tracker.update(game);
    final active = foreground && game.started && !game.paused && !game.over;
    final playing = active && musicEnabled;
    final effects = active && effectsEnabled;
    final musicChanged = playing != _playing;
    final audible = foreground && effectsEnabled && !game.paused;
    final silence = (!effects && _effects) || (!audible && _audible);
    _playing = playing;
    _effects = effects;
    _audible = audible;
    // Game over may play its final cue while music is stopped.
    final sounds = audible ? cues : <SoundCue>[];
    if (!musicChanged && !silence && sounds.isEmpty) return _queue;
    return _enqueue(() async {
      if (musicChanged) await _backend.music(playing);
      if (silence) await _backend.stopEffects();
      for (final cue in sounds) { await _backend.effect(cue); }
    });
  }

  Future<void> rotate() {
    if (!_effects) return _queue;
    return _enqueue(() => _backend.effect(SoundCue.rotate));
  }

  Future<void> dispose() async {
    _disposed = true;
    await _queue;
    try { await _backend.dispose(); } catch (error) { debugPrint('Audio cleanup: $error'); }
  }
}
