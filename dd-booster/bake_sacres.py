# Les trois sacres, v2 — LE PIANO D'ABORD (verdicts Kathryn : « au-delà
# des ahh, du piano, de la mélancolie, un côté poétique sombre et
# majestueux » ; « du piano assez discret et des sons poétiques magiques
# et élégants — pas mystique, pas féérique, pas bébé, pas fake, élégant
# et volatile »). Zéro carillon, zéro église, zéro gong — toujours.
#
# La voix maison : un PIANO FEUTRÉ synthétique (partiels inharmoniques,
# marteau doux, décroissance expo — jamais une cloche), des phrases
# ÉPARSES en mi mineur (le rubato écrit à la main), des nappes de cordes
# sombres dessous, et pour la légendaire : le chœur en retrait, le sub,
# la timbale douce. Sommets TÔT (4-8 s : la plongée n'entend que ~10 s).
#
# sacre-commune (18 s)    — le piano seul, la tendresse.
# sacre-epique (22 s)     — le piano et la houle.
# sacre-legendaire (24 s) — l'opéra sombre poétique.
import subprocess
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(44)


def write(path, mix, peak_db):
    mix = mix / np.max(np.abs(mix))
    mix = mix * 10 ** (peak_db / 20)
    pcm = (mix * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", path)


def reverb(dry, N, rt60, darken=6):
    ln = int(1.25 * rt60 * SR)
    ir = rng.standard_normal(ln) * np.exp(-6.91 * np.arange(ln) / SR / rt60)
    ir = np.convolve(ir, np.ones(darken) / darken, mode="same")
    wet = np.fft.irfft(np.fft.rfft(dry, N + ln) * np.fft.rfft(ir, N + ln))[:N]
    return wet / (np.max(np.abs(wet)) + 1e-9)


def sstep(a, b, x):
    y = np.clip((x - a) / (b - a), 0, 1)
    return y * y * (3 - 2 * y)


def swell(t, on, up, off, down):
    return sstep(on, on + up, t) * (1 - sstep(off, off + down, t))


# ----------------------------- LE PIANO ----------------------------------
def piano_note(f0, dur, velo=1.0):
    """Une note de piano FEUTRÉ : partiels légèrement inharmoniques
    (B=3e-4), les hauts qui meurent plus vite, un souffle de marteau —
    et deux cordes désaccordées d'un cheveu (la chaleur). Pas de cloche :
    le spectre est dense et la décroissance est celle d'une corde."""
    ln = int(dur * SR)
    tt = np.arange(ln) / SR
    out = np.zeros(ln)
    for det in (1.0006, 0.9994):
        for k in range(1, 11):
            fk = f0 * det * k * (1 + 3e-4 * k * k)
            if fk > 5200:
                break
            a = (1.0 / k ** 1.25) * np.exp(-k / 3.2)
            tau = 2.4 / (0.55 + 0.16 * k)
            out += a * np.sin(2 * np.pi * fk * tt + rng.uniform(0, 6.28)) \
                * np.exp(-tt / tau)
    # L'attaque : 6 ms de rampe + le souffle du marteau feutré.
    out *= np.minimum(tt / 0.006, 1)
    nz = rng.standard_normal(int(0.014 * SR)) * 0.10
    nz = np.convolve(nz, np.ones(24) / 24, mode="same")
    out[: len(nz)] += nz * np.exp(-np.arange(len(nz)) / SR / 0.006)
    return out * velo


def piano_phrase(N, notes):
    """La phrase posée dans la boucle : [(temps, fréquence, vélocité)] —
    le rubato est écrit à la main, chaque note respire."""
    out = np.zeros((N, 2))
    for pos, f, v in notes:
        tone = piano_note(f, min(6.5, N / SR - pos + 0.5), v)
        i0 = int(pos * SR)
        seg = tone[: max(0, N - i0)]
        pan = 0.5 + rng.uniform(-0.1, 0.1)
        out[i0:i0 + len(seg), 0] += seg * np.cos(pan * np.pi / 2)
        out[i0:i0 + len(seg), 1] += seg * np.sin(pan * np.pi / 2)
    return out


def strings(t, notes, env, dark=1.4, K=6):
    N = len(t)
    out = np.zeros((N, 2))
    for f0 in notes:
        for det in (1.0018, 0.9982):
            tone = np.zeros(N)
            for k in range(1, K + 1):
                a = (1.0 / k) ** dark * np.exp(-k / 3.5)
                tone += a * np.sin(2 * np.pi * f0 * det * k * t
                                   + rng.uniform(0, 6.28))
            pan = 0.5 + rng.uniform(-0.2, 0.2)
            out[:, 0] += tone * env * np.cos(pan * np.pi / 2)
            out[:, 1] += tone * env * np.sin(pan * np.pi / 2)
    return out


def choir(t, notes, env):
    N = len(t)
    formants = ((700, 110, 1.0), (1080, 140, 0.55), (2650, 260, 0.18))
    out = np.zeros((N, 2))
    for f0 in notes:
        for det in (1.003, 0.997, 1.0):
            tone = np.zeros(N)
            for k in range(1, 26):
                fk = f0 * det * k
                if fk > 3400:
                    break
                w = sum(a * np.exp(-((fk - fc) / bw) ** 2)
                        for fc, bw, a in formants)
                vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t
                                         + rng.uniform(0, 6.28))
                tone += (w / k ** 0.3) * np.sin(2 * np.pi * fk * t * vib
                                                + rng.uniform(0, 6.28))
            pan = 0.5 + rng.uniform(-0.25, 0.25)
            out[:, 0] += tone * env * np.cos(pan * np.pi / 2)
            out[:, 1] += tone * env * np.sin(pan * np.pi / 2)
    return out


