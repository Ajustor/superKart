"""Assemble la page de téléchargement publiée sur GitHub Pages.

La page propose une version publiée : une Release GitHub et ses fichiers. Ce
script copie le site (`site/`) dans le dossier de sortie, y range les
binaires sous `telecharger/` avec des noms fixes — les liens de la page ne
changent jamais d'une version à l'autre — et remplit les champs de la page :
version, date, tailles, notes de version.

    gh release view v1.2 --json tagName,name,publishedAt,body > release.json
    python3 .github/scripts/page_de_telechargement.py \\
        --site site --sortie _site --release release.json \\
        --windows SuperKart-windows.zip --apk SuperKart.apk
"""

import argparse
import datetime
import hashlib
import html
import json
import pathlib
import re
import shutil

MOIS = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
]


def taille(chemin: pathlib.Path) -> str:
    octets = chemin.stat().st_size
    return "%.0f Mo" % (octets / 1_000_000) if octets >= 10_000_000 else "%.1f Mo" % (octets / 1_000_000)


def date_en_francais(iso: str) -> str:
    jour = datetime.date.fromisoformat(iso[:10]) if iso else datetime.date.today()
    return "%d %s %d" % (jour.day, MOIS[jour.month - 1], jour.year)


def empreinte(chemin: pathlib.Path) -> str:
    sha = hashlib.sha256()
    with chemin.open("rb") as fichier:
        for bloc in iter(lambda: fichier.read(1 << 20), b""):
            sha.update(bloc)
    return sha.hexdigest()


def manifeste(release: dict, archive: pathlib.Path, apk: pathlib.Path) -> dict:
    """Ce que le jeu lit pour se mettre à jour (scripts/core/mise_a_jour.gd).
    Les fichiers sont relatifs au manifeste : il vit à côté d'eux."""
    def fichier(chemin: pathlib.Path) -> dict:
        return {"fichier": chemin.name, "taille": chemin.stat().st_size, "sha256": empreinte(chemin)}

    return {
        "version": version_du_tag(release["tagName"]),
        "date": (release.get("publishedAt") or "")[:10],
        "notes": release.get("body") or "",
        "page": "../",
        "windows": fichier(archive),
        "android": fichier(apk),
    }


def version_du_tag(tag: str) -> str:
    """« v1.2 » s'affiche « 1.2 »."""
    return tag[1:] if re.match(r"^[vV]\d", tag) else tag


def _en_ligne(texte: str) -> str:
    """Échappe, puis rend le gras et le code du Markdown."""
    texte = html.escape(texte)
    texte = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", texte)
    texte = re.sub(r"`(.+?)`", r"<code>\1</code>", texte)
    return texte


def notes_en_html(markdown: str) -> str:
    """Les notes de la Release, en HTML. Juste ce qu'on y écrit d'habitude :
    des titres, des listes, des paragraphes. Tout le reste est du texte."""
    morceaux: list[str] = []
    liste = False
    for ligne in markdown.replace("\r\n", "\n").split("\n"):
        ligne = ligne.rstrip()
        puce = re.match(r"^\s*[-*+]\s+(.*)$", ligne)
        if puce is None and liste:
            morceaux.append("</ul>")
            liste = False
        if not ligne.strip():
            continue
        if puce is not None:
            if not liste:
                morceaux.append("<ul>")
                liste = True
            morceaux.append("<li>%s</li>" % _en_ligne(puce.group(1)))
            continue
        titre = re.match(r"^#{1,6}\s+(.*)$", ligne)
        if titre is not None and not morceaux and titre.group(1).strip().lower() == "nouveautés":
            continue  # la section porte déjà ce titre
        if titre is not None:
            morceaux.append("<h4>%s</h4>" % _en_ligne(titre.group(1)))
        else:
            morceaux.append("<p>%s</p>" % _en_ligne(ligne.strip()))
    if liste:
        morceaux.append("</ul>")
    return "\n".join(morceaux)


def section_nouveautes(markdown: str) -> str:
    corps = notes_en_html(markdown or "")
    if not corps:
        return ""
    return ('    <div class="nouveautes">\n      <h3>Nouveautés</h3>\n%s\n    </div>' % corps)


def main() -> None:
    args = argparse.ArgumentParser()
    args.add_argument("--site", required=True, type=pathlib.Path)
    args.add_argument("--sortie", required=True, type=pathlib.Path)
    args.add_argument("--release", required=True, type=pathlib.Path,
                      help="JSON de `gh release view --json tagName,name,publishedAt,body`")
    args.add_argument("--windows", required=True, type=pathlib.Path, help="l'archive ZIP Windows")
    args.add_argument("--apk", required=True, type=pathlib.Path)
    a = args.parse_args()

    release = json.loads(a.release.read_text(encoding="utf-8"))

    if a.sortie.exists():
        shutil.rmtree(a.sortie)
    shutil.copytree(a.site, a.sortie, ignore=shutil.ignore_patterns(".gdignore"))
    telecharger = a.sortie / "telecharger"
    telecharger.mkdir()
    archive = telecharger / "SuperKart-windows.zip"
    apk = telecharger / "SuperKart.apk"
    shutil.copyfile(a.windows, archive)
    shutil.copyfile(a.apk, apk)

    # Le manifeste de mise à jour, à côté des binaires.
    (telecharger / "version.json").write_text(
        json.dumps(manifeste(release, archive, apk), ensure_ascii=False, indent=2), encoding="utf-8")

    champs = {
        "{{VERSION}}": html.escape(version_du_tag(release["tagName"])),
        "{{DATE}}": date_en_francais(release.get("publishedAt") or ""),
        "{{TAILLE_WINDOWS}}": taille(archive),
        "{{TAILLE_ANDROID}}": taille(apk),
        "{{NOUVEAUTES}}": section_nouveautes(release.get("body") or ""),
    }
    page = a.sortie / "index.html"
    texte = page.read_text(encoding="utf-8")
    for cle in champs:
        if cle not in texte:
            raise SystemExit("champ %s absent de la page" % cle)
    # Les notes en dernier : elles viennent de la Release, et peuvent
    # contenir des accolades sans être un champ oublié.
    notes = champs.pop("{{NOUVEAUTES}}")
    for cle, valeur in champs.items():
        texte = texte.replace(cle, valeur)
    if re.search(r"\{\{[A-Z_]+\}\}", texte.replace("{{NOUVEAUTES}}", "")):
        raise SystemExit("champ non rempli dans la page")
    texte = texte.replace("{{NOUVEAUTES}}", notes)
    page.write_text(texte, encoding="utf-8")

    print("Page %s : Windows %s, Android %s" % (
        champs["{{VERSION}}"], champs["{{TAILLE_WINDOWS}}"], champs["{{TAILLE_ANDROID}}"]))


if __name__ == "__main__":
    main()
