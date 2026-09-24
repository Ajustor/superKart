# Dessiner un circuit : murs, rampes, trous, tremplins, raccourcis

Un circuit, c'est un nœud `Track` et sa courbe (`Curve3D`). La route, sa
collision et la ligne de l'IA en sont tirées automatiquement. Tout le reste se
pose **sur le tracé**, comme enfant du nœud `Track`.

## Les éléments

| Nœud | Ce qu'il fait | Collision |
|---|---|---|
| `TrackWall` | un muret rouge et blanc qui suit le tracé : au bord gauche, au bord droit, aux deux, ou à un endroit libre | oui : le kart s'y arrête de face, glisse le long de biais ; les carapaces rebondissent |
| `TrackRamp` | une vraie rampe en relief : le kart la monte et décolle au sommet avec l'élan qu'elle lui donne | oui |
| `TrackGap` | un trou : la route n'est pas construite sur cette portion, on la franchit en sautant | — |
| `TrackJump` | une zone de saut peinte : le kart qui passe dessus décolle d'une impulsion fixe, avec un turbo en option | non, c'est une zone |
| `TrackOffroad` | une zone d'herbe, de sable ou de boue : on y roule, mais au ralenti | oui : elle crée du sol, même à côté de la route |
| `TrackDecor` | une rangée de décor le long du tracé : palmiers, phare, piliers enflammés, étoiles, champignons géants, rochers. `espacement` 0 pose un objet seul | non : on passe au travers |

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
  mais ne cherche pas les raccourcis. Une rampe devant un trou doit donc
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
| Forteresse de Lave | 773 m | remparts presque partout, montée vers une chicane à 10 m de haut (340 à 470 m), douve de lave à sauter (542 à 566 m), piliers enflammés |
| Ruban Céleste | 1 099 m | route arc-en-ciel dans la nuit, en huit : le pont (560 à 650 m) passe 20 m au-dessus de la ligne droite de départ ; saut dans le vide (866 à 892 m), garde-fous seulement dans les virages serrés |
| Jardin Champignon | 855 m | bosses douces, bas-côtés d'herbe, champignons géants, deux champignons rebondissants (392 et 650 m) ; prairie à 2,5 m sous la route |
| Mine Scintillante | 724 m | descente de 14 m entre des étais (90 à 280 m), fond de galerie aux cristaux, remontée étayée (420 à 620 m), gouffre à sauter (636 à 661 m) juste avant la ligne |
| Ville Néon | 746 m | la nuit, rues à angle droit entre les tours, bordures fluo, lampadaires, avenue en travaux à sauter (550 à 576 m) |
| Station des Neiges | 869 m | départ à 30 m, descente à bosses (292, 398 m), vallée, remontée par le col (bosse à 640 m) ; larges bas-côtés de neige, sapins |

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
  (`relief`) et se creuse en ravin sous les trous (`ravin`). Sans collision :
  il ne change rien à la course. `tests/test_relief.gd` vérifie qu'il ne
  perce jamais la route. Premier utilisateur : le Circuit des Collines.
- `TrackBoost` : une plaque d'accélération (turbo `duree_turbo` à
  `force_turbo`), aux flèches qui défilent dans le sens de la course.
- `TrackDecor` : nouveaux objets `ARBRE`, `BOTTE_DE_FOIN`, `MOULIN`,
  `BUISSON` (en rangée serrée, une haie qui marque le bord du praticable).
  `eviter_la_route` saute les objets qui tomberaient sur une autre partie du
  tracé ; s'il y a un `TrackTerrain`, les objets hors de la route se posent
  sur le relief.
