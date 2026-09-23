# Pipeline de build

La pipeline `.github/workflows/build.yml` exporte le jeu pour **Windows** et
**Android**, et dépose les binaires en artefacts de run GitHub Actions.

## Quand elle se déclenche

| Déclencheur | Ce qui se passe |
| --- | --- |
| Push sur `main` | Les deux plateformes sont construites en release. |
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
debug et le signale dans le résumé du run.

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

L'icône du fichier `.exe` lui-même, dans l'explorateur, n'est pas changée : il
faudrait `application/modify_resources=true`, donc rcedit (et Wine sur le
runner Linux). La fenêtre du jeu et la barre des tâches affichent bien l'icône.
