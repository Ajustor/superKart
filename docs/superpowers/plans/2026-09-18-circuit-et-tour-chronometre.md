# Circuit et tour chronométré — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pouvoir boucler un tour chronométré sur un vrai circuit, généré depuis une courbe, avec hors-piste et remise en piste.

**Architecture:** Un `Curve3D` tracé à la souris définit l'axe du circuit. `TrackCurve` l'enrobe et en dérive tout le reste par le calcul — échantillonnage, projection, ligne de course, hors-piste — sans dépendre de l'arbre de scènes, exactement comme `KartMotor`. `TrackBuilder` en extrude le maillage et la collision. `RaceProgress` transforme une position en distance cumulée, ce qui donne les tours sans aucun checkpoint à poser.

**Tech Stack:** Godot 4.7.2, GDScript typé, GUT.

**Spec de référence :** `docs/superpowers/specs/2026-09-17-karting-3d-design.md`, §5.

**Un fichier de test qui ne compile pas est silencieusement ignoré par GUT** — observé à la tâche 7 : la suite a annoncé « 70/70, all tests passed » alors qu'un fichier entier venait d'être écarté pour erreur de parsing. C'est exactement pourquoi les attentes de ce plan sont exprimées en nombre de tests gagnés et non en couleur : un vert ne prouve rien, un décompte si.

**Ce que fait vraiment `assert()` ici**, vérifié à la tâche 4 : il journalise une erreur et fait échouer le test GUT qui le déclenche, mais **il n'interrompt pas l'exécution**. En jeu, l'objet fautif est tout de même construit et rendu à l'appelant. C'est une protection de développement, pas une garantie d'exécution — à ne pas confondre avec un arrêt net si un invariant doit vraiment tenir en production.

**Mesuré à la tâche 4**, et utile pour la suite : l'intervalle de bake par défaut d'un `Curve3D` donne 0,27 mm d'erreur de longueur sur un anneau de 314 m — inutile de le baisser. Et `TANGENT_EPSILON = 0.25` ne coûte que 0,006° d'erreur de tangente sur un virage de 5 m de rayon, parce qu'une différence centrée est d'ordre deux. Il ne fond une direction que sur un angle vif véritable, c'est-à-dire un point de contrôle aux poignées de longueur nulle — ce que le générateur de la tâche 8 ne produit pas.

**État de départ :** `main` à 46 tests verts. `KartMotor` est complet et couvre toute la physique horizontale ; `Kart`, `PlayerInput`, `ChaseCamera`, `KartVisuals` et le terrain d'essai existent.

---

## Périmètre

**Dans ce plan :** le circuit 1 généré depuis une courbe, sa collision, la détection hors-piste, la progression et les tours, la remise en piste, un chrono et un HUD minimal. Plus les trois dettes que la revue du plan 1 plaçait avant d'ouvrir celui-ci.

**Hors périmètre, pour le plan suivant :** l'IA, la grille de huit karts, le classement. Ce plan livre un tour en solitaire — c'est délibéré : la génération procédurale est la partie la plus incertaine du projet, et il faut savoir si une piste extrudée depuis une courbe se conduit bien avant d'y poser sept adversaires.

## Convention d'angles

Héritée du plan 1 et **à respecter partout** : le moteur et `TrackCurve` comptent leurs caps à la boussole — **lacet positif = vers la droite**. Godot compte l'inverse. La conversion se fait uniquement dans `kart.gd`, au seul endroit où les deux repères se rencontrent. Un cap produit par `TrackCurve` se compare donc directement à `motor.heading`, sans signe intermédiaire.

Le vecteur avant d'un cap θ vaut `Vector3(sin(θ), 0, -cos(θ))`, et sa droite `Vector3(cos(θ), 0, sin(θ))`.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `scripts/track/track_curve.gd` | Enrobe un `Curve3D` : échantillonnage, projection, hors-piste, ligne de course. Aucune dépendance à la scène |
| `scripts/track/track_builder.gd` | Extrude le ruban de route en `ArrayMesh` |
| `scripts/track/track.gd` | Le nœud `Track` : assemble courbe, maillage, collision |
| `scripts/race/race_progress.gd` | Distance cumulée et comptage des tours. Logique pure |
| `scripts/race/race_timer.gd` | Chrono du tour et meilleur tour. Logique pure |
| `scripts/ui/race_hud.gd` | Tour courant, chrono, meilleur temps |
| `tools/build_track_01.gd` | Génère la courbe du circuit 1 en `.tres` via l'API du moteur |
| `scenes/tracks/track_01.tscn` | Le circuit 1 |
| `scenes/race.tscn` | Scène jouable : circuit, kart, caméra, HUD |

---

### Task 1 : `KartMotor.reset()` plutôt qu'une réallocation

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `scripts/kart/kart.gd`
- Modify: `tests/test_kart_motor.gd`

La revue du plan 1 a relevé que `respawn_at()` remplace l'objet moteur par un neuf. Ça marche aujourd'hui parce que la caméra et les visuels relisent `_kart.motor` à chaque frame — mais la première présentation qui le mettra en cache dans son `_ready()` se détachera en silence, sans erreur et sans test pour l'attraper. Ce plan multiplie les lecteurs du moteur, donc on ferme la classe entière de bug maintenant.

- [ ] **Step 1 : Écrire le test qui échoue**

Ajoute à la fin de `tests/test_kart_motor.gd` :

```gdscript
func test_reset_remet_le_moteur_a_neuf_sans_le_remplacer() -> void:
	_enter_drift(1)
	motor.boost_timer = 1.0
	motor.on_offroad = true
	var avant := motor

	motor.reset(1.5)

	assert_eq(motor, avant, "reset ne doit pas remplacer l'objet moteur")
	assert_eq(motor.state, KartMotor.State.GRIP)
	assert_eq(motor.speed, 0.0)
	assert_eq(motor.boost_timer, 0.0)
	assert_eq(motor.drift_dir, 0)
	assert_eq(motor.drift_charge, 0.0)
	assert_false(motor.on_offroad, "on repart sur la piste")
	assert_almost_eq(motor.velocity_dir, 1.5, 0.001, "le cap demandé est appliqué")
	assert_almost_eq(motor.heading, 1.5, 0.001)
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
export GODOT="/c/Users/alexa/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `reset` n'est pas définie.

- [ ] **Step 3 : Écrire l'implémentation**

Ajoute à la fin de `scripts/kart/kart_motor.gd` :

```gdscript
## Remet le moteur à neuf au cap donné, sans changer d'objet. Les nœuds de
## présentation gardent des références au moteur : le remplacer les
## détacherait en silence, sans erreur et sans test pour l'attraper.
func reset(yaw: float) -> void:
	state = State.GRIP
	speed = 0.0
	velocity_dir = yaw
	heading = yaw
	boost_timer = 0.0
	on_offroad = false
	drift_dir = 0
	drift_charge = 0.0
	drift_angle = 0.0
	hop_timer = 0.0
	_drift_locked_out = false
```

Dans `scripts/kart/kart.gd`, `respawn_at()` devient :

```gdscript
## Remet le kart à un état neutre à la position donnée. Le terrain d'essai
## s'en sert ; la remise en piste du circuit aussi.
func respawn_at(where: Transform3D) -> void:
	global_transform = where
	velocity = Vector3.ZERO
	_vertical = 0.0
	_was_hopping = false
	motor.reset(-where.basis.get_euler().y)
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : `47 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd scripts/kart/kart.gd tests/test_kart_motor.gd && rtk git commit -m "refactor: reset du moteur plutôt que réallocation à la remise en piste"
```

---

### Task 2 : Le test d'indépendance au pas de temps

**Files:**
- Modify: `tests/test_kart_motor.gd`

`KartMotor` est *défini* comme `f(état, commande, delta)` — c'est la thèse de toute l'architecture — et les 50 tests tournent tous à exactement 1/60. C'est la seule propriété que le design revendique et que la suite ne vérifie nulle part. Le correctif de courbure du plan 1 a justement démontré que cette fonction peut héberger une erreur de couplage qui survit à quinze tâches.

- [ ] **Step 1 : Écrire le test qui échoue**

Ajoute à la fin de `tests/test_kart_motor.gd` :

