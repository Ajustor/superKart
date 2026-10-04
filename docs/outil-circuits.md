# Dessiner un circuit : murs, rampes, trous, tremplins, raccourcis

Un circuit, c'est un nœud `Track` et sa courbe (`Curve3D`). La route, sa
collision et la ligne de l'IA en sont tirées automatiquement. Tout le reste se
pose **sur le tracé**, comme enfant du nœud `Track`.

## Les éléments

| Nœud | Ce qu'il fait | Collision |
|---|---|---|
| `TrackWall` | un muret rouge et blanc qui suit le tracé : au bord gauche, au bord droit, aux deux, ou à un endroit libre | oui : le kart s'y arrête de face, glisse le long de biais ; les carapaces rebondissent |
| `TrackRamp` | une vraie rampe en relief : le kart la monte et décolle au sommet avec l'élan qu'elle lui donne | oui |
| `TrackGap` | un trou : la route n'est pas construite sur cette portion, on la franchit en sautant. `chute_voulue` : un trou où l'on tombe exprès (portail à plat, boucle après l'arrivée d'une course linéaire), sans rampe ni bandes | — |
| `TrackJump` | une zone de saut peinte : le kart qui passe dessus décolle d'une impulsion fixe, avec un turbo en option | non, c'est une zone |
| `TrackOffroad` | une zone d'herbe, de sable ou de boue : on y roule, mais au ralenti | oui : elle crée du sol, même à côté de la route |
| `TrackTunnel` | un passage sous terre : deux parois (des `TrackWall`), une voûte, un massif par-dessus (`montagne`), des lampes au plafond et deux portails. `marge`, `hauteur` et `fleche` élargissent la galerie en salle | les parois seulement |
| `TrackVerglas` | une plaque de glace : le nez tourne, la trajectoire suit avec retard (`adherence`), les roues patinent | non, c'est une zone |
| `TrackCourant` | une poussée : vent en rafales (`periode`, `phase`), courant d'eau ou tapis roulant (`style`), en travers (`poussee_laterale`) ou le long du tracé (`poussee_avant`, négative à contre-sens). Le vent pousse aussi en l'air | non, c'est une zone |
| `TrackApesanteur` | la gravité faiblit (`gravite`) : chaque saut dure plus longtemps. Une arche violette à chaque bout | non, c'est une zone |
| `TrackAnneau` | un anneau d'or flottant à `hauteur` m : le traverser donne un turbo | non |
| `TrackObstacle` | un obstacle mobile : marteau qui balance (`PENDULE`), pilon qui s'abat (`PISTON`), bloc ou tonneau qui va et vient (`BLOC`, `TONNEAU`), gardien qui arpente la route (`GARDIEN`). Le kart pris part en tête-à-queue | non : une zone qui fait tourner le kart |
| `TrackPortail` | un passage vers un autre monde : de l'autre côté, un autre ciel (`ambiance`) et d'autres décors (`decors`). `mode` : `VORTEX`, un tourbillon qui s'ouvre devant le premier et se ferme derrière le dernier ; `CADRE`, un voile dans un cadre de blocs d'obsidienne, toujours ouvert ; `SOL`, un puits d'étoiles à plat sur un trou à `chute_voulue` : on tombe dedans et l'on ressort au bas du plongeon, sans rien perdre (`Kart.teleporter`) ; `SEUIL`, rien à voir, on change seulement de contrée. `nouveau_monde` à faux : le ciel change, les décors restent. On voit à travers un `VORTEX` ou un `CADRE` : voir plus bas | non |
| `TrackSpectacle` | une scène animée autour de la route : éclair, voitures volantes, train, méduses, bulles, lune, dragon | non |
| `TrackSol` | un sol plat à `altitude` autour du circuit (prairie, banquise, dalle), percé là où la route passe dessous : une galerie qui plonge sous la surface ne le traverse pas. `portion` le limite aux abords d'une portion du tracé. Percé aussi sous un trou de la route. Les décors posés à côté de la route s'y posent au lieu de flotter à hauteur de bitume | oui, sur `Track.PORTEE_HORS_PISTE` (14 m) de chaque côté de la route de son monde : voir « Sols réels » |
| `TrackDecor` | une rangée de décor le long du tracé : palmiers, phare, piliers enflammés, étoiles, champignons géants, rochers. `espacement` 0 pose un objet seul | oui, sauf les étoiles : une forme simple au pied de chaque objet (tronc, pied de champignon, base d'immeuble) ; `solide` à faux pour qu'on la traverse. Un test vérifie qu'aucun décor solide ne mord sur la route |

Les obstacles battent sur l'horloge du circuit (`Track.horloge`), remise à
zéro au feu vert : en réseau, toutes les machines voient le même marteau au
même endroit. `TrackOffroad` accepte une `teinte` pour sortir des quatre sols
(béton, poussière lunaire, herbe sombre).

## Habiller le circuit

Sur le nœud `Track` lui-même :

- **motif** : `UNI` (la couleur `road_color`) ou `ARC_EN_CIEL`, sept bandes
  de couleur qui brillent un peu dans le noir ;
- **bordures** : des bordures rouges et blanches sur les deux rives
  (`couleur_bordure`, `couleur_bordure_bis`) ;
- **altitude_du_liquide** : l'altitude d'une mer ou d'un lac de lave sous le
  circuit. Un kart qui passe dessous est remis en piste tout de suite, sans
  attendre de tomber de douze mètres. Le liquide lui-même se dessine à part :
  un `MeshInstance3D` avec un grand `PlaneMesh`, comme la `Mer` de la plage.

Un circuit peut aussi apporter son ciel et sa lumière : un `WorldEnvironment`
et un `DirectionalLight3D` placés directement sous le nœud `Track`
remplacent ceux de `race.tscn` le temps de la course.

## Les poser

Dans la scène du circuit (`scenes/tracks/track_01.tscn` par exemple) :

1. Clic droit sur le nœud `Track` → **Ajouter un nœud enfant** → chercher
   `TrackWall`, `TrackJump` ou `TrackOffroad`.
2. Le régler dans l'inspecteur :
   - **debut** : où il commence, en mètres le long du tracé depuis la ligne
     de départ ;
   - **longueur** : sur combien de mètres ;
   - **decalage** : l'écart de son milieu à l'axe de la route, positif à
     droite dans le sens de la course. La route va de −9 à +9 m : au-delà,
     on est à côté ;
   - **largeur** : combien il couvre en travers.
3. Ou l'attraper dans la vue 3D et le déplacer : il se recale sur le tracé et
   ses réglages suivent. Un mur de bord passe d'un côté à l'autre selon le
   côté où on le lâche.

La géométrie se refait à chaque réglage et à chaque retouche de la courbe :
déplacer un point de contrôle emmène les murs et les zones avec lui.

## Les mécaniques

- **Vrai saut par-dessus le vide** : un `TrackRamp` qui finit là où commence
  un `TrackGap`. Le saut dépend de la rampe et de la vitesse d'arrivée :
  - `hauteur` et `longueur` fixent l'angle de sortie ; le profil `INCURVE`
    (par défaut) sort deux fois plus raide que sa pente moyenne ;
  - la vitesse verticale au décollage vaut vitesse × sinus de l'angle de
    sortie : une rampe incurvée de 1,8 m sur 12 m, abordée à 22 m/s, fait
    monter le kart à 2,9 m au-dessus de la route et parcourir 19 m, de quoi
    franchir un trou de 12 m ;
  - pour relier deux parties de la carte, dessine la courbe au-dessus du vide
    entre les deux rives : c'est elle qui dit où la route reprend, et le kart
    en vol la suit à peu près.
- **Tomber dans un trou** remet le kart en piste **après** le trou : reposé
  avant, à l'arrêt, il n'aurait pas l'élan de sauter et retomberait sans fin.
  Un trou sans rampe ni tremplin dans les 30 m qui précèdent est signalé par
  un avertissement dans l'éditeur.

- **Raccourci** : une `TrackOffroad` posée à côté de la route (par exemple
  `decalage` 14, `largeur` 10 à l'intérieur d'un virage) crée un passage plus
  court mais plus lent. Il devient payant avec un champignon.
- **Saut** : une `TrackJump` fait décoller le kart. En vol, il peut survoler
  le vide sans être remis en piste ; il ne l'est que s'il **atterrit** hors de
  tout sol (route ou zone hors-piste), ou s'il tombe sous la route.
  `impulsion` 10 donne environ 0,7 s de vol et 15 à 18 m parcourus à pleine
  vitesse ; `duree_turbo` ajoute une poussée au décollage.
- **Mur libre** : un `TrackWall` en `cote = LIBRE` au milieu de la route la
  sépare en deux voies, pour marquer l'entrée d'un raccourci.
- **Bande d'herbe** : une `TrackOffroad` posée sur la route la rétrécit.

## Pièges

- Une zone ne peut pas s'étendre, vers l'intérieur d'un virage, au-delà de
  son centre : dans un virage de 25 m de rayon, rien ne va à plus de 25 m de
  l'axe côté intérieur. L'éditeur affiche un avertissement sur le nœud dans
  ce cas.
- L'IA suit sa ligne : elle prend les rampes et tremplins qui s'y trouvent,
  mais ne cherche pas les raccourcis. Elle s'en écarte pour doubler ou
  flâner, sauf dans les 40 m qui précèdent une rampe ou un trou, sur le
  verglas et dans le vent : là, elle reprend la ligne. Une rampe devant un trou doit donc
  couvrir la ligne de course — le plus simple est de lui donner toute la
  largeur de la route.
- Un kart qui aborde une rampe trop lentement (après un choc, par exemple)
  tombe dans le trou et perd du temps : c'est voulu.
- Au-delà du bord de la route, le sol construit reste à plat, à la hauteur du
  bord : il ne prolonge pas le dévers du virage.

## Créer un nouveau circuit

1. Ajouter ses points dans `tools/build_track_curves.gd`, dans le sens de la
   marche, altitude comprise. Le premier est la ligne de départ, et le
   dernier tronçon, qui y ramène, doit être droit : la grille s'y range.
   Puis :
   ```
   godot --headless --path . -s tools/build_track_curves.gd -- <id>
   godot --headless --path . -s tools/shape_track_curve.gd -- res://resources/tracks/<id>_curve.tres <rayon_min> <devers_max>
   ```
2. Lire le profil pour savoir où poser les éléments : rayon et pente tous les
   10 m, lignes droites (pour les rampes), et portions qui se frôlent.
   ```
   godot --headless --path . -s tools/profil_circuit.gd -- res://resources/tracks/<id>_curve.tres
   ```
   Un pont doit passer à au moins vingt mètres au-dessus de la route qu'il
   croise : plus bas, le classement confond les deux tronçons.
3. Écrire la scène (`scenes/tracks/<id>.tscn`) et sa fiche
   (`resources/tracks/<id>_info.tres`), puis l'ajouter à
   `scripts/race/track_catalog.gd`.
4. Faire courir huit IA dessus, et regarder :
   ```
   godot --headless --fixed-fps 60 --path . -s tools/essai_circuit.gd -- <id>
   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
       -s tools/capture_circuit.gd -- <id> <dossier> 100 250 400h
   ```
   Tout le monde doit arriver ; les remises en piste et les arrêts sont
   comptés par tranche de 10 m, ce qui montre où ça coince.
   `tests/test_circuits.gd` vérifie ensuite chaque circuit du catalogue :
   virages roulables, rampe devant chaque trou, grille et boîtes sur la
   route, liquide sous la route, pas de tronçons confondus.

## Les circuits

| Circuit | Longueur | Ce qui le distingue |
|---|---|---|
| Circuit des Collines | 774 m | le circuit d'origine : collines, épingle en montée bordée de deux murs (375 à 470 m), un trou à sauter (314 à 338 m), bas-côtés d'herbe tout le tour sauf au trou. Pentes adoucies (35 % → 22 % au plus dans l'épingle) |
| Plage aux Palmiers | 1 032 m | bordures, bas-côtés de sable, dune à tremplin (262 m), lacet autour du phare, bras de mer à sauter (766 à 790 m), raccourci de sable à l'intérieur du virage 380 à 475 m |
| Bastion de Magma | 773 m | remparts presque partout, montée vers une chicane à 10 m de haut (340 à 470 m), douve de lave à sauter (542 à 566 m), piliers enflammés |
| Prisme de Minuit | 1 099 m | route arc-en-ciel dans la nuit, en huit : le pont (560 à 650 m) passe 20 m au-dessus de la ligne droite de départ ; saut dans le vide (866 à 892 m), garde-fous seulement dans les virages serrés |
| Clairière Enchantée | 1 015 m | un trèfle à trois feuilles, bosses douces, bas-côtés d'herbe, champignons géants, trois champignons rebondissants (98, 438, 778 m) ; prairie à 2,5 m sous la route |
| Mine Scintillante | 724 m | descente de 14 m entre des étais (90 à 280 m), fond de galerie aux cristaux, remontée étayée (420 à 620 m), gouffre à sauter (636 à 661 m) juste avant la ligne |
| Boulevard Électrique | 1 482 m (2 tours) | la nuit, un vrai quartier : rues à angle droit autour des pâtés de maisons (coins de 44 m), bordures fluo, lampadaires, avenue en travaux à sauter (812 à 826 m) |
| Station des Neiges | 1 225 m | un slalom de ski : quatre traversées de la pente et leurs épingles, bosses (262, 575, 795 m), puis la remontée par le télésiège ; larges bas-côtés de neige, sapins |

Coupes Aventure et Tempête :

| Circuit | Longueur | Ce qui le distingue |
|---|---|---|
| Canyon Venteux | 939 m | tunnel dans une mesa (300 à 400 m), rafales alternées qui poussent à droite puis à gauche (560 à 680 m), ravin à sauter (874 à 886 m) avec un anneau d'or décentré |
| Grotte Glacée | 1 099 m | en huit, presque tout sous le glacier : galeries et trois salles à stalagmites et cristaux, plaques de verglas, la galerie passe 22 m sous la ligne de départ (608 m), crevasse à sauter (892 à 905 m) |
| Usine à Engrenages | 934 m | tapis roulants (dans le sens, en travers, et à contre-sens sur une voie de la ligne d'arrivée), passage sous la presse (150 à 230 m), pilons (538, 550, 623 m) |
| Ruines d'Émeraude | 1 668 m (2 tours) | les méandres d'une rivière : gorge à sauter dès le départ (62 à 74 m), galeries du temple, couloir de trois marteaux (vers 1 000 m), gué dans le courant (vers 1 100 m) |
| Base Lunaire | 1 314 m | un croissant : deux zones d'apesanteur, cratères de 22 m à sauter dans des anneaux sur l'arc extérieur (912 et 1 002 m), tremplin et anneaux en l'air (vers 710 m) ; dôme (370 à 470 m) |
| Port des Pirates | 889 m | sur les quais au-dessus de la mer : grotte marine (330 à 420 m), saut depuis le pont du galion (560 à 572 m), tonneaux qui roulent (614, 624 m), courant de la crique (640 à 700 m) |
| Château des Brumes | 901 m | la nuit, en huit : la crypte passe 22 m sous la cour du départ, entre trois lames (398 à 458 m) ; fosse à sauter (177 à 189 m), cercueils qui glissent (826, 840 m) ; lac de brume sous le circuit |
| Citadelle des Orages | 1 376 m | une forteresse en étoile à cinq bastions au-dessus d'une mer de nuages : rafales alternées, vides à sauter (422 et 972 m), porte de la citadelle (526 m), tremplin en apesanteur (684 m) |

Coupe Vertige :

| Circuit | Longueur | Ce qui le distingue |
|---|---|---|
| Grand Huit | 1 698 m | des montagnes russes en nœud de trèfle sur piliers : la piste se croise trois fois, à 21–23 m au-dessus d'elle-même (vers 316/1 056, 488/1 448, 880/1 620 m) ; rails tout du long, anneaux aux sommets, saut (392 à 406 m) |
| Pic des Lacets | 1 470 m | tunnel en spirale dans la montagne (100 à 600 m), 32 m entre deux tours ; sommet verglacé et venteux ; trois lacets en épingle de 25 m ; ravin à sauter (952 à 966 m) ; le tunnel de retour passe sous les lacets (1 265 à 1 345 m) |
| Cœur de la Terre | 1 236 m | un puits en hélice (100 à 565 m) plonge à 85 m sous la surface, chaque tour 34 m sous le précédent ; galerie au-dessus du magma, faille à sauter (612 à 626 m), concasseurs ; second puits pour remonter (715 à 1 185 m), parois qui changent de roche avec la profondeur |
| Échelle Céleste | 1 703 m | une hélice autour d'une tour (100 à 765 m) monte à 105 m, chaque tour 30 m au-dessus du précédent ; pont en apesanteur dans les nuages (trou de 20 m, tremplin et anneaux, rafale) ; large hélice de descente autour d'une seconde tour (1 000 à 1 605 m) |

Coupe Odyssée — des courses longues, à travers plusieurs mondes :

| Circuit | Longueur | Ce qui le distingue |
|---|---|---|
| Faille Temporelle | 2 073 m (3 tours) | trois époques : la grand-place des années cinquante et sa tour de l'horloge frappée par la foudre, une ville du futur (voie aérienne, voitures volantes, tremplin en apesanteur dans deux anneaux), le Far West (train à vapeur, saloons, ravin à sauter 1 312 à 1 326 m). Trois portails (466, 1 116, 1 650 m) |
| Lagon des Bulles | 1 656 m (2 tours) | au fond de la mer, une méduse géante : la cloche festonnée du récif (méduses, tremplin en apesanteur, faille à sauter 812 à 826 m), puis les tentacules ondulants dans la forêt d'algues, son courant et ses bulles ; la ville des maisons-ananas au départ |
| Carnaval de la Lune | 4 300 m, d'un seul tenant | une course linéaire, sans tours, en trois sections : le bourg de l'horloge et ses remparts, la plaine, la montagne enneigée et son col verglacé, la baie et son temple, le marais, le canyon et la spirale autour de la tour de pierre, un pont jusqu'au sommet de l'horloge — puis la bouche de la lune, et l'arrivée sur la lune, au pied du grand arbre. La lune descend vers la tour au fil de la course |
| Terres Carrées | 2 424 m (2 tours) | la prairie ; un portail d'obsidienne toujours ouvert vers le monde du dessous et ses ponts sur la lave (trou à sauter 667 à 681 m) ; un puits d'étoiles à même le sol où l'on tombe (904 m), vers l'île du bout du monde au-dessus du vide et son dragon ; un second puits (1 356 m) vers la cité engloutie et son gardien (1 450 m), et la longue remontée dans la grotte jusqu'à la prairie |

Les portails (`TrackPortail`) relient les mondes d'un circuit. Chacun
s'ouvre quand le premier en approche à 90 m, et se referme quand le dernier
l'a passé (`Track.tete_total`, `queue_total`, que `RaceSession` tient à
jour) : en réseau, tout le monde le voit ouvert au même moment. Son couloir
s'évase au double de l'entrée, et la caméra qui le traverse change de
perspective (`ChaseCamera.vortex` : elle se rapproche du kart pendant que son
champ s'ouvre) — le couloir semble bien plus long qu'il ne l'est. De l'autre
côté, le ciel est celui de `ambiance`, et seuls les nœuds de `decors` de ce
portail se voient, jusqu'au portail suivant (`Track.montrer_le_monde_de`) :
de la grand-place, on ne voit pas les tours du futur.

Une course peut être linéaire, comme certaines de Mario Kart 8 : `Track.arrivee`
est la distance du départ où elle finit, `Track.sections` découpe le parcours
(le compteur affiche « SECTION 2/3 »). Le tracé reste une boucle, mais la
suite de l'arrivée n'est pas courue (`Track.hors_course`) : un trou à
`chute_voulue` la remplace jusqu'à la grille, sans route, hors de la carte et
du relief. Un `TrackTerrain` ou un `TrackSol` à `portion` n'épouse qu'une
partie du tracé : un pont à 50 m de haut ne soulève pas de crête sous lui,
et la prairie de la lune ne recouvre pas Termina.

On voit l'autre monde à travers un portail, comme dans le mod Immersive
Portals : de face, à travers le cadre, la route continue dans l'autre monde
(son ciel, ses décors) ; de biais ou autour du cadre, on voit le monde où
l'on est ; on ne bascule qu'en franchissant la surface. Chaque monde range
ses décors sur un calque de rendu (`Track.calque_du_monde`) : la caméra du
joueur ne dessine que celui du monde où elle se trouve, et chaque portail
proche a une seconde caméra (`SubViewport`), placée exactement comme celle
du joueur, qui ne dessine que le monde de l'autre côté. Son image est collée
sur la surface du portail à l'endroit où elle tombe à l'écran
(`shaders/fenetre_portail.gdshader`). Pas en qualité basse : une seconde
image de toute la scène, à mi-résolution en qualité moyenne, aux trois
quarts en haute, et seulement à moins de 260 m du portail.

Les spectacles (`TrackSpectacle`) s'animent autour de la route sans qu'on y
touche : éclair, voitures volantes, train, méduses, bulles, lune qui descend
au fil de la course (`Track.avancement`), dragon. Le gardien est un
`TrackObstacle` de type `GARDIEN` qui arpente la route d'un bord à l'autre.

Les scènes de la coupe sont générées depuis une description des éléments par
circuit ; les courbes sont dans `tools/build_track_curves.gd`.

Une hélice se dessine point par point, tous les 45° : `tools/build_track_curves.gd`
en contient deux. Ne pas lui appliquer l'élargissement de
`shape_track_curve.gd` (il resserrerait les tours empilés) : un rayon minimal
de 12 suffit à ne garder que le dévers. Entre deux tours, au moins vingt mètres
de hauteur.

Les scènes de ces huit circuits sont écrites comme les autres : on les
retouche dans l'éditeur. `tools/plan_circuit.gd` dessine le plan vu du ciel
d'un circuit et de ses éléments, en PNG :

```
godot --headless --path . -s tools/plan_circuit.gd -- <id> plan.png
```

## Filmer un circuit

`tools/film_circuit.gd` filme un tour depuis la caméra de poursuite, le kart
du joueur confié à l'IA, avec le mode Movie Maker de Godot (image et son) :

```
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 \
    --write-movie tour.avi -s tools/film_circuit.gd -- <id> [case] [tours]
ffmpeg -i tour.avi -vf scale=960:-2 -c:v libx264 -crf 27 -c:a aac tour.mp4
```

## Exemples sur le circuit 1

- `MurEpingle` : mur extérieur de l'épingle en montée (400 à 465 m).
- `RampeLigneDroite` + `TrouLigneDroite` : rampe incurvée de 1,8 m (314 à
  326 m) et trou de 12 m juste derrière (326 à 338 m).
- `TremplinMontee` : tremplin turbo dans la montée (155 m).
- `RaccourciHerbe` : raccourci en herbe à l'intérieur du virage 560 à 605 m.

## Liquides et ciels (`shaders/`)

- `liquide.gdshader` : l'eau et la lave. Un bruit qui dérive dans deux sens
  mêle `couleur_profonde` et `couleur_claire` et ride la surface ; `lueur`
  (lave) fait briller et battre les veines claires. Tout au pixel : le plan
  peut rester à deux triangles.
- `ciel.gdshader` : dégradé, nuages (`nuages`, part du ciel couverte),
  disque du soleil (la première lumière de la scène) et étoiles la nuit
  (`etoiles`). Immobile, pour que les reflets ne se recalculent qu'une fois.

## Relief, accélérateurs et décor posé sur le sol

- `TrackTerrain` (un par circuit) : le sol autour du tracé. Sous le bitume et
  au ras des bas-côtés près de la route, il monte en collines au loin
  (`relief`) et se creuse en ravin sous les trous (`ravin`). Il porte le
  kart près de la route, comme `TrackSol` : voir « Sols réels ».
  `tests/test_relief.gd` vérifie qu'il ne perce jamais la route. Premier
  utilisateur : le Circuit des Collines.
- `TrackBoost` : une plaque d'accélération (turbo `duree_turbo` à
  `force_turbo`), aux flèches qui défilent dans le sens de la course.
- `TrackDecor` : nouveaux objets `ARBRE`, `BOTTE_DE_FOIN`, `MOULIN`,
  `BUISSON` (en rangée serrée, une haie qui marque le bord du praticable).
  `eviter_la_route` saute les objets qui tomberaient sur une autre partie du
  tracé ; s'il y a un `TrackTerrain`, les objets hors de la route se posent
  sur le relief.

## Sols réels

`TrackSol` et `TrackTerrain` portent le kart sur `Track.PORTEE_HORS_PISTE`
(14 m) de chaque côté du bitume : on sort de la route, on roule dans l'herbe,
lentement — c'est du hors-piste, comme une `TrackOffroad` —, et l'on revient.
Seule cette bande a une collision (`SolPorteur`) ; au-delà, le sol n'est que
décor. Un sol qui est le décor d'un monde (`TrackPortail.decors`) ne porte
qu'au bord de la route de ce monde : invisible ailleurs, il n'y fait pas de
plancher fantôme.

La session remet le kart en piste s'il sort de la bande, s'il tombe à plus de
3,5 m sous la route (d'un pont dans le pré d'en dessous), ou s'il gagne dans
l'herbe bien plus de tracé qu'il n'en roule (`RACCOURCI_TOLERE`) : on peut
prendre la corde d'un virage, pas couper une épingle à travers champs. Les
raccourcis voulus restent des `TrackOffroad`. `tests/test_sols_reels.gd`.

