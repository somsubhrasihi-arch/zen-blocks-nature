import 'package:flutter/material.dart';

const appDisplayName = 'T-Block Aurora';

class MusicTrack {
  const MusicTrack(this.id, this.name, this.bpm, this.mood, this.asset);
  final String id, name, mood, asset;
  final int bpm;
  String get label => '$name · $bpm BPM';
}

const musicTracks = [
  MusicTrack('aurora', 'Aurora Ambient', 60, 'Calm, spacious bells · original default', 'audio/aurora.mp3'),
  MusicTrack('forest', 'Forest Flow', 80, 'Warm, gentle arpeggios', 'audio/forest_flow.mp3'),
  MusicTrack('ocean', 'Ocean Pulse', 105, 'Flowing synths and a light rhythm', 'audio/ocean_pulse.mp3'),
  MusicTrack('rush', 'Neon Rush', 135, 'Bright, energetic arcade groove', 'audio/neon_rush.mp3'),
];

MusicTrack trackForId(String? id) => musicTracks.firstWhere((track) => track.id == id,
  orElse: () => musicTracks.first);

class GamePalette {
  const GamePalette({required this.id, required this.name, required this.background,
    required this.panel, required this.control, required this.accent, required this.muted,
    required this.grid, required this.board, required this.overlay, required this.stats,
    required this.blocks});
  final String id, name;
  final List<Color> background, stats, blocks;
  final Color panel, control, accent, muted, grid, board, overlay;

  List<List<Color>> get auroras => id == 'neon' ? const [
    [Color(0xFF00DFFF), Color(0xFFAB47FF)],
    [Color(0xFF00FFC8), Color(0xFF5C89FF)],
    [Color(0xFFFF48B7), Color(0xFFFF9D3B)],
    [Color(0xFFAD65FF), Color(0xFF2E8EFF)],
    [Color(0xFF2CF8F1), Color(0xFFFA4CFF)],
  ] : [[accent, blocks[2]], [blocks[3], blocks[1]], [blocks[5], accent]];
}

const neonPalette = GamePalette(id: 'neon', name: 'Neon Aurora',
  background: [Color(0xFF090B31), Color(0xFF251054), Color(0xFF071638)],
  panel: Color(0xFF121947), control: Color(0xFF18265B), accent: Color(0xFF38D8FF),
  muted: Color(0xFFA9B9EE), grid: Color(0xFF354B91), board: Color(0xE8081031), overlay: Color(0xE9091030),
  stats: [Color(0xFF172B68), Color(0xFF211044)],
  blocks: [Color(0xFF00DFFF), Color(0xFFFFC247), Color(0xFFE250FF), Color(0xFF00F2B2),
    Color(0xFFFF648F), Color(0xFF598BFF), Color(0xFFAB72FF)]);

const gamePalettes = [neonPalette,
  GamePalette(id: 'forest', name: 'Forest Calm',
    background: [Color(0xFF061D19), Color(0xFF123B2E), Color(0xFF091E1B)],
    panel: Color(0xFF153D31), control: Color(0xFF1C4B3D), accent: Color(0xFF8EE6B7),
    muted: Color(0xFFB5D5C5), grid: Color(0xFF345D4E), board: Color(0xED071F19), overlay: Color(0xEF092B21),
    stats: [Color(0xFF1F503B), Color(0xFF143629)],
    blocks: [Color(0xFF8CE1C5), Color(0xFFE9CC83), Color(0xFFC4A7E7), Color(0xFF77CE8E),
      Color(0xFFF1A887), Color(0xFF83BFD9), Color(0xFFC6D77A)]),
  GamePalette(id: 'sunset', name: 'Solar Sunset',
    background: [Color(0xFF291127), Color(0xFF5A2234), Color(0xFF20142C)],
    panel: Color(0xFF3C2038), control: Color(0xFF572B40), accent: Color(0xFFFFBE73),
    muted: Color(0xFFF1C6BD), grid: Color(0xFF754357), board: Color(0xED271223), overlay: Color(0xEF321627),
    stats: [Color(0xFF613040), Color(0xFF39203F)],
    blocks: [Color(0xFFFFBC77), Color(0xFFFFDE8A), Color(0xFFE79ADD), Color(0xFF99D9BE),
      Color(0xFFFF8D9A), Color(0xFFA1AFF4), Color(0xFFC5A0ED)]),
  GamePalette(id: 'ocean', name: 'Ocean Drift',
    background: [Color(0xFF061D35), Color(0xFF0D4351), Color(0xFF082C42)],
    panel: Color(0xFF123C50), control: Color(0xFF174B5D), accent: Color(0xFF6BE4EC),
    muted: Color(0xFFB1D5E5), grid: Color(0xFF35677B), board: Color(0xED07253B), overlay: Color(0xEF082C40),
    stats: [Color(0xFF195368), Color(0xFF173752)],
    blocks: [Color(0xFF6DE6EB), Color(0xFFFFDA83), Color(0xFFB8AAEF), Color(0xFF7EE0BC),
      Color(0xFFF5A1B9), Color(0xFF7EBBF6), Color(0xFF9CACE9)]),
];

GamePalette paletteForId(String? id) => gamePalettes.firstWhere((theme) => theme.id == id,
  orElse: () => neonPalette);
