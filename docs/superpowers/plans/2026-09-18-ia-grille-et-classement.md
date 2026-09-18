# Plan 3 — IA, grille de départ et classement

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire de la course un vrai départ à huit karts, avec sept adversaires qui pilotent pour de vrai et un classement qui dit qui est devant.

**Architecture:** `AIInput` produit le même `KartCommand` que le joueur, donc elle est enfermée dans la même physique : elle ne peut pas tricher, elle dérape pour de vrai. Elle vise un point sur la ligne de course situé à environ une demi-seconde de trajet devant elle, et en déduit un braquage. `RaceSession` passe d'un kart à huit : un `RaceEntry` par concurrent, et le classement est un tri sur un seul nombre — la distance parcourue que `RaceProgress` tient déjà.

**Tech Stack:** Godot 4.7.2, GDScript typé statiquement, GUT 9.7.1 pour les tests headless.

---

## Ce qui existe déjà et qu'il ne faut pas réinventer

Le plan 2 est fusionné dans `main`. Ces classes sont livrées, testées, et ce plan s'appuie dessus :

| Classe | Ce qu'elle fait | Ce qu'il faut en retenir ici |
|---|---|---|
| `TrackCurve` | tout ce qui se dérive de la courbe | `racing_line_at(d)`, `right_at(d)`, `yaw_at(d)`, `distance_of(p)`, `lateral_offset(p)`, `length`, `half_width` |
| `Track` | maillage, collision, `spawn_at(d)` | nœud de scène ; `track_curve` est construit dans `_ready()` |
| `RaceProgress` | avancement le long de l'axe | `RaceProgress.new(curve, distance_depart)`, puis `update(point)` ; `total` part de zéro et **mesure ce qui a été roulé** |
| `RaceTimer` | chrono du tour, meilleur temps | `advance(delta)`, `complete_lap()`, `current`, `best`, `has_best`, `format(s)` statique |
| `RaceSession` | met le kart et le circuit en rapport | `demarrer(piste, kart)` et `avancer(point, delta)` — testable sans arbre de scènes |
| `KartInput` | source de commande | `poll(delta)` remet la commande à neuf puis appelle `_fill(delta)` ; le champ `kart` est renseigné par `Kart._ready()` |
| `KartMotor` | toute la physique | `step(cmd, delta)`, `state`, `speed`, `heading`, `velocity_dir`, `drift_charge`, `tier_for_charge(charge)` |

**Convention d'angles, à ne jamais oublier.** `KartMotor` et `TrackCurve` comptent les lacets à la boussole : **positif vers la droite**. Godot compte l'inverse. La conversion vit uniquement dans `kart.gd`. Une direction de cap θ correspond au vecteur `Vector3(sin(θ), 0, -cos(θ))`, et le cap d'un vecteur `v` est `atan2(v.x, -v.z)`. L'IA travaille **entièrement en repère boussole** : elle compare des caps entre eux, jamais des rotations Godot.

**Divergence de nom assumée.** Le spec §3.3 appelle l'orchestrateur `RaceDirector`. Le code livré l'appelle `RaceSession`. On garde `RaceSession` : renommer du code testé pour coller à un croquis d'architecture coûterait plus que ça ne rapporte.

## Pièges de ce dépôt, qui ont déjà coûté du temps

- **Un fichier de test qui ne compile pas est silencieusement sauté par GUT**, et la campagne annonce quand même « all tests passed ». Le décompte de scripts et de tests est le seul garde-fou. Ce plan donne des **deltas** (`+3 tests`) et jamais des totaux absolus : un total recopié devient faux dès qu'une tâche est faite dans le désordre.
- **`assert()` journalise mais n'interrompt pas.**
- **Dans `TrackCurve`, `wrap()` est masquée par le `wrap()` global de GDScript** : écrire `self.wrap(...)`.
- **Monter un circuit depuis `SceneTree._initialize()` gèle Godot headless** (`Track._ready()` construit maillage et collision trop tôt) : monter au premier `_process()`.
- **Godot headless ne signale pas un `load_steps` faux** dans un `.tscn`. La convention du dépôt est *nombre de ressources déclarées + 1* : `test_ground.tscn` en déclare huit et porte `load_steps=9`.
- **Lire `global_position` hors de l'arbre échoue** et renvoie `(0,0,0)`. C'est la raison d'être des coutures `avancer(point, delta)` : on passe la position, on ne la lit pas.
- **Les objets `Node` créés hors arbre dans un test doivent être libérés** (`free()`), sinon GUT signale des fuites.

Commande de campagne, utilisée partout dans ce plan :

```bash
export GODOT="/c/Users/alexa/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Toute autre commande shell se préfixe de `rtk` (règle du CLAUDE.md), y compris dans les chaînes `&&`.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `scripts/race/race_entry.gd` | **créé** — l'état de course d'un concurrent : son kart, sa progression, son chrono, sa place |
| `scripts/race/race_session.gd` | **modifié** — passe d'un kart à N, place la grille, tient le classement |
| `scripts/track/track.gd` | **modifié** — `spawn_at` accepte un décalage latéral, pour la grille |
| `scripts/kart/ai_input.gd` | **créé** — l'IA : vise un point devant elle, en déduit braquage et dérapage |
| `scripts/ui/race_hud.gd` | **modifié** — affiche la place au classement |
| `scenes/kart/ai_kart.tscn` | **créé** — le kart piloté par l'IA |
| `scenes/race.tscn` | **modifié** — huit karts au lieu d'un |
| `tests/test_race_entry.gd` | **créé** |
| `tests/test_ai_input.gd` | **créé** |
| `tests/test_race_session.gd` | **modifié** — la session est multi-kart |
| `tests/test_track.gd` | **créé** — `spawn_at` et son décalage latéral |

**Une dette assumée : `ai_kart.tscn` duplique les sous-ressources de `kart.tscn`** (boîte de collision, maillage, matériau, particules). Un `.tscn` ne peut pas partager de sous-ressource avec un autre fichier, et une scène héritée ne sait pas supprimer le nœud `PlayerInput` dont elle hérite. Extraire ces quatre sous-ressources en `.tres` maintenant serait du travail jeté : le jalon 7 (shader toon) refait entièrement l'apparence du kart. On duplique, on le note, et on collapse à ce moment-là.

---

### Task 1 : `spawn_at` accepte un décalage latéral

**Files:**
- Modify: `scripts/track/track.gd`
- Test: `tests/test_track.gd`

La grille de départ a besoin de poser des karts côte à côte. `spawn_at` ne sait poser que sur la ligne de course. Un paramètre par défaut à zéro laisse les appelants existants — les remises en piste — strictement inchangés.

- [ ] **Step 1 : Écrire les tests qui échouent**

Crée `tests/test_track.gd` :

```gdscript
extends GutTest

## Track a besoin de l'arbre pour construire son maillage, mais spawn_at ne
## touche qu'à la courbe : on renseigne track_curve à la main et on teste la
## géométrie sans jamais entrer dans l'arbre.

var track: Track


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
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)


func after_each() -> void:
	track.free()


func test_sans_decalage_on_reste_sur_la_ligne_de_course() -> void:
	var avant := track.spawn_at(120.0)
	var attendu := track.track_curve.racing_line_at(120.0)
	assert_almost_eq(avant.origin.x, attendu.x, 0.001)
	assert_almost_eq(avant.origin.z, attendu.z, 0.001)


func test_un_decalage_positif_pose_le_kart_a_droite() -> void:
	var centre := track.spawn_at(120.0)
	var droite := track.spawn_at(120.0, 3.0)
	var vers := droite.origin - centre.origin
	vers.y = 0.0
	var a_droite := track.track_curve.right_at(120.0)
	assert_almost_eq(vers.dot(a_droite), 3.0, 0.001,
		"trois mètres vers la droite de la marche, et pas ailleurs")
	assert_almost_eq(vers.length(), 3.0, 0.001)


func test_un_decalage_negatif_pose_le_kart_a_gauche() -> void:
	var centre := track.spawn_at(120.0)
	var gauche := track.spawn_at(120.0, -3.0)
	var vers := gauche.origin - centre.origin
	vers.y = 0.0
	assert_almost_eq(vers.dot(track.track_curve.right_at(120.0)), -3.0, 0.001)


