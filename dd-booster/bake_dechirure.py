# Les sons d'ARRACHAGE (remplacent la braise — verdict Kathryn : il faut
# du PAPIER/FOIL qu'on arrache, comme un vrai booster, pas du feu).
#
# dechirure-lente / dechirure-franche (2,0 s, boucles circulaires) : le
#   « crrrr » du foil qui cède fibre à fibre — rafales denses de
#   micro-transitoires large-bande + corps fibreux modulé.
# dechirure-finale (one-shot ~0,5 s) : LE grand RRRIP — la déchirure qui
#   accélère, se libère d'un coup sec, et claque.
import wave

import numpy as np

SR = 48000
rng = np.random.default_rng(41)


def write(path, mix, peak_db):
    mix /= np.max(np.abs(mix)) + 1e-9
    mix *= 10 ** (peak_db / 20)
    pcm = (mix * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ok", path)


def micro_ticks(N, rate, f_lo, f_hi, tau_lo=0.0004, tau_hi=0.0016):
    """Rafale de micro-transitoires large-bande sur timeline circulaire."""
    out = np.zeros((N, 2))
    n = int(rate * N / SR)
    for _ in range(n):
        tau = rng.uniform(tau_lo, tau_hi)
        ln = max(int(5 * tau * SR), 8)
        tt = np.arange(ln) / SR
        burst = rng.standard_normal(ln) * np.exp(-tt / tau)
        # bande aléatoire : différence de moyennes glissantes
        k = max(2, int(SR / rng.uniform(f_lo, f_hi)))
        burst = burst - np.convolve(burst, np.ones(k) / k, mode="same")
        amp = 10 ** (rng.uniform(-14, 0) / 20)
        idx = (rng.integers(0, N) + np.arange(ln)) % N
        pan = rng.uniform(0.3, 0.7)
        out[idx, 0] += burst * amp * np.cos(pan * np.pi / 2)
        out[idx, 1] += burst * amp * np.sin(pan * np.pi / 2)
    return out / (np.max(np.abs(out)) + 1e-9)


def fibrous(N, am_hz):
    """Le corps fibreux : bruit moyen-aigu modulé vite (le grain du papier)."""
    freqs = np.fft.rfftfreq(N, 1 / SR)
    shape = np.where((freqs > 900) & (freqs < 7000),
                     1.0 / np.sqrt(np.maximum(freqs, 900)), 0)
    t = np.arange(N) / SR
    out = np.zeros((N, 2))
    for ch in range(2):
        spec = shape * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
        s = np.fft.irfft(spec, N)
        s /= np.max(np.abs(s))
        # modulation rapide périodique (k entier de cycles sur la boucle)
        k = round(am_hz * N / SR)
        am = 0.35 + 0.65 * np.clip(np.sin(2 * np.pi * k * t / (N / SR))
                                   + 0.4 * np.sin(2 * np.pi * (k * 2.7 // 1) * t / (N / SR)), 0, 1)
        out[:, ch] = s * am
    return out


L = 2.0
N = int(SR * L)
lente = micro_ticks(N, 260, 1500, 8000) * 0.7 + fibrous(N, 43) * 0.30
write("/tmp/dechirure-lente.wav", lente, -10)
franche = micro_ticks(N, 750, 1800, 9500) * 0.8 + fibrous(N, 71) * 0.30
write("/tmp/dechirure-franche.wav", franche, -8)

# ------------------------- le grand RRRIP --------------------------------
DUR = 0.55
N = int(SR * DUR)
t = np.arange(N) / SR
rip = np.zeros((N, 2))
# densité et brillance qui MONTENT puis se libèrent : trois phases
n_ticks = 700
for _ in range(n_ticks):
    # position biaisée vers la fin (la déchirure accélère)
    pos = (rng.uniform(0, 1) ** 0.55) * 0.42
    tau = rng.uniform(0.0003, 0.0012)
    ln = max(int(5 * tau * SR), 8)
    tt = np.arange(ln) / SR
    burst = rng.standard_normal(ln) * np.exp(-tt / tau)
    f = 1800 + 6500 * (pos / 0.42)  # de plus en plus brillant
    k = max(2, int(SR / f))
    burst = burst - np.convolve(burst, np.ones(k) / k, mode="same")
    idx = int(pos * SR) + np.arange(ln)
    idx = idx[idx < N]
    amp = 10 ** (rng.uniform(-10, 0) / 20) * (0.4 + 1.4 * pos / 0.42)
    pan = rng.uniform(0.35, 0.65)
    rip[idx, 0] += burst[: len(idx)] * amp * np.cos(pan * np.pi / 2)
    rip[idx, 1] += burst[: len(idx)] * amp * np.sin(pan * np.pi / 2)
# la LIBÉRATION : un claquement grave sec à 0,42 s + petit souffle qui meurt
snap_t = 0.42
ln = int(0.09 * SR)
tt = np.arange(ln) / SR
snap = (np.sin(2 * np.pi * 130 * tt) * np.exp(-tt / 0.018)
        + rng.standard_normal(ln) * np.exp(-tt / 0.008) * 0.5)
idx = int(snap_t * SR) + np.arange(ln)
idx = idx[idx < N]
rip[idx, 0] += snap[: len(idx)] * 1.6
rip[idx, 1] += snap[: len(idx)] * 1.5
write("/tmp/dechirure-finale.wav", rip, -6)
