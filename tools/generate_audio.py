"""Compose original Zen Blocks audio. Requires numpy and ffmpeg to regenerate."""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
OUT.mkdir(parents=True, exist_ok=True)

def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)

def render(name, samples):
    samples = np.clip(samples, -.95, .95)
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        with wave.open(tmp.name, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes((samples * 32767).astype('<i2').tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp.name,
            '-codec:a', 'libmp3lame', '-b:a', '48k', str(OUT / f'{name}.mp3')], check=True)

def bell(note, seconds, strength=.3):
    t = np.arange(round(seconds * RATE)) / RATE
    envelope = (1 - np.exp(-t * 120)) * np.exp(-t * 4 / seconds)
    return strength * envelope * (np.sin(2*np.pi*frequency(note)*t)
        + .22*np.sin(2*np.pi*frequency(note)*2*t))

def phrase(name, notes, spacing, tail=.6):
    output = np.zeros(round((len(notes)*spacing + tail)*RATE))
    for i, note in enumerate(notes):
        sound = bell(note, tail)
        start = round(i*spacing*RATE)
        output[start:start+len(sound)] += sound
    render(name, output)

# 32-second, four-chord original ambient score with a gentle arpeggio.
music = np.zeros(32 * RATE)
chords = [(48,55,60,64), (45,52,57,60), (41,48,53,57), (43,50,55,59)]
for bar, chord in enumerate(chords):
    t = np.arange(8*RATE)/RATE
    pad = sum(np.sin(2*np.pi*frequency(note)*t) for note in chord) / len(chord)
    envelope = np.minimum(t/.5, 1) * np.minimum((8-t)/.9, 1)
    music[bar*8*RATE:(bar+1)*8*RATE] += .2*pad*envelope
    pattern = [0,2,1,3,2,1,3,2,0,1,2,3,1,2,3,2]
    for beat, index in enumerate(pattern):
        start = round((bar*8+beat*.5)*RATE)
        sound = bell(chord[index]+24, .9, .13)
        count = min(len(sound), len(music)-start)
        music[start:start+count] += sound[:count]
music[:round(.2*RATE)] *= np.linspace(0,1,round(.2*RATE))
music[-round(.3*RATE):] *= np.linspace(1,0,round(.3*RATE))
render('aurora', music)
phrase('start', [60,64,67,72], .1)
phrase('rotate', [84], .02, .12)
# A short descending wooden/mallet landing tone.
phrase('lock', [55,48], .035, .15)
phrase('clear', [72,76,79,84], .07, .5)
phrase('levelUp', [60,64,67,72,76,79,84], .09, .7)
phrase('gameOver', [64,60,55,48], .22, .9)
print('Generated original ambient score and six event cues in', OUT)


# Optional music choices. The original aurora track above remains the default.
def groove(name, bpm, chords, energy):
    beat = 60 / bpm
    duration = 32 * beat
    output = np.zeros(round(duration * RATE))
    rng = np.random.default_rng(77 + bpm)
    for bar in range(8):
        chord = chords[bar % len(chords)]
        start = round(bar * 4 * beat * RATE)
        count = min(round(4 * beat * RATE), len(output)-start)
        t = np.arange(count)/RATE
        pad = sum(np.sin(2*np.pi*frequency(note)*t) for note in chord)/len(chord)
        envelope = np.minimum(t/.14, 1)*np.minimum((count/RATE-t)/.25, 1)
        output[start:start+count] += .12 * pad * envelope
        for eighth in range(8):
            note = chord[[0,2,1,2,0,1,2,1][eighth]] + 24
            tone = bell(note, min(.7, beat*.9), .14 if energy < 2 else .18)
            offset = round((bar*4*beat+eighth*beat/2)*RATE)
            length = min(len(tone), len(output)-offset)
            output[offset:offset+length] += tone[:length]
        if energy:
            for pulse in range(4):
                t = np.arange(round(.16*RATE))/RATE
                kick = .13 * np.sin(2*np.pi*(70*t+5*(1-np.exp(-t*25))))*np.exp(-t*25)
                offset = round((bar*4+pulse)*beat*RATE)
                length = min(len(kick),len(output)-offset)
                output[offset:offset+length] += kick[:length]
                if energy > 1:
                    t = np.arange(round(.06*RATE))/RATE
                    hat = .035*rng.uniform(-1,1,len(t))*np.exp(-t*70)
                    offset = round((bar*4+pulse+.5)*beat*RATE)
                    length = min(len(hat),len(output)-offset)
                    output[offset:offset+length] += hat[:length]
    edge = round(.08*RATE)
    output[:edge] *= np.linspace(0,1,edge)
    output[-edge:] *= np.linspace(1,0,edge)
    render(name, output)

groove('forest_flow', 80, [(48,55,64),(45,52,60),(41,48,57),(43,50,59)], 0)
groove('ocean_pulse', 105, [(50,57,65),(46,53,62),(48,55,64),(45,52,60)], 1)
groove('neon_rush', 135, [(45,52,60),(48,55,64),(43,50,59),(41,48,57)], 2)
print('Generated optional 80, 105 and 135 BPM original tracks.')
