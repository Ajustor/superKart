# Dessiner un circuit : murs, tremplins, raccourcis

Un circuit, c'est un nœud `Track` et sa courbe (`Curve3D`). La route, sa
collision et la ligne de l'IA en sont tirées automatiquement. Tout le reste se
pose **sur le tracé**, comme enfant du nœud `Track`.

## Les trois éléments

| Nœud | Ce qu'il fait | Collision |
|---|---|---|
| `TrackWall` | un muret rouge et blanc qui suit le tracé : au bord gauche, au bord droit, aux deux, ou à un endroit libre | oui : le kart s'y arrête de face, glisse le long de biais ; les carapaces rebondissent |
| `TrackJump` | une zone de saut peinte : le kart qui passe dessus décolle, avec un turbo en option | non, c'est une zone |
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
- L'IA suit sa ligne : elle prend les tremplins qui s'y trouvent, mais ne
  cherche pas les raccourcis. Ils restent un avantage pour le joueur.
- Au-delà du bord de la route, le sol construit reste à plat, à la hauteur du
  bord : il ne prolonge pas le dévers du virage.

## Exemples sur le circuit 1

- `MurEpingle` : mur extérieur de l'épingle en montée (400 à 465 m).
- `TremplinLigneDroite` : tremplin turbo sur la ligne droite (332 m).
- `RaccourciHerbe` : raccourci en herbe à l'intérieur du virage 560 à 605 m.