```gdscript
## Rejoue la même seconde de pilotage à trois pas de temps différents et
## renvoie l'état final. Un moteur correctement écrit doit converger vers
## le même résultat, à la précision d'intégration près.
func _simuler(pas: float) -> Dictionary:
	var m := KartMotor.new(KartStats.new())
	var c := KartCommand.new()
	c.throttle = 1.0
	var t := 0.0
	while t < 4.0:
		m.step(c, pas)
		t += pas
	c.steer = 1.0
	c.drift = true
	t = 0.0
	while t < 2.0:
		m.step(c, pas)
		t += pas
	return {"speed": m.speed, "dir": m.velocity_dir, "charge": m.drift_charge}


func test_le_moteur_ne_depend_pas_du_pas_de_temps() -> void:
	var lent := _simuler(1.0 / 30.0)
	var normal := _simuler(1.0 / 60.0)
	var rapide := _simuler(1.0 / 120.0)

	for champ in ["speed", "dir", "charge"]:
		assert_almost_eq(lent[champ], normal[champ], 0.15,
			"%s doit être stable entre 30 et 60 Hz" % champ)
		assert_almost_eq(rapide[champ], normal[champ], 0.15,
			"%s doit être stable entre 120 et 60 Hz" % champ)
```

- [ ] **Step 2 : Lancer les tests**

Attendu : `51 passing`.

Mesures obtenues : écart maximal de 0,053 rad sur `dir` entre 30 et 60 Hz, pour une tolérance de 0,15 — trois fois de marge. À savoir : le champ `speed` ne contribue rien au garde-fou, car `move_toward` à taux constant est exactement intégrable et la vitesse sature de toute façon au plafond. Les dents du test sont dans `dir` et `charge`.

**Si ce test échoue, ne l'ajuste pas.** Rapporte les trois valeurs obtenues pour chaque champ. Un écart réel signifierait que le moteur dépend du pas de temps quelque part, ce qui est un défaut d'architecture et non un problème de tolérance.

- [ ] **Step 3 : Commit**

```bash
rtk git add tests/test_kart_motor.gd && rtk git commit -m "test: le moteur doit donner le même résultat à 30, 60 et 120 Hz"
```

---

### Task 3 : Une poignée du kart vers sa source de commande

**Files:**
- Modify: `scripts/kart/kart_input.gd`
- Modify: `scripts/kart/kart.gd`
- Modify: `scripts/kart/player_input.gd`

L'IA du plan suivant aura besoin de lire la position et la vitesse de son kart. Aujourd'hui `KartInput` n'expose aucune poignée, donc chaque sous-classe improviserait un `get_parent()`. On sanctionne la relation par le contrat plutôt que par la convention. On en profite pour fermer le piège relevé en revue : `PlayerInput` écrase les cinq champs sans jamais appeler `clear()`, donc le jour où un champ sera écrit conditionnellement, la valeur de la frame précédente fuitera en silence.

- [ ] **Step 1 : Écrire la classe de base**

`scripts/kart/kart_input.gd` devient :

```gdscript
class_name KartInput
extends Node

## Source d'intention pour un kart. Les sous-classes remplissent `command`
## dans _fill(). C'est le seul point de variation entre le joueur et l'IA :
## en aval, KartMotor ne sait pas qui lui parle.

## Renseigné par Kart._ready(). Le joueur n'en a pas besoin — le singleton
## Input est global — mais l'IA doit lire la position et la vitesse du kart
## qu'elle pilote, et mieux vaut une poignée au contrat qu'un get_parent()
## improvisé dans chaque sous-classe.
var kart: Kart

var command := KartCommand.new()


## Point d'entrée, volontairement non surchargeable en pratique : il garantit
## qu'aucun champ ne garde la valeur de la frame précédente, même si une
## sous-classe oublie d'en écrire un.
func poll(delta: float) -> KartCommand:
	command.clear()
	_fill(delta)
	return command


## À surcharger. La commande est déjà remise à neuf.
func _fill(_delta: float) -> void:
	pass
```

- [ ] **Step 2 : Adapter la source joueur**

`scripts/kart/player_input.gd` devient :

```gdscript
class_name PlayerInput
extends KartInput

## Lit le clavier et la manette. Aucune allocation : on réutilise
## l'instance de KartCommand héritée de KartInput.


func _fill(_delta: float) -> void:
	command.steer = Input.get_axis(&"steer_left", &"steer_right")
	command.throttle = Input.get_action_strength(&"throttle")
	command.brake = Input.get_action_strength(&"brake")
	command.drift = Input.is_action_pressed(&"drift")
	command.use_item = Input.is_action_just_pressed(&"use_item")
```

- [ ] **Step 3 : Câbler la poignée**

Dans `scripts/kart/kart.gd`, `_ready()` gagne une ligne après la récupération de `_input` :

```gdscript
	_input.kart = self
```

- [ ] **Step 4 : Vérifier**

```bash
"$GODOT" --headless --quit-after 120 scenes/test_ground.tscn
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : chargement propre, `53 passing` — inchangé, aucun test ne touche à l'input.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_input.gd scripts/kart/player_input.gd scripts/kart/kart.gd && rtk git commit -m "refactor: la commande est remise à neuf par la classe de base, et l'input connaît son kart"
```

---

### Task 4 : `TrackCurve` — échantillonnage

**Files:**
- Create: `scripts/track/track_curve.gd`
- Create: `tests/test_track_curve.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

`tests/test_track_curve.gd` :

```gdscript
extends GutTest

var track: TrackCurve


## Un anneau circulaire de rayon 50, parcouru dans le sens horaire vu de
## dessus. Une forme dont on connaît analytiquement toutes les propriétés,
## ce qui permet de tester les formules et non leurs approximations.
func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	# Longueur de poignée d'une approximation de Bézier d'un arc de cercle.
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func before_each() -> void:
	track = TrackCurve.new(_anneau(), 8.0)


func test_la_longueur_approche_le_perimetre() -> void:
	assert_almost_eq(track.length, TAU * 50.0, 1.0,
		"la longueur bakée doit approcher le périmètre du cercle")


func test_le_point_a_zero_est_le_premier_point_de_la_courbe() -> void:
	var p := track.position_at(0.0)
	assert_almost_eq(p.x, 0.0, 0.1)
	assert_almost_eq(p.z, -50.0, 0.1)


func test_la_tangente_est_horizontale_et_unitaire() -> void:
	for d in [0.0, 50.0, 120.0, 250.0]:
		var t := track.tangent_at(d)
		assert_almost_eq(t.y, 0.0, 0.001, "la tangente reste horizontale")
		assert_almost_eq(t.length(), 1.0, 0.001, "la tangente est normalisée")


func test_le_cap_suit_la_convention_boussole() -> void:
	# Au point de départ, la courbe part vers +X : cap de +90° à la boussole.
	assert_almost_eq(track.yaw_at(0.0), PI * 0.5, 0.1,
		"partir vers +X correspond à un cap de +90°")


func test_la_droite_est_perpendiculaire_a_la_tangente() -> void:
	for d in [0.0, 70.0, 200.0]:
		var t := track.tangent_at(d)
		var r := track.right_at(d)
		assert_almost_eq(t.dot(r), 0.0, 0.001, "droite et tangente sont perpendiculaires")
		assert_almost_eq(r.length(), 1.0, 0.001)


func test_la_droite_pointe_vers_l_interieur_de_l_anneau() -> void:
	# L'anneau tourne à droite en permanence, donc son centre est à droite de
	# la marche : c'est le côté intérieur du virage.
	var d := 80.0
	var vers_droite := track.position_at(d) + track.right_at(d) * 10.0
	assert_lt(vers_droite.length(), track.position_at(d).length(),
		"la droite de la marche se rapproche du centre sur un anneau horaire")


func test_la_distance_s_enroule_sur_la_longueur() -> void:
	assert_almost_eq(track.wrap(track.length + 10.0), 10.0, 0.001)
	assert_almost_eq(track.wrap(-10.0), track.length - 10.0, 0.001)
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Attendu : ÉCHEC — `TrackCurve` introuvable.

- [ ] **Step 3 : Écrire l'implémentation**

`scripts/track/track_curve.gd` :

