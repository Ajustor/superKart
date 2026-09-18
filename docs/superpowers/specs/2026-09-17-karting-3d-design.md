# Jeu de karting 3D — design

**Date :** 2026-09-17
**Statut :** validé, prêt pour le plan d'implémentation

## 1. Objectif

Un jeu de course de karting arcade en 3D, dans la veine de Mario Kart : course solo contre sept
adversaires pilotés par l'IA, dérapages à mini-turbo, objets offensifs. Trois circuits.

Le jeu doit être léger, tourner à 60 fps sur une machine modeste, et reposer sur un code clair
et découpé en unités petites et testables.

## 2. Contraintes

| Contrainte | Décision |
|---|---|
| Distribution | Exécutable natif autonome (Windows / Linux / macOS) |
| Matériel cible | 60 fps en 1080p sur GPU intégré |
| Moteur | Godot 4, backend de rendu *Compatibility* (OpenGL 3.3) |
| Langage | GDScript avec typage statique |
| Direction artistique | Toon / cel-shaded, contours noirs, couleurs saturées |
| Mode de jeu | Solo contre IA uniquement |

### Alternatives écartées

- **Bevy (Rust)** — architecture ECS plus propre et binaires plus compacts, mais absence
  d'éditeur. Sur un jeu de course, l'essentiel du travail de contenu est le tracé des pistes ;
  le faire sans éditeur 3D allonge chaque itération de façon rédhibitoire.
- **raylib / wgpu en custom** — temps passé sur la plomberie plutôt que sur le game feel.
- **Unity, Unreal** — builds lourds et complexité disproportionnée. Unreal contredit
  frontalement la cible « machine modeste ».
- **C# plutôt que GDScript** — meilleur outillage de refactoring, mais export plus lourd et
  friction d'outillage. À cette échelle de logique, le typage statique de GDScript suffit.
- **`VehicleBody3D`** — simulation de suspension et d'adhérence réalistes. Le pilotage arcade
  n'est pas réaliste : on veut un kart qui pivote plus vite que la physique ne l'autoriserait.
  Un `CharacterBody3D` avec raycasts donne moins de code, un comportement déterministe et un
  contrôle total sur la sensation.

## 3. Architecture

### 3.1 Principes

1. **Une seule physique, deux sources d'intention.** Le joueur et l'IA produisent le même
   `KartCommand` ; en aval, `KartMotor` ignore qui lui parle. L'IA ne peut donc pas tricher, et
   régler le dérapage le règle pour les huit karts à la fois.
2. **Le moteur ne dépend pas de l'arbre de scènes.** `KartMotor` transforme un état et une
   commande en nouvel état. Cette contrainte rend testable la partie du code où les bugs coûtent
   le plus cher à diagnostiquer à l'œil.
3. **Les réglages sortent du code.** Tout ce qui se règle au feeling vit dans des `Resource`
   éditables moteur tournant.

### 3.2 Contrat d'entrée

```gdscript
class_name KartCommand

var steer: float      # -1.0 .. 1.0
var throttle: float   #  0.0 .. 1.0
var brake: float      #  0.0 .. 1.0
var drift: bool
var use_item: bool
```

`KartInput` est la classe de base ; `PlayerInput` (clavier et manette) et `AIInput` en héritent.
C'est le seul point de variation entre le kart du joueur et ceux des adversaires.

### 3.3 Arbre de scènes

```
race.tscn
└─ RaceScene
   ├─ Track                    (scène de circuit, interchangeable)
   │  ├─ TrackMesh             géométrie + collision trimesh
   │  ├─ RacingLine (Path3D)   trajectoire IA, classement, respawn, grille
   │  ├─ Checkpoints           Area3D numérotés
   │  ├─ ItemBoxes             Area3D, réapparition différée
   │  └─ Decor
   ├─ Karts                    1 joueur + 7 IA
   ├─ ChaseCamera
   ├─ RaceDirector             décompte, tours, classement, arrivée
   └─ HUD
```

```
kart.tscn
└─ Kart (CharacterBody3D)
   ├─ KartMotor          physique arcade, état sonné
   ├─ KartInput          PlayerInput | AIInput
   ├─ KartVisuals        inclinaison, roues, étincelles, shader toon
   ├─ KartInventory      un emplacement d'objet
   ├─ RaceProgress       checkpoint courant, tour, distance parcourue
   └─ stats: KartStats   ressource
```