func test_le_decalage_ne_change_pas_l_orientation() -> void:
	var centre := track.spawn_at(120.0)
	var decale := track.spawn_at(120.0, 4.0)
	assert_almost_eq(decale.basis.get_euler().y, centre.basis.get_euler().y, 0.0001,
		"un kart décalé sur la grille regarde toujours dans le sens de la marche")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Lance la campagne. Attendu : ÉCHEC — `spawn_at()` n'accepte qu'un argument. Le message ressemblera à `Invalid argument count for "spawn_at()" call. Expected 1 but received 2.`

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/track/track.gd`, remplace `spawn_at` par :

```gdscript
## Transformée de départ, sur la ligne de course, orientée dans le sens de la
## marche. Sert au placement initial comme aux remises en piste.
##
## Le décalage latéral est en mètres vers la droite de la marche, et sert à la
## grille de départ. Il vaut zéro par défaut pour que les remises en piste
## continuent de ramener le kart sur la ligne de course, où il doit être.
func spawn_at(distance: float, lateral: float = 0.0) -> Transform3D:
	var position := track_curve.racing_line_at(distance) \
		+ track_curve.right_at(distance) * lateral \
		+ Vector3.UP * 0.1
	var lacet := track_curve.yaw_at(distance)
	return Transform3D(Basis(Vector3.UP, -lacet), position)
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+4 tests et +1 script** par rapport à la campagne d'avant, tout vert, et aucun test existant disparu. Si le compte n'y est pas, un fichier ne compile pas.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/track/track.gd tests/test_track.gd tests/test_track.gd.uid && rtk git commit -m "feat: spawn_at accepte un decalage lateral pour la grille"
```

---

### Task 2 : `RaceEntry`, l'état de course d'un concurrent

**Files:**
- Create: `scripts/race/race_entry.gd`
- Test: `tests/test_race_entry.gd`

`RaceSession` porte aujourd'hui l'état d'un seul kart dans ses propres champs : `progress`, `timer`, `finished`, `_derniere_en_piste`, `_tours_comptes`. À huit karts, cet état devient un état **par concurrent**. On le sort dans un objet avant de toucher à la session, pour que la tâche suivante ne fasse qu'une chose.

- [ ] **Step 1 : Écrire le test qui échoue**

Crée `tests/test_race_entry.gd` :

```gdscript
extends GutTest

## RaceEntry n'est qu'un sac d'état, mais un sac dont les valeurs initiales
## comptent : une place à zéro ou une dernière position en piste à zéro pour un
## kart parti du fond de grille enverrait ce kart à la ligne de départ à sa
## première sortie de route.


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


func test_une_entree_demarre_a_sa_place_de_grille() -> void:
	var piste := TrackCurve.new(_anneau(), 9.0)
	var kart := Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)

	var entree := RaceEntry.new(kart, piste, 300.0)

	assert_eq(entree.kart, kart)
	assert_almost_eq(entree.progress.distance, 300.0, 0.001,
		"la progression part de la case de grille, pas de la ligne")
	assert_almost_eq(entree.progress.total, 0.0, 0.001,
		"mais la distance parcourue part de zéro pour tout le monde")
	assert_almost_eq(entree.derniere_en_piste, 300.0, 0.001,
		"une sortie de route au premier virage ne doit pas renvoyer à la ligne")
	assert_eq(entree.tours_comptes, 0)
	assert_eq(entree.position, 0, "la place n'a pas de sens avant le premier classement")
	assert_false(entree.finished)
	assert_false(entree.timer.has_best)

	kart.free()


func test_deux_entrees_ne_partagent_pas_leur_chrono() -> void:
	var piste := TrackCurve.new(_anneau(), 9.0)
	var un := Kart.new()
	un.stats = KartStats.new()
	un.motor = KartMotor.new(un.stats)
	var deux := Kart.new()
	deux.stats = KartStats.new()
	deux.motor = KartMotor.new(deux.stats)

	var a := RaceEntry.new(un, piste, 0.0)
	var b := RaceEntry.new(deux, piste, 10.0)
	a.timer.advance(3.0)

	assert_almost_eq(a.timer.current, 3.0, 0.001)
	assert_almost_eq(b.timer.current, 0.0, 0.001,
		"un chrono partagé entre concurrents donnerait huit fois le même temps")

	un.free()
	deux.free()
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `RaceEntry` introuvable.

- [ ] **Step 3 : Écrire l'implémentation**

Crée `scripts/race/race_entry.gd` :

```gdscript
class_name RaceEntry
extends RefCounted

## L'état de course d'un concurrent. Sorti de RaceSession quand la course est
## passée d'un kart à huit : chacun a sa progression, son chrono et sa place,
## et rien de tout ça ne doit se partager par accident.
##
## Comme RaceProgress et KartMotor, cette classe ne connaît pas l'arbre de
## scènes — elle détient une référence au kart, mais ne lit jamais sa position.

var kart: Kart
var progress: RaceProgress
var timer := RaceTimer.new()
var finished: bool = false

## Place au classement, 1 = premier. Zéro tant qu'aucun classement n'a été
## calculé : afficher « 0e » est une erreur visible, afficher « 1er » à tort
## ne l'est pas.
var position: int = 0

## Dernière distance à laquelle le kart roulait encore sur le bitume. Initialisée
## à la case de grille : sans ça, une sortie de route au premier virage
## renverrait à la ligne de départ un kart parti du fond.
var derniere_en_piste: float = 0.0

## Ligne de crue des tours comptés. Le numéro de tour de RaceProgress, lui,
## redescend quand le kart recule.
var tours_comptes: int = 0


func _init(pilote: Kart, piste: TrackCurve, depart: float) -> void:
	kart = pilote
	progress = RaceProgress.new(piste, depart)
	derniere_en_piste = piste.wrap(depart)
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+2 tests et +1 script**, tout vert.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/race/race_entry.gd scripts/race/race_entry.gd.uid tests/test_race_entry.gd tests/test_race_entry.gd.uid && rtk git commit -m "feat: l etat de course d un concurrent"
```

---

### Task 3 : `RaceSession` passe d'un kart à huit

**Files:**
- Modify: `scripts/race/race_session.gd`
- Test: `tests/test_race_session.gd`

C'est la tâche la plus lourde du plan : elle réécrit la session et adapte ses tests existants. Elle ne fait **que** ça — la grille arrive à la tâche 4, le classement à la tâche 5.

Le contrat de la couture change : `avancer(point, delta)` devient `avancer(entree, point, delta)`, et `_physics_process` boucle sur les concurrents.

- [ ] **Step 1 : Réécrire `tests/test_race_session.gd`**

Remplace intégralement le fichier par :

