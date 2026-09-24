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
| 200cc | 118 %, braquage compris | 100 % |

- En 50, 100 et 150cc, le braquage ne change pas : plus lent, on tourne plus
  serré. En 200cc, il suit la vitesse, sans quoi un rayon de braquage de
  14 m ne passait plus les épingles de 12,5 m.
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

## Déblocages

| | Se débloque par | Ce que c'est |
|---|---|---|
| 200cc | l'or dans toutes les coupes en 150cc | vitesse ×1,18 ; le braquage suit, pour que les virages gardent leur forme |
| Miroir | l'or dans toutes les coupes en 100cc | le circuit retourné gauche-droite (`Miroir`) : courbe en x → -x, dévers et écarts latéraux inversés, murs de l'autre côté |

- Les deux ont leurs propres records (`@200cc`, `@miroir`).
- Le podium annonce ce qu'un trophée vient de débloquer.
- En réseau, c'est ce que l'hôte a débloqué qui compte.

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
- Le fantôme garde aussi son temps de passage à chaque tour. Le joueur voit,
  sous le chrono, son écart au fantôme au même passage : en vert quand il est
  en avance, en rouge quand il est en retard.

## Objets (`ItemManager`, `ItemKind`, `ItemTable`)

Dix objets, tirés selon la place au classement (`ItemTable`, une ligne par
tranche du peloton, une colonne par objet) :

| Objet | Effet |
| --- | --- |
| Champignon, triple champignon | turbo |
| Banane | posée derrière ; qui roule dessus part en tête-à-queue |
| Fausse boîte | comme une banane, déguisée en boîte (rougeâtre, « ¿ ») |
| Carapace verte | tout droit, rebondit sur les murs |
| Carapace rouge | suit la route jusqu'au kart de devant |
| Carapace bleue | survole le peloton jusqu'au premier (le second si c'est lui qui la lance) et explose : tout kart à moins de 4,5 m du premier y passe |
| Éclair | tous les autres karts : tête-à-queue, rétrécis 5 s (vitesse ×0,72), objet perdu |
| Étoile | 7 s intouchable, plus rapide, l'herbe ne freine plus ; les karts percutés partent en tête-à-queue |
| Pièces | +2 pièces (10 au plus) ; chacune donne +1 % de vitesse de pointe ; un choc ou une remise en piste en coûte 3 |

En tête surtout des bananes, fausses boîtes et pièces ; en queue des
carapaces rouges, triples champignons, étoiles, et les rares carapaces
bleues et éclairs.

En réseau, l'hôte décide de tout, comme pour les autres objets ; les effets
sur un kart (étoile, pièces, éclair) sont appliqués par la machine qui le
simule, et l'étoile et le rétrécissement voyagent dans l'instantané du kart
(`KartSnapshot`) : l'hôte doit savoir qu'une carapace ne touche pas un kart
sous étoile.

## Garage (`ModeleKart`, `GaragePanel`)

Cinq karts au choix, accessibles depuis l'accueil et depuis le salon
multijoueur, et huit couleurs. Chaque modèle retouche les caractéristiques
du kart d'origine (celui sur lequel les circuits sont validés) :

| Modèle | Vitesse | Accélération | Virage | Glisse | Poids |
| --- | --- | --- | --- | --- | --- |
| Standard | 1 | 1 | 1 | 1 | 1 |
| Fusée | 1,04 | 0,80 | 1 | 0,90 | 1,1 |
| Plume | 0,97 | 1,30 | 1,08 | 1,05 | 0,8 |
| Dériveur | 0,99 | 0,95 | 1 | 1,30 | 0,95 |
| Costaud | 1,02 | 0,88 | 0,97 | 0,95 | 1,4 |

La glisse divise les seuils des paliers de mini-turbo ; le poids pèse dans
les chocs entre karts (le plus léger prend la plus grande part de
l'échange) et réduit la perte de vitesse contre un mur. La caisse change
aussi d'allure.

Le choix est enregistré (`[garage]` dans les réglages). En réseau, chaque
joueur l'annonce à l'hôte, qui le range dans le salon et le met dans le plan
de course : tout le monde voit chacun dans sa couleur, et le poids de chacun
compte dans les chocs. L'IA prend les couleurs restantes.

Le harnais IA accepte `kart=N` pour valider un modèle :
`tools/essai_circuit.gd -- <id> 1 200 kart=4`.

## Bataille (`Bataille`, arènes de `TrackCatalog.ARENES`)

Trois ballons chacun. Chaque objet encaissé (carapace, banane, fausse boîte,
explosion) en crève un ; sans ballon, on est éliminé et classé derrière tous
ceux qui en ont encore. Le dernier en lice gagne ; au bout de 3 minutes, les
survivants sont classés au nombre de ballons.

- L'arène est un anneau large et fermé de murs (`arene_ovale`), hors du menu
  des courses et des coupes. Les karts y partent dispersés, sans grille ni
  portique.
- La session ne compte pas de tours (`RaceSession.sans_tours`) : `Bataille`
  donne les places comme des arrivées, et l'écran des résultats suit sans
  changement.
- Table d'objets à part : ni carapace bleue, ni éclair, ni pièces. La
  carapace rouge vise le kart en jeu le plus proche devant soi.
- Un kart d'IA éliminé quitte l'arène ; le joueur éliminé s'arrête et voit
  les résultats.
- Solo contre l'IA pour l'instant ; pas encore en réseau.

Harnais : `tools/essai_circuit.gd -- arene_ovale 1 150 bataille`.
