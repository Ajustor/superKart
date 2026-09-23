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

## Exemples sur le circuit 1

- `MurEpingle` : mur extérieur de l'épingle en montée (400 à 465 m).
- `RampeLigneDroite` + `TrouLigneDroite` : rampe incurvée de 1,8 m (314 à
  326 m) et trou de 12 m juste derrière (326 à 338 m).
- `TremplinMontee` : tremplin turbo dans la montée (155 m).
- `RaccourciHerbe` : raccourci en herbe à l'intérieur du virage 560 à 605 m.
