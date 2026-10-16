# Le nuage magique — design

**Date :** 2026-10-09
**Statut :** validé, prêt pour le plan d'implémentation

## 1. Objectif

Un nouveau kart au garage, inspiré du nuage de Goku : un nuage doré sur lequel le pilote se tient
debout. Il a sa propre allure et son propre caractère de pilotage, mais la même physique que les
autres karts.

## 2. Place dans le garage

Aujourd'hui, tous les karts portent la même caisse Kenney (`kart-oobi.glb`), repeinte. La ligne
« Moteur » du garage (`ModeleKart.CARROSSERIES`, champ `modele` partout ailleurs) ne change que les
réglages ; seules les roues, la couleur et le pilote changent l'allure.

- La ligne « Moteur » devient **« Kart »**.
- Le nuage magique est la **6ᵉ entrée de `CARROSSERIES`**, ajoutée en fin de liste : une sauvegarde
  existante garde ses indices, et la sauvegarde, le salon, le réseau, le lanceur et la liste
  multijoueur transportent déjà `modele`.
- Quand le nuage est choisi, **les lignes Roues et Couleur se masquent** : un nuage n'a pas de roues,
  et il est toujours doré. Le choix de roues et de couleur reste enregistré, pour quand on repasse
  sur un kart.
- **Les roues ne comptent pas** pour le nuage : `ModeleKart.stats` le traite comme monté sur les
  roues Standard (facteur 1). Sans ça, un réglage invisible changerait la tenue de route.

### Écarté

- *Une nouvelle ligne « Véhicule » dédiée* : plus propre si d'autres véhicules suivent, mais elle
  touche toute la plomberie (sauvegarde, salon, protocole, lanceur) pour un seul ajout.
- *Une caisse posée sur n'importe quel moteur* : le moteur et les roues garderaient leurs effets
  alors que les roues ne se voient plus.

## 3. Pilotage : « aérien »

| Vitesse | Accélération | Maniabilité | Glisse | Poids | Tout-terrain |
|---|---|---|---|---|---|
| 0,995 | 0,90 | 1,0 | 1,25 | 0,75 | 1,35 |

Description au garage : *« Il flotte sur l'herbe et glisse comme un rêve, mais un rien le bouscule. »*

Il gagne en glisse et en tout-terrain, et perd en pointe et en reprise : la règle du garage (chaque
entrée gagne au moins une caractéristique et en perd au moins une) est tenue. Les garde-fous
existants s'appliquent tels quels : parabole des sauts conservée, rayon de braquage sous 13,1 m,
pertes au mur et hors piste bornées.

L'IA ne le prend pas (`KARTS_IA` inchangé). La course de fond du menu, qui tire tout le garage au
hasard, peut le montrer.

## 4. Allure

### 4.1 Le nuage

Un nouveau script, `scripts/kart/nuage_magique.gd` (classe `NuageMagique`, un `Node3D`), posé en
`Body/Nuage` :

- **Une douzaine de sphères fusionnées en un seul maillage**, donc un seul appel de dessin, en
  couleurs de sommets : jaune doré, plus clair sur le dessus. Le maillage est construit une fois et
  partagé par tous les nuages.
- **Une traîne** de trois bouffées qui rapetissent vers l'arrière, dans le même maillage.
- **Emprise d'environ 1,4 × 2 m**, proche de la boîte de collision (1,1 × 0,7 × 1,7 m) : la physique,
  les chocs et le cadrage de l'aperçu ne changent pas.
- **Il flotte** à quelques centimètres du sol, avec un léger bercement vertical. Le bercement vit
  dans le nuage lui-même, pas dans `Body`, que la suspension et `KartVisuals` pilotent déjà.
- **Une traînée de petites bouffées dorées** quand il roule, en `CPUParticles3D` : `test_chargement`
  interdit les `GPUParticles3D`.

### 4.2 Ce qui disparaît, ce qui reste

- La caisse `Body/Kenney` est masquée.
- Les 4 nœuds `Wheels/*` restent en place, parce que la suspension en dépend, mais leurs jantes sont
  masquées.
- Plus de fumée de pneus en glisse ni de poussière hors piste : il ne touche pas le sol.
- Les étincelles de glisse et les flammes du turbo restent : ce sont des signaux de jeu, pas de la
  décoration.
- Habiller deux fois ne doit rien empiler : passer du kart au nuage et retour bascule entre
  `Body/Kenney` et `Body/Nuage`.

### 4.3 Le pilote

Il se tient **debout au centre du nuage**, avec l'animation de repos des personnages Kenney
(`idle`) au lieu de `drive`. `ModeleKart.siege` dépend désormais du kart, et plus seulement du train
de roues. Les gestes (lancer, choc), les figures et les fêtes d'arrivée passent avant le repos,
comme ils passent avant la conduite aujourd'hui.

## 5. Réseau

Le choix de kart circule déjà sous forme d'indice, et rien de visuel ne transite à chaque image.
Mais un client plus ancien ignorerait l'indice 5 : il calculerait d'autres caractéristiques pour un
joueur monté sur le nuage. La version du protocole (`NetworkManager.VERSION`) est donc incrémentée.

## 6. Tests

Dans `tests/test_garage.gd` :

- habillé en nuage, le kart montre `Body/Nuage` et masque `Body/Kenney` ;
- les 4 roues sont toujours présentes, mais leurs jantes sont invisibles ;
- habiller kart → nuage → kart → nuage ne laisse ni doublon ni caisse masquée par erreur ;
- les roues choisies ne changent pas les caractéristiques du nuage ;
- au garage, les lignes Roues et Couleur se masquent quand le nuage est choisi, et reviennent avec
  un kart ;
- un joueur sur le nuage fait l'aller-retour du salon et du plan de course réseau.

Dans `tests/test_personnages.gd` :

- le pilote est debout au centre du nuage, et joue `idle`.

Les tests existants couvrent d'office la nouvelle entrée : gains et pertes, rayon de braquage,
parabole des sauts, jauges.

Le rendu se vérifie à l'œil, par captures, dans l'aperçu du garage et en course.

## 7. Documentation

- `docs/modes-de-jeu.md`, sections Garage et Pilotes : la ligne Kart, la nouvelle entrée et son
  allure.
- `docs/multijoueur.md` : la version du protocole.

## 8. Hors périmètre

- Un son propre au nuage : il garde le moteur synthétisé des karts.
- Le nuage pour l'IA.
- Une couleur au choix pour le nuage.