```gdscript
extends GutTest

## RaceSession n'a besoin de l'arbre que pour lire global_position. En passant
## le point en paramètre, toute sa logique se teste comme KartMotor : sans
## nœud, sans rendu, en quelques microsecondes. Deux défauts — un meilleur tour
## fabriqué en reculant sur la ligne, un kart qui tombait sans fin après
## l'arrivée — avaient traversé une campagne verte faute de cette couture.
##
## La remise en piste se constate sur le moteur et non sur la position : lire
## global_position hors de l'arbre est justement ce qui ne marche pas, et
## respawn_at remet le moteur à neuf.

var track: Track
var karts: Array[Kart] = []
var cerveaux: Array[AIInput] = []
var session: RaceSession


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


func _kart() -> Kart:
	var k := Kart.new()
	k.stats = KartStats.new()
	k.motor = KartMotor.new(k.stats)
	return k


## Monte une session de `combien` karts, sans jamais entrer dans l'arbre.
## Démonte d'abord ce qui existe : `before_each` a déjà monté une session à un
## kart, et un test qui en remonte une à huit laisserait sinon des nœuds
## orphelins derrière lui — que GUT compte et signale.
func _monter(combien: int) -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	for i in combien:
		karts.append(_kart())
	session.demarrer(track, karts)


func _demonter() -> void:
	if session != null:
		session.free()
		session = null
	for c in cerveaux:
		c.free()
	cerveaux.clear()
	for k in karts:
		k.free()
	karts.clear()
	if track != null:
		track.free()
		track = null


func before_each() -> void:
	_monter(1)


func after_each() -> void:
	_demonter()


## Le concurrent du joueur, celui qu'on suit dans la plupart des tests.
func _joueur() -> RaceEntry:
	return session.entries[0]


## Avance le long de l'axe par pas de 50 cm, en appelant la session comme le
## ferait le moteur, à 60 Hz.
func _rouler(de: float, vers: float) -> void:
	var d := de
	var pas := 0.5 * signf(vers - de)
	while absf(vers - d) > 0.5:
		d += pas
		session.avancer(_joueur(), track.track_curve.position_at(d), 1.0 / 60.0)
	session.avancer(_joueur(), track.track_curve.position_at(vers), 1.0 / 60.0)


func test_un_tour_honnete_enregistre_un_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_eq(_joueur().progress.lap, 1)
	assert_true(_joueur().timer.has_best, "le tour bouclé donne un meilleur temps")
	assert_gt(_joueur().timer.best, 1.0, "et ce temps n'est pas dérisoire")


func test_reculer_sur_la_ligne_ne_refabrique_pas_de_tour() -> void:
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var reference := _joueur().timer.best

	# À cheval sur la ligne, et non au-delà : c'est le passage sous une
	# longueur entière qui fait redescendre progress.lap, et rien d'autre.
	for i in 20:
		session.avancer(_joueur(), track.track_curve.position_at(L - 0.4), 1.0 / 60.0)
		assert_eq(_joueur().progress.lap, 0,
			"reculer sous la ligne ramène bien le compteur à zéro")
		session.avancer(_joueur(), track.track_curve.position_at(L + 0.3), 1.0 / 60.0)

	assert_almost_eq(_joueur().timer.best, reference, 0.0001,
		"repasser la ligne à l'envers ne doit pas offrir un tour de deux images")


func test_le_hors_piste_ne_se_fige_pas_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished, "un tour suffit à finir cette course")

	# Entre le bord de piste et la marge de remise en piste : assez dehors pour
	# que le drapeau lève, pas assez pour être ramené. Sinon la remise en piste
	# remettrait le moteur à neuf dans la même image et effacerait le drapeau.
	var large := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 10.5
	session.avancer(_joueur(), large, 1.0 / 60.0)

	assert_true(karts[0].motor.on_offroad,
		"le hors-piste ne se fige pas parce que la course est finie")


func test_la_remise_en_piste_continue_apres_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	assert_true(_joueur().finished)

	karts[0].motor.speed = 20.0
	var dehors := track.track_curve.position_at(100.0) \
		+ track.track_curve.right_at(100.0) * 40.0
	session.avancer(_joueur(), dehors, 1.0 / 60.0)

	assert_eq(karts[0].motor.speed, 0.0,
		"respawn_at remet le moteur à neuf : sans lui le kart tombe sans fin")


func test_le_chrono_s_arrete_a_l_arrivee() -> void:
	session.lap_count = 1
	var L := track.track_curve.length
	_rouler(0.0, L + 0.3)
	var fige := _joueur().timer.current
	for i in 30:
		session.avancer(_joueur(), track.track_curve.position_at(10.0), 1.0 / 60.0)
	assert_almost_eq(_joueur().timer.current, fige, 0.0001,
		"le chrono ne tourne plus une fois la course finie")


func test_chaque_concurrent_a_son_propre_etat() -> void:
	_monter(3)
	var L := track.track_curve.length

	# Seul le deuxième roule.
	for i in 40:
		session.avancer(session.entries[1], track.track_curve.position_at(float(i) * 0.5), 1.0 / 60.0)

	assert_gt(session.entries[1].progress.total, 5.0, "celui qui roule avance")
	assert_almost_eq(session.entries[0].progress.total, 0.0, 0.001,
		"et les autres restent où ils sont")
	assert_almost_eq(session.entries[2].timer.current, 0.0, 0.001,
		"un chrono par concurrent, pas un pour tous")


func test_la_course_finit_pour_chacun_separement() -> void:
	_monter(2)
	session.lap_count = 1
	var L := track.track_curve.length
	var d := 0.0
	while d < L + 0.3:
		d = minf(d + 0.5, L + 0.3)
		session.avancer(session.entries[0], track.track_curve.position_at(d), 1.0 / 60.0)

	assert_true(session.entries[0].finished, "celui qui a bouclé a fini")
	assert_false(session.entries[1].finished, "celui qui n'a pas bouclé court toujours")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `demarrer()` prend un `Kart` et non un tableau, et `session.entries` n'existe pas.

- [ ] **Step 3 : Réécrire la session**

Remplace intégralement `scripts/race/race_session.gd` par :

```gdscript
class_name RaceSession
extends Node

## Met les karts et le circuit en rapport. Les karts ignorent le circuit, le
## circuit ignore les karts : c'est ici et nulle part ailleurs que les deux se
## parlent.
##
## Le concurrent d'indice 0 est le joueur — c'est lui que le HUD suit. Rien
## d'autre ne distingue les huit : l'IA passe par le même KartCommand et subit
## la même physique, donc elle ne peut pas tricher.

const FLOOR_LIMIT := -10.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

## Distance de départ le long de l'axe, pour la première case de grille.
const DEPART := 0.0

@export var track_path: NodePath
@export var kart_paths: Array[NodePath] = []
@export var lap_count: int = 3

var entries: Array[RaceEntry] = []

var _track: Track
var _demi_largeur: float = 0.0


func _ready() -> void:
	# get_node lèverait l'erreur avant l'assert, et les assert disparaissent en
	# export release : le message n'aurait servi à personne.
	var piste := get_node_or_null(track_path) as Track
	assert(piste != null, "track_path doit pointer vers un Track")

	var pilotes: Array[Kart] = []
	for chemin in kart_paths:
		var k := get_node_or_null(chemin) as Kart
		assert(k != null, "chaque entrée de kart_paths doit pointer vers un Kart")
		pilotes.append(k)

	demarrer(piste, pilotes)


## Prend le circuit et les karts en paramètres plutôt que de les lire dans
## l'arbre : c'est toute la différence entre une logique testable et une
## logique qu'on ne peut qu'espérer juste.
func demarrer(piste: Track, pilotes: Array[Kart]) -> void:
	assert(lap_count > 0, "une course sans tour à boucler ne finit jamais")
	assert(not pilotes.is_empty(), "une course a besoin d'au moins un concurrent")
	_track = piste
	_demi_largeur = _track.track_curve.half_width

	entries.clear()
	for i in pilotes.size():
		var depart := DEPART
		pilotes[i].respawn_at(_track.spawn_at(depart))
		entries.append(RaceEntry.new(pilotes[i], _track.track_curve, depart))


func _physics_process(delta: float) -> void:
	for entree in entries:
		avancer(entree, entree.kart.global_position, delta)


## Le point est passé plutôt que lu sur le kart : global_position exige
## l'arbre de scènes, et c'est le seul obstacle qui rendait cette logique
## intestable.
func avancer(entree: RaceEntry, point: Vector3, delta: float) -> void:
	entree.progress.update(point)

	# La comptabilité s'arrête à l'arrivée ; le monde, lui, continue.
	if not entree.finished:
		entree.timer.advance(delta)
		# progress.lap n'est pas monotone : il redescend quand le kart recule.
		# Se déclencher sur sa montée enregistrait un tour à chaque
		# franchissement, donc reculer sur la ligne d'arrivée fabriquait un
		# meilleur temps de deux images. On compte sur une ligne de crue.
		if entree.progress.lap > entree.tours_comptes:
			entree.tours_comptes = entree.progress.lap
			entree.timer.complete_lap()
			if entree.tours_comptes >= lap_count:
				entree.finished = true

	# Une seule projection par image et par kart : is_off_track la referait
	# entièrement, et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(point))
	var dehors := ecart > _demi_largeur
	entree.kart.set_offroad(dehors)
	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie. Dans l'épingle la courbe se replie sur
		# elle-même : le point le plus proche d'une sortie de 29 m s'y trompe
		# de 48 m — en arrière d'un côté, mais en avant de l'autre. Reprojeter
		# ne punissait donc pas seulement la sortie de route, elle pouvait
		# aussi l'offrir en raccourci.
		entree.derniere_en_piste = entree.progress.distance

	if point.y < FLOOR_LIMIT or ecart > _demi_largeur + OFF_TRACK_RESPAWN_MARGIN:
		entree.kart.respawn_at(_track.spawn_at(entree.derniere_en_piste))
```

- [ ] **Step 4 : Réparer le HUD, qui lit l'ancien contrat**

`scripts/ui/race_hud.gd` lit `_session.progress`, `_session.timer` et `_session.finished`, qui n'existent plus. Remplace le corps de `_process` par :

```gdscript
func _process(_delta: float) -> void:
	if _session.entries.is_empty():
		return
	var moi := _session.entries[0]
	var tour := mini(moi.progress.lap + 1, _session.lap_count)
	var lignes := PackedStringArray()
	lignes.append("TOUR %d/%d" % [tour, _session.lap_count])
	lignes.append(RaceTimer.format(moi.timer.current))
	if moi.timer.has_best:
		lignes.append("MEILLEUR %s" % RaceTimer.format(moi.timer.best))
	if moi.finished:
		lignes.append("ARRIVÉE")
	_label.text = "\n".join(lignes)
```

- [ ] **Step 5 : Réparer la scène de course**

Dans `scenes/race.tscn`, le nœud `Session` porte `kart_path = NodePath("../Kart")`. Remplace cette ligne par :

```
kart_paths = [NodePath("../Kart")]
```

- [ ] **Step 6 : Lancer les tests et la scène**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
"$GODOT" --headless --quit-after 180 scenes/race.tscn
```

Attendu : **+2 tests** par rapport à la campagne d'avant (les six tests existants de la session restent, deux s'ajoutent), tout vert, et la scène charge sans aucune ligne `ERROR` ni `SCRIPT ERROR`.

