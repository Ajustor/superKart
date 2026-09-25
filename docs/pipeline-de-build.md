# Pipeline de build

La pipeline `.github/workflows/build.yml` exporte le jeu pour **Windows** et
**Android**, dépose les binaires en artefacts de run GitHub Actions et, sur
`main`, les publie sur une page de téléchargement (GitHub Pages).

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

## Page de téléchargement

Après chaque build release de `main` où les deux plateformes ont réussi, le
job **Page de téléchargement** publie sur GitHub Pages une page qui propose
la dernière version :

| Lien (relatif à la page) | Contenu |
| --- | --- |
| `telecharger/SuperKart-windows.zip` | `SuperKart/SuperKart.exe` + `SuperKart/SuperKart.pck` |
| `telecharger/SuperKart.apk` | l'APK, quel que soit son mode de signature |

Les noms ne changent jamais : un lien partagé mène toujours à la dernière
version. La page affiche la version (la même que celle de l'APK), la date,
le commit et la taille des fichiers. Si l'APK est signé en debug, elle
prévient qu'il faut désinstaller l'ancienne version pour mettre à jour : la
clé de debug change à chaque build.

Les binaires sont servis par Pages lui-même, pas par une release GitHub :
sur un dépôt privé, les fichiers d'une release ne se téléchargent pas sans
compte.

Le site vit dans `site/` (HTML, CSS, captures d'écran) ; les champs
`{{VERSION}}`, `{{TAILLE_WINDOWS}}`… de `site/index.html` sont remplis par
`.github/scripts/page_de_telechargement.py`, qui range aussi les binaires.
Pour voir la page sans passer par la CI :

```sh
python3 .github/scripts/page_de_telechargement.py --site site --sortie /tmp/page \
    --windows build/windows --apk build/android/SuperKart.apk \
    --version 1.1.0 --commit $(git rev-parse HEAD) --signature release
```

`site/.gdignore` tient le dossier hors du projet Godot : ses images ne sont
ni importées ni exportées avec le jeu.

**À faire une fois**, dans *Settings* → *Pages* : choisir la source
**GitHub Actions**. Sans cela, le job échoue à l'étape *Préparer la
publication*. GitHub Pages sur un dépôt privé demande un compte GitHub Pro
(ou une organisation Team) ; sinon, rendre le dépôt public. La page, elle,
est toujours publique : n'importe qui ayant le lien peut télécharger le jeu.

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
Le calcul se fait une fois, dans le job *Paramètres* ; l'APK et la page de
téléchargement portent donc le même numéro.

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

L'icône est aussi celle du fichier `.exe` lui-même, dans l'explorateur :
`application/modify_resources=true`. Godot 4.7 réécrit les ressources de
l'exécutable sans rcedit ni Wine, y compris depuis le runner Linux.