def timpani(N, pos, f0=41.2, amp=1.0, roll=None):
    out = np.zeros((N, 2))
    hits = [(pos, amp)]
    if roll:
        r0, r1, n = roll
        hits = [(r0 + (r1 - r0) * i / n, amp * (0.25 + 0.75 * i / n))
                for i in range(n)] + [(r1, amp)]
    for p, a in hits:
        ln = int(1.1 * SR)
        tt = np.arange(ln) / SR
        fall = f0 * (1 + 0.16 * np.exp(-tt / 0.09))
        body = np.sin(2 * np.pi * np.cumsum(fall) / SR) * np.exp(-tt / 0.42)
        nz = rng.standard_normal(ln) * np.exp(-tt / 0.05)
        nz = np.convolve(nz, np.ones(48) / 48, mode="same")
        hit = (body * 1.0 + nz * 0.5) * a
        i0 = int(p * SR)
        seg = hit[: max(0, min(ln, N - i0))]
        out[i0:i0 + len(seg), 0] += seg * 0.52
        out[i0:i0 + len(seg), 1] += seg * 0.48
    return out


def sub(t, f0, env):
    return np.sin(2 * np.pi * f0 * t)[:, None] * env[:, None] * [0.5, 0.5]


E1, E2, B2, E3, G3, B3 = 41.2, 82.41, 123.47, 164.81, 196.0, 246.94
C2, C3, G2, D3, Fs3, A3 = 65.41, 130.81, 98.0, 146.83, 185.0, 220.0
B3n, E4, Fs4, G4, A4, B4, D5, E5, G5 = (246.94, 329.63, 369.99, 392.0,
                                        440.0, 493.88, 587.33, 659.26,
                                        783.99)

# ================= sacre-commune (18 s) — le piano seul ==================
L = 18.0
N = int(SR * L)
t = np.arange(N) / SR
# La phrase tendre : éparse, mélancolique, qui se pose sur mi.
mel = piano_phrase(N, [
    (0.9, E4, 0.85), (2.15, G4, 0.7), (3.45, B4, 0.9), (5.2, Fs4, 0.65),
    (6.7, E4, 0.8), (8.6, D5, 0.55), (10.3, B4, 0.6), (12.4, G4, 0.5),
    (14.2, E4, 0.62),
])
# La main gauche : deux accords graves, à peine posés.
basse = piano_phrase(N, [(0.9, E3, 0.55), (0.93, B3n / 2, 0.4),
                         (7.6, C3, 0.5), (7.64, G3, 0.35),
                         (12.4, E3, 0.42)])
pad = strings(t, [E3, G3, B3], swell(t, 1.5, 3.5, 11.0, 5.0), dark=1.7)
mix = mel * 0.075 + basse * 0.06 + pad * 0.010 \
    + sub(t, E2, swell(t, 0.8, 3.0, 11.0, 5.0)) * 0.035
out = np.zeros((N, 2))
for ch in range(2):
    wet = reverb(mix[:, ch], N, 2.4)
    out[:, ch] = mix[:, ch] * 0.8 + wet * 0.26
write("/tmp/sacre-commune.wav", out, -15)

# ================ sacre-epique (22 s) — le piano et la houle =============
L = 22.0
N = int(SR * L)
t = np.arange(N) / SR
mel = piano_phrase(N, [
    (0.8, E4, 0.9), (1.95, B4, 0.8), (3.1, G4, 0.75), (4.3, E5, 1.0),
    (5.9, B4, 0.7), (7.6, Fs4, 0.6), (9.3, E4, 0.75), (11.6, G4, 0.5),
    (13.6, E4, 0.55),
])
basse = piano_phrase(N, [(0.8, E3, 0.6), (4.3, C3, 0.55), (6.0, D3, 0.5),
                         (7.9, E3, 0.6)])
