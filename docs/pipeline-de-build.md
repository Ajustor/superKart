# Pipeline de build

La pipeline `.github/workflows/build.yml` exporte le jeu pour **Windows** et
**Android** et dépose les binaires en artefacts de run GitHub Actions. Quand
on publie une Release GitHub, elle attache les binaires à la Release et met
à jour la page de téléchargement (GitHub Pages).

## Quand elle se déclenche

| Déclencheur | Ce qui se passe |
| --- | --- |
| Push sur `main` | Les deux plateformes sont construites en release. La page de téléchargement ne change pas. |
| Publication d'une Release GitHub (tag `v1.2`…) | Les deux plateformes sont construites en release, attachées à la Release, et la page de téléchargement passe à cette version. |
| Déclenchement manuel (onglet *Actions* → *Build* → *Run workflow*) | Sur n'importe quelle branche, avec le choix des plateformes et du type d'export. |

Les entrées du déclenchement manuel :

- **platforms** — `all` (défaut), `windows` ou `android`.
- **build_type** — `release` (défaut) ou `debug`. Un export debug embarque le
  moteur en version debug : plus lent, mais il affiche les erreurs.
- **godot_version** — tag de version tel que publié sur
  [godot-builds](https://github.com/godotengine/godot-builds/releases)
  (ex. `4.7-stable`). Vide, la pipeline prend `GODOT_VERSION_DEFAULT`.

Un nouveau push sur la même référence annule le run précédent.

> **Le déclenchement manuel n'apparaît qu'une fois le workflow sur la branche
> par défaut.** GitHub ne liste *Run workflow* que pour les workflows présents
> sur `main` ; il peut ensuite cibler n'importe quelle branche, y compris une
> branche où le fichier n'existe pas encore. Tant que cette pipeline n'a pas
> rejoint `main`, elle ne peut donc être lancée ni automatiquement ni à la
> main : le premier run réel sera celui du push sur `main`.

## Ce qu'on récupère

| Artefact | Contenu |
| --- | --- |
| `superkart-windows-<branche>-<sha>` | `SuperKart.exe` + `SuperKart.pck` (x86_64) |
| `superkart-android-<branche>-<sha>` | `SuperKart.apk` (arm64-v8a), ou `SuperKart-debug.apk` |

Conservés 14 jours.

## Page de téléchargement

La page propose **la dernière version publiée** : une Release GitHub, pas
chaque push sur `main`.

**Publier une version** : *Releases* → *Draft a new release*, un tag
`v1.2` (le nom affiché sera 1.2), des notes de version, *Publish release*.
Le workflow **Build** se lance alors sur ce tag, puis le job *Publier la
Release* :

1. attache à la Release `SuperKart-windows.zip` (`SuperKart/SuperKart.exe`
   et `SuperKart/SuperKart.pck`) et `SuperKart.apk` ;
2. lance le workflow **Page de téléchargement** (`pages.yml`) sur `main`.

Celui-ci récupère la Release (ses fichiers, sa date, ses notes), assemble la
page et la publie. Les liens `telecharger/SuperKart-windows.zip` et
`telecharger/SuperKart.apk` ne changent jamais : un lien partagé mène
toujours à la dernière version. Les notes de la Release s'affichent sous
les boutons, dans un encadré *Nouveautés* (titres, listes et paragraphes ;
le gras et le `code` passent).

On peut relancer **Page de téléchargement** à la main (onglet *Actions*),
avec un tag ou sans (la dernière Release) : pour republier la page après
avoir retouché `site/`, ou revenir à une version précédente.

La page se publie depuis `main` et non depuis le tag : l'environnement
`github-pages` n'accepte par défaut que la branche par défaut.

Les binaires sont servis par Pages lui-même : sur un dépôt privé, les
fichiers d'une Release ne se téléchargent pas sans compte.

Une Release exige un APK **signé en release** (voir plus bas) : sans les
secrets, le build de la Release échoue plutôt que de publier un APK de
debug, qui ne pourrait pas s'installer par-dessus la version précédente.

Le site vit dans `site/` (HTML, CSS, captures d'écran) ; les champs
`{{VERSION}}`, `{{TAILLE_WINDOWS}}`… de `site/index.html` sont remplis par
`.github/scripts/page_de_telechargement.py`. Pour voir la page sans passer
par la CI :

```sh
gh release view v1.2 --json tagName,name,publishedAt,body > /tmp/release.json
gh release download v1.2 --dir /tmp
python3 .github/scripts/page_de_telechargement.py --site site --sortie /tmp/page \
    --release /tmp/release.json \
    --windows /tmp/SuperKart-windows.zip --apk /tmp/SuperKart.apk
```

`site/.gdignore` tient le dossier hors du projet Godot : ses images ne sont
ni importées ni exportées avec le jeu.

GitHub Pages doit avoir la source **GitHub Actions** (*Settings* →
*Pages*). Sur un dépôt privé, il demande un compte GitHub Pro (ou une
organisation Team). La page, elle, est toujours publique : n'importe qui
ayant le lien peut télécharger le jeu.

## Presets d'export

`export_presets.cfg` est gitignoré : il porte les chemins et les clés de chaque
poste. La pipeline utilise donc `.github/export_presets.ci.cfg`, qu'elle copie
vers `export_presets.cfg` au début du job. Le fichier local d'un dev n'est
jamais touché.

Les presets excluent `tests/`, `tools/`, `docs/` et `addons/gut/` du paquet
exporté : le jeu livré ne contient que ce qui tourne à l'exécution.

Si on ajoute une option d'export qui compte (architecture, nom de paquet,
version…), c'est dans `.github/export_presets.ci.cfg` qu'elle doit atterrir,
sinon la CI ne la verra pas.

## Version

Android n'installe une mise à jour que si son code de version augmente. La
pipeline le fait d'elle-même : le code du preset (`version/code`) sert de
base, et le numéro du run GitHub (`github.run_number`, qui croît à chaque
exécution du workflow) s'y ajoute. Le nom affiché prend ce numéro en dernier
chiffre : `version/name="1.1"` au run 57 donne la version 1.1.57, code 59.
Pour une Release, le nom affiché est celui du tag (`v1.2` → 1.2) ; le code
suit toujours le numéro du run. Le calcul se fait une fois, dans le job
*Paramètres* : l'APK et la page de téléchargement portent le même nom.

Pour une nouvelle version majeure, changer `version/name` dans le preset ;
le code, lui, n'a jamais besoin d'être touché à la main.

## Signature Android

Sans secret configuré, la pipeline génère une clé de debug jetable et produit un
APK **signé en debug** : installable directement sur un téléphone, mais refusé
par le Play Store.

Pour un APK signé en release, ajouter ces trois secrets au dépôt
(*Settings* → *Secrets and variables* → *Actions*) :

| Secret | Valeur |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Le keystore encodé : `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_USER` | L'alias de la clé |
| `ANDROID_KEYSTORE_PASSWORD` | Le mot de passe du keystore |

Les trois doivent être présents ; sinon la pipeline retombe sur la signature de
debug et le signale dans le résumé du run — sauf pour une Release, qui
échoue : une version publiée doit s'installer par-dessus la précédente, donc
être signée à chaque fois par la même clé.

Créer la clé, une fois, et la garder précieusement (la perdre, c'est ne
plus pouvoir mettre à jour l'application installée) :

```sh
keytool -genkeypair -v -keystore release.keystore -alias superkart \
    -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 release.keystore   # → ANDROID_KEYSTORE_BASE64
```

L'alias (`superkart`) va dans `ANDROID_KEYSTORE_USER`, le mot de passe dans
`ANDROID_KEYSTORE_PASSWORD`. Le passage d'un APK de debug à un APK release
change la signature : il faut désinstaller une dernière fois la version de
debug.

## Changer de version de Godot

La version par défaut vit dans `env.GODOT_VERSION_DEFAULT` en tête du workflow.
Elle doit rester alignée sur `config/features` dans `project.godot` : un export
avec un moteur plus ancien que le projet échoue.

Pour tester une version sans rien committer, passer `godot_version` au
déclenchement manuel.

## Notes

- L'export Android impose `rendering/textures/vram_compression/import_etc2_astc`
  à `true` dans `project.godot` — sans quoi Godot refuse d'exporter.
- L'export passe par le modèle Android pré-compilé (pas de build Gradle) : le
  runner n'a donc besoin que du JDK 17, de `platform-tools` et de `build-tools`,
  pas du NDK.
- L'éditeur et les modèles d'export sont mis en cache par version : seul le
  premier run d'une version paie le téléchargement (~1,4 Go).

## Icône

Elle est dessinée en code par `tools/icone.py` (des SVG dans
`resources/icone/`). `tools/icone_png.gd` en tire les images attendues par
chaque plateforme :

| Fichier | Sert à |
| --- | --- |
| `icone.svg` | icône du projet et de la fenêtre (`application/config/icon`) |
| `icone_192.png` | icône Android classique |
| `icone_premier_plan_432.png` + `icone_fond_432.png` | icône adaptative Android (le kart est ramené dans la zone sûre de 66 %) |
| `icone.ico` | fenêtre et barre des tâches Windows (`config/windows_native_icon`) |

Pour la retoucher : modifier `tools/icone.py`, puis relancer
`python3 tools/icone.py` et
`godot --headless --path . -s tools/icone_png.gd`.

L'icône est aussi celle du fichier `.exe` lui-même, dans l'explorateur :
`application/modify_resources=true`. Godot 4.7 réécrit les ressources de
l'exécutable sans rcedit ni Wine, y compris depuis le runner Linux.