Changer le pilote d'un kart revient à échanger deux nœuds : la source d'input et la ressource de
stats. Le `RaceDirector` détient l'état de course ; les karts déclarent les checkpoints qu'ils
franchissent et ne connaissent pas leur position au classement.

### 3.4 KartStats (Resource)

Vitesse maximale, accélération, freinage, taux de braquage, adhérence, vitesse minimale
d'entrée en dérapage, fourchette d'angle de glisse, seuils des trois paliers de dérapage, durées
des trois turbos, multiplicateur hors-piste, durée de l'état sonné.

## 4. Pilotage et game feel

### 4.1 Modèle de dérapage

En conduite normale, le cap du kart et son vecteur vitesse sont alignés. À l'entrée en dérapage,
on verrouille un sens — celui du braquage à cet instant — et la caisse pivote vers l'extérieur
dans une fourchette de 30 à 55°, tandis que le vecteur vitesse ne rattrape ce cap qu'avec du
retard. Ce décalage est la glisse. Pendant le dérapage, le braquage ne fait plus tourner le kart :
il module l'angle de glisse à l'intérieur de la fourchette.

### 4.1 bis Marche arrière

Le frein a deux rôles : il ralentit, puis engage la marche arrière une fois le kart à l'arrêt.
Freiner est franc, reculer est lent, et la vitesse en marche arrière plafonne bien en deçà de la
vitesse avant. On ne dérape pas en reculant.

Conséquence à connaître : `speed` peut être négatif, donc toute fonction qui le lit doit le
supposer signé — l'autorité de braquage travaille sur sa valeur absolue.

**Déraper ne doit presque pas coûter de vitesse.** Si la glisse ralentit, le joueur l'évite et le
mini-turbo devient une punition déguisée. Le dérapage doit rester gratuit et rentable, pour que la
conduite devienne un rythme plutôt qu'une série de virages négociés.

### 4.2 Machine à états

```
ADHÉRENCE ──(bouton + braquage + vitesse > seuil)──▶ SAUT (0,15 s) ──▶ DÉRAPAGE
DÉRAPAGE  ──(relâché)──▶ TURBO(palier) ──(épuisé)──▶ ADHÉRENCE
DÉRAPAGE  ──(contre-braquage ou vitesse trop basse)──▶ ADHÉRENCE, sans turbo
n'importe quel état ──(touché)──▶ SONNÉ ──▶ ADHÉRENCE
```

### 4.3 Paliers de charge — valeurs de départ

| Palier | Temps en dérapage | Étincelles | Durée du turbo |
|---|---|---|---|
| 1 | 0,6 s | bleues | 0,5 s |
| 2 | 1,5 s | orange | 1,0 s |
| 3 | 2,6 s | violettes | 1,8 s |

Ces chiffres seront ajustés manette en main ; ils ne seront probablement pas bons du premier coup.

**La couleur des étincelles est toute l'interface de charge.** Pas de jauge dans le HUD : le joueur
apprend à lire sa charge en trois courses. C'est aussi ce qui rend les adversaires lisibles.

### 4.4 Sensation de vitesse

Elle vient presque entièrement de la caméra : suivi à ressort amorti qui se laisse distancer à
l'accélération, FOV interpolé de 70 à 85° avec la vitesse, léger roulis dans le dérapage, regard
porté en avant du kart.

S'y ajoutent : secousse courte au déclenchement du turbo, lignes de vitesse, hauteur du son moteur
indexée sur le régime, écrasement des suspensions à la réception d'un saut.

Hors-piste, un multiplicateur de vitesse à 0,6 suffit ; pas de physique de terrain.

## 5. Piste

### 5.1 Une courbe, tout le circuit

Un `Curve3D` tracé à la souris dans l'éditeur définit l'axe du circuit. **Tout le reste en
découle par le calcul**, sans rien à placer à la main :

| Ce qu'on en tire | Comment |
|---|---|
| La géométrie de la route | extrusion d'un ruban le long de la courbe, largeur et dévers paramétrés |
| La collision | le même ruban, en trimesh |
| La ligne de course de l'IA | l'axe décalé vers l'intérieur, proportionnellement à la courbure locale |
| La progression et les tours | distance parcourue le long de la courbe |
| Le classement | tri sur la distance cumulée |
| Les remises en piste | projection du kart sur la courbe ; la tangente donne l'orientation |
| La grille de départ | décalages en amont du point zéro |
| Le hors-piste | distance à l'axe supérieure à la demi-largeur |