- [ ] **Step 7 : Commit**

```bash
rtk git add scripts/race/race_session.gd scripts/ui/race_hud.gd scenes/race.tscn tests/test_race_session.gd && rtk git commit -m "refactor: la session gere plusieurs concurrents"
```

---

### Task 4 : La grille de départ

**Files:**
- Modify: `scripts/race/race_session.gd`
- Test: `tests/test_race_session.gd`

Huit karts ne peuvent pas naître au même endroit. La grille les décale **en amont du point zéro**, sur deux colonnes.

Les distances de départ sont négatives, donc `RaceProgress` les enroule dans `[0, length)` — un kart de fond de grille démarre à `length - 14`. Ça ne pose aucun problème : `total` part de zéro pour tout le monde, donc **chacun doit rouler exactement la même distance** pour boucler le même nombre de tours. C'est la propriété qui rend la grille équitable, et elle vient gratuitement du choix fait au plan 2 de compter l'avancement et non la position.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à la fin de `tests/test_race_session.gd` :

```gdscript
func test_la_grille_ne_superpose_personne() -> void:
	_monter(8)
	# Sur les positions dans l'espace et non sur les distances le long de l'axe :
	# deux karts de la même rangée sont côte à côte, ce qui est exactement le
	# but d'une grille à deux colonnes.
	var places: Array[Vector3] = []
	for i in session.entries.size():
		var ou := _place_de_la_case(i).origin
		for autre in places:
			assert_gt(ou.distance_to(autre), 2.0,
				"la case %d chevauche une autre" % i)
		places.append(ou)


func test_la_grille_part_en_amont_de_la_ligne() -> void:
	_monter(8)
	var L := track.track_curve.length
	for i in session.entries.size():
		# Les cases sont à des distances négatives, donc enroulées près de la
		# fin du tour. wrapf les relit en « combien de mètres avant la ligne ».
		var recul := wrapf(-session.entries[i].progress.distance, 0.0, L)
		assert_between(recul, 0.0, 20.0,
			"la case %d doit être entre la ligne et vingt mètres en amont" % i)


func test_tout_le_monde_part_a_zero_de_distance_parcourue() -> void:
	_monter(8)
	for entree in session.entries:
		assert_almost_eq(entree.progress.total, 0.0, 0.001,
			"la grille décale la position, jamais la distance à parcourir")


func test_la_grille_tient_sur_la_chaussee() -> void:
	_monter(8)
	for i in session.entries.size():
		var place := _place_de_la_case(i)
		var ecart := absf(track.track_curve.lateral_offset(place.origin))
		assert_lt(ecart, 9.0,
			"la case %d doit être sur le bitume, pas sur le bas-côté" % i)


## Rejoue le placement de la session pour la case donnée.
func _place_de_la_case(index: int) -> Transform3D:
	var rangee := index / RaceSession.GRID_COLUMNS
	var colonne := index % RaceSession.GRID_COLUMNS
	var d := RaceSession.DEPART \
		- float(rangee) * RaceSession.GRID_ROW_SPACING \
		- float(colonne) * RaceSession.GRID_COLUMN_STAGGER
	var lateral := (float(colonne) - 0.5) * 2.0 * RaceSession.GRID_COLUMN_OFFSET
	return track.spawn_at(d, lateral)
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `RaceSession.GRID_COLUMNS` n'existe pas, et les huit karts naissent tous à la même distance.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/race/race_session.gd`, ajoute les constantes auprès de `DEPART` :

```gdscript
## Deux colonnes, comme une vraie grille : huit karts en file indienne
## s'étireraient sur trente mètres et le dernier ne verrait jamais le premier.
const GRID_COLUMNS := 2

## Écart entre deux rangées, en mètres le long de l'axe.
const GRID_ROW_SPACING := 5.0

## Demi-écartement des colonnes, en mètres de part et d'autre de la ligne de
## course. Reste bien en deçà de la demi-largeur de 9 m, y compris là où la
## ligne de course mord déjà le bord intérieur d'un virage.
const GRID_COLUMN_OFFSET := 2.5

## Recul de la colonne de droite par rapport à celle de gauche, en mètres.
## Une grille alignée au cordeau n'existe nulle part, et décaler donne à
## chaque kart une distance de départ qui lui est propre.
const GRID_COLUMN_STAGGER := 2.5
```

puis remplace la boucle de `demarrer` par :

```gdscript
	entries.clear()
	for i in pilotes.size():
		var rangee := i / GRID_COLUMNS
		var colonne := i % GRID_COLUMNS
		var depart := DEPART \
			- float(rangee) * GRID_ROW_SPACING \
			- float(colonne) * GRID_COLUMN_STAGGER
		# -1 pour la colonne de gauche, +1 pour celle de droite.
		var lateral := (float(colonne) - 0.5) * 2.0 * GRID_COLUMN_OFFSET
		var place := _track.spawn_at(depart, lateral)
		pilotes[i].respawn_at(place)
		entries.append(RaceEntry.new(pilotes[i], _track.track_curve, depart))
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+4 tests**, tout vert.

- [ ] **Step 5 : Mesurer la grille sur le vrai circuit**

Les tests tournent sur un anneau parfait ; c'est sur `track_01` que la grille doit tenir, et son premier virage est plus proche de la ligne. Écris un script jetable (**non commité**, supprimé avant le commit) qui charge `res://resources/tracks/track_01_curve.tres`, construit un `TrackCurve`, rejoue le placement des huit cases et **rapporte les chiffres** :

1. l'écart latéral de chaque case à l'axe, et la marge restante sur les 9 m ;
2. la distance de la case la plus en amont à la ligne ;
3. si deux cases se chevauchent à moins de 2 m l'une de l'autre en distance 3D.

Donne les nombres, pas une appréciation. Si une case sort du bitume, **arrête-toi et dis-le** : il faudra resserrer `GRID_COLUMN_OFFSET`, pas déplacer le test.

- [ ] **Step 6 : Commit**

```bash
rtk git add scripts/race/race_session.gd tests/test_race_session.gd && rtk git commit -m "feat: grille de depart sur deux colonnes"
```

---

### Task 5 : Le classement

**Files:**
- Modify: `scripts/race/race_session.gd`
- Test: `tests/test_race_session.gd`

Le classement ne compare jamais les karts entre eux sur la piste : chacun connaît sa distance parcourue, et trier huit nombres reste juste quelle que soit la forme du circuit.

