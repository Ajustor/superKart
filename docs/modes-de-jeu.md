# Modes de jeu

Le menu « Jouer » propose trois modes et, sauf en contre-la-montre, une
cylindrée. Tout se règle dans `RaceSetup` ; `RaceLauncher.monter` en tire la
course.

## Cylindrées (`Cylindree`)

| | Vitesse et accélération | Allure de l'IA |
|---|---|---|
| 50cc | 78 % | 95 % de celle du joueur |
| 100cc | 89 % | 97,5 % |
| 150cc | 100 % (réglage d'origine) | 100 % |

- Le braquage ne change pas : plus lent, on tourne plus serré.
- La gravité suit le carré du facteur de vitesse, et l'impulsion des tremplins
  le facteur lui-même. Chaque saut garde ainsi sa trajectoire. Sans ça, en
  50cc, toute l'IA tombait dans le gouffre de la mine.
- Chaque kart reçoit une copie de ses caractéristiques. La ressource
  `default_kart.tres` reste intacte.
- Les records sont rangés par cylindrée. La 150cc garde la clé d'avant
  (l'identifiant du circuit seul), les autres ajoutent `@50cc` ou `@100cc`.
- Le choix de cylindrée est enregistré dans les réglages.
- Le harnais IA la prend en troisième argument :
  `tools/essai_circuit.gd -- <id> <tours> 50`.

## Grand Prix (`GrandPrix`)

- Deux coupes de quatre circuits, définies dans `TrackCatalog.COUPES` :
  - Coupe Champignon : Collines, Jardin, Plage, Mine ;
  - Coupe Étoile : Forteresse, Ville, Neiges, Ruban.
- Chaque manche se court en trois tours. Le barème de `RaceScoring`
  s'additionne d'une course à l'autre.
- Ceux qui n'ont pas franchi la ligne quand le joueur passe à la suite
  prennent la place qu'ils occupaient.
- À égalité de points, le mieux placé à la dernière course passe devant.
- Première course : le joueur choisit sa case. Ensuite, chacun repart de la
  place où il a fini la course précédente (le vainqueur en pole).
- L'écran de résultats ajoute une colonne « Coupe » (le total, cette course
  comprise) et un bouton « Course suivante », puis « Podium ».
- Le podium (`PodiumScreen`) enregistre le meilleur trophée par coupe et par
  cylindrée (or, argent, bronze). Le menu l'affiche sur le bouton de la coupe.

## Contre-la-montre (`FantomeCourse`, `Fantome`)

- Le joueur est seul, en 150cc, sans boîtes, avec un triple champignon au
  départ. Ses records sont à part (`<id>@clm`).
- Le parcours est échantillonné vingt fois par seconde à partir du vert :
  - la position ;
  - l'orientation du kart ;
  - celle de sa caisse, pour que le fantôme dérape aussi.
- Si le temps bat le fantôme enregistré, le parcours le remplace dans
  `user://fantomes/<clé>.fantome`.
- Le fantôme rejoue le meilleur parcours à partir du vert : une copie
  translucide de la caisse et des roues, sans script ni collision.
- Un fichier qui ne commence pas par la signature, ou d'une autre version,
  est ignoré.