Déplacer un point de contrôle redéfinit donc le circuit entier, sa collision, la trajectoire de
l'IA et la logique de course d'un seul geste. Un troisième circuit coûte une courbe.

### 5.2 Progression continue plutôt que checkpoints

Une version précédente de ce spec prévoyait des `Area3D` numérotés à franchir dans l'ordre, pour
interdire de faire demi-tour et valider un tour. La courbe rend l'idée inutile : **on suit une
distance cumulée**, qui augmente en avançant et diminue en reculant. Un tour est validé quand
cette distance franchit la longueur du circuit.

C'est plus simple, plus robuste, et surtout il n'y a plus rien à poser : un circuit n'a pas
d'objets de gameplay à aligner, seulement une courbe.

Le classement ne compare jamais les karts entre eux : chacun connaît sa distance cumulée, et trier
huit karts sur un seul nombre reste juste quelle que soit la forme du circuit.

### 5.3 Pipeline de fabrication

Aucun outil externe. On trace un `Curve3D` dans l'éditeur Godot, un générateur produit le maillage
et la collision au chargement, et le décor s'ajoute par-dessus séparément.

*Écarté : la modélisation dans Blender avec import glTF.* Plus riche visuellement et sans limite
de forme, mais elle faisait dépendre les trois circuits d'un travail manuel dans un outil tiers,
sans bénéfice pour un rendu toon à facettes plates. La génération procédurale rend en prime la
piste paramétrable : changer la largeur ou le dévers de tous les circuits est un réglage, pas une
reprise de modélisation.

### 5.4 Les trois circuits

Trois circuits qui explorent des choses différentes, pas trois variations :

1. **Côtier** — large et rapide, virages ouverts. Sert de circuit d'apprentissage.
2. **Urbain nocturne** — technique, virages serrés, peu de marge.
3. **Montagne** — dénivelé, sauts, et un raccourci risqué.

Un écran de sélection de circuit précède la course.

## 6. IA

`AIInput` vise un point situé environ 0,45 seconde de trajet devant le kart — donc plus loin à
vitesse élevée. Elle calcule l'angle entre son cap et ce point, en déduit un braquage, et déclenche
le dérapage au-delà d'un seuil d'angle. Passant par `KartCommand`, elle est enfermée dans la même
physique que le joueur : elle dérape pour de vrai, avec les mêmes étincelles.

**La difficulté ne se règle pas en donnant de la vitesse gratuite.** Elle se règle sur quatre
variables :

- distance du point visé — viser court produit des trajectoires sales ;
- décalage latéral aléatoire par rapport à la ligne idéale ;
- délai de réaction ;
- propension à tenir le dérapage jusqu'au palier violet plutôt qu'à le lâcher au bleu.

Une IA facile est une IA qui pilote mal, pas une IA bridée — et la différence se voit à l'écran.

Si un rattrapage élastique s'avère nécessaire au réglage, il jouera sur l'accélération et jamais
sur la vitesse de pointe, pour qu'un adversaire ne double jamais le joueur en ligne droite alors
qu'il est à fond.

Politique d'objets de l'IA, volontairement simple : utiliser dès réception, sauf garder une banane
en protection quand elle est en tête et la lâcher si un poursuivant se rapproche.

## 7. Objets

### 7.1 Les quatre objets

| Objet | Effet |
|---|---|
| Champignon | poussée instantanée. Une variante « triple » accorde trois usages du même objet |
| Banane | lâchée derrière soi, provoque un tête-à-queue |
| Carapace verte | projectile en ligne droite, rebondit sur les murs |
| Carapace rouge | poursuit le kart classé devant le lanceur |

### 7.2 Probabilités selon la position

La table de tirage dépend de la position au classement : c'est elle qui rend le jeu vivant, pas
les objets eux-mêmes. En tête, surtout des bananes ; en fond de peloton, souvent une carapace rouge
ou un triple champignon. La table est une `Resource`, réglable sans toucher au code.

### 7.3 Intégration

- `KartCommand.use_item` déclenche l'usage ; l'IA l'emploie comme le joueur.
- `KartInventory` détient un seul emplacement.
- `ItemBox` est un `Area3D` qui réapparaît après un délai.
- L'impact met le kart dans l'état **sonné** : un compteur dans `KartMotor` qui ignore les
  commandes et fait pivoter la caisse. Pas de machine à états supplémentaire.