**Trier sur ce nombre-là et sur aucun autre.** Reconstituer un couple (numéro de tour, position sur l'axe) donnerait un classement faux : un kart ayant reculé sous la ligne a une position d'axe proche de la fin du tour, donc paraîtrait devant ceux qui le précèdent réellement. C'est exactement le piège que `total` évite, et le test ci-dessous le met en scène.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à la fin de `tests/test_race_session.gd` :

```gdscript
func test_le_classement_suit_la_distance_parcourue() -> void:
	_monter(3)
	session.entries[0].progress.total = 120.0
	session.entries[1].progress.total = 400.0
	session.entries[2].progress.total = 250.0

	session.classer()

	assert_eq(session.entries[1].position, 1, "le plus avancé est premier")
	assert_eq(session.entries[2].position, 2)
	assert_eq(session.entries[0].position, 3)


func test_le_classement_ne_se_laisse_pas_tromper_par_la_position_sur_l_axe() -> void:
	_monter(2)
	var L := track.track_curve.length

	# Le premier a bouclé un tour et entamé le suivant : 10 m parcourus au-delà.
	session.entries[0].progress.total = L + 10.0
	session.entries[0].progress.distance = 10.0
	# Le second a reculé sous la ligne sans jamais boucler : sa position sur
	# l'axe est proche de la fin du tour, mais il n'a presque rien parcouru.
	session.entries[1].progress.total = 5.0
	session.entries[1].progress.distance = L - 2.0

	session.classer()

	assert_eq(session.entries[0].position, 1,
		"celui qui a réellement parcouru le plus est devant")
	assert_eq(session.entries[1].position, 2,
		"une position d'axe élevée ne vaut pas un tour")


func test_le_classement_est_stable_a_egalite() -> void:
	_monter(3)
	for entree in session.entries:
		entree.progress.total = 100.0

	session.classer()

	var places := [session.entries[0].position, session.entries[1].position, session.entries[2].position]
	places.sort()
	assert_eq(places, [1, 2, 3],
		"trois karts à égalité occupent quand même trois places distinctes")


func test_chaque_image_met_le_classement_a_jour() -> void:
	_monter(2)
	session.avancer(session.entries[1], track.track_curve.position_at(30.0), 1.0 / 60.0)
	session.classer()
	assert_eq(session.entries[1].position, 1,
		"celui qui a roulé passe devant sans qu'on ait à le dire")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `classer()` n'existe pas.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/race/race_session.gd`, ajoute la méthode après `avancer` :

```gdscript
## Attribue les places, 1 au plus avancé. Trie sur la distance parcourue et
## sur rien d'autre : un couple (tour, position sur l'axe) mettrait devant un
## kart qui a reculé sous la ligne, parce que sa position d'axe est alors
## proche de la fin du tour. `total` porte le signe que ce couple perd.
func classer() -> void:
	var ordre := entries.duplicate()
	ordre.sort_custom(func(a: RaceEntry, b: RaceEntry) -> bool:
		return a.progress.total > b.progress.total)
	for i in ordre.size():
		ordre[i].position = i + 1
```

et appelle-la à la fin de `_physics_process` :

```gdscript
func _physics_process(delta: float) -> void:
	for entree in entries:
		avancer(entree, entree.kart.global_position, delta)
	classer()
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+4 tests**, tout vert.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/race/race_session.gd tests/test_race_session.gd && rtk git commit -m "feat: classement trie sur la distance parcourue"
```

---

### Task 6 : `AIInput` — viser un point et braquer vers lui

**Files:**
- Create: `scripts/kart/ai_input.gd`
- Test: `tests/test_ai_input.gd`

Le cœur de l'IA, et rien d'autre : elle vise un point de la ligne de course situé devant elle, mesure l'écart entre son cap et la direction de ce point, et en tire un braquage. Le dérapage arrive à la tâche 7, les réglages de difficulté à la tâche 8.

**Elle travaille en repère boussole.** `kart.motor.heading` est un cap boussole ; le cap d'un vecteur `v` est `atan2(v.x, -v.z)`. Aucune rotation Godot n'apparaît dans ce fichier.

**La session lui donne sa position et sa distance.** Les lire elle-même coûterait une projection de plus par kart et par image — huit projections gratuites —, et surtout `global_position` interdirait de la tester hors de l'arbre. Ces champs ont donc un temps d'image de retard sur la physique : c'est sans importance pour une IA, et c'est même plutôt réaliste.

- [ ] **Step 1 : Écrire les tests qui échouent**

Crée `tests/test_ai_input.gd` :

```gdscript
extends GutTest

## L'IA ne touche jamais à l'arbre de scènes : la session lui donne sa position
## et sa distance, elle rend un KartCommand. Elle se teste donc comme
## KartMotor, en posant un kart quelque part et en lisant ce qu'elle décide.

var piste: TrackCurve
var kart: Kart
var ia: AIInput


## Un anneau parcouru dans le sens des lacets croissants.
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
	piste = TrackCurve.new(_anneau(), 9.0)
	kart = Kart.new()
	kart.stats = KartStats.new()
	kart.motor = KartMotor.new(kart.stats)
	ia = AIInput.new()
	ia.kart = kart
	ia.track = piste


func after_each() -> void:
	ia.free()
	kart.free()


## Pose l'IA à la distance donnée, sur la ligne de course, cap donné.
func _poser(distance: float, cap: float) -> void:
	ia.distance = distance
	ia.position = piste.racing_line_at(distance)
	kart.motor.heading = cap
	kart.motor.velocity_dir = cap
	kart.motor.speed = 15.0


func test_elle_met_les_gaz() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_almost_eq(cmd.throttle, 1.0, 0.001,
		"la difficulté ne se règle pas en bridant la vitesse")
	assert_almost_eq(cmd.brake, 0.0, 0.001)


func test_dans_l_axe_elle_ne_braque_presque_pas() -> void:
	# Sur un anneau, viser devant soi demande toujours un peu de braquage :
	# on tolère un quart de butée, pas plus.
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_lt(absf(cmd.steer), 0.25,
		"dans l'axe d'un virage large, elle ne doit pas tirer à fond")


func test_desaxee_vers_la_gauche_elle_braque_a_droite() -> void:
	# Cap tourné de 30° vers la gauche : la cible est à droite du kart, donc
	# le braquage doit être positif (convention boussole).
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(30.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_gt(cmd.steer, 0.5, "un écart de 30° doit produire un braquage franc à droite")


func test_desaxee_vers_la_droite_elle_braque_a_gauche() -> void:
	_poser(0.0, piste.yaw_at(0.0) + deg_to_rad(30.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_lt(cmd.steer, -0.5, "et symétriquement à gauche")


func test_le_braquage_est_borne() -> void:
	_poser(0.0, piste.yaw_at(0.0) + deg_to_rad(170.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_between(cmd.steer, -1.0, 1.0,
		"même à contresens, la commande reste dans les bornes du joueur")


func test_elle_vise_plus_loin_quand_elle_va_vite() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	kart.motor.speed = 5.0
	var court := ia.point_vise()
	kart.motor.speed = 20.0
	var loin := ia.point_vise()
	var d_court := piste.distance_of(court)
	var d_loin := piste.distance_of(loin)
	assert_gt(d_loin, d_court,
		"viser à durée constante veut dire viser plus loin quand on va plus vite")


func test_a_l_arret_elle_vise_quand_meme_devant() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	kart.motor.speed = 0.0
	var vise := ia.point_vise()
	var d := piste.distance_of(vise)
	assert_gt(d, 1.0,
		"sans plancher, un kart à l'arrêt viserait ses propres roues et ne partirait jamais")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `AIInput` introuvable.

- [ ] **Step 3 : Écrire l'implémentation**

Crée `scripts/kart/ai_input.gd` :

```gdscript
class_name AIInput
extends KartInput

## Pilote automatique. Elle vise un point de la ligne de course situé à une
## demi-seconde de trajet devant elle, mesure l'écart entre son cap et la
## direction de ce point, et en tire un braquage.
##
## Elle passe par le même KartCommand que le joueur, donc elle est enfermée
## dans la même physique : elle ne peut pas prendre un virage que le joueur ne
## pourrait pas prendre, et elle dérape pour de vrai, avec les mêmes étincelles.
##
## Tous les angles sont des caps boussole — positif vers la droite — comme dans
## KartMotor et TrackCurve. Aucune rotation Godot n'apparaît ici.

## Durée de trajet qui sépare le kart de son point de mire. Plus elle est
## grande, plus l'IA anticipe et plus ses trajectoires sont propres.
@export var aim_time: float = 0.45

## Distance de mire minimale, en mètres. Sans elle, un kart à l'arrêt viserait
## ses propres roues et ne démarrerait jamais.
@export var aim_minimum: float = 6.0

## Écart de cap, en degrés, au-delà duquel l'IA braque à fond.
@export var full_steer_angle_deg: float = 20.0

## Renseignés par la session avant chaque image. Les lire soi-même coûterait
## une projection de plus par kart, et global_position interdirait de tester
## cette classe hors de l'arbre.
var track: TrackCurve
var distance: float = 0.0
var position := Vector3.ZERO


## Le point de mire, sur la ligne de course, devant le kart.
func point_vise() -> Vector3:
	var avance := maxf(kart.motor.speed * aim_time, aim_minimum)
	return track.racing_line_at(distance + avance)


func _fill(_delta: float) -> void:
	command.throttle = 1.0
	command.steer = _braquage()


## Écart de cap entre la direction du kart et celle du point de mire, en
## radians, ramené dans [-PI, PI]. Positif = la cible est à droite.
func ecart_de_cap() -> float:
	var vers := point_vise() - position
	vers.y = 0.0
	if vers.length_squared() < 0.0001:
		return 0.0
	var cap_voulu := atan2(vers.x, -vers.z)
	return wrapf(cap_voulu - kart.motor.heading, -PI, PI)


func _braquage() -> float:
	var plein := deg_to_rad(full_steer_angle_deg)
	return clampf(ecart_de_cap() / plein, -1.0, 1.0)
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+7 tests et +1 script**, tout vert.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/ai_input.gd scripts/kart/ai_input.gd.uid tests/test_ai_input.gd tests/test_ai_input.gd.uid && rtk git commit -m "feat: l IA vise un point devant elle et braque vers lui"
```

---

### Task 7 : L'IA dérape

**Files:**
- Modify: `scripts/kart/ai_input.gd`
- Test: `tests/test_ai_input.gd`

Une IA qui ne dérape pas ne charge jamais de mini-turbo, et se fait donc distancer par n'importe quel joueur qui, lui, dérape. Elle déclenche la glisse au-delà d'un seuil d'écart de cap, et la tient jusqu'au palier visé.

`KartMotor` expose déjà ce qu'il faut : `state`, `drift_charge` et `tier_for_charge(charge)`. L'IA ne fait que décider du booléen `drift`, exactement comme le joueur appuie ou relâche sa gâchette.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à la fin de `tests/test_ai_input.gd` :

```gdscript
func test_elle_ne_derape_pas_en_ligne_droite() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "déraper tout droit ne charge rien et ralentit")


