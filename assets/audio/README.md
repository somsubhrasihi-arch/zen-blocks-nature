# Original Zen Blocks audio

The ambient score and six event cues in this directory were composed and
synthesized for Zen Blocks using `tools/generate_audio.py`. They contain no
sampled recordings or third-party songs. All audio is bundled for offline use.

- `aurora.mp3`: 32-second four-chord ambient loop with a gentle bell arpeggio
- `start.mp3`: ascending welcome cue
- `rotate.mp3`: short rotation bell
- `lock.mp3`: soft mallet landing
- `clear.mp3`: ascending row-clear sparkle
- `levelUp.mp3`: longer ascending level-up phrase
- `gameOver.mp3`: descending closing phrase

To regenerate, install Python numpy and ffmpeg, then run
`python tools/generate_audio.py`. Runtime playback does not require either tool.