- La carapace rouge obtient sa cible du classement et sa trajectoire du `Path3D` — les deux
  existent déjà, ce qui rend le guidage presque gratuit.

## 8. Périmètre

### Dans la v1

Trois circuits avec écran de sélection. Huit karts (joueur + 7 IA), trois tours. Dérapage et
mini-turbo. Les quatre objets et les boîtes. Classement. HUD réduit à position, tour et chrono.
Écran de fin. Clavier et manette.

### Hors périmètre

Coupes et championnats, écran partagé, multijoueur en ligne, personnalisation des karts,
sauvegarde et progression, time attack et fantômes, menu complet au-delà de la sélection de
circuit.

## 9. Ordre de livraison

1. Un kart qui roule sur un plan nu, avec la caméra. Un cube gris suffit.
2. Dérapage, mini-turbo, étincelles.
3. **Point de validation — le jeu se joue.** Si conduire un cube gris sur un plan vide n'est pas
   déjà agréable, aucune piste et aucune direction artistique ne le rattraperont. C'est le seul
   jalon qui peut remettre en cause le reste du design, et il arrive tôt délibérément.
4. Circuit 1 réel, checkpoints, tours, chrono.
5. IA.
6. Système d'objets complet, sur le circuit 1.
7. Shader toon et direction artistique, sur le circuit 1.
8. Circuits 2 et 3, écran de sélection.
9. Juice, son, HUD, écran de fin.
10. Export et passe de performance.

Les circuits 2 et 3 arrivent tard délibérément : le pipeline de fabrication se valide une fois sur
le circuit 1, et une fois la direction artistique figée, les refaire est mécanique. Les construire
avant, c'est prendre le risque de les refaire.

## 10. Budget de performance

- Backend *Compatibility* (OpenGL 3.3), cible 60 fps en 1080p sur GPU intégré.
- Moins de 150 draw calls à l'écran, moins de 100 000 triangles visibles.
- Absence de textures : les matériaux se comptent sur les doigts d'une main.
- **Contours par *inverted hull* réservés aux karts et aux objets de gameplay.** La technique
  dessine chaque objet deux fois ; l'appliquer au décor doublerait le coût de rendu. Le décor reste
  en cel-shading sans contour, ce qui fait ressortir les karts — contrainte technique retournée en
  choix de lisibilité.
- Aucune allocation dans `_physics_process` : pas de tableau ni de dictionnaire créé par frame.

## 11. Tests

GUT, sur la logique pure uniquement :

- accumulation de la charge de dérapage et franchissement des paliers ;
- rejet d'un checkpoint franchi hors séquence ;
- validation d'un tour complet ;
- tri du classement à partir des couples (checkpoint, distance) ;
- projection d'un point sur la courbe, pour le respawn ;
- tirage d'objet respectant la table de probabilités selon la position.

Ni le rendu ni le game feel ne sont testés automatiquement — ils se valident manette en main.

## 12. Arborescence

```
scenes/     race.tscn · kart/kart.tscn · tracks/track_01..03.tscn · ui/track_select.tscn
scripts/    kart/    kart.gd, kart_motor.gd, kart_input.gd, player_input.gd,
                     ai_input.gd, kart_visuals.gd, kart_inventory.gd, race_progress.gd
            race/    race_director.gd, checkpoint.gd, standings.gd
            items/   item_box.gd, item_roulette.gd, projectile.gd,
                     green_shell.gd, red_shell.gd, banana.gd, mushroom.gd
            camera/  chase_camera.gd
resources/  karts/*.tres · items/item_weights.tres
shaders/    toon.gdshader · outline.gdshader
assets/     models/ · sfx/
tests/      GUT
```

## 13. Risques

- **Le game feel est le risque principal.** Il ne se conçoit pas sur le papier, il se règle. Le
  point de validation du jalon 3 existe pour le révéler tôt plutôt qu'après trois circuits.
- **Le volume de contenu.** Trois circuits modélisés à la main représentent la plus grosse part du
  temps du projet, et ce temps est en modélisation, pas en code.
- **Le réglage de la table d'objets.** L'équilibre entre « vivant » et « injuste » est délicat ;
  la table étant une ressource, il se corrige sans reprendre de code.