func test_elle_declenche_la_glisse_sur_un_gros_ecart() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var cmd := ia.poll(1.0 / 60.0)
	assert_true(cmd.drift, "un virage franc se prend en dérapage")


func test_elle_ne_derape_pas_trop_lentement() -> void:
	# En dessous de min_drift_speed le moteur refuse la glisse : insister ne
	# ferait que garder la gâchette enfoncée pour rien.
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	kart.motor.speed = kart.stats.min_drift_speed - 1.0
	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "trop lente pour glisser, elle n'essaie pas")


func test_elle_tient_la_glisse_jusqu_au_palier_vise() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	ia.drift_release_tier = 2
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	# Charge correspondant au palier 1 : elle en veut un de plus.
	kart.motor.drift_charge = kart.stats.drift_tiers[0]
	assert_eq(kart.motor.tier_for_charge(kart.motor.drift_charge), 1,
		"prémisse du test : on est bien au palier 1")

	var cmd := ia.poll(1.0 / 60.0)
	assert_true(cmd.drift, "elle ne lâche pas un palier trop tôt")


func test_elle_lache_la_glisse_au_palier_vise() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	ia.drift_release_tier = 2
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	kart.motor.drift_charge = kart.stats.drift_tiers[1]
	assert_eq(kart.motor.tier_for_charge(kart.motor.drift_charge), 2,
		"prémisse du test : on est bien au palier 2")

	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift, "palier atteint, elle encaisse son turbo")


func test_elle_lache_la_glisse_quand_la_route_se_redresse() -> void:
	# Cap redevenu aligné : garder la glisse ferait sortir le kart de la piste.
	_poser(0.0, piste.yaw_at(0.0))
	ia.drift_release_tier = 3
	kart.motor.state = KartMotor.State.DRIFT
	kart.motor.drift_dir = 1
	kart.motor.drift_charge = 0.1

	var cmd := ia.poll(1.0 / 60.0)
	assert_false(cmd.drift,
		"une glisse qu'on tient en ligne droite finit dans le décor")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `drift_release_tier` n'existe pas, et `command.drift` vaut toujours `false`.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/kart/ai_input.gd`, ajoute les réglages auprès des autres :

```gdscript
## Écart de cap, en degrés, à partir duquel l'IA engage le dérapage.
@export var drift_entry_angle_deg: float = 32.0

## Écart de cap, en degrés, en dessous duquel elle lâche une glisse en cours.
## Plus bas que l'entrée, pour ne pas battre de l'aile à la frontière.
@export var drift_exit_angle_deg: float = 14.0

## Palier de mini-turbo visé avant de lâcher, de 1 à 3. Une IA gourmande tient
## la glisse plus longtemps et sort plus vite — c'est un des quatre leviers de
## difficulté, et le seul qui se voie à l'œil nu.
@export var drift_release_tier: int = 2
```

puis complète `_fill` :

```gdscript
func _fill(_delta: float) -> void:
	command.throttle = 1.0
	command.steer = _braquage()
	command.drift = _veut_deraper()
```

et ajoute la décision :

```gdscript
## Le dérapage se décide comme le joueur appuie : un booléen, rien de plus.
## Le moteur reste seul juge de ce qu'il en fait.
func _veut_deraper() -> bool:
	if kart.motor.speed < kart.stats.min_drift_speed:
		return false

	var angle := absf(rad_to_deg(ecart_de_cap()))
	if kart.motor.state == KartMotor.State.DRIFT:
		# Une glisse tenue en ligne droite finit dans le décor, et une glisse
		# lâchée trop tôt ne rapporte rien : on sort au premier des deux.
		var palier := kart.motor.tier_for_charge(kart.motor.drift_charge)
		return palier < drift_release_tier and angle > drift_exit_angle_deg

	return angle > drift_entry_angle_deg
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+6 tests**, tout vert.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/ai_input.gd tests/test_ai_input.gd && rtk git commit -m "feat: l IA derape et encaisse ses mini-turbos"
```

---

### Task 8 : Les leviers de difficulté

**Files:**
- Modify: `scripts/kart/ai_input.gd`
- Test: `tests/test_ai_input.gd`

Le spec est catégorique : **une IA facile est une IA qui pilote mal, pas une IA bridée.** Aucune de ces variables ne touche à la vitesse.

Trois leviers manquent encore — le quatrième, la gourmandise au dérapage, existe depuis la tâche 7.

| Levier | Effet quand on l'augmente |
|---|---|
| `aim_time` | anticipe davantage, trajectoires plus propres |
| `lateral_bias` | s'écarte de la ligne idéale d'un décalage constant |
| `reaction_delay` | rafraîchit sa décision moins souvent, donc rate les corrections fines |

`reaction_delay` se modélise en ne **recalculant** la décision que toutes les `reaction_delay` secondes et en tenant la précédente entre-temps. C'est plus honnête qu'un lissage : une IA lente ne braque pas mollement, elle braque en retard.

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à la fin de `tests/test_ai_input.gd` :

```gdscript
func test_le_decalage_lateral_deplace_la_mire() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var propre := ia.point_vise()
	ia.lateral_bias = 4.0
	var decale := ia.point_vise()

	var d := piste.distance_of(propre)
	var vers := decale - propre
	vers.y = 0.0
	assert_almost_eq(vers.dot(piste.right_at(d)), 4.0, 0.3,
		"un biais positif vise quatre mètres à droite de la ligne idéale")


func test_le_decalage_lateral_ne_change_pas_la_distance_de_mire() -> void:
	_poser(0.0, piste.yaw_at(0.0))
	var avant := piste.distance_of(ia.point_vise())
	ia.lateral_bias = 4.0
	var apres := piste.distance_of(ia.point_vise())
	assert_almost_eq(apres, avant, 1.0,
		"se décaler sur le côté ne veut pas dire viser plus loin")


func test_sans_delai_elle_decide_a_chaque_image() -> void:
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var premier := ia.poll(1.0 / 60.0).steer
	# Le kart se réaligne d'un coup : sans délai, la commande suit tout de suite.
	kart.motor.heading = piste.yaw_at(0.0)
	var second := ia.poll(1.0 / 60.0).steer
	assert_lt(absf(second), absf(premier) - 0.2,
		"sans délai de réaction, elle corrige dans l'image")


func test_le_delai_de_reaction_fige_la_commande() -> void:
	ia.reaction_delay = 0.25
	_poser(0.0, piste.yaw_at(0.0) - deg_to_rad(40.0))
	var premier := ia.poll(1.0 / 60.0).steer

	kart.motor.heading = piste.yaw_at(0.0)
	var tout_de_suite := ia.poll(1.0 / 60.0).steer
	assert_almost_eq(tout_de_suite, premier, 0.0001,
		"une IA lente braque en retard, elle ne braque pas mollement")

	# Après le délai, elle finit par voir.
	for i in 20:
		ia.poll(1.0 / 60.0)
	var plus_tard := ia.poll(1.0 / 60.0).steer
	assert_lt(absf(plus_tard), absf(premier) - 0.2,
		"le retard finit par se rattraper")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `lateral_bias` et `reaction_delay` n'existent pas.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/kart/ai_input.gd`, ajoute les deux réglages :

```gdscript
## Décalage constant par rapport à la ligne idéale, en mètres vers la droite.
## Une IA qui vise systématiquement à côté pilote mal sans jamais être bridée.
@export var lateral_bias: float = 0.0

## Intervalle entre deux décisions, en secondes. Zéro veut dire une décision
## par image. Au-delà, l'IA tient sa commande précédente : elle braque en
## retard plutôt que mollement, ce qui est la façon dont un humain rate un
## virage.
@export var reaction_delay: float = 0.0
```

et les champs d'état qui vont avec :

```gdscript
var _depuis_decision: float = 0.0
var _steer_decide: float = 0.0
var _drift_decide: bool = false
var _jamais_decide: bool = true
```

Modifie `point_vise` pour porter le biais :

```gdscript
## Le point de mire, sur la ligne de course, devant le kart. Le biais latéral
## s'applique à ce point et non à la distance : viser à côté ne veut pas dire
## viser plus loin.
func point_vise() -> Vector3:
	var avance := maxf(kart.motor.speed * aim_time, aim_minimum)
	var ou := distance + avance
	return track.racing_line_at(ou) + track.right_at(ou) * lateral_bias
```

et remplace `_fill` par :

```gdscript
func _fill(delta: float) -> void:
	_depuis_decision += delta
	if _jamais_decide or _depuis_decision >= reaction_delay:
		_jamais_decide = false
		_depuis_decision = 0.0
		_steer_decide = _braquage()
		_drift_decide = _veut_deraper()

	command.throttle = 1.0
	command.steer = _steer_decide
	command.drift = _drift_decide
```

