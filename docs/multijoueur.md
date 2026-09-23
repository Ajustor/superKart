# Multijoueur en réseau

Jusqu'à 8 joueurs humains, sur PC et Android mélangés. Les places libres de la
grille sont prises par l'IA.

## Jouer

1. **Menu → Multijoueur**, choisir son pseudo.
2. L'un des joueurs clique **Héberger une partie**. Son salon affiche
   l'adresse à laquelle les autres peuvent le joindre.
3. Les autres le trouvent dans **Parties sur ce réseau** (même Wi-Fi), ou
   tapent son adresse puis **Rejoindre**.
4. L'hôte choisit le circuit et le nombre de tours, puis **Lance la course**.
5. À la fin, l'hôte ramène tout le monde au salon avec **Retour au salon**.

Sur Internet (hors du réseau local), l'hôte doit rediriger le port **UDP 8910**
de sa box vers sa machine, et donner son adresse IP publique aux autres.

## Qui fait quoi

| | L'hôte | Chaque joueur |
|---|---|---|
| son propre kart | simule | simule |
| les karts d'IA | simule | affiche |
| les karts des autres | affiche | affiche |
| objets : boîtes, lancers, chocs | décide | affiche, demande à l'hôte |
| classement, arrivées | décide | recopie |
| départ | donne quand tout le monde a chargé (10 s au plus) | attend |

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

## Tester sans deuxième appareil

Deux instances sans écran sur la même machine, qui font une course d'un tour :

```
godot --headless --path . -s tools/essai_reseau.gd -- hote &
godot --headless --path . -s tools/essai_reseau.gd -- client
```

Les deux journaux doivent donner le même classement et les mêmes temps.

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
