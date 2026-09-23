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
quelle que soit la latence. Les autres karts sont affichés avec 100 ms de
retard, interpolés entre deux positions reçues, pour rester lisses.

Les chocs entre karts suivent la même règle : chaque machine applique le choc
à son propre kart, et le kart d'en face encaisse le sien sur sa machine.

Un joueur qui quitte en pleine course laisse son kart à l'IA ; si c'est l'hôte
qui part, tout le monde revient au menu.

## Réseau

- Port de jeu : **UDP 8910** (ENet).
- Annonces sur le réseau local : diffusion **UDP 8911**, une fois par seconde.
- Envois : l'état des karts 30 fois par seconde, le classement et les objets
  10 fois par seconde.
- Le protocole porte un numéro de version (`Reseau.VERSION`) : un joueur dont
  le jeu n'est pas à la même version est refusé avec un message clair.

## Tester sans deuxième appareil

Deux instances sans écran sur la même machine, qui font une course d'un tour :

```
godot --headless --path . -s tools/essai_reseau.gd -- hote &
godot --headless --path . -s tools/essai_reseau.gd -- client
```

Les deux journaux doivent donner le même classement et les mêmes temps.
