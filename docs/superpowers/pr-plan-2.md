# Plan 2 — Circuit généré et tour chronométré

## Ce que ça apporte

- **Le circuit entier dérive d'une seule `Curve3D`.** Le maillage de route, la collision, la ligne de course, la progression, les remises en piste et la grille de départ sortent tous de la même courbe. Aucun checkpoint à poser : déplacer un point de contrôle déplace tout le reste avec lui.
- **La progression est une distance, pas une paire (tour, checkpoint).** `RaceProgress` accumule l'avancement le long de l'axe par le chemin le plus court, donc faire demi-tour ne fait pas gagner de tour, et le classement du plan suivant se triera sur un seul nombre.
- **Chrono du tour et meilleur temps**, plus un HUD réduit à trois lignes. `scenes/race.tscn` devient la scène principale.
- Le pilotage du plan 1 est inchangé : `KartMotor` reste un `RefCounted` sans dépendance à l'arbre de scènes, et l'IA du plan 3 passera par le même `KartCommand` que le joueur.

## Ce que la mesure a trouvé, et que les tests n'avaient pas vu

Quatre défauts réels ont vécu sous une campagne verte, tous trouvés en mesurant plutôt qu'en lisant :

| défaut | mesure |
|---|---|
| le kart empochait un tour au premier centimètre | `lap = 1` après 5 cm sur 768 m |
| reculer sur la ligne fabriquait un meilleur tour | 21 tours enregistrés, meilleur 0:00.033 |
| après l'arrivée, le kart hors-piste tombait sans fin | `y = −2530` après 13 s |
| la reprojection d'une sortie de route dans l'épingle | 48 m d'erreur, dans les deux sens |

Les deux premiers venaient de la même cause : `RaceSession` n'était pas testable, parce qu'elle lisait `global_position`. Passer le point en paramètre a coûté deux lignes et couvert toute sa logique.

Le `clampf` de la ligne de course n'était protégé par aucun test — le retirer laissait la campagne verte alors que la ligne sortait du bitume dans l'épingle (9,125 m pour 9,0 m de demi-largeur). Il l'est maintenant.

## Plan de vérification

- [x] 96 tests verts, 10 scripts (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`)
- [x] `scenes/race.tscn` charge 180 images sans `ERROR` ni `SCRIPT ERROR`
- [x] Chaque correctif prouvé rouge contre le code d'avant, un par un
- [ ] **Session de conduite humaine** — le seul juge du visuel et du ressenti. Le headless ne rastérise rien : il ne dit ni si la route est visible du bon côté, ni si l'épingle est amusante, ni si le HUD est lisible en roulant.

## Réserves connues

- La caméra part de l'origine alors que le kart apparaît à plus de cent mètres : vol plané au départ, attendu.
- `motor.speed` n'est pas réconcilié après une collision de `move_and_slide()`. Sans mur sur le circuit, c'est sans effet aujourd'hui.
- Le compteur de tours résiste à l'aliasing de projection **par la géométrie de `track_01`**, pas par construction : un circuit dont l'épingle frôlerait la ligne d'arrivée rouvrirait le trou. À revérifier en dessinant les circuits 2 et 3.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