- [ ] **Step 4 : Lancer les tests**

Attendu : **+4 tests**, tout vert.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/ai_input.gd tests/test_ai_input.gd && rtk git commit -m "feat: les quatre leviers de difficulte de l IA"
```

---

### Task 9 : La session nourrit l'IA

**Files:**
- Modify: `scripts/race/race_session.gd`
- Test: `tests/test_race_session.gd`

`AIInput.track`, `AIInput.distance` et `AIInput.position` ne sont renseignés par personne. La session les remplit, puisqu'elle projette déjà chaque kart une fois par image.

**Un temps d'image de retard, assumé.** L'ordre d'exécution de `_physics_process` suit l'ordre de l'arbre : les karts sont déclarés avant la session dans `race.tscn`, donc chaque IA décide à partir des valeurs écrites à l'image précédente. Pour une IA, c'est sans conséquence — et le premier tour d'horloge est couvert parce que `demarrer()` renseigne les valeurs initiales.

- [ ] **Step 1 : Écrire les tests qui échouent**

Dans `tests/test_race_session.gd`, `_monter` gagne un paramètre : les mêmes karts, mais pilotés. Remplace sa signature et sa boucle par :

```gdscript
func _monter(combien: int, avec_ia: bool = false) -> void:
	_demonter()
	track = Track.new()
	track.half_width = 9.0
	track.track_curve = TrackCurve.new(_anneau(), 9.0)
	session = RaceSession.new()
	for i in combien:
		var k := _kart()
		karts.append(k)
		if avec_ia:
			var cerveau := AIInput.new()
			cerveau.kart = k
			cerveaux.append(cerveau)
			session.brancher_ia(cerveau)
	session.demarrer(track, karts)
```

`_demonter` libère déjà `cerveaux` : rien d'autre à changer dans le démontage.

Puis ajoute les deux tests à la fin du fichier :

```gdscript
func test_la_session_branche_l_ia_sur_le_circuit() -> void:
	_monter(1, true)

	assert_eq(cerveaux[0].track, track.track_curve,
		"sans circuit, l'IA ne sait pas où viser")
	assert_almost_eq(cerveaux[0].distance, session.entries[0].progress.distance, 0.001,
		"et elle part de sa case de grille, pas de la ligne")
	assert_gt(cerveaux[0].position.length(), 1.0,
		"amorcée sur sa case, pas sur l'origine du monde")


func test_avancer_tient_l_ia_a_jour() -> void:
	_monter(1, true)

	var ou := track.track_curve.position_at(60.0)
	session.avancer(session.entries[0], ou, 1.0 / 60.0)

	assert_almost_eq(cerveaux[0].distance, 60.0, 0.5,
		"l'IA doit savoir où elle est rendue")
	assert_almost_eq(cerveaux[0].position.distance_to(ou), 0.0, 0.001,
		"et à quel endroit exactement, pour mesurer son écart à la ligne")
```

- [ ] **Step 2 : Lancer et vérifier l'échec**

Attendu : ÉCHEC — `brancher_ia()` n'existe pas.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/race/race_session.gd`, ajoute le champ auprès des autres :

```gdscript
var _cerveaux: Array[AIInput] = []
```

Ajoute la méthode d'enregistrement, avant `demarrer` :

```gdscript
## Déclare une IA à nourrir. Appelée depuis _ready pour chaque kart dont
## l'entrée en est une ; les tests l'appellent directement.
func brancher_ia(cerveau: AIInput) -> void:
	if cerveau != null and not _cerveaux.has(cerveau):
		_cerveaux.append(cerveau)
```

Dans `_ready`, après avoir résolu chaque kart et **avant** `demarrer(piste, pilotes)`, ajoute la collecte :

```gdscript
	for k in pilotes:
		for enfant in k.get_children():
			if enfant is AIInput:
				brancher_ia(enfant as AIInput)
```

Dans `demarrer`, amorce chaque IA **à l'intérieur de la boucle de grille**, avec la case que tu viens de calculer :

```gdscript
		var entree := RaceEntry.new(pilotes[i], _track.track_curve, depart)
		entries.append(entree)
		# L'IA décide à partir des valeurs de l'image précédente : sans
		# amorçage, sa toute première décision viserait l'origine du monde.
		# On lui donne la case de grille et non kart.global_position, qui
		# échoue hors de l'arbre et rendrait cette ligne intestable.
		_nourrir_ia(entree, place.origin)
```

(la dernière ligne de la boucle devient donc ces quatre-là, à la place du simple `entries.append(...)`)

et dans `avancer`, juste après `entree.progress.update(point)` :

```gdscript
	_nourrir_ia(entree, point)
```

Enfin, la méthode elle-même :

```gdscript
## Donne à l'IA de ce kart ce qu'elle ne peut pas aller chercher seule. Elle
## pourrait projeter sa propre position, mais ce serait une projection de plus
## par kart et par image — et lire global_position l'empêcherait d'être testée
## hors de l'arbre.
func _nourrir_ia(entree: RaceEntry, point: Vector3) -> void:
	for cerveau in _cerveaux:
		if cerveau.kart == entree.kart:
			cerveau.track = _track.track_curve
			cerveau.distance = entree.progress.distance
			cerveau.position = point
			return
```

**Pourquoi l'amorçage ne lit pas le kart.** `global_position` et `global_transform` échouent tous les deux hors de l'arbre de scènes — c'est précisément ce qui a motivé toutes les coutures de ce dépôt. La case de grille, elle, vient d'être calculée : on la passe.

- [ ] **Step 4 : Lancer les tests**

