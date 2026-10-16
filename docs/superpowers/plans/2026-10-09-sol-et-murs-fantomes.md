# Sol et murs fantômes — plan de correction

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** plus aucun kart dessiné sous la route ou dans le sol, et plus aucun mur qu'on ne voit pas.

**Architecture :** cinq chantiers indépendants, chacun dans ses propres fichiers, donc menés en parallèle :

- les bords de piste (bandes d'herbe, talus) ;
- le kart (roues, caisse, figures) ;
- les collisions de décor ;
- le relief d'etoiles ;
- l'affaissement du bitume.

Chaque correctif commence par un test qui échoue sur le code d'aujourd'hui. Il est validé par un test vert, puis par le banc qui avait trouvé le défaut.

**Tech Stack :** Godot 4.7.2, GDScript typé, physique Jolt, GUT 9.7.1.

---

## Ce que la mesure a établi

Trois bancs ont tourné moteur tournant sur les 29 circuits, le 2026-10-09. Ils ne sont pas dans le dépôt : ils vivent dans le dossier temporaire de la session, chemins plus bas.

| # | Défaut | Mesure | Cause |
|---|---|---|---|
| M1 | Le bord intérieur des bandes d'herbe fait mur | 920 sorties bloquées sur 1 220 bordées d'une bande (74 %), 16 circuits. Bande refaite au ras : 5 | `track_offroad.gd:37-40` : collision à +2 cm du bitume |
| M2 | On ne remonte pas du sol sur la route | Sur 1 297 retours depuis TrackSol / TrackTerrain : 44 réussis, 598 bloqués par le bord (marche de 0,20 à 0,29 m), 548 **sous la route**, enfoncés de 0,48 m | le sol est 0,14 à 0,45 m sous le bord ; la route n'a pas de flanc solide |
| M3 | Les bords extérieurs et les bouts des bandes flottent | 99 blocages au bord extérieur (jardin_champignon 91), 14 bouts sur 20 (marche de 0,13 à 0,32 m) | la bande reste à la hauteur du bord de route, le sol est plus bas |
| M4 | Collisions de décor plus grandes que leur modèle | TENTE : bloc de 6 × 4 × 6 m, rien de visible à hauteur de kart, à 2,1 m du bord. PANNEAU_PUB : dalle de 8 m sous un panneau perché. SAPIN : +1,2 m. BUISSON : +1 m, 117 près du bord. CRISTAL : +0,76 m, 119 près du bord. CORAIL, ROCHER (Falaises ×4 : +4,4 m), PALMIER décalé de 0,36 m, TRIBUNE, STANDS, ANANAS | formes taillées à la main (`track_decor.gd:252-360`) sur des modèles Kenney rééchelonnés |
| E1 | Les roues passent sous la route | > 5 cm dans 8 % du temps, au pire 13,4 cm (glisse 30 %, freinage 23 %) | le ressort d'une roue délestée s'allonge au-delà du contact (`kart_suspension.gd:113-120`, `kart_spring.gd:66-69`) |
| E2 | La caisse passe sous la route | > 5 cm dans 28 % des glisses et 66 % des têtes-à-queue, au pire 24,9 cm (roues Légères) ; toujours un coin du pare-chocs avant | tangage ±7° et inclinaison de 14° autour d'un pivot au ras du sol (`kart_suspension.gd:196-204`, `kart_visuals.gd:180-194`) |
| E3 | La figure finit sous la route | 22 % des figures tournent encore au toucher ; caisse jusqu'à 78 cm sous la route, sur les tremplins courts | le tonneau pivote au ras du sol et dure 0,45 s (`kart_visuals.gd:186-211`) |
| E4 | Le relief d'etoiles traverse la route | d ≈ 1 510 à 1 605 m : désert 26 cm au-dessus du bitume en médiane, au pire 65 cm | le relief « Desert » déborde sa portion |
| E5 | Le bitume s'affaisse aux changements de dévers | jusqu'à 20 cm sous la courbe en milieu de section, marquages flottants ; écart > 2 cm sur 34 % de circuit_01 | chaque section de 2 m est un quadrilatère tordu, coupé selon une seule diagonale |

**Mesuré sain, à ne pas toucher :**

- les murs de piste (`TrackWall`) collent à leur modèle, écart de 4 cm au 95ᵉ centile ;
- les plis du bitume ne font jamais mur, sur 4 114 passages au ras du bord ;
- les mondes des portails ne se gênent pas.

**Hors de ce plan, relevé pour plus tard :**

- des éléments visibles se traversent : poteaux du portique de départ (29 circuits), façades et masses des tunnels, piliers de portiques ;
- la roue s'enfonce dans les bordures (0,18 % du temps) ;
- l'extrapolation à plat des karts distants en réseau, non mesurée.

### Les bancs

Dossier : `C:\Users\alexa\AppData\Local\Temp\claude\C--Users-alexa-dev-perso-games-karting\0dc79d77-21cc-4aec-b8fc-71d52de054a0\scratchpad\`

| Banc | Mesure | Lancer |
|---|---|---|
| `banc_bords/` | sorties, retours, ras du bord, sur 29 circuits | `bash run_all.sh` puis `python final.py` (`run_types.sh <dir> types=retour` pour les seuls retours) |
| `banc_sol/` | hauteur des roues et de la caisse en course d'IA | `"$GODOT" --headless --fixed-fps 60 --path . -s "<dir>/loader.gd" -- <id> 2 tag=<id>`, puis `python -I analyse.py out/*.csv` |
| `banc_decor/` | collision contre modèle visible | `bash run_all.sh` puis `python aggregate.py` |

### Commandes et pièges du dépôt

```bash
export GODOT="/c/Users/alexa/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
# Un fichier de test :
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<fichier>.gd -gexit
# La campagne (759 tests, 52 scripts, environ 7 min, tout vert au départ) :
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- **`--import` réécrit les fins de ligne** de tous les `.import`. Avant chaque commit, `git diff --ignore-all-space --ignore-cr-at-eol --name-only` montre les vrais changements ; on n'ajoute que ses fichiers, nommément, jamais `git add .`.
- Un nouveau script a besoin de son `.uid` (`"$GODOT" --headless --path . --import` le crée). Le `.uid` est versionné.
- Un fichier de test qui ne compile pas est **sauté en silence** par GUT : on vérifie le nombre de scripts et de tests au résumé.
- Un script lancé par `-s` est compilé avant les autoloads : les bancs passent par un chargeur (voir `tools/essai_circuit.gd`).
- Préfixer les commandes git par `rtk`.

---

## Task 1 : Bords de piste (M1, M2, M3)

**Files :**

| Statut | Fichier |
|---|---|
| Create | `scripts/track/track_talus.gd` (et son `.uid`) |
| Modify | `scripts/track/track.gd` : `_reconstruire`, `_vider` |
| Modify | `scripts/track/features/track_offroad.gd` : `_construire` |
| Test | `tests/test_bords_de_piste.gd` |
| Doc | `docs/outil-circuits.md` |

**Le correctif retenu :**

1. **M1.** Dans `TrackOffroad._construire`, la bande **dessinée** reste à +2 cm, pour qu'elle se voie là où elle recouvre la route. Sa **collision** est une seconde nappe à hauteur 0, au ras du bitume. On garde `TrackFeature._poser(…, solide = false)` pour l'affichage, et on ajoute un `StaticBody3D` dont la forme est `_nappe(c, g, r, 0.0).create_trimesh_shape()`.
2. **M2.** Un talus le long des deux bords de route, partout où un sol réel porte le kart juste au-delà. Il descend en pente douce du bord de la chaussée jusque sous le sol.
   - Le prédicat de pose : `Track.sol_reel(point, d)`, appelé sur `TrackFeature.point(c, d, ±(half_width + 2), 0)`. Il est faux au-dessus du vide, donc **jamais de talus au-dessus du vide** : ce serait un sol invisible.
   - Ni dans un trou (`trou_en(d)`), ni hors course (`hors_course(d)`).
   - Géométrie : du bord, `point(c, d, ±demi, 0)`, à `point(c, d, ±(demi + LARGEUR), -CHUTE)`, avec `CHUTE = 1.2` et `LARGEUR = 4.5` (15°). Il atteint ainsi sous un sol bordé jusqu'à `TrackSol.MARCHE = 1 m` plus bas. Au-delà, le sol ne borde plus la route.
   - **Visible**, avec le matériau du tablier, pour que le kart qui le remonte ne flotte pas au-dessus de rien. Il plonge sous le sol à quelques dizaines de centimètres du bord.
   - Construit par `Track._reconstruire` **après** `element.reconstruire()`, puisque les sols doivent exister pour répondre à `sol_reel`.
   - Nœud nommé (`NOM_TALUS := "Talus"`), retiré par `_vider`.
3. **M3.** La même pente, posée par `TrackOffroad` le long de ses bords **qui ne touchent pas la route** (bord extérieur, et intérieur si la bande est détachée), et en travers de ses deux bouts, partout où `piste().sol_reel` est vrai sous ce bord. La hauteur de départ est celle de la nappe de collision, donc 0.
4. `scripts/track/track_talus.gd` (`class_name TrackTalus`, `RefCounted`, tout en `static`) porte la géométrie commune :
   - `le_long(c, de, sur, lateral, cote, porte: Callable) -> PackedVector3Array` : des triangles le long d'un bord, entre les sections où `porte(d)` est vrai ;
   - `en_travers(c, d, de_lateral, a_lateral, sens, porte: Callable) -> PackedVector3Array` : un bout de bande.

   `Track` et `TrackOffroad` en font un `ArrayMesh` (affichage) et un `ConcavePolygonShape3D` (collision, `backface_collision = true`, couche `Kart.COUCHE_DECOR`). Il n'y a pas de deuxième source de géométrie.

- [ ] **Step 1 : les tests rouges**

  `tests/test_bords_de_piste.gd` monte un anneau de 50 m de rayon, comme `_anneau()` de `tests/test_track.gd`, et un vrai `scenes/kart/kart.tscn`. Le kart est conduit par un `KartInput` de test (plein gaz, sans braquer), branché par `kart.changer_pilote(input)`. On place le kart avec `respawn_at`, puis on fixe `motor.speed`. On compte les contacts `get_slide_collision(i).get_normal().y < 0.6` à chaque image physique : c'est le seuil de `Kart` → `motor.heurter_mur`.

  1. `test_sortir_vers_une_bande_d_herbe_ne_heurte_rien` : bande `TrackOffroad` collée au bord (`decalage = half_width + largeur/2`). Le kart part du bitume à `half_width - 2.5`, cap 35° vers l'extérieur, 15 m/s, pendant 1,5 s. Attendu : `|lateral| > half_width + 1.5` et 0 contact. **Rouge aujourd'hui** (le banc bloque à 8,1 m).
  2. `test_revenir_du_sol_sur_la_route` : `TrackSol` à `altitude = -0.4`. Le kart part du sol à `half_width + 4`, cap 35° vers la route, 12 m/s, pendant 2,5 s. Attendu : `|lateral| < half_width - 1`, hauteur à moins de 5 cm de la chaussée, 0 contact. **Rouge aujourd'hui** (bloqué, ou sous la route).
  3. `test_le_kart_ne_passe_jamais_sous_la_route` : même départ, à chaque image `kart.global_position.y >= hauteur de la chaussée - 0.05` dès que `|lateral| < half_width`. **Rouge aujourd'hui** (−0,48 m mesuré).
  4. `test_pas_de_talus_au_dessus_du_vide` : sans aucun sol, un rayon vers le bas à `half_width + 2` (masque 1) ne touche rien. Vert aujourd'hui, et il doit le rester : c'est le garde-fou du prédicat.
  5. `test_rejoindre_une_bande_depuis_le_sol` : bande de `half_width` à `half_width + 7`, sur un `TrackSol`. Le kart part du sol à `half_width + 10` vers la bande. Attendu : il monte dessus sans contact. **Rouge aujourd'hui.**
  6. `test_entrer_dans_une_bande_par_son_bout` : le kart roule sur le sol, dans l'axe, vers le bout d'une bande détachée de la route. Même attendu. **Rouge aujourd'hui.**

- [ ] **Step 2 : les faire échouer**, avec le message attendu, et noter les nombres (latéral atteint, contacts, hauteur sous la route).
- [ ] **Step 3 : M1**, puis faire passer le test 1.
- [ ] **Step 4 : `TrackTalus` et le talus de route (M2)**, puis faire passer les tests 2 à 4.
- [ ] **Step 5 : les talus de bande (M3)**, puis faire passer les tests 5 et 6.
- [ ] **Step 6 : la campagne entière**, sans régression (`test_sols_reels`, `test_hors_piste`, `test_circuits`, `test_track_features` en premier lieu).
- [ ] **Step 7 : le banc des bords sur les 29 circuits.**

  Attendu :

  | Mesure | Avant | Cible |
  |---|---|---|
  | blocages fantômes au bord d'une bande | 920 | moins de 10 |
  | retours depuis le sol réussis | 44 / 1 297 | au moins 90 % |
  | karts sous la route | 548 | 0 |
  | bords extérieurs et bouts de bande bloquants | 99 + 14 | 0 |

  Rapporter le tableau par circuit.
- [ ] **Step 8 : documenter** dans `docs/outil-circuits.md` : talus et bandes, ce que le circuit pose seul.
- [ ] **Step 9 : commit**

  ```bash
  rtk git add scripts/track/track_talus.gd scripts/track/track_talus.gd.uid scripts/track/track.gd scripts/track/features/track_offroad.gd tests/test_bords_de_piste.gd tests/test_bords_de_piste.gd.uid docs/outil-circuits.md
  rtk git commit -m "fix: les bords de piste se franchissent dans les deux sens"
  ```

---

## Task 2 : Le kart reste sur la route (E1, E2, E3)

**Files :**

| Statut | Fichier |
|---|---|
| Modify | `scripts/kart/kart_suspension.gd` : placement des roues, assiette de la caisse |
| Modify | `scripts/kart/kart_visuals.gd` : `_update_lean`, `_tourner_les_roues`, `_update_taille` |
| Modify, si l'enquête le montre | `scripts/kart/kart_spring.gd` |
| Test | `tests/test_kart_au_sol.gd` |
| Mettre à jour | `tests/test_figures.gd:102-118` : il fige le pivot du tonneau au ras du sol, le défaut même |

**Le correctif retenu :**

1. **E1.** Le **dessin** d'une roue ne descend jamais sous le point où son rayon touche le sol : son centre reste à `point de contact + rayon` au minimum. Le ressort garde sa physique, seule la roue affichée est bornée. Une roue en l'air, sans contact, garde son comportement.
2. **E2.** Après le tangage (suspension) et l'inclinaison (visuels), on calcule le point le plus bas de la caisse **dessinée** dans le repère du kart, à partir de l'AABB des maillages visibles de `Body`, Kenney comme pilote, mise en cache une fois par habillage. Si ce point passe sous sa hauteur au repos, on relève `Body` de l'écart.
   - Une seule fonction, appelée en dernier : `KartVisuals` tourne dans `_process`, la suspension dans la physique. Lire les deux et choisir le bon point d'appel.
   - Elle tient compte du rétrécissement (`_echelle`).
3. **E3.** Le tonneau pivote autour du **centre de la caisse**, plus au ras du sol. Les roues suivent le même pivot (`_tourner_les_roues`), et la même remontée d'E2 s'applique. Au toucher, le tonneau qui reste se termine en accéléré, au moins quatre fois plus vite, au lieu de continuer au sol.

- [ ] **Step 1 : les tests rouges**, dans `tests/test_kart_au_sol.gd`, sur un vrai `kart.tscn` habillé par `ModeleKart.habiller`, posé sur un `StaticBody3D` plat.
  1. `test_une_roue_delestee_ne_passe_pas_sous_le_sol` : kart à 20 m/s, plein braquage pendant 1 s. À chaque image, le point le plus bas de chaque `Jante` reste à 5 mm près au-dessus du sol (rayon vers le bas). **Rouge** : le banc mesure jusqu'à 9,5 cm par délestage seul.
  2. `test_la_caisse_ne_passe_pas_sous_le_sol_en_glisse` : `motor.state = DRIFT`, `drift_dir = ±1`, avec le tangage poussé en piqué (freinage ou tête-à-queue, selon ce qu'expose la suspension). Le point le plus bas de la caisse dessinée reste au-dessus du sol. Les deux sens, et les roues Légères (`roues = 3`). **Rouge** : 24,9 cm mesurés.
  3. `test_une_figure_au_sol_reste_au_dessus_du_sol` : déclencher `kart.figure`, garder le kart au sol, échantillonner tout le tonneau. Caisse et roues au-dessus du sol. **Rouge** : 118 cm en milieu de tonneau.
  4. `test_au_repos_rien_ne_bouge` : à l'arrêt sur le plat, la caisse et les roues gardent la hauteur d'aujourd'hui, à 5 mm près. Garde-fou contre un kart qui flotterait : vert avant, vert après.
- [ ] **Step 2 : les faire échouer**, et noter les nombres.
- [ ] **Step 3 : E1**, puis faire passer le test 1.
- [ ] **Step 4 : E2**, puis faire passer les tests 2 et 4.
- [ ] **Step 5 : E3**, puis faire passer le test 3. Mettre à jour `test_figures.gd` en écrivant dans le test pourquoi le pivot a changé.
- [ ] **Step 6 : la campagne entière** (`test_garage`, `test_figures`, `test_kart_spring`, `test_personnages` en premier lieu).
- [ ] **Step 7 : le banc sol** sur les dix courses du premier passage (circuit_01, ruban_celeste, grand_huit, escalier, etoiles, jardin_champignon, usine_engrenages, station_neiges, saut_temporel, plus circuit_01 en `roues=3`).

  Attendu :

  | Mesure | Avant | Cible |
  |---|---|---|
  | roues à plus d'1 cm sous la route | 37,6 % | moins de 1 % |
  | caisse à plus d'1 cm sous la route | 6,6 % | moins de 1 % |
  | figures à plus de 5 cm sous la route | 20 | 0 |

  Hors bordures, qui n'ont pas de collision et restent hors périmètre.
- [ ] **Step 8 : contrôle visuel.** Des captures en fenêtre (glisse, freinage, figure sur `jardin_champignon`) : la caisse ne doit pas flotter non plus.
- [ ] **Step 9 : commit**

  ```bash
  rtk git add scripts/kart/kart_suspension.gd scripts/kart/kart_visuals.gd tests/test_kart_au_sol.gd tests/test_kart_au_sol.gd.uid tests/test_figures.gd
  rtk git commit -m "fix: ni roue ni caisse ne passent sous la route"
  ```

---

## Task 3 : Les collisions de décor collent au modèle (M4)

**Files :**

| Statut | Fichier |
|---|---|
| Modify | `scripts/track/features/track_decor.gd:252-360` : formes par type |
| Modify, si besoin | `scripts/track/features/kenney_decor.gd` |
| Test | `tests/test_decor_collisions.gd` |

**Le correctif retenu :** à hauteur de kart (0,1 à 0,7 m au-dessus du sol), la forme de chaque type ne dépasse pas son modèle visible de plus de 0,15 m, et ne laisse pas de partie visible pleine sans collision au-delà de 0,15 m.

| Type | Aujourd'hui | Devient |
|---|---|---|
| TENTE | bloc de 6 × 4 × 6 m | ses seuls montants visibles, ou rien si le modèle n'en a pas à cette hauteur (on passe dessous) |
| PANNEAU_PUB | dalle | ses pieds |
| SAPIN, BUISSON, CRISTAL, CORAIL, ANANAS, TRIBUNE, STANDS | gabarits faits main | dimensions tirées du modèle à cette hauteur, échelle de l'instance comprise |
| PALMIER | décalé de 0,36 m | recentré sur le tronc |
| ROCHER | rangée à l'échelle ×4 | l'échelle de la rangée appliquée à la forme comme au modèle |

- [ ] **Step 1 : le test rouge.** Pour chaque type de `TrackDecor` qui a une collision, `tests/test_decor_collisions.gd` construit une instance isolée et compare, à 0,1, 0,4 et 0,7 m, l'étendue de sa collision à celle de son modèle visible.
  - Méthode : celle de `banc_decor/audit.gd`, des rayons horizontaux contre une copie en trimesh des maillages visibles, dans un `World3D` à part.
  - Tolérance 0,15 m.
  - **Rouge aujourd'hui** sur au moins TENTE, PANNEAU_PUB, SAPIN, BUISSON, CRISTAL et PALMIER.
- [ ] **Step 2 : le faire échouer**, et lister les écarts par type.
- [ ] **Step 3 : corriger les formes, type par type**, jusqu'au vert.
- [ ] **Step 4 : la campagne entière** (`test_circuits` : aucun décor solide sur la route).
- [ ] **Step 5 : le banc décor sur les 29 circuits.**
  - Attendu : plus aucun type au-delà de 0,15 m d'excès près du bord.
  - Le banc des bords ne doit gagner aucun « mur visible » de décor là où il n'y en avait pas.
- [ ] **Step 6 : commit**

  ```bash
  rtk git add scripts/track/features/track_decor.gd scripts/track/features/kenney_decor.gd tests/test_decor_collisions.gd tests/test_decor_collisions.gd.uid
  rtk git commit -m "fix: les collisions du decor collent a ce qu on voit"
  ```

---

## Task 4 : Le relief d'etoiles reste sous la route (E4)

**Files :**

| Statut | Fichier |
|---|---|
| Modify | `scripts/track/features/track_terrain.gd` : `_preparer`, `_hauteur`, `_sous_les_autres_routes` |
| Modify, si la cause est de réglage | `scenes/tracks/etoiles.tscn` |
| Test | `tests/test_relief.gd` |

**À établir d'abord :**

- La mesure : sur etoiles, de d ≈ 1 510 à 1 605 m, le relief « Desert » (marge 120) déborde sa portion et passe au-dessus du bitume, de 26 cm en médiane, 65 cm au pire.
- L'hypothèse : `_sous_les_autres_routes` ne voit que les échantillons de la portion du relief. Les routes d'ailleurs sur le tracé ne le plafonnent donc pas.
- Le correctif visé, si l'hypothèse se confirme : le plafond prend **tous** les échantillons de route du circuit à portée, portion ou pas.

- [ ] **Step 1 : le test rouge**, dans `tests/test_relief.gd`, sur la vraie scène `etoiles` : pour d de 1 500 à 1 610 m par pas de 2 m, et des écarts latéraux de -demi à +demi, le relief est sous la chaussée d'au moins `SOUS_LE_BORD`. **Rouge aujourd'hui.**
- [ ] **Step 2 :** le faire échouer, puis confirmer ou infirmer l'hypothèse **avant** de corriger.
- [ ] **Step 3 :** corriger, puis vérifier le vert.
- [ ] **Step 4 :** le même test, étendu aux 29 circuits : tout relief sous toute route.
- [ ] **Step 5 :** la campagne entière.
- [ ] **Step 6 : commit**

  ```bash
  rtk git add scripts/track/features/track_terrain.gd tests/test_relief.gd
  rtk git commit -m "fix: le relief ne perce plus la route hors de sa portion"
  ```

---

## Task 5 : Le bitume suit la courbe aux changements de dévers (E5)

**Files :**

| Statut | Fichier |
|---|---|
| Modify | `scripts/track/track_builder.gd` : `build`, `_section`, et `tablier` s'il partage la découpe |
| Test | `tests/test_track_builder.gd` |

**Le correctif retenu :** une section dont le quadrilatère est tordu (dévers différent à ses deux bouts) est **recoupée en travers**, en bandes de 3 m au plus. L'écart au milieu de la section tombe alors sous 2 cm.

- Une section plate garde ses deux triangles : on ne paie que là où ça se voit.
- La collision suit, puisque c'est le même `build`.
- Coût en triangles, à mesurer et à consigner : `docs/performances.md` fixe le budget.
- Les couleurs de l'arc-en-ciel (`couleurs`) doivent survivre au recoupage.

- [ ] **Step 1 : le test rouge.** Une courbe dont le dévers passe de 11° à 6° sur 10 m. Au milieu de chaque section, la surface du maillage (rayon vers le bas contre son trimesh) est à moins de 2 cm de la chaussée calculée par `TrackCurve` : `position_at` + `right_at` × latéral, à -demi, -demi/2, 0, demi/2 et demi. **Rouge aujourd'hui** (jusqu'à 20 cm).
- [ ] **Step 2 :** le faire échouer, et noter l'écart.
- [ ] **Step 3 :** recouper les sections tordues, puis vérifier le vert. Les tests existants de `test_track_builder.gd` ne doivent pas bouger : normales vers le haut, largeur complète, et le compte de triangles sur une courbe plate.
- [ ] **Step 4 :** la campagne entière, puis le scan de route du banc sol (`-- <id> 1 scan`). Attendu : l'écart de plus de 2 cm passe de 34 % à moins de 1 % sur circuit_01, et sur coeur_terre, echelle_celeste et pic_lacets.
- [ ] **Step 5 :** mesurer le nombre de triangles de route avant et après sur les 29 circuits, et le consigner dans `docs/performances.md`.
- [ ] **Step 6 : commit**

  ```bash
  rtk git add scripts/track/track_builder.gd tests/test_track_builder.gd docs/performances.md
  rtk git commit -m "fix: le bitume ne s affaisse plus aux changements de devers"
  ```

---

## Après les cinq tâches

- [ ] Fusionner les cinq branches. Les fichiers ne se recoupent pas, à `docs/` près.
- [ ] Lancer la campagne entière sur le résultat : nombre de scripts et de tests au résumé.
- [ ] Relancer les trois bancs sur le résultat fusionné, et rapporter les tableaux avant et après.
- [ ] Contrôle visuel en fenêtre, par captures, sur circuit_01, jardin_champignon, etoiles et lune_carnaval.
