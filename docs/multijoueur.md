# Multijoueur en réseau

Jusqu'à 8 joueurs humains, sur PC et Android mélangés. Les places libres de la
grille sont prises par l'IA.

Deux façons de jouer ensemble :

- **En ligne** : par un serveur public, sans rien ouvrir chez soi. Voir
  [Mode en ligne](#mode-en-ligne) plus bas.
- **Multijoueur local** : un des joueurs héberge la partie sur son appareil.

## Jouer en local

1. **Menu → Multijoueur local**, choisir son pseudo.
2. L'un des joueurs clique **Héberger une partie**. Son salon affiche
   l'adresse à laquelle les autres peuvent le joindre.
3. Les autres le trouvent dans **Parties sur ce réseau** (même Wi-Fi), ou
   tapent son adresse puis **Rejoindre**.
4. L'hôte choisit le mode, la cylindrée, le circuit et le nombre de tours,
   puis **Lance la course**.
   - **Course seule** : un circuit, le nombre de tours voulu.
   - **Grand Prix** : une des coupes, quatre manches de trois tours. Voir plus
     bas.
5. À la fin, l'hôte ramène tout le monde au salon avec **Retour au salon**.

## Chargement

- Chaque course s'ouvre sur un écran de chargement (`EcranChargement`). Il
  s'affiche tout de suite, puis :
  1. il charge la scène de course et le circuit dans un fil à part ;
  2. il monte la course derrière lui ;
  3. il attend que la musique soit composée et que quelques images soient
     dessinées, pour que les shaders se compilent derrière l'écran et pas en
     pleine course.
- Il affiche la liste des joueurs : ✓ prêt, … en cours de chargement.
- Le départ est donné quand tous sont prêts, ou au bout de 15 s.
- Ce rendez-vous passe par l'autoload `Reseau` (`charges`, `depart`), qui
  existe sur toutes les machines : les machines ne finissent pas de charger
  en même temps, et un message adressé à une course pas encore montée se
  perdrait.
- L'hôte n'envoie l'état de la course (karts, objets, classement) qu'aux
  machines prêtes.
- Pendant le chargement, une doublure de `RaceSync` avale les paquets encore
  en route de la course précédente.
- Les circuits eux-mêmes ne se chargent plus avec le menu : la fiche d'un
  circuit ne porte que le chemin de sa scène.

## Grand Prix en réseau

- L'hôte tient la coupe. À la fin d'une manche, il la compte et lance la
  suivante pour tous (**Course suivante**).
- L'état de la coupe (points, places de la dernière course) part avec chaque
  manche : tout le monde affiche les mêmes points.
- Chacun repart de la place où il a fini la manche précédente.
- Après la dernière manche, l'hôte montre le podium à tous, puis ramène tout
  le monde au salon.
- Les points se comptent par nom. Un joueur ne peut donc pas prendre le nom
  d'un pilote IA.
- Les trophées, comme les records, ne se gagnent qu'en solo.

Sur Internet (hors du réseau local), le jeu ouvre lui-même le port **UDP 8910**
sur la box de l'hôte (UPnP) et affiche au salon l'adresse publique à donner
aux autres (voir « Jouer par Internet » plus bas). Si la box refuse ou est
introuvable, il reste à rediriger ce port à la main vers la machine de l'hôte.

## Qui fait quoi

| | L'hôte | Chaque joueur |
|---|---|---|
| son propre kart | simule | simule |
| les karts d'IA | simule | affiche |
| les karts des autres | affiche | affiche |
| objets : boîtes, lancers, chocs | décide | affiche, demande à l'hôte |
| classement, arrivées | décide | recopie |
| départ | donne quand tout le monde a chargé (15 s au plus) | attend, derrière l'écran de chargement |

Chaque joueur simule **son** kart : le pilotage reste aussi vif qu'en solo,
quelle que soit la latence. Les autres karts sont montrés là où ils sont
**maintenant** : chaque état reçu est prolongé du temps qu'il a mis à arriver
(mesuré par ENet), en ligne droite ou en virage selon ce que faisait le kart.
Quand un état contredit la prédiction (l'autre a freiné, a été touché),
l'écart est rattrapé en quelques images plutôt que d'un bond. Le champignon,
qui ne touche que le kart qui le prend, part tout de suite sans attendre la
réponse de l'hôte.

Sur la mini-carte, en haut à droite, votre kart est le gros point jaune, les
autres joueurs sont bleu clair et l'IA rouge.

Les chocs entre karts suivent la même règle : chaque machine applique le choc
à son propre kart, et le kart d'en face encaisse le sien sur sa machine.

Un joueur qui quitte en pleine course laisse son kart à l'IA ; si c'est l'hôte
qui part, tout le monde revient au menu.

## Réseau

- Port de jeu : **UDP 8910** (ENet).
- Annonces sur le réseau local : diffusion **UDP 8911**, une fois par seconde.
- Envois : l'état des karts à chaque image de physique (60 fois par seconde),
  relayé par l'hôte dès réception ; les objets sur la piste 30 fois par
  seconde ; le classement 10 fois par seconde.
- Le protocole porte un numéro de version (`Reseau.VERSION`) : un joueur dont
  le jeu n'est pas à la même version est refusé avec un message clair.
- L'état de chaque kart porte aussi son compteur de figures. Le tonneau d'un
  kart distant se voit partout, même si un paquet se perd.
- Le turbo de départ, le dérapage (étincelles, paliers) et les flammes du
  turbo se lisent sur l'état du moteur, déjà transmis.

## Tester sans deuxième appareil

Deux instances sans écran sur la même machine, qui font une course d'un tour :

```
godot --headless --path . -s tools/essai_reseau.gd -- hote &
godot --headless --path . -s tools/essai_reseau.gd -- client
```

Les deux journaux doivent donner le même classement et les mêmes temps.

Avec `coupe` en second argument des deux côtés, l'essai joue une coupe
entière en 100cc (manches d'un tour). Les deux journaux doivent donner les
mêmes grilles, les mêmes points après chaque manche et le même podium.

## Mesurer le retard

Même principe, mais chaque instance note où elle affiche le kart de l'autre,
et un script compare avec où il était vraiment au même instant. Le second
argument ajoute un retard artificiel à chaque envoi, en millisecondes :

```
godot --headless --path . -s tools/mesure_latence.gd -- hote 40 &
godot --headless --path . -s tools/mesure_latence.gd -- client 40
python3 tools/mesure_latence.py
```

| retard ajouté | avant (retard fixe de 100 ms) | maintenant (prédiction) |
|---|---|---|
| 0 ms | 2,1 m, soit ~96 ms | 0,27 m, soit ~13 ms |
| 40 ms par sens | 3,2 m, soit ~145 ms | 0,13 m, soit ~6 ms |

(écart médian entre la position affichée et la vraie, et le retard que cela
représente à la vitesse du kart.)

## Jouer par Internet (`PortInternet`)

En hébergeant, le jeu demande à la box d'ouvrir le port de la partie (UDP
8910) par **UPnP**, dans un fil à part, et affiche dans le salon l'adresse
publique à donner aux autres (`ip:port`). Ceux qui rejoignent tapent cette
adresse telle quelle : `Reseau.decouper_adresse` sépare l'hôte et le port.

- Le port est demandé avec un bail de 4 h (sans limite si la box refuse les
  baux), et refermé en quittant la partie ou le jeu.
- Quand ça ne marche pas, le salon dit pourquoi : box introuvable, UPnP
  désactivé, ou accès derrière le réseau de l'opérateur (CGNAT, adresse
  publique privée ou en 100.64.0.0/10). Il reste alors à ouvrir le port à la
  main, ou à jouer en réseau local.
- Pas de relais : un hôte derrière un CGNAT ne peut pas être rejoint depuis
  Internet. C'est à ça que sert le mode en ligne.

## Mode en ligne

**Menu → En ligne** : les salons d'un serveur public. Chaque salon est tenu
par une instance du jeu sur ce serveur, sans écran et sans pilote
(`ServeurDedie`) ; les joueurs n'ont rien à ouvrir chez eux.

- **Partie rapide** : rejoint le salon public le plus rempli qui a de la
  place et n'est pas en pleine course ; à défaut, en crée un.
- **Créer un salon** : public (dans la liste) ou **privé** (on y entre
  seulement par son code de 5 caractères, affiché dans le salon).
- **Code d'un salon** : rejoindre un salon, privé ou non, par son code.
- La liste des salons publics se met à jour toute seule.
- **Serveur** : l'adresse d'un autre serveur que celui du jeu (vide : celui
  inscrit dans le jeu par la CI, `application/config/annuaire_en_ligne`).

### Le chef du salon

Le serveur ne pilote pas : c'est le **premier joueur arrivé** (`Lobby.chef`)
qui choisit le mode, le circuit et lance la course, comme l'hôte en local.
S'il s'en va, le suivant prend la main. Ses choix partent au serveur par
`Reseau._demande`, qui vérifie qu'ils viennent bien du chef ; le serveur
monte la course et l'arbitre comme le ferait un hôte, en simulant l'IA.

Pour qu'un salon ne reste jamais bloqué, le serveur enchaîne seul si le chef
tarde : retour au salon 25 s après la dernière arrivée, manche suivante d'une
coupe au bout de 12 s, retour au salon 20 s après le podium. Une manche est
comptée d'après la course du serveur, jamais d'après un classement envoyé par
un joueur.

### Le serveur

`serveur/annuaire.py` (Python, bibliothèque standard) tient la liste des
salons et lance un processus du jeu par salon, chacun sur son port UDP ; le
salon lui envoie son état toutes les 5 s et s'arrête quand il est vide depuis
2 min (5 min s'il n'a encore vu personne). Installation avec Dokploy (ou
Docker et Caddy) : [serveur/README.md](../serveur/README.md). L'image Docker
se construit depuis le dépôt ; pour un serveur sans Docker, la CI construit le
jeu pour Linux (`SuperKart-serveur-linux.zip`) et l'attache à chaque Release.

Le jeu lancé en serveur :

```
godot --headless --path . -- --serveur --port 8930 --nom "Salon" \
    [--code ABCDE] [--prive] [--permanent] [--annuaire URL --jeton SECRET]
```

### Tester sans serveur public

Un serveur et deux joueurs sans écran, sur la même machine :

```
godot --headless --path . -- --serveur --port 8930 --nom Essai &
godot --headless --path . -s tools/essai_en_ligne.gd -- chef 8930 &
godot --headless --path . -s tools/essai_en_ligne.gd -- invite 8930
```

Le chef règle le salon et lance la course à distance ; les deux journaux
doivent donner le même classement. Avec `coupe` en dernier argument, une
coupe entière, que le serveur enchaîne seul jusqu'au podium.

Pour l'écran En ligne, lancer l'annuaire en local (voir
[serveur/README.md](../serveur/README.md#essayer-sans-docker)) et régler
**Serveur** sur `127.0.0.1:8900`.
