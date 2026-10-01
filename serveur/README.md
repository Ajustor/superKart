# Le serveur du mode en ligne

Le mode **En ligne** du jeu passe par un serveur public : un petit *annuaire*
HTTP (`annuaire.py`) tient la liste des salons et en ouvre à la demande ;
chaque salon est le jeu lui-même, lancé sans écran en serveur dédié
(`--headless --serveur`, voir `scripts/net/serveur_dedie.gd`), sur son propre
port UDP. Les joueurs demandent un salon à l'annuaire, puis s'y connectent
directement en UDP.

```
joueur ──https──▶ Traefik ou Caddy :443 ──▶ annuaire :8900 ──lance──▶ salon (jeu) :8910…8949/udp
joueur ─────────────────────── UDP ─────────────────────▶ salon
```

Le premier joueur arrivé dans un salon en est le **chef** : il choisit le
circuit et lance la course. S'il part, le suivant prend la main. Le serveur
enchaîne seul les fins de course et les manches d'une coupe si le chef tarde,
et ferme le salon quand il n'y a plus personne (sauf le salon public
permanent, qui reste toujours ouvert).

## Mettre le serveur en ligne avec Dokploy

L'image se construit depuis le dépôt (`serveur/Dockerfile`) : Godot y fait
tourner le jeu depuis ses sources, sans export. Le serveur suit donc le commit
déployé, sans attendre de Release ; il faut seulement que sa version du
protocole réseau (`Reseau.VERSION`) soit celle du jeu des joueurs, sinon le
salon les refuse poliment.

Prévoir environ un quart de cœur et 190 Mo de mémoire par salon en course
(mesuré avec 8 karts dont 6 pilotés par l'IA) ; un salon qui attend ne
consomme presque rien.

1. **DNS** : deux noms peuvent servir, ou un seul.
   - Le **domaine https** (par exemple `superkart.darthoit.eu`), celui de la
     liste des salons : il peut passer par Cloudflare (nuage orange).
   - L'**adresse des salons**, que les joueurs joignent en **UDP** : elle doit
     pointer **directement** sur la machine. Cloudflare ne relaie pas l'UDP :
     derrière son proxy, les joueurs voient les salons mais ne peuvent pas y
     entrer. Si le domaine https est proxifié, créer un second nom en nuage
     gris (par exemple `jeu.darthoit.eu`, enregistrement A vers l'IP de la
     machine) et le mettre dans `HOTE_SALONS` (voir *Réglages*). On peut aussi
     y mettre directement l'adresse IP de la machine.

   Au démarrage, l'annuaire prévient dans ses logs si l'adresse des salons
   passe par Cloudflare.
2. **Pare-feu** : ouvrir **8910 à 8949 en UDP** (les salons), en plus des 80
   et 443 que Dokploy utilise déjà, sur la machine et chez l'hébergeur.
3. Dans Dokploy, **Create Service → Compose** :
   - *Provider* : le dépôt GitHub `Ajustor/superKart`, branche `main` ;
   - *Compose Path* : `./serveur/docker-compose.yml` ;
   - onglet **Environment** : `DOMAINE=superkart.darthoit.eu`, et
     `HOTE_SALONS=…` si ce domaine passe par Cloudflare ;
   - **Deploy**. La première construction prend quelques minutes (Godot est
     téléchargé et le jeu importé dans l'image).
4. Onglet **Domains** → *Add Domain* : le domaine, service `annuaire`,
   port `8900`, **HTTPS** activé avec Let's Encrypt.
5. Vérifier : `https://superkart.darthoit.eu/sante` répond `{"ok": true}`, et
   `https://superkart.darthoit.eu/salons` liste le « Salon public 1 ».

Avec l'*Autodeploy* de Dokploy (ou son webhook), chaque push sur `main`
reconstruit le serveur. Les salons ouverts sont alors fermés : mieux vaut
déployer quand personne ne joue.

### Réglages

Dans l'onglet Environment, à côté de `DOMAINE` :

| Variable               | Défaut      | Rôle                                               |
|------------------------|-------------|----------------------------------------------------|
| `HOTE_SALONS`          | `DOMAINE`   | Le nom ou l'IP que les joueurs joignent en UDP : il doit pointer directement sur la machine, sans proxy |
| `PORTS_SALONS`         | `8910-8949` | Ports UDP des salons, publiés tels quels (à ouvrir dans le pare-feu) |
| `SALONS_MAX`           | 20          | Salons ouverts en même temps (pas plus que de ports ; ~200 Mo chacun en course) |
| `SALONS_PERMANENTS`    | 1           | Salons publics toujours ouverts                    |
| `CREATIONS_PAR_MINUTE` | 4           | Salons créés par adresse IP et par minute          |

### Sans Dokploy

Le même serveur derrière Caddy, qui obtient seul son certificat :

```sh
cd serveur
echo "DOMAINE=superkart.darthoit.eu" > .env
docker compose -f docker-compose.caddy.yml up -d --build
```

Ports à ouvrir : 80 et 443 en TCP, 8910 à 8949 en UDP.

### Sans Docker

`SuperKart-serveur-linux.zip`, attaché à chaque Release, contient le jeu
exporté pour Linux et l'annuaire :

```sh
ANNUAIRE_PORT=8900 HOTE_PUBLIC=superkart.darthoit.eu \
JEU_COMMANDE="$PWD/SuperKart-serveur.x86_64 --headless" python3 annuaire.py
```

avec un proxy https devant le port 8900.

## Brancher le jeu dessus

Deux façons :

- **Pour tout le monde** : le jeu vise `superkart.darthoit.eu`, inscrit dans
  `project.godot` (`application/config/annuaire_en_ligne`). Pour un autre
  domaine, changer cette ligne, ou créer la variable de dépôt
  `ANNUAIRE_EN_LIGNE` (*Settings → Secrets and variables → Actions →
  Variables*) : la CI l'inscrit à la place dans le jeu qu'elle exporte.
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