Attendu : **+2 tests**, tout vert. GUT ne doit signaler **aucun nœud orphelin** : si `_demonter` oublie un cerveau ou un kart, il le dira.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/race/race_session.gd tests/test_race_session.gd && rtk git commit -m "feat: la session nourrit les IA en position et en distance"
```

---

### Task 10 : Le kart de l'IA et la scène à huit

**Files:**
- Create: `scenes/kart/ai_kart.tscn`
- Modify: `scenes/race.tscn`

- [ ] **Step 1 : Écrire la scène du kart piloté**

Crée `scenes/kart/ai_kart.tscn`. C'est `kart.tscn` avec `AIInput` à la place de `PlayerInput` — un `.tscn` ne peut pas partager de sous-ressource avec un autre fichier, et une scène héritée ne sait pas supprimer le nœud dont elle hérite, d'où la copie. Le jalon 7 refera l'apparence du kart et c'est là qu'on collapsera les deux.

```
[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/kart/kart.gd" id="1_kart"]
[ext_resource type="Script" path="res://scripts/kart/ai_input.gd" id="2_input"]
[ext_resource type="Resource" path="res://resources/karts/default_kart.tres" id="3_stats"]
[ext_resource type="Script" path="res://scripts/kart/kart_visuals.gd" id="4_visuals"]

[sub_resource type="BoxShape3D" id="Shape_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="BoxMesh" id="Mesh_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="StandardMaterial3D" id="Mat_body"]
albedo_color = Color(0.78, 0.35, 0.3, 1)

[sub_resource type="ParticleProcessMaterial" id="Proc_sparks"]
emission_shape = 1
emission_sphere_radius = 0.25
direction = Vector3(0, 1, 0)
spread = 45.0
initial_velocity_min = 1.5
initial_velocity_max = 3.0
gravity = Vector3(0, -2, 0)
scale_min = 0.05
scale_max = 0.12

[sub_resource type="QuadMesh" id="Mesh_spark"]
size = Vector2(0.1, 0.1)

[node name="AIKart" type="CharacterBody3D"]
script = ExtResource("1_kart")
stats = ExtResource("3_stats")
input_path = NodePath("AIInput")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
shape = SubResource("Shape_body")

[node name="Body" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
mesh = SubResource("Mesh_body")
surface_material_override/0 = SubResource("Mat_body")

[node name="Sparks" type="GPUParticles3D" parent="Body"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.2, 0.9)
emitting = false
amount = 24
lifetime = 0.35
process_material = SubResource("Proc_sparks")
draw_pass_1 = SubResource("Mesh_spark")

[node name="AIInput" type="Node" parent="."]
script = ExtResource("2_input")

[node name="Visuals" type="Node3D" parent="."]
script = ExtResource("4_visuals")
kart_path = NodePath("..")
body_path = NodePath("../Body")
sparks_path = NodePath("../Body/Sparks")
```

`load_steps` vaut 10 : quatre `ext_resource` et cinq `sub_resource`, plus un. Recompte-le à la main — Godot ne signale pas un compte faux en headless. La carrosserie est rouge pour distinguer les adversaires du kart gris du joueur.

- [ ] **Step 2 : Mettre sept adversaires dans la scène de course**

Dans `scenes/race.tscn` :

1. Ajoute la ressource de scène, après celle du kart du joueur :

```
[ext_resource type="PackedScene" path="res://scenes/kart/ai_kart.tscn" id="6_ai"]
```

2. Incrémente `load_steps` de 1 — il passe de 7 à **8**.

3. Ajoute sept instances, après le nœud `Kart` :

```
[node name="AIKart1" parent="." instance=ExtResource("6_ai")]

[node name="AIKart2" parent="." instance=ExtResource("6_ai")]

[node name="AIKart3" parent="." instance=ExtResource("6_ai")]

[node name="AIKart4" parent="." instance=ExtResource("6_ai")]

[node name="AIKart5" parent="." instance=ExtResource("6_ai")]

[node name="AIKart6" parent="." instance=ExtResource("6_ai")]

[node name="AIKart7" parent="." instance=ExtResource("6_ai")]
```

4. Remplace la ligne `kart_paths` du nœud `Session` par :

```
kart_paths = [NodePath("../Kart"), NodePath("../AIKart1"), NodePath("../AIKart2"), NodePath("../AIKart3"), NodePath("../AIKart4"), NodePath("../AIKart5"), NodePath("../AIKart6"), NodePath("../AIKart7")]
```

Le joueur reste en tête de liste : c'est l'indice 0 que le HUD suit.

- [ ] **Step 3 : Vérifier le chargement**

```bash
"$GODOT" --headless --quit-after 300 scenes/race.tscn
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : la bannière et rien d'autre — aucune ligne `ERROR` ni `SCRIPT ERROR` —, et **le même nombre de tests qu'avant** : cette tâche n'en ajoute aucun.

- [ ] **Step 4 : Commit**

```bash
rtk git add scenes/kart/ai_kart.tscn scenes/race.tscn && rtk git commit -m "feat: sept adversaires sur la grille"
```

---

### Task 11 : Le HUD affiche la place

**Files:**
- Modify: `scripts/ui/race_hud.gd`

- [ ] **Step 1 : Ajouter la ligne de position**

Dans `scripts/ui/race_hud.gd`, remplace le corps de `_process` par :

```gdscript
func _process(_delta: float) -> void:
	if _session.entries.is_empty():
		return
	var moi := _session.entries[0]
	var tour := mini(moi.progress.lap + 1, _session.lap_count)
	var lignes := PackedStringArray()
	lignes.append("%de / %d" % [maxi(moi.position, 1), _session.entries.size()])
	lignes.append("TOUR %d/%d" % [tour, _session.lap_count])
	lignes.append(RaceTimer.format(moi.timer.current))
	if moi.timer.has_best:
		lignes.append("MEILLEUR %s" % RaceTimer.format(moi.timer.best))
	if moi.finished:
		lignes.append("ARRIVÉE")
	_label.text = "\n".join(lignes)
```

Et mets à jour la docstring de la classe, qui annonce encore trois informations :

```gdscript
## Quatre informations, pas une de plus : la place, le tour, le chrono, le
## meilleur temps. Le palier de mini-turbo n'y figure pas — c'est la couleur
## des étincelles qui le dit, et le joueur ne doit pas avoir à quitter la route
## des yeux.
```

`maxi(moi.position, 1)` couvre la toute première image, avant que `classer()` n'ait tourné : afficher « 0e » serait un bug visible.

- [ ] **Step 2 : Mesurer ce qu'affiche le HUD**

Cette tâche n'ajoute aucun test — le HUD est de l'affichage, et le juger demande des yeux. Mais on peut mesurer la chaîne. Écris un script jetable (**non commité**) qui monte `scenes/race.tscn` au premier `_process()`, laisse tourner deux secondes, et **rapporte le texte exact du `Label`** à l'image 1 puis après 2 s.

Attendu à l'image 1 : la place vaut `1e` ou une autre place plausible entre 1 et 8, le tour vaut `1/3`, et le chrono démarre à `0:00.000`. **Rapporte la chaîne, pas une appréciation.**

- [ ] **Step 3 : Lancer les tests**

Attendu : le même nombre qu'avant, tout vert.

- [ ] **Step 4 : Commit**

```bash
rtk git add scripts/ui/race_hud.gd && rtk git commit -m "feat: le HUD affiche la place au classement"
```

---

### Task 12 : L'IA sait-elle boucler un tour ?

**Files:** aucun fichier suivi modifié, sauf si la mesure révèle un défaut.

Toute la campagne peut être verte sans qu'aucune IA n'ait jamais bouclé un tour de `track_01`. Les tests tournent sur un anneau de rayon 50 à courbure constante ; le vrai circuit a une épingle de 13,3 m de rayon d'axe, et le kart tourne au mieux à 12,3 m en adhérence et 10,5 m en dérapage. **C'est là que ça se joue, et aucun test ne le couvre.**

- [ ] **Step 1 : Monter le banc et mesurer**

Écris un script jetable (**non commité**, supprimé avant le commit) qui monte `scenes/race.tscn` au premier `_process()`, laisse tourner l'équivalent de trois tours de course, et **rapporte les nombres** :

1. **Combien des huit karts finissent les trois tours ?** Et en combien de temps chacun ?
2. **Combien de remises en piste** au total, et réparties comment le long du circuit ? Une IA qui se fait ramasser vingt fois dans l'épingle n'est pas une IA.
3. **Le meilleur tour de chaque kart.** Un humain qui pilote bien tourne dans quelle fourchette ? Compare au meilleur temps IA.
4. **L'écart latéral maximal à l'axe** atteint par chaque IA, et à quelle distance. Là où elles frôlent le bord, le tracé de l'épingle est-il en cause ou le réglage de l'IA ?
5. **Le classement final est-il cohérent** avec l'ordre d'arrivée chronométré ?

- [ ] **Step 2 : Régler, une variable à la fois**

Si une IA ne boucle pas, les leviers sont, dans cet ordre de préférence :

1. `full_steer_angle_deg` — trop grand, elle braque mou et rate l'épingle ; trop petit, elle zigzague ;
2. `aim_time` — trop court, elle coupe et sort ; trop long, elle arrondit tout et frôle l'intérieur ;
3. `drift_entry_angle_deg` — si elle entre en glisse dans les courbes rapides, elle part au large.

**Ne touche pas à `KartStats`.** Le pilotage du joueur a été réglé à la main lors d'une session de conduite ; le modifier pour arranger l'IA reviendrait à abîmer le jeu pour réparer l'adversaire. Si le pilotage semble en cause, **arrête-toi et dis-le**.

Consigne chaque réglage retenu avec le chiffre qui l'a motivé, dans un commentaire à côté de la valeur.

- [ ] **Step 3 : Commit, si quelque chose a bougé**

```bash
rtk git add scripts/kart/ai_input.gd && rtk git commit -m "tune: reglages de l IA mesures sur le circuit 1"
```

---

### Task 13 : Le point de validation

**Files:** aucun.

Rien de ce qui précède ne dit si la course est **amusante**. Ça ne se mesure pas en headless, et aucun agent ne peut le faire.

Lancer le jeu et juger :

- **La grille a-t-elle l'air d'une grille ?** Huit karts alignés sur deux colonnes, ou un tas informe ?
- **Les adversaires pilotent-ils de façon crédible ?** Le spec demande qu'une IA facile pilote mal, pas qu'elle roule lentement. Est-ce que ça se voit ?
- **Les dépassements sont-ils possibles**, ou l'IA est-elle un mur ?
- **La place au classement est-elle lisible** dans le feu de l'action ?
- **Se faire doubler fait-il quelque chose ?** S'il ne se passe rien émotionnellement, ce sont les objets qui manquent — et c'est le plan 4.

Ce qui reste hors de ce plan, et qu'il ne faut pas prendre pour des bugs : pas de décompte au départ, pas d'objets, pas d'écran de fin, et les karts se traversent (aucune collision entre karts n'est gérée).

---

## Ce que ce plan ne fait pas

- **Les collisions entre karts.** Huit karts sur une grille vont se rentrer dedans. `move_and_slide()` les fera glisser les uns contre les autres, mais `motor.speed` n'est jamais réconcilié après une collision — un kart bloqué contre un autre gardera sa vitesse au compteur tout en n'avançant pas. C'est la dette la plus visible de ce plan, et elle mérite sa propre tâche une fois qu'on aura vu ce que ça donne à l'écran.
- **Le décompte de départ.** Les huit karts partent à l'image 1. Le spec le prévoit dans `RaceDirector` ; ça viendra avec l'écran de fin, au jalon 9.
- **Les objets.** Jalon 6, plan suivant. `KartCommand.use_item` existe déjà et n'est lu par personne.
- **Le rattrapage élastique.** Le spec l'autorise en dernier recours, sur l'accélération et jamais sur la vitesse de pointe. On ne l'écrit pas tant que la mesure de la tâche 12 n'a pas montré qu'il manque.
