# Original music choices

The original `aurora.mp3` stays unchanged and is selected by default.

| Track | Tempo | File |
| --- | --- | --- |
| Aurora Ambient | 60 BPM | aurora.mp3 |
| Forest Flow | 80 BPM | forest_flow.mp3 |
| Ocean Pulse | 105 BPM | ocean_pulse.mp3 |
| Neon Rush | 135 BPM | neon_rush.mp3 |

All tracks are original synthesized compositions bundled for offline playback.
The additional tracks have 32 beats, with distinct chord sequences and rhythmic
arrangements. `tools/generate_audio.py` regenerates them using numpy and ffmpeg.
Music and visual themes are selected independently in Settings. Track changes
respect the music toggle, volume, pause state and app lifecycle.