```gdscript
class_name TrackCurve
extends RefCounted

## Enrobe le Curve3D qui définit l'axe d'un circuit et en dérive tout ce dont
## la course a besoin. Comme KartMotor, cette classe ne connaît ni la scène ni
## les nœuds : elle ne fait que du calcul sur une courbe, et se teste donc
## entièrement sans lancer le moteur de rendu.
##
## Les caps qu'elle produit suivent la convention du moteur — lacet positif
## vers la droite — pour se comparer directement à motor.heading.

## Écart utilisé pour dériver la tangente par différence finie, en mètres.
const TANGENT_EPSILON := 0.25

var curve: Curve3D
var half_width: float
var length: float


func _init(track_curve: Curve3D, track_half_width: float) -> void:
	curve = track_curve
	half_width = track_half_width
	length = curve.get_baked_length()


## Ramène une distance quelconque dans [0, length).
##
## Attention : GDScript expose une globale `wrap(valeur, min, max)`, et un
## appel interne non qualifié résout vers elle plutôt que vers cette
## méthode. Depuis l'intérieur de la classe, écrire `self.wrap(...)`.
## L'échec est une erreur de parsing, donc bruyant — mais déroutant.
func wrap(distance: float) -> float:
	return fposmod(distance, length)


func position_at(distance: float) -> Vector3:
	return curve.sample_baked(self.wrap(distance))


## Dérivée par différence finie plutôt que par sample_baked_with_rotation :
## on ne veut que le cap horizontal, et la différence finie ne dépend pas
## du tilt ni de la version de l'API.
func tangent_at(distance: float) -> Vector3:
	var avant := position_at(distance + TANGENT_EPSILON)
	var arriere := position_at(distance - TANGENT_EPSILON)
	var t := avant - arriere
	t.y = 0.0
	return t.normalized()


## Cap à la boussole : positif vers la droite, comme dans KartMotor.
func yaw_at(distance: float) -> float:
	var t := tangent_at(distance)
	return atan2(t.x, -t.z)


func right_at(distance: float) -> Vector3:
	var t := tangent_at(distance)
	return Vector3(-t.z, 0.0, t.x)
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : `60 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/track/track_curve.gd tests/test_track_curve.gd && rtk git commit -m "feat: échantillonnage d'un axe de circuit"
```

---

### Task 5 : `TrackCurve` — projection et hors-piste

**Files:**
- Modify: `scripts/track/track_curve.gd`
- Modify: `tests/test_track_curve.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à `tests/test_track_curve.gd` :

```gdscript
func test_un_point_sur_l_axe_se_projette_sur_lui_meme() -> void:
	for d in [0.0, 60.0, 180.0]:
		var p := track.position_at(d)
		assert_almost_eq(track.distance_of(p), d, 1.0,
			"la projection doit retrouver la distance d'origine")


func test_l_ecart_lateral_est_signe() -> void:
	var d := 90.0
	var axe := track.position_at(d)
	var droite := track.right_at(d)
	assert_almost_eq(track.lateral_offset(axe + droite * 5.0), 5.0, 0.3,
		"à droite de l'axe, l'écart est positif")
	assert_almost_eq(track.lateral_offset(axe - droite * 5.0), -5.0, 0.3,
		"à gauche, il est négatif")


func test_l_ecart_lateral_est_nul_sur_l_axe() -> void:
	assert_almost_eq(track.lateral_offset(track.position_at(140.0)), 0.0, 0.3)


func test_le_hors_piste_se_declenche_au_dela_de_la_demi_largeur() -> void:
	var d := 40.0
	var axe := track.position_at(d)
	var droite := track.right_at(d)
	assert_false(track.is_off_track(axe), "l'axe est sur la piste")
	assert_false(track.is_off_track(axe + droite * (track.half_width - 1.0)),
		"juste à l'intérieur du bord, on est encore sur la piste")
	assert_true(track.is_off_track(axe + droite * (track.half_width + 1.0)),
		"au-delà du bord, on est hors-piste")
	assert_true(track.is_off_track(axe - droite * (track.half_width + 1.0)),
		"des deux côtés")


func test_la_hauteur_n_influence_pas_le_hors_piste() -> void:
	var haut := track.position_at(20.0) + Vector3.UP * 30.0
	assert_false(track.is_off_track(haut),
		"sauter ne doit pas compter comme une sortie de piste")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Attendu : ÉCHEC — `distance_of` n'est pas définie.

- [ ] **Step 3 : Écrire l'implémentation**

Ajoute à `scripts/track/track_curve.gd` :

```gdscript
## Distance le long de l'axe du point de la courbe le plus proche.
func distance_of(point: Vector3) -> float:
	return curve.get_closest_offset(point)


## Écart signé à l'axe, positif à droite de la marche. La composante verticale
## est ignorée : un kart en l'air n'est pas hors-piste.
func lateral_offset(point: Vector3) -> float:
	var d := distance_of(point)
	var vers_point := point - position_at(d)
	vers_point.y = 0.0
	return vers_point.dot(right_at(d))


func is_off_track(point: Vector3) -> bool:
	return absf(lateral_offset(point)) > half_width
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : **cinq tests de plus** qu'avant cette tâche. Aucun test existant ne doit disparaître : c'est le décompte qui le vérifie, pas la couleur.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/track/track_curve.gd tests/test_track_curve.gd && rtk git commit -m "feat: projection sur l'axe et détection du hors-piste"
```

---

### Task 6 : `TrackCurve` — ligne de course

**Files:**
- Modify: `scripts/track/track_curve.gd`
- Modify: `tests/test_track_curve.gd`

Le spec veut une ligne de course qui « mord l'intérieur des virages, là où un bon pilote place son kart ». On la dérive de la courbure locale plutôt que de la tracer à la main : elle s'adapte alors toute seule quand on déplace un point de contrôle.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à `tests/test_track_curve.gd` :

```gdscript
func test_la_ligne_de_course_mord_l_interieur_d_un_virage() -> void:
	# L'anneau tourne à droite en permanence, donc l'intérieur est à droite
	# partout, et la ligne doit s'y décaler sur tout le tour.
	for d in [0.0, 80.0, 160.0, 240.0]:
		var ecart := track.lateral_offset(track.racing_line_at(d))
		assert_gt(ecart, 1.0, "la ligne se décale vers l'intérieur à %f" % d)


func test_la_ligne_de_course_reste_sur_la_piste() -> void:
	for i in 40:
		var d := track.length * float(i) / 40.0
		assert_false(track.is_off_track(track.racing_line_at(d)),
			"la ligne de course ne doit jamais sortir de la piste")


func test_la_ligne_de_course_suit_une_ligne_droite() -> void:
	var droite := Curve3D.new()
	droite.add_point(Vector3(0, 0, 0))
	droite.add_point(Vector3(0, 0, -100))
	droite.add_point(Vector3(0, 0, -200))
	var plate := TrackCurve.new(droite, 8.0)
	assert_almost_eq(plate.lateral_offset(plate.racing_line_at(100.0)), 0.0, 0.5,
		"sans courbure, la ligne de course reste sur l'axe")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Attendu : ÉCHEC — `racing_line_at` n'est pas définie.

- [ ] **Step 3 : Écrire l'implémentation**

Ajoute à `scripts/track/track_curve.gd`, sous les constantes :

```gdscript
## Distance de part et d'autre du point courant pour mesurer la courbure.
const CURVATURE_SAMPLE := 10.0

## Fraction de la demi-largeur que la ligne de course peut mordre. En deçà
## de 1.0 pour qu'elle reste sur le bitume et non sur le bord.
const RACING_LINE_BITE := 0.7
```

et à la fin du fichier :

```gdscript
## L'axe décalé vers l'intérieur du virage, proportionnellement à la courbure
## locale. Dérivée plutôt que tracée à la main : déplacer un point de contrôle
## déplace la ligne de course avec lui, sans rien à remettre à jour.
func racing_line_at(distance: float) -> Vector3:
	var avant := yaw_at(distance + CURVATURE_SAMPLE)
	var arriere := yaw_at(distance - CURVATURE_SAMPLE)
	# Positif = le circuit tourne à droite ici, donc l'intérieur est à droite.
	var virage := wrapf(avant - arriere, -PI, PI)
	var mordant := clampf(virage / (PI * 0.25), -1.0, 1.0)
	return position_at(distance) + right_at(distance) * mordant * half_width * RACING_LINE_BITE
```

