# Les deux autres actes du flux booster, boucles SANS COUTURE (méthode
# bake_nappe : fréquences au bin, enveloppes circulaires, réverbe en
# convolution circulaire).
#
# braise-veille (20 s) — l'ENGAGEMENT : une veillée sombre et tendue sous
#   la découpe. Bourdon grave de mi qui bat lentement, harmonique haute
#   fantôme, glas rare et doux. Très discret : les crépitements de la
#   passe 3 vivront par-dessus.
# sacre-lune (24 s) — LA CARTE : sombre et émouvante. Pad de cordes
#   chaudes en mi mineur (Em9 → Cmaj7 → Am → B), mélodie de clochettes
#   lente en mineur, réverbe profonde.
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(21)


def write(path, mix, peak_db):
    mix /= np.max(np.abs(mix))
    mix *= 10 ** (peak_db / 20)
    pcm = (mix * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", path, "| couture :", float(np.max(np.abs(mix[0] - mix[-1]))))


def reverb_circ(dry, N, rt60, darken=6):
    ir = rng.standard_normal(int(1.25 * rt60 * SR)) \
        * np.exp(-6.91 * np.arange(int(1.25 * rt60 * SR)) / SR / rt60)
    ir = np.convolve(ir, np.ones(darken) / darken, mode="same")
    wet = np.fft.irfft(np.fft.rfft(dry) * np.fft.rfft(ir, N), N)
    return wet / (np.max(np.abs(wet)) + 1e-9)


# ======================= braise-veille (20 s) ============================
L = 20.0
N = int(SR * L)
t = np.arange(N) / SR
qf = lambda f: round(f * L) / L

veille = np.zeros((N, 2))
# Le bourdon : mi grave en paires qui battent, sombre (peu de partiels).
for f0, a in ((82.41, 1.0), (123.47, 0.45), (164.81, 0.30)):  # E2 B2 E3
    for det in (1.0025, 0.9975):
        for k, ka in ((1, 1.0), (2, 0.28), (3, 0.10)):
            f = qf(f0 * det * k)
            lfo = 0.6 + 0.4 * np.sin(2 * np.pi * (2 / L) * t
                                     + rng.uniform(0, 6.28))
            for ch in range(2):
                veille[:, ch] += a * ka * 0.5 * lfo \
                    * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
veille *= 0.024
# L'harmonique fantôme, très haute et très faible (la tension).
ghost = np.sin(2 * np.pi * qf(82.41 * 12.02) * t) \
    * (0.5 + 0.5 * np.sin(2 * np.pi * (1 / L) * t + 2.1))
veille[:, 0] += ghost * 0.006
veille[:, 1] += ghost * 0.005
# Le glas : deux tolls de mi3 par boucle, doux, mangés de réverbe.
def toll(f0, dur, amp):
    ln = int(dur * SR)
    tt = np.arange(ln) / SR
    out = np.zeros(ln)
    for r, a, tau in ((1.0, 1.0, 2.6), (2.4, 0.25, 1.1), (4.2, 0.08, 0.5)):
        out += a * np.sin(2 * np.pi * qf(f0 * r) * tt) * np.exp(-tt / tau)
    return out * np.minimum(tt / 0.01, 1) * amp
tolls = np.zeros((N, 2))
for pos, f, a in ((3.2, 164.81, 1.0), (13.6, 123.47, 0.8)):
    tone = toll(f, 8.0, a)
    idx = (int(pos * SR) + np.arange(len(tone))) % N
    tolls[idx, 0] += tone * 0.55
    tolls[idx, 1] += tone * 0.45
mix = np.zeros((N, 2))
for ch in range(2):
    wet = reverb_circ(tolls[:, ch], N, 3.0)
    mix[:, ch] = veille[:, ch] + tolls[:, ch] * 0.035 + wet * 0.05
write("/tmp/braise-veille.wav", mix, -16)

# ======================= sacre-lune (24 s) ===============================
L = 24.0
N = int(SR * L)
t = np.arange(N) / SR
qf = lambda f: round(f * L) / L

# Les quatre accords (6 s chacun), voicings chauds :
E3, G3, B3, Fs4 = 164.81, 196.0, 246.94, 369.99
C3, E4, B4 = 130.81, 329.63, 493.88
A2, C4, G4 = 110.0, 261.63, 392.0
B2, Fs3, Ds4 = 123.47, 185.0, 311.13
chords = [
    [E3, G3, B3, Fs4],        # Em(add9)
    [C3, G3, E4, B4],         # Cmaj7
    [A2, E3, C4, G4],         # Am7
    [B2, Fs3, B3, Ds4],       # B (la tension qui ramène au mi)
]
seg = L / 4
pad = np.zeros((N, 2))
for ci, chord in enumerate(chords):
    # Enveloppe circulaire du segment : plateau + rampes cosinus 1,5 s.
    center = (ci + 0.5) * seg
    d = np.abs(((t - center + L / 2) % L) - L / 2)   # distance circulaire
    env = np.clip((seg / 2 + 0.75 - d) / 1.5, 0, 1)
    env = env * env * (3 - 2 * env)
    for note in chord:
        for det in (1.0018, 0.9982):
            tone = np.zeros(N)
            for k in range(1, 6):
                a = (1.0 / k) ** 1.4 * np.exp(-k / 3.5)  # cordes sombres
                tone += a * np.sin(2 * np.pi * qf(note * det * k) * t
                                   + rng.uniform(0, 6.28))
            pan = 0.5 + rng.uniform(-0.18, 0.18)
            pad[:, 0] += tone * env * np.cos(pan * np.pi / 2)
            pad[:, 1] += tone * env * np.sin(pan * np.pi / 2)
pad *= 0.020

# La mélodie : clochettes lentes en mineur, une par accord + une levée.
def bell(f0, dur, amp):
    ln = int(dur * SR)
    tt = np.arange(ln) / SR
    out = np.zeros(ln)
    for r, a, tau in ((1.0, 1.0, 2.2), (2.0, 0.3, 1.0), (2.76, 0.16, 0.5)):
        for det in (1.0017, 0.9983):
            out += a * 0.5 * np.sin(2 * np.pi * qf(f0 * r * det) * tt) \
                * np.exp(-tt / tau)
    return out * np.minimum(tt / 0.005, 1) * amp
melody = [(1.2, 493.88, 0.9), (7.4, 659.26, 0.8), (13.3, 523.25, 0.85),
          (19.2, 622.25, 0.7), (22.4, 493.88, 0.5)]  # B4 E5 C5 D#5 B4
mel = np.zeros((N, 2))
for pos, f, a in melody:
    tone = bell(f, 7.0, a)
    idx = (int(pos * SR) + np.arange(len(tone))) % N
    pan = rng.uniform(0.4, 0.6)
    mel[idx, 0] += tone * np.cos(pan * np.pi / 2)
    mel[idx, 1] += tone * np.sin(pan * np.pi / 2)
mel *= 0.055

mix = np.zeros((N, 2))
for ch in range(2):
    wet = reverb_circ(pad[:, ch] * 0.5 + mel[:, ch], N, 3.4)
    mix[:, ch] = pad[:, ch] * 0.75 + mel[:, ch] * 0.6 + wet * 0.20
write("/tmp/sacre-lune.wav", mix, -13)
