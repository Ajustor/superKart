# Performances

## Voir ce qui se passe

**Options → Affichage → Compteur de FPS** affiche une ligne en haut de
l'écran, partout (menus, course, pause) :

| Valeur | Ce qu'elle dit |
|---|---|
| FPS | images par seconde sur la dernière seconde. Vert à 55 et plus, orange à partir de 30, rouge en dessous |
| ms (pire) | durée moyenne d'une image, et la plus longue de la dernière seconde. Une pire image à 200 ms se sent comme un gel, même avec une bonne moyenne |
| à-coups | nombre d'images de plus de 50 ms depuis l'affichage du compteur |
| physique | temps passé dans la physique (karts, IA, objets) par image |
| dessins | appels de dessin de la dernière image : ce que coûte la scène à la carte graphique |

Pour savoir d'où vient un ralentissement :

- **physique élevée** (plus de 8 ms) : c'est le processeur, la qualité
  graphique n'y changera rien ;
- **physique basse mais FPS bas** : c'est la carte graphique. Baisser la
  qualité graphique.

## Qualité graphique

**Options → Affichage → Taille de l'interface** : en automatique, normale
sur un téléphone ou un écran tactile, plus petite ailleurs (× 0,75) — sur un
écran de PC, l'interface dessinée pour le doigt était énorme. Petite, normale
ou grande au choix.

**Options → Affichage → Qualité graphique** :

| Réglage | Résolution 3D | Ombres portées | Lueur, brouillard | Grain du bitume, contraste et saturation | Vignette et traits de vitesse |
|---|---|---|---|---|---|
| Haute | 100 % | oui | oui | oui | oui |
| Moyenne | 80 % | non | oui | non | oui |
| Basse | 60 % | non | non | non (ni tone mapping) | non |
| Automatique | Moyenne sur téléphone et tablette, Haute ailleurs | | |

Les ombres portées redessinent toute la scène une seconde fois, vue du
soleil : c'est le premier poste qu'on retire. Le grain du bitume (trois
lectures de texture par pixel de route, deux fois) et l'étalonnage (une passe
de plus sur toute l'image) suivent : sur téléphone, la route reste unie.

`tools/mesure_rendu.gd` relève, sur 40 s de course vue du kart du joueur,
les appels de dessin et les triangles par image : ce que la scène demande à
la carte graphique, quelle que soit sa puissance.

```
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 \
    --fixed-fps 30 -s tools/mesure_rendu.gd -- <circuit> [haute|moyenne|basse]
```

## Ce qui a été fait contre les gels et les commandes perdues

- **Moteur physique Jolt** au lieu de GodotPhysics, et projections sur le
  tracé cinq fois moins chères : une image coûte deux fois moins de
  processeur (mesuré : 4,0 à 4,8 ms → 2,3 à 2,5 ms sur PC, pires images de
  30-44 ms → une dizaine).
- **Au plus 3 pas de physique par image** (au lieu de 8). Quand une image
  prend du retard, Godot rattrape en enchaînant des pas de physique ; sur
  un téléphone lent, chaque rattrapage allongeait l'image suivante, jusqu'au
  gel. Maintenant le jeu ralentit un instant, puis repart.
- **Appuis brefs retenus** : un tap sur OBJET ou DRIFT plus court qu'une
  image n'est plus perdu.
- **Touchers traités avant chaque pas de physique**
  (`input_devices/buffering/agile_event_flushing`).
- **Mini-carte** : la route n'est plus redessinée à chaque image, seuls les
  points des karts le sont.

## Mesurer

```
godot --headless --fixed-fps 60 --path . -s tools/essai_circuit.gd -- <circuit> [tours]
```

fait courir huit IA et donne, en plus des temps, la durée réelle de chaque
image (moyenne, 95e centile, pire). Sans rendu : c'est le coût processeur
seul.

## Saccades

- **Tour de chauffe** (`TourDeChauffe`) : derrière l'écran de chargement,
  trois images sont rendues depuis une caméra qui voit tout le circuit, avec
  devant elle un exemplaire de chaque objet et de chaque effet (boîtes,
  bananes, carapaces, explosion, aura d'étoile, étincelles, poussière,
  flammes). En GL Compatibility, un matériau n'est compilé qu'à son premier
  dessin : sans ce tour, la première carapace ou la première vue sur la lave
  figeaient l'image en pleine course. Mesuré en rendu logiciel sur la
  Forteresse : 2 saccades de 150-165 ms à la première carapace sans le tour,
  aucune avec. Les portails y passent aussi, grands ouverts
  (`TrackPortail.chauffer`) : leur anneau, leur fenêtre — qui prend là sa
  taille définitive — et le ciel de chaque autre monde, une image par ciel.
  Sans ça, chaque portail figeait l'image en s'ouvrant sur un petit téléphone.

## Journal et plantages

Le jeu écrit son journal (`user://logs`, sur Android
`Android/data/com.ajustor.superkart/files/logs`). `Journal` (autoload) y
ajoute des repères : chaque écran, chaque course, et la mémoire toutes les
30 s. Une marque posée au lancement et retirée à la sortie propre (ou quand
le système met le jeu en pause) révèle un arrêt brutal : l'accueil le dit au
lancement suivant, et **Options → Journal de la partie précédente** en montre
la fin, avec un bouton **Copier** pour l'envoyer.

Mesuré sur 14 circuits enchaînés puis le premier à nouveau : 110 à 120 Mo de
mémoire, autant d'objets à 1 % près — pas de fuite d'une course à l'autre.
- Les maillages des objets sont faits une fois (`ItemManager._forme`) ; le
  tableau des résultats se réécrit en place au lieu d'être refait deux fois
  par seconde ; le son moteur, calculé échantillon par échantillon, tourne à
  11 025 Hz.
- `tools/essai_saccades.gd` relève les images anormalement longues d'une
  course et ce qui venait de se passer (objet, explosion, choc, figure…) :

      xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 480x270 \
          -s tools/essai_saccades.gd -- <id> [secondes] [sans_chauffe]

  Avec `--headless --fixed-fps 60` à la place, il ne mesure que le coût
  processeur.

## Finitions de l'image selon la qualité

- **Lissage des bords** (`QualiteGraphique.anticrenelage`) : MSAA 4× en haute
  et 2× en moyenne sur ordinateur ; jamais sur téléphone (certaines puces
  plantaient, voir le garage), dont l'écran dense crénelle moins.
- **Ombres du soleil** (haute seulement) : floutées (`shadow_blur` 1,5), en
  deux découpes fondues l'une dans l'autre, jusqu'à 140 m.
- **Ombres de contact** : quand le soleil ne projette pas d'ombre (moyenne,
  basse, donc les téléphones), chaque kart pose sous lui une tache sombre
  et floue (`KartVisuals._creer_ombre_de_contact`), cachée en l'air.
- **Fumées** : le sprite de fumée de Kenney (`assets/kenney/effets/`), en
  quelques particules calculées par le processeur, pour la poussière hors
  piste et la fumée blanche des pneus en glisse.
