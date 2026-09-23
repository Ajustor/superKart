#!/usr/bin/env python3
"""Compare les journaux de tools/mesure_latence.gd : où chaque instance affiche
le kart de l'autre, et où il était vraiment au même instant."""
import bisect, math, statistics, sys

DOSSIER = sys.argv[1] if len(sys.argv) > 1 else "/tmp/superkart_latence"

def lire(nom):
    lignes = []
    for l in open(f"{DOSSIER}/{nom}.csv"):
        t, mx, mz, ax, az, v = map(float, l.split(","))
        lignes.append((t, mx, mz, ax, az, v))
    return lignes

def vraie_position(journal, t):
    temps = [l[0] for l in journal]
    i = bisect.bisect_left(temps, t)
    if i <= 0 or i >= len(journal):
        return None
    a, b = journal[i - 1], journal[i]
    k = (t - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0
    return (a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[5])

def ecarts(observateur, observe):
    distances, retards = [], []
    for t, _, _, ax, az, _ in observateur:
        vrai = vraie_position(observe, t)
        if vrai is None:
            continue
        d = math.hypot(ax - vrai[0], az - vrai[1])
        # Les remises en piste font des sauts de dizaines de mètres : ce n'est
        # pas du retard, on les écarte.
        if d > 15:
            continue
        distances.append(d)
        if vrai[2] > 8:
            retards.append(d / vrai[2] * 1000)
    return distances, retards

hote, client = lire("hote"), lire("client")
for nom, (d, r) in {"le client voit l'hôte": ecarts(client, hote),
                    "l'hôte voit le client": ecarts(hote, client)}.items():
    d.sort(); r.sort()
    print(f"{nom:24s} écart médian {statistics.median(d):5.2f} m, 95e centile {d[int(len(d)*0.95)]:5.2f} m"
          f"  →  retard équivalent médian {statistics.median(r):4.0f} ms, 95e {r[int(len(r)*0.95)]:4.0f} ms")