pad = strings(t, [E2, B2, E3, G3], swell(t, 0.4, 2.2, 5.0, 2.2)) \
    + strings(t, [C2, G2, C3, E3], swell(t, 3.8, 1.8, 6.6, 2.2)) \
    + strings(t, [D3, Fs3, A3], swell(t, 5.6, 1.4, 8.0, 2.4)) \
    + strings(t, [E2, B2, E3, G3, B3], swell(t, 7.0, 1.6, 12.5, 5.0))
drone = np.zeros((N, 2))
for det in (1.0025, 0.9975):
    dr = np.sin(2 * np.pi * E1 * 2 * det * t)
    drone[:, 0] += dr * 0.5
    drone[:, 1] += dr * 0.5
drone *= swell(t, 0.0, 2.5, 11.0, 6.0)[:, None]
timp = timpani(N, 4.3, amp=0.7) + timpani(N, 7.0, amp=1.0, roll=(6.2, 6.9, 6))
mix = mel * 0.062 + basse * 0.05 + pad * 0.020 + drone * 0.035 \
    + timp * 0.24 + sub(t, E1, swell(t, 0.3, 2.8, 11.0, 6.0)) * 0.06
out = np.zeros((N, 2))
for ch in range(2):
    wet = reverb(mix[:, ch], N, 3.0)
    out[:, ch] = mix[:, ch] * 0.76 + wet * 0.27
write("/tmp/sacre-epique.wav", out, -13)

# ============ sacre-legendaire (24 s) — l'opéra sombre poétique ==========
L = 24.0
N = int(SR * L)
t = np.arange(N) / SR
# LE PIANO MÈNE : la phrase qui monte vers mi 5 puis REDESCEND se poser —
# la mélancolie majestueuse, jamais une fanfare.
mel = piano_phrase(N, [
    (0.7, B3n, 0.8), (1.9, E4, 0.9), (3.05, G4, 0.8), (4.2, B4, 0.95),
    (5.4, E5, 1.0), (6.9, D5, 0.7), (8.3, B4, 0.75), (10.1, G4, 0.6),
    (11.9, Fs4, 0.5), (13.6, E4, 0.65), (16.4, B3n, 0.45),
])
basse = piano_phrase(N, [(0.7, E3, 0.6), (0.74, B3n / 2, 0.42),
                         (4.2, C3, 0.55), (6.9, D3, 0.5),
                         (8.3, E3, 0.62), (13.6, E3, 0.45)])
# Le chœur EN RETRAIT (au-delà des ahh : il porte, il ne chante plus seul).
voix = choir(t, [E3, G3, B3], swell(t, 2.8, 3.0, 8.5, 3.5)) * 0.55 \
    + choir(t, [E3, G3, B3, E4], swell(t, 7.0, 2.0, 12.5, 5.0)) * 0.7
# Les cordes : la fondation sombre, l'octave qui s'ouvre au sommet.
pad = strings(t, [E2, B2, E3, G3, Fs3], swell(t, 0.0, 2.4, 4.4, 1.8)) \
    + strings(t, [C2, G2, C3, E3, B3], swell(t, 3.4, 1.8, 6.4, 1.8)) \
    + strings(t, [D3, Fs3, A3, D5 / 2], swell(t, 5.6, 1.4, 7.8, 1.8)) \
    + strings(t, [E2, B2, E3, G3, B3, E4, G4],
              swell(t, 7.0, 1.8, 15.5, 6.5))
air = strings(t, [E5, B4 * 2], swell(t, 7.6, 2.6, 13.5, 5.5),
              dark=2.2, K=2) * 0.4
timp = timpani(N, 2.9, amp=0.6) + timpani(N, 5.4, amp=0.75) \
    + timpani(N, 7.0, amp=1.15, roll=(6.0, 6.9, 8)) \
    + timpani(N, 11.9, amp=0.45)
mix = mel * 0.066 + basse * 0.052 + voix * 0.024 + pad * 0.019 \
    + air * 0.022 + timp * 0.26 \
    + sub(t, E1, swell(t, 0.2, 2.8, 13.0, 7.0)) * 0.075
out = np.zeros((N, 2))
for ch in range(2):
    wet = reverb(mix[:, ch], N, 4.2)
    out[:, ch] = mix[:, ch] * 0.72 + wet * 0.30
write("/tmp/sacre-legendaire.wav", out, -12)

for name in ("sacre-commune", "sacre-epique", "sacre-legendaire"):
    subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16",
                    f"/tmp/{name}.wav",
                    f"/Users/kathryn/Desktop/woochoper-ios/Woop/Media/{name}.caf"],
                   check=True)
    print("caf", name)