**Limite connue de la méthode** : deux virages opposés séparés de moins d'une vingtaine de mètres tombent ensemble dans la fenêtre de mesure et s'annulent partiellement. Sur une chicane serrée, la ligne resterait donc proche de l'axe là où un pilote traverserait franchement d'un bord à l'autre. C'est le prix d'une fenêtre symétrique à largeur fixe. Si le tracé finit par en comporter, les deux issues sont de réduire `CURVATURE_SAMPLE` ou de passer à une intégrale de courbure locale.

La fenêtre étant symétrique, la ligne entre aussi dans le virage une dizaine de mètres trop tôt et en ressort autant trop tard, là où un pilote braque tôt et débourre tard. Simplification assumée pour une IA d'arcade, à revoir seulement si le plan de l'IA veut un apex retardé perceptible.

**Calibrage mesuré** : sur l'anneau de 50 m la ligne mord 2,85 m, soit 51 % du maximum ; sur un anneau de 10 m elle sature à 100 %. Le diviseur `PI * 0.25` place donc la morsure complète autour d'un rayon de 10 m, et tout virage plus serré obtient la même correction — il n'y a pas de discrimination en deçà. La ligne est continue au point d'enroulement.

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : **trois tests de plus** qu'avant cette tâche. Aucun test existant ne doit disparaître : c'est le décompte qui le vérifie, pas la couleur.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/track/track_curve.gd tests/test_track_curve.gd && rtk git commit -m "feat: ligne de course dérivée de la courbure"
```

---

### Task 7 : `TrackBuilder` — le ruban de route

**Files:**
- Create: `scripts/track/track_builder.gd`

- [ ] **Step 1 : Écrire le générateur**

`scripts/track/track_builder.gd` :

```gdscript
class_name TrackBuilder

## Extrude un ruban de route le long d'un TrackCurve. Le maillage produit sert
## à la fois à l'affichage et, converti en trimesh, à la collision.


## Découpe la courbe en segments d'environ `segment_length` mètres et relie
## chaque section à la suivante par deux triangles.
static func build(track: TrackCurve, segment_length: float = 2.0) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sections := maxi(int(track.length / segment_length), 8)
	var pas := track.length / float(sections)

	for i in sections:
		var d0 := pas * float(i)
		var d1 := pas * float(i + 1)
		var gauche0 := track.position_at(d0) - track.right_at(d0) * track.half_width
		var droite0 := track.position_at(d0) + track.right_at(d0) * track.half_width
		var gauche1 := track.position_at(d1) - track.right_at(d1) * track.half_width
		var droite1 := track.position_at(d1) + track.right_at(d1) * track.half_width

		outil.add_vertex(gauche0)
		outil.add_vertex(gauche1)
		outil.add_vertex(droite0)

		outil.add_vertex(droite0)
		outil.add_vertex(gauche1)
		outil.add_vertex(droite1)

	outil.generate_normals()
	return outil.commit()
```

- [ ] **Step 2 : Écrire les tests**

`tests/test_track_builder.gd`. **L'orientation des faces est testable en headless**, contrairement à ce que j'ai cru en écrivant ce plan : `generate_normals()` dérive les normales de l'ordre des sommets, donc un ordre inversé produit des normales qui pointent vers le bas, et ça se lit dans le maillage.

```gdscript
extends GutTest

var track: TrackCurve


func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func before_each() -> void:
	track = TrackCurve.new(_anneau(), 8.0)


func test_les_normales_pointent_vers_le_haut() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var normales: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normales.size(), 0, "le maillage doit porter des normales")
	for n in normales:
		assert_gt(n.y, 0.9,
			"une normale vers le bas trahit un ordre de sommets inversé")


