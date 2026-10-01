# Le serveur du mode en ligne

Le mode **En ligne** du jeu passe par un serveur public : un petit *annuaire*
HTTP (`annuaire.py`) tient la liste des salons et en ouvre à la demande ;
chaque salon est le jeu lui-même, lancé sans écran en serveur dédié
(`--headless --serveur`, voir `scripts/net/serveur_dedie.gd`), sur son propre
port UDP. Les joueurs demandent un salon à l'annuaire, puis s'y connectent
directement en UDP.

```
joueur ──https──▶ Caddy :443 ──▶ annuaire :8900 ──lance──▶ salon (jeu) :8910…8949/udp
joueur ─────────────────────── UDP ─────────────────────▶ salon
```

Le premier joueur arrivé dans un salon en est le **chef** : il choisit le
circuit et lance la course. S'il part, le suivant prend la main. Le serveur
enchaîne seul les fins de course et les manches d'une coupe si le chef tarde,
et ferme le salon quand il n'y a plus personne (sauf le salon public
permanent, qui reste toujours ouvert).

## Mettre le serveur en ligne

Il faut une machine Linux joignable depuis Internet (un petit VPS suffit :
un salon en course prend environ un quart de cœur et 190 Mo de mémoire,
mesuré avec 8 karts dont 6 pilotés par l'IA),
avec Docker, et un nom de domaine qui pointe dessus.

1. Ouvrir les ports **80 et 443 en TCP** (Caddy, pour le certificat https) et
   **8910 à 8949 en UDP** (les salons) dans le pare-feu de la machine et chez
   l'hébergeur.
2. Télécharger `SuperKart-serveur-linux.zip` sur la page de la Release
   (même version que le jeu des joueurs : une autre version est refusée), et
   le décompresser.
3. Dans le dossier `SuperKart-serveur` :

   ```sh
   echo "DOMAINE=superkart.exemple.org" > .env
   docker compose up -d --build
   ```

4. Vérifier : `https://superkart.exemple.org/sante` répond `{"ok": true}`, et
   `https://superkart.exemple.org/salons` liste le salon public permanent.

Pour une nouvelle version du jeu : télécharger le nouveau zip, et relancer
`docker compose up -d --build` depuis son dossier.

### Réglages

Dans `.env`, à côté de `DOMAINE` :

| Variable               | Défaut | Rôle                                               |
|------------------------|--------|----------------------------------------------------|
| `SALONS_MAX`           | 20     | Salons ouverts en même temps (40 au plus : un port chacun ; ~200 Mo de mémoire chacun) |
| `SALONS_PERMANENTS`    | 1      | Salons publics toujours ouverts                    |
| `CREATIONS_PAR_MINUTE` | 4      | Salons créés par adresse IP et par minute          |

## Brancher le jeu dessus

Deux façons :

- **Pour tout le monde** : dans le dépôt GitHub, *Settings → Secrets and
  variables → Actions → Variables*, créer la variable `ANNUAIRE_EN_LIGNE` avec
  le nom de domaine (`superkart.exemple.org`). La CI l'inscrit dans le jeu
  qu'elle exporte (`application/config/annuaire_en_ligne`) : les versions
  suivantes se connectent toutes seules.
- **Pour soi** : dans le jeu, écran *En ligne*, champ *Serveur*. Un nom de
  domaine est joint en https ; une adresse IP ou `localhost`, en http (pour un
  serveur de test sur son réseau).

## Essayer sans Docker

Depuis la racine du dépôt, avec Godot installé :

```sh
ANNUAIRE_PORT=8900 HOTE_PUBLIC=127.0.0.1 \
JEU_COMMANDE="godot --headless --path $PWD" python3 serveur/annuaire.py
```

puis, dans le jeu, *En ligne* → *Serveur* : `127.0.0.1:8900`.

Les tests de l'annuaire : `python3 -m unittest serveur/test_annuaire.py`.

## L'API de l'annuaire

| Requête                     | Réponse                                                     |
|-----------------------------|-------------------------------------------------------------|
| `GET /sante`                | `{"ok": true}`                                              |
| `GET /salons`               | `{"salons": [...]}` : les salons publics ouverts            |
| `POST /salons`              | crée un salon (`{"nom": "...", "prive": false}`) ; 201 et le salon, une fois ouvert |
| `GET /salons/<code>`        | un salon, public ou privé, par son code de 5 caractères     |
| `POST /salons/<code>/etat`  | l'état envoyé par le salon lui-même (avec son jeton secret) |

Un salon : `code`, `nom`, `hote`, `port`, `prive`, `joueurs`, `places`,
`en_course`, `piste`, `version`, `ouvert`.
