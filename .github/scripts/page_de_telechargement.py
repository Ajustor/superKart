"""Assemble la page de téléchargement publiée sur GitHub Pages.

Copie le site (`site/`) dans le dossier de sortie, y range les binaires sous
`telecharger/` avec des noms fixes — les liens de la page ne changent jamais
d'une version à l'autre — et remplit les champs de la page : version, date,
commit, tailles.

    python3 .github/scripts/page_de_telechargement.py \\
        --site site --sortie _site \\
        --windows build/windows --apk build/android/SuperKart.apk \\
        --version 1.1.57 --commit 0123abc --signature release
"""

import argparse
import datetime
import pathlib
import shutil
import zipfile

MOIS = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
]


def taille(chemin: pathlib.Path) -> str:
    octets = chemin.stat().st_size
    return "%.0f Mo" % (octets / 1_000_000) if octets >= 10_000_000 else "%.1f Mo" % (octets / 1_000_000)


def date_du_jour() -> str:
    jour = datetime.date.today()
    return "%d %s %d" % (jour.day, MOIS[jour.month - 1], jour.year)


def main() -> None:
    args = argparse.ArgumentParser()
    args.add_argument("--site", required=True, type=pathlib.Path)
    args.add_argument("--sortie", required=True, type=pathlib.Path)
    args.add_argument("--windows", required=True, type=pathlib.Path, help="dossier de l'export Windows")
    args.add_argument("--apk", required=True, type=pathlib.Path)
    args.add_argument("--version", required=True)
    args.add_argument("--commit", required=True)
    args.add_argument("--signature", choices=["release", "debug"], required=True)
    a = args.parse_args()

    if a.sortie.exists():
        shutil.rmtree(a.sortie)
    shutil.copytree(a.site, a.sortie, ignore=shutil.ignore_patterns(".gdignore"))
    telecharger = a.sortie / "telecharger"
    telecharger.mkdir()

    # Windows : l'exécutable et son .pck, ensemble dans une archive.
    archive = telecharger / "SuperKart-windows.zip"
    fichiers = sorted(p for p in a.windows.iterdir() if p.is_file())
    if not any(p.suffix == ".exe" for p in fichiers) or not any(p.suffix == ".pck" for p in fichiers):
        raise SystemExit("export Windows incomplet dans %s : il faut le .exe et le .pck" % a.windows)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for f in fichiers:
            z.write(f, "SuperKart/" + f.name)

    apk = telecharger / "SuperKart.apk"
    shutil.copyfile(a.apk, apk)

    # Signé en release, une version remplace la précédente. Signé en debug,
    # la clé change à chaque build : Android refuse la mise à jour.
    if a.signature == "release":
        mise_a_jour = "Une nouvelle version s'installe par-dessus l'ancienne, sans perdre la progression."
    else:
        mise_a_jour = ("Cette version est signée en debug : pour mettre à jour, désinstaller "
                       "l'ancienne d'abord (la progression est alors perdue).")

    champs = {
        "{{VERSION}}": a.version,
        "{{DATE}}": date_du_jour(),
        "{{COMMIT}}": a.commit[:7],
        "{{TAILLE_WINDOWS}}": taille(archive),
        "{{TAILLE_ANDROID}}": taille(apk),
        "{{MISE_A_JOUR_ANDROID}}": mise_a_jour,
    }
    page = a.sortie / "index.html"
    texte = page.read_text(encoding="utf-8")
    for cle, valeur in champs.items():
        if cle not in texte:
            raise SystemExit("champ %s absent de la page" % cle)
        texte = texte.replace(cle, valeur)
    if "{{" in texte:
        raise SystemExit("champ non rempli dans la page")
    page.write_text(texte, encoding="utf-8")

    print("Page %s : Windows %s, Android %s" % (a.version, champs["{{TAILLE_WINDOWS}}"], champs["{{TAILLE_ANDROID}}"]))


if __name__ == "__main__":
    main()