func test_chaque_section_donne_deux_triangles() -> void:
	var maillage := TrackBuilder.build(track, 10.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sections := maxi(int(track.length / 10.0), 8)
	assert_eq(sommets.size(), sections * 6,
		"deux triangles de trois sommets par section")


func test_le_ruban_couvre_toute_la_largeur() -> void:
	var maillage := TrackBuilder.build(track, 5.0)
	var sommets: PackedVector3Array = maillage.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ecart_max := 0.0
	for v in sommets:
		ecart_max = maxf(ecart_max, absf(track.lateral_offset(v)))
	assert_almost_eq(ecart_max, track.half_width, 0.3,
		"les bords du ruban tombent sur la demi-largeur")
```

- [ ] **Step 3 : Lancer les tests**

Attendu : **trois tests de plus** qu'avant cette tâche. Aucun test existant ne doit disparaître.

- [ ] **Step 4 : Commit**

```bash
rtk git add scripts/track/track_builder.gd tests/test_track_builder.gd && rtk git commit -m "feat: extrusion du ruban de route"
```

---

### Task 8 : Le circuit 1

**Files:**
- Create: `tools/build_track_01.gd`
- Create: `scripts/track/track.gd`
- Create: `scenes/tracks/track_01.tscn`

Écrire les poignées de Bézier d'une courbe fermée à la main est fragile. On fait générer la ressource par le moteur lui-même, comme pour l'input map du plan 1 : le format est alors juste par construction, et la courbe reste éditable à la souris dans l'éditeur ensuite.

- [ ] **Step 1 : Écrire le générateur de courbe**

`tools/build_track_01.gd` :

```gdscript
extends SceneTree

## Génère la courbe du circuit 1 et l'enregistre en ressource.
## Lancer une seule fois :
##   godot --headless --script tools/build_track_01.gd
## La courbe reste ensuite éditable à la souris dans l'éditeur.

const SORTIE := "res://resources/tracks/track_01_curve.tres"

## Circuit côtier : une boucle large et rapide, avec deux virages serrés pour
## donner au dérapage de quoi s'exprimer. Les points sont donnés dans le sens
## de la marche ; les poignées sont calculées pour lisser le tout.
const POINTS: Array[Vector3] = [
	Vector3(0, 0, -120),
	Vector3(90, 0, -110),
	Vector3(140, 0, -40),
	Vector3(120, 0, 40),
	Vector3(40, 0, 60),
	Vector3(-20, 0, 30),
	Vector3(-80, 0, 50),
	Vector3(-130, 0, 10),
	Vector3(-110, 0, -70),
	Vector3(-50, 0, -120),
]


func _init() -> void:
	var courbe := Curve3D.new()
	var n := POINTS.size()
	for i in n:
		var precedent := POINTS[(i - 1 + n) % n]
		var suivant := POINTS[(i + 1) % n]
		# Poignées façon Catmull-Rom : la tangente en un point suit la corde
		# entre ses deux voisins, ce qui donne une boucle lisse et fermée.
		var tangente := (suivant - precedent) / 6.0
		courbe.add_point(POINTS[i], -tangente, tangente)
	# On referme explicitement en répétant le premier point.
	courbe.add_point(POINTS[0], -courbe.get_point_out(0), courbe.get_point_out(0))

	DirAccess.make_dir_recursive_absolute("res://resources/tracks")
	var err := ResourceSaver.save(courbe, SORTIE)
	if err != OK:
		printerr("échec de l'écriture de la courbe : %d" % err)
		quit(1)
		return
	print("circuit 1 écrit, longueur %.1f m" % courbe.get_baked_length())
	quit()
```

- [ ] **Step 2 : Générer la courbe**

```bash
"$GODOT" --headless --script tools/build_track_01.gd
```

Attendu : `circuit 1 écrit, longueur ...` avec une longueur de l'ordre de 700 à 900 m.

- [ ] **Step 3 : Écrire le nœud de circuit**

`scripts/track/track.gd` :

```gdscript
class_name Track
extends Node3D

## Assemble un circuit : la courbe qui le définit, le maillage extrudé et la
## collision. Tout est construit au chargement, donc modifier la courbe suffit
## à redéfinir la piste, sa collision et la trajectoire de l'IA d'un seul geste.

@export var curve: Curve3D
@export var half_width: float = 9.0
@export var segment_length: float = 2.0
@export var road_color: Color = Color(0.36, 0.38, 0.42)

var track_curve: TrackCurve


func _ready() -> void:
	assert(curve != null, "un Track doit avoir une courbe")
	track_curve = TrackCurve.new(curve, half_width)

	var maillage := TrackBuilder.build(track_curve, segment_length)

	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = road_color
	maillage.surface_set_material(0, materiau)

	var affichage := MeshInstance3D.new()
	affichage.name = "RoadMesh"
	affichage.mesh = maillage
	add_child(affichage)

	var corps := StaticBody3D.new()
	corps.name = "RoadBody"
	var forme := CollisionShape3D.new()
	forme.shape = maillage.create_trimesh_shape()
	corps.add_child(forme)
	add_child(corps)


## Transformée de départ, sur la ligne de course, orientée dans le sens de la
## marche. Sert au placement initial comme aux remises en piste.
func spawn_at(distance: float) -> Transform3D:
	var position := track_curve.racing_line_at(distance) + Vector3.UP * 1.0
	var lacet := track_curve.yaw_at(distance)
	# Le circuit compte ses caps à la boussole, Godot à l'envers.
	return Transform3D(Basis(Vector3.UP, -lacet), position)
```

- [ ] **Step 4 : Écrire la scène de circuit**

`scenes/tracks/track_01.tscn` :

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/track/track.gd" id="1_track"]
[ext_resource type="Curve3D" path="res://resources/tracks/track_01_curve.tres" id="2_curve"]

[node name="Track" type="Node3D"]
script = ExtResource("1_track")
curve = ExtResource("2_curve")
```

- [ ] **Step 5 : Vérifier**

```bash
"$GODOT" --headless --quit-after 60 scenes/tracks/track_01.tscn
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : chargement sans ligne `ERROR`, et **le même nombre de tests qu'avant** — cette tâche n'en ajoute aucun.

- [ ] **Step 6 : Commit**

```bash
rtk git add tools/build_track_01.gd scripts/track/track.gd scenes/tracks/track_01.tscn resources/tracks && rtk git commit -m "feat: le circuit 1, généré depuis sa courbe"
```

---

### Task 9 : `RaceProgress` — distance cumulée et tours

**Files:**
- Create: `scripts/race/race_progress.gd`
- Create: `tests/test_race_progress.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

`tests/test_race_progress.gd` :

```gdscript
extends GutTest

var track: TrackCurve
var progress: RaceProgress


func _anneau(rayon: float = 50.0, points: int = 16) -> Curve3D:
	var c := Curve3D.new()
	var pas := TAU / float(points)
	var poignee := rayon * (4.0 / 3.0) * tan(pas / 4.0)
	for i in points:
		var a := pas * float(i)
		var p := Vector3(sin(a) * rayon, 0.0, -cos(a) * rayon)
		var t := Vector3(cos(a), 0.0, sin(a)) * poignee
		c.add_point(p, -t, t)
	c.add_point(c.get_point_position(0), -c.get_point_out(0), c.get_point_out(0))
	return c


func before_each() -> void:
	track = TrackCurve.new(_anneau(), 8.0)
	progress = RaceProgress.new(track)


## Déplace le kart le long de l'axe par petits pas, comme le ferait un vrai
## tour : la détection de passage de ligne repose sur la continuité.
##
## L'aide travaille en compteur kilométrique, pas en coordonnée enroulée :
## pour franchir la ligne vers l'avant on vise `length + 10`, pas `10`, sans
## quoi elle recule sur presque tout le tour au lieu d'avancer de quinze
## mètres.
func _parcourir(de: float, vers: float, pas: float = 5.0) -> void:
	var d := de
	while absf(vers - d) > pas:
		d += pas * signf(vers - d)
		progress.update(track.position_at(d))
	progress.update(track.position_at(vers))


func test_au_depart_on_est_au_tour_zero() -> void:
	progress.update(track.position_at(0.0))
	assert_eq(progress.lap, 0)
	assert_almost_eq(progress.total, 0.0, 1.0)


func test_avancer_augmente_la_distance_cumulee() -> void:
	_parcourir(0.0, 120.0)
	assert_almost_eq(progress.total, 120.0, 2.0)
	assert_eq(progress.lap, 0, "on n'a pas encore bouclé")


func test_boucler_incremente_le_tour() -> void:
	_parcourir(0.0, track.length - 5.0)
	assert_eq(progress.lap, 0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	assert_eq(progress.lap, 1, "franchir la ligne compte un tour")
	assert_almost_eq(progress.total, track.length + 10.0, 3.0)


func test_reculer_decremente_la_distance() -> void:
	_parcourir(0.0, 100.0)
	var avant := progress.total
	_parcourir(100.0, 60.0)
	assert_lt(progress.total, avant, "reculer réduit la progression")


func test_repasser_la_ligne_a_l_envers_annule_le_tour() -> void:
	_parcourir(0.0, track.length - 5.0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	assert_eq(progress.lap, 1)
	_parcourir(10.0, -10.0)
	assert_eq(progress.lap, 0,
		"revenir en arrière par la ligne doit reprendre le tour")


func test_deux_tours_complets() -> void:
	_parcourir(0.0, track.length - 5.0)
	_parcourir(track.length - 5.0, track.length + 10.0)
	_parcourir(track.length + 10.0, 2.0 * track.length - 5.0)
	_parcourir(2.0 * track.length - 5.0, 2.0 * track.length + 10.0)
	assert_eq(progress.lap, 2)
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Attendu : ÉCHEC — `RaceProgress` introuvable.

- [ ] **Step 3 : Écrire l'implémentation**

`scripts/race/race_progress.gd` :

```gdscript
class_name RaceProgress
extends RefCounted

## Transforme une position en progression de course. Le spec a renoncé aux
## checkpoints posés à la main : une distance cumulée le long de l'axe suffit,
## elle augmente en avançant et diminue en reculant, donc faire demi-tour ne
## permet pas de gagner un tour.
##
## Comme TrackCurve et KartMotor, cette classe ne connaît ni la scène ni les
## nœuds : on lui donne un point, elle met son état à jour.

var track: TrackCurve

var lap: int = 0
var distance: float = 0.0   ## position le long de l'axe, dans [0, length)
var total: float = 0.0      ## distance cumulée depuis le départ, signée

var _demarre: bool = false


func _init(track_curve: TrackCurve) -> void:
	track = track_curve


func update(point: Vector3) -> void:
	var d := track.distance_of(point)

	if not _demarre:
		_demarre = true
		distance = d
		total = d
		return

	# Le déplacement réel sur une boucle est le chemin le plus court, pas la
	# différence brute des coordonnées : sans ça, deux centimètres de
	# tremblement au-dessus de la ligne se lisent comme un tour complet, et le
	# compteur oscille pendant que le kart attend le départ, immobile.
	total += wrapf(d - distance, -track.length * 0.5, track.length * 0.5)
	distance = d

	# Un kart qui recule avant même d'être parti reste au tour zéro : la
	# distance cumulée peut devenir négative, le numéro de tour non.
	lap = maxi(floori(total / track.length), 0)
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : **six tests de plus** qu'avant cette tâche. Aucun test existant ne doit disparaître : c'est le décompte qui le vérifie, pas la couleur.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/race/race_progress.gd tests/test_race_progress.gd && rtk git commit -m "feat: progression continue et comptage des tours"
```

---

### Task 10 : Le chrono

**Files:**
- Create: `scripts/race/race_timer.gd`
- Create: `tests/test_race_timer.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

`tests/test_race_timer.gd` :

```gdscript
extends GutTest

var chrono: RaceTimer


func before_each() -> void:
	chrono = RaceTimer.new()


func test_au_depart_tout_est_a_zero() -> void:
	assert_eq(chrono.current, 0.0)
	assert_eq(chrono.best, 0.0)
	assert_false(chrono.has_best, "aucun tour bouclé, aucun record")


func test_le_temps_courant_avance() -> void:
	chrono.advance(1.5)
	chrono.advance(0.5)
	assert_almost_eq(chrono.current, 2.0, 0.001)


func test_boucler_un_tour_fige_le_record_et_repart_a_zero() -> void:
	chrono.advance(42.0)
	chrono.complete_lap()
	assert_true(chrono.has_best)
	assert_almost_eq(chrono.best, 42.0, 0.001)
	assert_eq(chrono.current, 0.0, "le tour suivant repart de zéro")


func test_seul_un_meilleur_temps_remplace_le_record() -> void:
	chrono.advance(42.0)
	chrono.complete_lap()
	chrono.advance(50.0)
	chrono.complete_lap()
	assert_almost_eq(chrono.best, 42.0, 0.001, "un tour plus lent ne bat pas le record")
	chrono.advance(38.0)
	chrono.complete_lap()
	assert_almost_eq(chrono.best, 38.0, 0.001, "un tour plus rapide le bat")


func test_le_formatage_est_lisible() -> void:
	assert_eq(RaceTimer.format(0.0), "0:00.000")
	assert_eq(RaceTimer.format(42.5), "0:42.500")
	assert_eq(RaceTimer.format(83.25), "1:23.250")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

Attendu : ÉCHEC — `RaceTimer` introuvable.

- [ ] **Step 3 : Écrire l'implémentation**

`scripts/race/race_timer.gd` :

```gdscript
class_name RaceTimer
extends RefCounted

## Chrono du tour en cours et meilleur tour. Ne lit aucune horloge : on lui
## donne le temps écoulé, ce qui le rend testable et indépendant du framerate.

var current: float = 0.0
var best: float = 0.0
var has_best: bool = false


func advance(delta: float) -> void:
	current += delta


func complete_lap() -> void:
	if not has_best or current < best:
		best = current
		has_best = true
	current = 0.0


## Minutes:secondes.millisecondes, la forme attendue sur un chrono de course.
##
## On arrondit au millième avant de découper. Calculer les minutes sur la
## partie entière puis arrondir le reste séparément fige les minutes trop
## tôt : un temps à moins d'un millième d'une minute pleine s'affichait
## 0:60.000 au lieu de 1:00.000.
##
## Un temps négatif n'existe pas sur un chrono ; on l'écrase plutôt que de
## montrer 0:-5.000 si un appelant nous passe une valeur qui n'en est pas un.
static func format(seconds: float) -> String:
	var millisecondes := roundi(maxf(seconds, 0.0) * 1000.0)
	var minutes := millisecondes / 60000
	var reste := millisecondes % 60000
	return "%d:%02d.%03d" % [minutes, reste / 1000, reste % 1000]
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

Attendu : **cinq tests de plus** qu'avant cette tâche. Aucun test existant ne doit disparaître : c'est le décompte qui le vérifie, pas la couleur.

À vérifier dans la revue de la tâche 11 : `complete_lap()` appelé deux fois sans `advance()` entre les deux enregistre un tour de zéro seconde, donc un record imbattable. Inatteignable sous le pilotage normal — le compteur de tours ne monte que d'une unité par image — mais une boucle qui rattraperait plusieurs tours d'un coup après une téléportation le déclencherait. Le garde-fou appartient à l'appelant, pas au chrono.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/race/race_timer.gd tests/test_race_timer.gd && rtk git commit -m "feat: chrono du tour et meilleur temps"
```

---

### Task 11 : Le câblage du kart au circuit

**Files:**
- Create: `scripts/race/race_session.gd`
- Modify: `scripts/kart/kart.gd`

Le kart n'a aucune raison de connaître le circuit : c'est la session de course qui les met en rapport. Elle lit la position du kart, met à jour sa progression, lui dit s'il est hors-piste et le remet en piste s'il tombe.

- [ ] **Step 1 : Exposer le hors-piste sur le kart**

`Kart` pilote déjà `motor.on_offroad`, mais rien ne l'alimente. Ajoute cette méthode à la fin de `scripts/kart/kart.gd` :

```gdscript
## Renseigné de l'extérieur par la session de course : le kart ne connaît pas
## le circuit, et le moteur encore moins.
func set_offroad(value: bool) -> void:
	motor.on_offroad = value
```

- [ ] **Step 2 : Écrire la session**

`scripts/race/race_session.gd` :

```gdscript
class_name RaceSession
extends Node

## Met le kart et le circuit en rapport. Le kart ignore le circuit, le circuit
## ignore le kart : c'est ici et nulle part ailleurs que les deux se parlent.

const FLOOR_LIMIT := -10.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

@export var track_path: NodePath
@export var kart_path: NodePath
@export var lap_count: int = 3

var progress: RaceProgress
var timer := RaceTimer.new()
var finished: bool = false

var _track: Track
var _kart: Kart


func _ready() -> void:
	_track = get_node(track_path) as Track
	_kart = get_node(kart_path) as Kart
	assert(_track != null, "track_path doit pointer vers un Track")
	assert(_kart != null, "kart_path doit pointer vers un Kart")

	progress = RaceProgress.new(_track.track_curve)
	_kart.respawn_at(_track.spawn_at(0.0))
	progress.update(_kart.global_position)


func _physics_process(delta: float) -> void:
	if finished:
		return

	var tours_avant := progress.lap
	progress.update(_kart.global_position)
	timer.advance(delta)

	if progress.lap > tours_avant:
		timer.complete_lap()
		if progress.lap >= lap_count:
			finished = true
			return

	# Une seule projection par image : is_off_track la referait entièrement,
	# et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(_kart.global_position))
	_kart.set_offroad(ecart > _track.half_width)

	if _kart.global_position.y < FLOOR_LIMIT or ecart > _track.half_width + OFF_TRACK_RESPAWN_MARGIN:
		_kart.respawn_at(_track.spawn_at(progress.distance))
```

- [ ] **Step 3 : Vérifier que les scripts compilent**

```bash
"$GODOT" --headless --check-only --script scripts/race/race_session.gd
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : compilation propre et **le même nombre de tests qu'avant** — cette tâche n'en ajoute aucun.

- [ ] **Step 4 : Commit**

```bash
rtk git add scripts/race/race_session.gd scripts/kart/kart.gd && rtk git commit -m "feat: la session met le kart et le circuit en rapport"
```

**Note sur la marge de remise en piste.** Sortir de la piste ne remet pas en piste immédiatement : on laisse trois mètres au-delà du bord, pour qu'une trajectoire un peu large soit pénalisée par le hors-piste sans être interrompue. C'est un réglage de ressenti, à revoir à la tâche 13.

---

### Task 11bis : Le tour fantôme du départ

**Files:**
- Modify: `scripts/race/race_progress.gd`
- Modify: `scripts/race/race_session.gd`
- Test: `tests/test_race_progress.gd`

Deux défauts découverts en câblant la tâche 11, tous deux dans des couches déjà réputées testées. Le premier rend chaque course fausse.

**Le tour fantôme.** `RaceSession._ready()` pose le kart avec `spawn_at(0.0)` puis demande à `RaceProgress` de retrouver sa distance *en la reprojetant*. Or `spawn_at` ne place pas le kart sur l'axe mais sur la **ligne de course**, décalée latéralement ; et à la distance 0, ce point décalé se projette 0,7 mm **avant** la ligne. Mesuré sur `track_01` :

```
longueur                    = 768.07800
distance_of(position_at(0)) =   0.00000     <- l'axe, net
distance_of(spawn_at(0))    = 768.07727     <- la ligne de course, de l'autre côté
```

`update()` amorce alors `total = 768.077`. Cinq centimètres plus loin, `total` franchit une longueur et `lap` passe à 1. Mesuré : **le tour 1 tombe après 5 cm sur 768 m.** Une course de trois tours n'en demande donc que deux, et `complete_lap()` enregistre d'entrée un meilleur temps de quelques millisecondes que rien ne battra jamais.

Aucun des 88 tests ne pouvait le voir : ils tournent tous sur un anneau parfait, dont la projection au point 0 vaut exactement 0. La géométrie de test était trop propre pour reproduire le cas.

**La correction va plus loin que la couture.** Le vrai tort est que la session *sait* à quelle distance elle a posé le kart, et jette cette information pour la redeviner par projection — précisément à l'endroit où la projection est ambiguë. On la lui donne. Et tant qu'à toucher à `total`, on le rend **relatif au départ** : il devient littéralement « distance parcourue depuis le départ ». C'est ce que le classement doit trier (§5 du spec), et c'est ce qui rendra la grille décalée du plan 3 équitable — sinon le kart placé 20 m avant la ligne bouclerait son premier tour en 20 m.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute ces deux tests à la fin de `tests/test_race_progress.gd` :

```gdscript
func test_naitre_juste_avant_la_ligne_ne_donne_pas_un_tour() -> void:
	# Le kart est posé un millimètre avant la ligne — ce que fait spawn_at dès
	# que la ligne de course est décalée par rapport à l'axe. Avancer de cinq
	# centimètres ne boucle pas un tour de 314 m.
	var p := RaceProgress.new(track, 0.0)
	p.update(track.position_at(track.length - 0.001))
	assert_eq(p.lap, 0, "naître derrière la ligne ne compte pas un tour")
	p.update(track.position_at(0.05))
	assert_eq(p.lap, 0, "franchir la ligne au premier centimètre non plus")


func test_le_vrai_circuit_ne_boucle_pas_au_depart() -> void:
	# Le cas réel, sur la géométrie livrée : l'anneau des autres tests projette
	# trop proprement pour reproduire la couture.
	var courbe: Curve3D = load("res://resources/tracks/track_01_curve.tres")
	var piste := TrackCurve.new(courbe, 9.0)
	var p := RaceProgress.new(piste, 0.0)
	p.update(piste.racing_line_at(0.0) + Vector3.UP * 0.1)
	p.update(piste.racing_line_at(0.5) + Vector3.UP * 0.1)
	assert_eq(p.lap, 0, "un demi-mètre depuis la grille ne boucle pas 768 m")
	assert_almost_eq(p.total, 0.5, 0.2, "et la distance parcourue vaut ce qu'on a roulé")
```

Puis remplace, dans `before_each` et partout ailleurs dans ce fichier, `RaceProgress.new(track)` par `RaceProgress.new(track, 0.0)`.

- [ ] **Step 2 : Lancer et vérifier l'échec**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `RaceProgress.new()` prend un argument de trop tant que l'étape 3 n'est pas faite. Cet échec-là ne prouve rien : il dit seulement que la signature a changé.

**Donc : fais l'étape 3, puis reviens neutraliser le seul correctif de comptage** — garde la nouvelle signature, mais remets dans `_init` le comportement d'avant (`distance = 0.0` sans `wrap`, et un `update()` qui amorce `total = d` au premier appel). Relance, et **rapporte le message d'échec obtenu** pour les deux nouveaux tests. Un test de régression qui n'a jamais été rouge ne prouve rien.

- [ ] **Step 3 : Corriger `RaceProgress`**

Dans `scripts/race/race_progress.gd`, remplace les déclarations, `_init` et `update` par :

```gdscript
var track: TrackCurve

var lap: int = 0
var distance: float = 0.0   ## position le long de l'axe, dans [0, length)
var total: float = 0.0      ## distance parcourue depuis le départ, signée


## La distance de départ est donnée, jamais devinée : celui qui pose le kart
## la connaît. La redériver par projection revenait à interroger la courbe à
## l'endroit précis où elle est ambiguë — la couture — et un point posé un
## millimètre du mauvais côté offrait un tour complet.
func _init(track_curve: TrackCurve, start_distance: float) -> void:
	track = track_curve
	distance = track.wrap(start_distance)


func update(point: Vector3) -> void:
	var d := track.distance_of(point)

	# Le déplacement réel sur une boucle est le chemin le plus court, pas la
	# différence brute des coordonnées : sans ça, deux centimètres de
	# tremblement au-dessus de la ligne se lisent comme un tour complet, et le
	# compteur oscille pendant que le kart attend le départ, immobile.
	total += wrapf(d - distance, -track.length * 0.5, track.length * 0.5)
	distance = d

	# total part de zéro : le tour se compte sur ce qui a été roulé, pas sur la
	# position absolue. Deux karts sur une grille décalée doivent parcourir la
	# même distance pour boucler le même nombre de tours.
	#
	# Un kart qui recule avant même d'être parti reste au tour zéro : la
	# distance parcourue peut devenir négative, le numéro de tour non.
	lap = maxi(floori(total / track.length), 0)
```

Le drapeau `_demarre` disparaît : il n'y a plus de premier appel particulier.

- [ ] **Step 4 : Corriger l'appel dans la session**

Dans `scripts/race/race_session.gd`, `_ready()` — poser le kart d'abord, puis annoncer la distance au lieu de la faire redeviner :

```gdscript
	_kart.respawn_at(_track.spawn_at(0.0))
	progress = RaceProgress.new(_track.track_curve, 0.0)
```

La ligne `progress.update(_kart.global_position)` disparaît.

- [ ] **Step 5 : Lancer les tests**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : **+2 tests par rapport aux 88**, tous verts, et aucun test existant disparu. Si le total n'est pas 90, un fichier ne compile pas et GUT l'a sauté en silence.

- [ ] **Step 6 : La remise en piste recule le kart dans les épingles**

Second défaut mesuré à la tâche 11 : sur l'épingle (vers d ≈ 410 m), une sortie latérale de 29 m se projette sur **380,69 m** — la courbe se replie sur elle-même, et le point le plus proche n'est plus celui d'où l'on est sorti. La remise en piste replace alors le kart 29 m en arrière.

La progression y survit (`wrapf` encaisse l'aller-retour, le tour reste intact), mais rendre 29 m pour une sortie de route est une punition qu'on n'a pas décidée. La session n'a pas besoin de deviner : elle sait où le kart roulait encore.

Dans `scripts/race/race_session.gd`, ajoute le champ auprès des autres :

```gdscript
var _derniere_en_piste: float = 0.0
```

puis, dans `_physics_process`, remplace le bloc qui suit le calcul de `ecart` par :

```gdscript
	var dehors := ecart > _track.half_width
	_kart.set_offroad(dehors)
	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie : dans une épingle la courbe se replie,
		# et le point le plus proche peut être trente mètres en arrière.
		_derniere_en_piste = progress.distance

	if _kart.global_position.y < FLOOR_LIMIT or ecart > _track.half_width + OFF_TRACK_RESPAWN_MARGIN:
		_kart.respawn_at(_track.spawn_at(_derniere_en_piste))
```

- [ ] **Step 7 : Mesurer les deux corrections en situation**

Cette étape ne s'appuie sur aucun test : `RaceSession` a besoin de l'arbre de scènes, et monter un banc permanent pour trois lignes coûterait plus qu'il ne rapporte. Écris un script jetable (**non commité**) qui instancie `track_01` et le kart, câble une `RaceSession`, et **rapporte les nombres** :

1. Au départ, après dix images sans toucher aux commandes : `lap` vaut-il toujours 0 ? `timer.best` est-il resté vide ?
2. Un tour complet parcouru pas à pas : `lap` passe-t-il à 1 une seule fois, et `total` vaut-il bien une longueur de piste ?
3. Téléportation latérale de 29 m au niveau de l'épingle (d ≈ 410 m) : **à quelle distance le kart est-il replacé ?** Attendu : près de 410, pas 380. Donne le chiffre obtenu, pas une appréciation.
4. La même téléportation sur une portion droite : le kart revient-il au même endroit qu'avant la correction ?

Supprime le script avant de committer, et vérifie avec `rtk git status` qu'il ne reste rien d'autre à l'index.

- [ ] **Step 8 : Commit**

```bash
rtk git add scripts/race/race_progress.gd scripts/race/race_session.gd tests/test_race_progress.gd && rtk git commit -m "fix: le kart empochait un tour au premier centimetre"
```

**Ce que la correction ne corrige pas, et pourquoi ça tient quand même.** Seul le point de réapparition cesse d'être reprojeté ; `progress.total`, lui, continue de se nourrir de la projection brute. Pendant une sortie dans l'épingle, la distance parcourue gonfle donc toujours de 48 m, puis se rétracte au retour en piste. Ce gonflement ne fabriquerait un tour que s'il franchissait un multiple de la longueur. Balayage du circuit entier, sortie latérale de 29 m des deux côtés, de mètre en mètre :

```
mensonge maximal vers l'AVANT               : +48.51 m à d=384
mensonge maximal vers l'ARRIÈRE             : -48.02 m à d=432
mensonge maximal à moins de 60 m de la ligne :  0.065 m
```

Le repli de la courbe vit dans l'épingle, à une demi-piste de la ligne ; près de la ligne, la projection ne ment que de six centimètres. Le compteur de tours est donc hors d'atteinte — **par la géométrie de `track_01`, pas par construction**. Un circuit dont l'épingle passerait à moins d'une cinquantaine de mètres de la ligne d'arrivée rouvrirait le trou : une sortie de route y offrirait un tour. À vérifier en dessinant les circuits 2 et 3, avec ce même balayage.

**Ce que cette tâche coûte en leçon.** Les deux défauts vivaient sous 88 tests verts, dans deux des classes les plus soigneusement testées du dépôt. Aucun ne s'est montré avant qu'on branche les morceaux ensemble sur la vraie géométrie. Les tests vérifient ce qu'on a pensé à imaginer ; la mesure montre ce qui arrive.

---


### Task 12 : Le HUD et la scène de course

**Files:**
- Create: `scripts/ui/race_hud.gd`
- Create: `scenes/race.tscn`
- Modify: `project.godot`

- [ ] **Step 1 : Écrire le HUD**

`scripts/ui/race_hud.gd` :

```gdscript
class_name RaceHUD
extends Control

## Trois informations, pas une de plus : le tour, le chrono, le meilleur temps.
## Le palier de mini-turbo n'y figure pas — c'est la couleur des étincelles qui
## le dit, et le joueur ne doit pas avoir à quitter la route des yeux.

@export var session_path: NodePath

var _session: RaceSession
var _label: Label


func _ready() -> void:
	_session = get_node(session_path) as RaceSession
	assert(_session != null, "session_path doit pointer vers une RaceSession")

	_label = Label.new()
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 28)
	add_child(_label)


func _process(_delta: float) -> void:
	var tour := mini(_session.progress.lap + 1, _session.lap_count)
	var lignes := PackedStringArray()
	lignes.append("TOUR %d/%d" % [tour, _session.lap_count])
	lignes.append(RaceTimer.format(_session.timer.current))
	if _session.timer.has_best:
		lignes.append("MEILLEUR %s" % RaceTimer.format(_session.timer.best))
	if _session.finished:
		lignes.append("ARRIVÉE")
	_label.text = "\n".join(lignes)
```

- [ ] **Step 2 : Écrire la scène de course**

`scenes/race.tscn` :

```
[gd_scene load_steps=7 format=3]

[ext_resource type="PackedScene" path="res://scenes/tracks/track_01.tscn" id="1_track"]
[ext_resource type="PackedScene" path="res://scenes/kart/kart.tscn" id="2_kart"]
[ext_resource type="Script" path="res://scripts/camera/chase_camera.gd" id="3_camera"]
[ext_resource type="Script" path="res://scripts/race/race_session.gd" id="4_session"]
[ext_resource type="Script" path="res://scripts/ui/race_hud.gd" id="5_hud"]

[sub_resource type="Environment" id="Env_race"]
background_mode = 1
background_color = Color(0.55, 0.72, 0.90, 1)
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.68, 0.78, 1)
ambient_light_energy = 0.6

[node name="Race" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_race")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.766, -0.492, 0.414, 0, 0.643, 0.766, -0.643, -0.587, 0.492, 0, 40, 0)
shadow_enabled = true

[node name="Track" parent="." instance=ExtResource("1_track")]

[node name="Kart" parent="." instance=ExtResource("2_kart")]

[node name="ChaseCamera" type="Camera3D" parent="."]
script = ExtResource("3_camera")
target_path = NodePath("../Kart")

[node name="Session" type="Node" parent="."]
script = ExtResource("4_session")
track_path = NodePath("../Track")
kart_path = NodePath("../Kart")

[node name="HUD" type="CanvasLayer" parent="."]

[node name="RaceHUD" type="Control" parent="HUD"]
script = ExtResource("5_hud")
session_path = NodePath("../../Session")
```

`load_steps` vaut 7 : six ressources déclarées — cinq `ext_resource` et une `sub_resource` — plus un, comme dans `test_ground.tscn` (huit ressources, `load_steps=9`). Godot ne signale pas un compte faux en headless, donc recompte-le toi-même.

- [ ] **Step 3 : Faire de la course la scène principale**

Dans `project.godot`, remplace la ligne `run/main_scene` par :

```ini
run/main_scene="res://scenes/race.tscn"
```

Le terrain d'essai du plan 1 reste dans le dépôt : il sert encore à régler le pilotage à l'écart de toute piste.

- [ ] **Step 4 : Vérifier**

```bash
"$GODOT" --headless --quit-after 180 scenes/race.tscn
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : chargement sans ligne `ERROR`, et **le même nombre de tests qu'avant** — cette tâche n'en ajoute aucun.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/ui/race_hud.gd scenes/race.tscn project.godot && rtk git commit -m "feat: scène de course avec circuit, chrono et HUD"
```

---

### Task 13 : Le point de validation

**Files:** aucun — c'est une session de jeu.

Comme au plan 1, cette tâche ne peut pas être exécutée par un agent.

- [ ] **Step 1 : Lancer le jeu**

```bash
"$GODOT" --path .
```

- [ ] **Step 2 : Boucler trois tours**

Ce qui se vérifie ici, et nulle part ailleurs :

- **La route est visible et posée au bon endroit.** Si elle est invisible vue de dessus mais visible par en dessous, c'est l'ordre des sommets dans `TrackBuilder` — échange les deux derniers de chaque triangle.
- **La collision suit le maillage.** Le kart roule sur la route, ne passe pas au travers, ne flotte pas au-dessus.
- **Le bord intérieur de l'épingle.** L'axe y fait 13,3 m et la chaussée 9 m de demi-largeur, donc le bord intérieur décrit un arc de 4,3 m. Le facettage n'est pas en cause — moins d'un centimètre de flèche — mais l'écart entre un bord extérieur à 22 m et un bord intérieur à 4,3 m peut se lire comme un coin plutôt qu'un virage. Si ça te gêne, le levier est `half_width` : une route plus étroite rendrait toutes les épingles plus régulières, partout.
- **La largeur est jouable.** 9 m de demi-largeur, soit 18 m de route : trop large et les virages n'existent pas, trop étroit et le dérapage devient punitif.
- **Les virages du circuit 1 méritent le dérapage.** Mesuré avant conduite : épingle à 13,3 m de rayon, contre 9,2 m de rayon de braquage en adhérence à pleine vitesse — il faut donc y lever le pied. Le reste du tour est à 97 % au-dessus de 25 m, donc rapide. Si le contraste paraît trop faible ou trop brutal, les points de contrôle sont dans `tools/build_track_01.gd` et le tracé se regénère d'une commande. Si tout se prend à fond, il faut resserrer des points de contrôle ; si tout est trop serré, c'est l'inverse.
- **Le hors-piste se sent** sans être punitif au point de décourager une trajectoire large.
- **La remise en piste tombe juste** — ni trop prompte, ni trop tardive. Le réglage est `OFF_TRACK_RESPAWN_MARGIN` dans `race_session.gd`.
- **Le compte des tours est fiable**, y compris si tu fais volontairement demi-tour sur la ligne.
- **Le chrono est lisible** en courant, sans quitter la route des yeux.
- **Le début de course.** La caméra naît à l'origine alors que le kart apparaît à plus de cent mètres de là : attends-toi à une seconde de vol plané avant qu'elle ne le rattrape. Si ça gêne, donne à `ChaseCamera` une transformée initiale proche du départ dans `race.tscn` — un décompte de départ le masquera de toute façon plus tard.

La courbe s'édite à la souris : ouvre `resources/tracks/track_01_curve.tres`, déplace les points, relance. La piste, sa collision et la ligne de course se régénèrent ensemble.

- [ ] **Step 3 : Commiter les réglages retenus**

```bash
rtk git add resources/tracks scenes/tracks && rtk git commit -m "tune: tracé et largeur du circuit 1 après la session de validation"
```

---

## Ce que ce plan ne livre pas

L'IA, les sept adversaires, la grille de départ et le classement : plan suivant. Les objets, les circuits 2 et 3, le shader toon et la finition viennent après.

La suspension par quatre raycasts et l'alignement sur la pente restent hors périmètre tant que le circuit est plat. Le circuit 1 est tracé à altitude constante précisément pour que ce plan n'ait pas à les traiter.

## Dette reportée du plan 1

Toujours ouverte, et toujours sans urgence : `motor.speed` n'est pas réconcilié après une collision avec `move_and_slide()`. Ce plan ajoute une piste mais **pas de murs** — sortir de la route mène au hors-piste puis à une remise en piste, jamais à un choc. Le sujet redevient obligatoire le jour où le circuit gagnera des rails.
