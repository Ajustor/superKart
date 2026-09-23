"""Dessine l'icône de SuperKart, en SVG, en trois variantes :

- icone.svg : l'icône complète, carré arrondi (projet, fenêtre, Android ancien) ;
- icone_premier_plan.svg : le kart seul sur fond transparent, rétréci dans la
  zone sûre des icônes adaptatives Android (66 % du centre) ;
- icone_fond.svg : le fond seul, pour l'arrière-plan adaptatif.

    python3 tools/icone.py
    godot --headless --path . -s tools/icone_png.gd

Le second script en tire les PNG qu'attend l'export Android.
"""
from pathlib import Path

DOSSIER = Path(__file__).resolve().parent.parent / "resources" / "icone"

DEFS = """
<defs>
  <radialGradient id="ciel" cx="50%" cy="38%" r="75%">
    <stop offset="0" stop-color="#3f6fd1"/>
    <stop offset="0.55" stop-color="#1d3677"/>
    <stop offset="1" stop-color="#0b1330"/>
  </radialGradient>
  <linearGradient id="caisse" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ff5a45"/>
    <stop offset="1" stop-color="#c41d1d"/>
  </linearGradient>
  <linearGradient id="casque" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ffe27a"/>
    <stop offset="1" stop-color="#f0a800"/>
  </linearGradient>
</defs>
"""

def damier() -> str:
    """Deux rangées de cases, dessinées une à une : le moteur SVG de Godot
    ignore les motifs (<pattern>)."""
    cases = ['<rect x="-40" y="440" width="600" height="44" fill="#f4f4f6"/>']
    for colonne in range(27):
        for rangee in range(2):
            if (colonne + rangee) % 2 == 0:
                cases.append('<rect x="%d" y="%d" width="22" height="22" fill="#16161c"/>'
                             % (-40 + colonne * 22, 440 + rangee * 22))
    return '<g transform="rotate(-4.5 256 460)">' + "".join(cases) + "</g>"


# Le fond : ciel de nuit, une route qui file, un damier d'arrivée.
FOND = """
<rect width="512" height="512" fill="url(#ciel)"/>
<path d="M0,372 L512,332 L512,512 L0,512 Z" fill="#2b2d38"/>
<path d="M0,372 L512,332 L512,344 L0,384 Z" fill="#ffc72e"/>
""" + damier()

# Le kart, de profil, lancé vers la droite, avec ses traits de vitesse.
KART = """
<g stroke-linecap="round" fill="none" stroke="#ffffff">
  <line x1="28" y1="232" x2="118" y2="232" stroke-width="14" opacity="0.85"/>
  <line x1="52" y1="276" x2="112" y2="276" stroke-width="12" opacity="0.6"/>
  <line x1="18" y1="318" x2="96" y2="318" stroke-width="10" opacity="0.45"/>
</g>
<ellipse cx="275" cy="392" rx="170" ry="16" fill="#000000" opacity="0.35"/>
<!-- aileron arrière -->
<path d="M122,236 L176,236 L184,262 L130,262 Z" fill="#16161c"/>
<rect x="148" y="258" width="12" height="40" fill="#16161c"/>
<!-- caisse -->
<path d="M120,318 C120,290 142,282 170,280 L300,276 C352,274 404,290 444,318
         L452,340 C452,352 444,358 430,358 L136,358 C124,358 118,348 120,318 Z"
      fill="url(#caisse)" stroke="#16161c" stroke-width="8" stroke-linejoin="round"/>
<path d="M300,292 C348,292 392,302 426,322" fill="none" stroke="#ffffff" stroke-width="10"
      stroke-linecap="round" opacity="0.9"/>
<!-- pilote -->
<path d="M214,282 C214,246 238,232 262,232 C286,232 298,250 300,280 Z" fill="#1f5fd6"
      stroke="#16161c" stroke-width="8" stroke-linejoin="round"/>
<circle cx="262" cy="194" r="50" fill="url(#casque)" stroke="#16161c" stroke-width="8"/>
<path d="M252,180 L300,178 C310,178 314,186 313,196 C312,206 306,212 296,212 L252,212
         C244,212 240,206 240,196 C240,186 244,180 252,180 Z" fill="#16161c"/>
<path d="M258,190 L296,189" fill="none" stroke="#7fd3ff" stroke-width="6" stroke-linecap="round"/>
<!-- volant -->
<line x1="300" y1="270" x2="326" y2="236" stroke="#16161c" stroke-width="10" stroke-linecap="round"/>
<!-- roues -->
<g stroke="#16161c" stroke-width="8">
  <circle cx="172" cy="352" r="54" fill="#23232b"/>
  <circle cx="172" cy="352" r="22" fill="#cfd3dc"/>
  <circle cx="384" cy="356" r="48" fill="#23232b"/>
  <circle cx="384" cy="356" r="19" fill="#cfd3dc"/>
</g>
"""


def svg(contenu: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
        + DEFS + contenu + "</svg>\n"
    )


def main() -> None:
    DOSSIER.mkdir(parents=True, exist_ok=True)
    complete = (
        '<clipPath id="coins"><rect width="512" height="512" rx="112"/></clipPath>'
        '<g clip-path="url(#coins)">' + FOND + KART + "</g>"
    )
    (DOSSIER / "icone.svg").write_text(svg(complete), encoding="utf-8")
    # Android découpe l'icône adaptative en cercle ou en goutte : seul le centre
    # (66 %) est garanti visible. Le kart y est ramené, un peu remonté.
    premier_plan = '<g transform="translate(256 256) scale(0.7) translate(-236 -284)">' + KART + "</g>"
    (DOSSIER / "icone_premier_plan.svg").write_text(svg(premier_plan), encoding="utf-8")
    (DOSSIER / "icone_fond.svg").write_text(svg(FOND), encoding="utf-8")


if __name__ == "__main__":
    main()
