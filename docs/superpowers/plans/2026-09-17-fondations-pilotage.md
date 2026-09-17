# Fondations de pilotage — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Obtenir un kart pilotable sur un plan nu, avec dérapage à mini-turbo, caméra dynamique et étincelles colorées — le point de validation du jalon 3 du spec.

**Architecture:** Toute la physique vit dans `KartMotor`, un `RefCounted` qui transforme un `KartCommand` et un delta en nouvel état, sans jamais toucher à l'arbre de scènes. Le nœud `Kart` ne fait que lui fournir des commandes et appliquer la vitesse résultante. C'est cette séparation qui rend les neuf dixièmes de la logique testables sans lancer le jeu.

**Tech Stack:** Godot 4 (backend de rendu Compatibility / OpenGL 3.3), GDScript typé statiquement, GUT pour les tests unitaires.

**Spec de référence :** `docs/superpowers/specs/2026-09-17-karting-3d-design.md`

---

## Écarts assumés par rapport au spec

Trois points à connaître avant de commencer — ils sont délibérés, pas des oublis.

**Le turbo est un modificateur, pas un état.** La machine à états du spec (§4.2) présente `TURBO` comme un état à part. À l'implémentation c'est faux : on doit pouvoir continuer à déraper pendant un turbo, et enchaîner un second dérapage sans attendre la fin du premier boost. Les états réels sont donc `ADHÉRENCE`, `SAUT`, `DÉRAPAGE`, `SONNÉ`, et `boost_timer` tourne en parallèle en modifiant la vitesse maximale.

**Le sol est plat dans ce plan.** La suspension par quatre raycasts et l'alignement sur la pente décrits au spec arrivent avec le circuit réel, dans le plan 2. Ici, `is_on_floor()` et une gravité simple suffisent, et l'état `SONNÉ` n'est pas encore déclenché par quoi que ce soit — il sera câblé aux objets dans le plan 3. Le champ existe dès maintenant pour ne pas avoir à rouvrir le moteur.

**Les scènes sont écrites à la main.** Les fichiers `.tscn` sont du texte et sont donnés en entier dans les tâches, de sorte que tout le plan s'exécute sans ouvrir l'éditeur. Le format est stable en Godot 4, mais si un chargement se plaint d'un `load_steps` incorrect, la valeur attendue est le total des `ext_resource` et `sub_resource` plus un. Même logique pour les actions d'entrée : plutôt que de sérialiser des `InputEvent` à la main, on les fait écrire par le moteur (Task 9).

## Convention de commit

Depuis la 4.4, Godot génère un fichier `.uid` à côté de chaque script au premier scan. **Ces fichiers se commitent**, systématiquement et avec le script qu'ils accompagnent. Ils portent l'identifiant stable de la ressource, utilisé pour les références entre fichiers : les laisser hors du dépôt fait diverger les UID d'un clone à l'autre et casse la résolution des références. Les lignes `git add` des tâches ne les listent pas une par une ; ajoute-les sans le demander.

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `scripts/kart/kart_command.gd` | Données d'intention : braquage, gaz, frein, dérapage, objet |
| `scripts/kart/kart_stats.gd` | Ressource de réglage, éditable moteur tournant |
| `scripts/kart/kart_motor.gd` | Toute la physique arcade. Aucune dépendance à la scène |
| `scripts/kart/kart_input.gd` | Classe de base des sources de commande |
| `scripts/kart/player_input.gd` | Lecture clavier et manette |
| `scripts/kart/kart.gd` | Nœud `CharacterBody3D` : relie input, moteur et déplacement |
| `scripts/kart/kart_visuals.gd` | Inclinaison de la caisse et étincelles par palier |
| `scripts/camera/chase_camera.gd` | Suivi à ressort et FOV indexé sur la vitesse |
| `tests/test_kart_motor.gd` | Tests unitaires de la physique |

---

### Task 1 : Projet Godot et harnais de test

**Files:**
- Create: `project.godot`
- Create: `tests/test_harness.gd`
- Create: `addons/gut/` (dépendance externe)

- [ ] **Step 1 : Créer le projet Godot**

Crée `project.godot` à la racine. La version installée sur cette machine est **Godot 4.7.2**, d'où le `4.7`.

```ini
config_version=5

[application]
config/name="Karting"
config/features=PackedStringArray("4.7", "GL Compatibility")

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 2 : Installer GUT**

```bash
rtk git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut
mkdir -p addons
cp -r /tmp/gut/addons/gut addons/gut
rm -rf /tmp/gut
```

Si GUT refuse de se charger sous Godot 4.7, prends la release taguée la plus récente du dépôt plutôt que `main` — c'est le seul point du plan où une incompatibilité de version est plausible, et il se manifeste immédiatement au Step 4.

Le runner en ligne de commande (`gut_cmdln.gd`) fonctionne sans activer l'extension : le panneau dans l'éditeur n'est utile que pour lancer les tests à la souris. Aucune étape de ce plan n'en a besoin.

- [ ] **Step 3 : Écrire un test de fumée**

`tests/test_harness.gd` :

```gdscript
extends GutTest


func test_le_harnais_de_test_fonctionne() -> void:
	assert_eq(2 + 2, 4, "l'arithmétique de base doit fonctionner")
```

- [ ] **Step 4 : Lancer les tests**

Définis d'abord un raccourci vers ton binaire Godot — les commandes de tout le plan s'en servent :

```bash
export GODOT="/c/Users/alexa/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
```

Amorce ensuite le cache d'import, une seule fois :

```bash
"$GODOT" --headless --import
```

Sans cela, le tout premier lancement échoue sur `Some GUT class_names have not been imported` : un projet neuf n'a jamais eu son système de fichiers scanné, donc le `class_name GutTest` dont hérite le test n'est pas encore enregistré. Le piège est que la commande sort malgré tout en code 0 alors qu'aucun test n'a tourné — vérifie toujours le décompte, pas seulement le code de retour. Le cache vit dans `.godot/`, qui est ignoré par git : après un clone frais, il faut refaire cet import.

Puis :

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `1 passing`, sortie en code 0.

- [ ] **Step 5 : Commit**

```bash
rtk git add project.godot addons tests/test_harness.gd && rtk git commit -m "chore: projet Godot en rendu Compatibility et harnais GUT"
```

---

### Task 2 : Le contrat d'entrée et la ressource de réglage

**Files:**
- Create: `scripts/kart/kart_command.gd`
- Create: `scripts/kart/kart_stats.gd`
- Test: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire `KartCommand`**

`scripts/kart/kart_command.gd` :

```gdscript
class_name KartCommand
extends RefCounted

## Intention d'un pilote pour une frame. Produite par KartInput,
## consommée par KartMotor. Une seule instance par kart, réutilisée
## à chaque frame pour ne rien allouer dans _physics_process.

var steer: float = 0.0      ## -1.0 (gauche) .. 1.0 (droite)
var throttle: float = 0.0   ##  0.0 .. 1.0
var brake: float = 0.0      ##  0.0 .. 1.0
var drift: bool = false
var use_item: bool = false


func clear() -> void:
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	drift = false
	use_item = false
```

- [ ] **Step 2 : Écrire `KartStats`**

`scripts/kart/kart_stats.gd`. Les angles sont stockés en degrés pour rester lisibles dans l'inspecteur ; le moteur les convertit.

```gdscript
class_name KartStats
extends Resource

## Tous les réglages de pilotage. Éditable moteur tournant :
## c'est le fichier qu'on triture pendant les sessions de réglage.

@export_group("Vitesse")
@export var max_speed: float = 22.0
@export var acceleration: float = 14.0
@export var brake_force: float = 26.0
@export var coast_friction: float = 6.0

@export_group("Braquage")
@export var turn_rate: float = 2.4              ## rad/s à pleine vitesse

@export_group("Dérapage")
@export var min_drift_speed: float = 8.0
@export var drift_angle_min_deg: float = 30.0
@export var drift_angle_max_deg: float = 55.0
@export var drift_angle_rate_deg: float = 220.0 ## convergence de l'angle, deg/s
@export var drift_turn_rate: float = 2.8        ## rad/s pendant la glisse
@export var hop_duration: float = 0.15

@export_group("Mini-turbo")
@export var drift_tiers: PackedFloat32Array = PackedFloat32Array([0.6, 1.5, 2.6])
@export var boost_durations: PackedFloat32Array = PackedFloat32Array([0.5, 1.0, 1.8])
@export var boost_speed_multiplier: float = 1.35

@export_group("Pénalités")
@export var offroad_speed_multiplier: float = 0.6
@export var stun_duration: float = 1.2
```

- [ ] **Step 3 : Écrire le test qui vérifie les valeurs par défaut**

`tests/test_kart_motor.gd` — ce fichier accueillera tous les tests du moteur.

```gdscript
extends GutTest

var stats: KartStats
var cmd: KartCommand


func before_each() -> void:
	stats = KartStats.new()
	cmd = KartCommand.new()


func test_les_paliers_et_les_durees_de_turbo_vont_par_paires() -> void:
	assert_eq(stats.drift_tiers.size(), stats.boost_durations.size(),
		"chaque palier de charge doit avoir une durée de turbo correspondante")


func test_les_paliers_sont_strictement_croissants() -> void:
	for i in range(1, stats.drift_tiers.size()):
		assert_gt(stats.drift_tiers[i], stats.drift_tiers[i - 1],
			"le palier %d doit demander plus de charge que le précédent" % i)


func test_une_commande_effacee_est_neutre() -> void:
	cmd.steer = 1.0
	cmd.throttle = 1.0
	cmd.brake = 1.0
	cmd.drift = true
	cmd.use_item = true
	cmd.clear()
	assert_eq(cmd.steer, 0.0)
	assert_eq(cmd.throttle, 0.0)
	assert_eq(cmd.brake, 0.0)
	assert_false(cmd.drift)
	assert_false(cmd.use_item)
```

- [ ] **Step 4 : Lancer les tests**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `4 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_command.gd scripts/kart/kart_stats.gd tests/test_kart_motor.gd && rtk git commit -m "feat: contrat KartCommand et ressource de réglage KartStats"
```

---

### Task 3 : Le moteur — vitesse longitudinale

**Files:**
- Create: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute au début de `tests/test_kart_motor.gd`, après les variables existantes :

```gdscript
var motor: KartMotor
```

Complète `before_each()` :

```gdscript
func before_each() -> void:
	stats = KartStats.new()
	cmd = KartCommand.new()
	motor = KartMotor.new(stats)
```

Ajoute ce helper et ces quatre tests à la fin du fichier :

```gdscript
## Fait tourner le moteur pendant `seconds` à 60 Hz avec la commande courante.
func _run(seconds: float) -> void:
	var step := 1.0 / 60.0
	var elapsed := 0.0
	while elapsed < seconds:
		motor.step(cmd, step)
		elapsed += step


func test_les_gaz_accelerent_jusqu_a_la_vitesse_max() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.1,
		"dix secondes plein gaz doivent atteindre la vitesse maximale")


func test_la_vitesse_ne_depasse_jamais_le_maximum() -> void:
	cmd.throttle = 1.0
	_run(60.0)
	assert_lte(motor.speed, stats.max_speed + 0.001)


func test_relacher_les_gaz_fait_ralentir() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	var lancee := motor.speed
	cmd.throttle = 0.0
	_run(1.0)
	assert_lt(motor.speed, lancee, "sans gaz, la friction doit réduire la vitesse")


func test_le_frein_arrete_le_kart() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	cmd.throttle = 0.0
	cmd.brake = 1.0
	_run(3.0)
	assert_almost_eq(motor.speed, 0.0, 0.01, "trois secondes de frein doivent immobiliser le kart")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC, avec une erreur de parsing sur l'identifiant `KartMotor` introuvable.

- [ ] **Step 3 : Écrire l'implémentation minimale**

`scripts/kart/kart_motor.gd` :

```gdscript
class_name KartMotor
extends RefCounted

## Toute la physique arcade du kart. Ne connaît ni la scène, ni les nœuds,
## ni le temps réel : il transforme (état, commande, delta) en nouvel état.
## C'est ce qui le rend testable sans lancer le jeu.

enum State { GRIP, HOP, DRIFT, STUNNED }

var stats: KartStats

var state: int = State.GRIP
var speed: float = 0.0
var velocity_dir: float = 0.0   ## yaw du vecteur vitesse, en radians
var heading: float = 0.0        ## yaw de la caisse, en radians
var boost_timer: float = 0.0
var on_offroad: bool = false


func _init(kart_stats: KartStats) -> void:
	stats = kart_stats


func step(cmd: KartCommand, delta: float) -> void:
	_update_speed(cmd, delta)


## Vitesse maximale effective. Le turbo écrase la pénalité hors-piste :
## foncer dans l'herbe sous champignon doit rester payant.
func _current_max_speed() -> float:
	if boost_timer > 0.0:
		return stats.max_speed * stats.boost_speed_multiplier
	if on_offroad:
		return stats.max_speed * stats.offroad_speed_multiplier
	return stats.max_speed


func _update_speed(cmd: KartCommand, delta: float) -> void:
	var ceiling := _current_max_speed()

	if cmd.brake > 0.0:
		speed = move_toward(speed, 0.0, stats.brake_force * cmd.brake * delta)
	elif cmd.throttle > 0.0:
		speed = move_toward(speed, ceiling, stats.acceleration * cmd.throttle * delta)
	else:
		speed = move_toward(speed, 0.0, stats.coast_friction * delta)

	if speed > ceiling:
		speed = move_toward(speed, ceiling, stats.coast_friction * 2.0 * delta)
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `8 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: vitesse longitudinale du moteur de kart"
```

---

### Task 4 : Le moteur — braquage en adhérence

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

Ajoute à la fin de `tests/test_kart_motor.gd` :

```gdscript
func test_braquer_a_droite_fait_tourner_le_cap_a_droite() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	var depart := motor.velocity_dir
	cmd.steer = 1.0
	_run(1.0)
	assert_gt(motor.velocity_dir, depart, "braquer à droite doit augmenter le yaw")


func test_a_l_arret_le_kart_ne_tourne_pas() -> void:
	cmd.steer = 1.0
	_run(1.0)
	assert_almost_eq(motor.velocity_dir, 0.0, 0.001,
		"un kart immobile ne doit pas pouvoir pivoter sur place")


func test_en_adherence_la_caisse_suit_le_vecteur_vitesse() -> void:
	cmd.throttle = 1.0
	cmd.steer = 1.0
	_run(3.0)
	assert_almost_eq(motor.heading, motor.velocity_dir, 0.001,
		"hors dérapage, caisse et trajectoire sont alignées")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `test_braquer_a_droite_fait_tourner_le_cap_a_droite` échoue, `velocity_dir` restant à 0.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/kart/kart_motor.gd`, remplace `step()` par :

```gdscript
func step(cmd: KartCommand, delta: float) -> void:
	_update_speed(cmd, delta)
	_update_grip_steering(cmd, delta)
```

et ajoute ces deux méthodes à la fin du fichier :

```gdscript
## Le braquage perd son autorité à basse vitesse : un kart à l'arrêt
## ne pivote pas sur place, et l'effet monte progressivement.
func _steering_authority() -> float:
	return clampf(speed / (stats.max_speed * 0.5), 0.0, 1.0)


func _update_grip_steering(cmd: KartCommand, delta: float) -> void:
	velocity_dir += cmd.steer * stats.turn_rate * _steering_authority() * delta
	heading = velocity_dir
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `11 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: braquage en adhérence avec autorité indexée sur la vitesse"
```

---

### Task 5 : Le moteur — entrée en dérapage

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

```gdscript
func test_le_bouton_de_derapage_declenche_un_saut() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.state, KartMotor.State.HOP, "le dérapage commence par un saut")


func test_le_saut_debouche_sur_le_derapage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.state, KartMotor.State.DRIFT, "après le saut, le kart glisse")


func test_le_sens_de_glisse_est_verrouille_a_l_entree() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = -1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.1)
	assert_eq(motor.drift_dir, -1, "braquer à gauche verrouille une glisse à gauche")
	cmd.steer = 1.0
	_run(0.5)
	assert_eq(motor.drift_dir, -1, "le sens ne change pas en cours de glisse")


func test_pas_de_derapage_sans_braquage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.drift = true
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "le dérapage exige un braquage")


func test_pas_de_derapage_sous_la_vitesse_minimale() -> void:
	cmd.steer = 1.0
	cmd.drift = true
	_run(0.5)
	assert_eq(motor.state, KartMotor.State.GRIP, "trop lent pour déraper")


func test_relacher_le_bouton_pendant_le_saut_annule_le_derapage() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration * 0.5)
	cmd.drift = false
	_run(stats.hop_duration)
	assert_eq(motor.state, KartMotor.State.GRIP)
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `motor.drift_dir` n'existe pas et l'état reste `GRIP`.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `scripts/kart/kart_motor.gd`, ajoute ces variables sous `on_offroad` :

```gdscript
var drift_dir: int = 0          ## -1 gauche, +1 droite, 0 hors dérapage
var drift_charge: float = 0.0
var drift_angle: float = 0.0    ## écart caisse / trajectoire, en radians
var hop_timer: float = 0.0
```

Ajoute cette constante sous `enum State` :

```gdscript
const STEER_DEADZONE := 0.2
```

Remplace `step()` par :

```gdscript
func step(cmd: KartCommand, delta: float) -> void:
	_update_speed(cmd, delta)

	match state:
		State.GRIP:
			_update_grip_steering(cmd, delta)
			_try_enter_drift(cmd)
		State.HOP:
			_update_grip_steering(cmd, delta)
			_update_hop(cmd, delta)
```

et ajoute à la fin du fichier :

```gdscript
func _try_enter_drift(cmd: KartCommand) -> void:
	if not cmd.drift:
		return
	if absf(cmd.steer) < STEER_DEADZONE:
		return
	if speed < stats.min_drift_speed:
		return
	state = State.HOP
	hop_timer = stats.hop_duration
	drift_dir = 1 if cmd.steer > 0.0 else -1


func _update_hop(cmd: KartCommand, delta: float) -> void:
	hop_timer -= delta
	if hop_timer > 0.0:
		return
	if cmd.drift:
		state = State.DRIFT
		drift_charge = 0.0
		drift_angle = 0.0
	else:
		_end_drift()


## Retour en adhérence, sans turbo. Utilisé par les annulations.
func _end_drift() -> void:
	state = State.GRIP
	drift_dir = 0
	drift_charge = 0.0
	drift_angle = 0.0
	hop_timer = 0.0
	heading = velocity_dir
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `17 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: saut et entrée en dérapage avec verrouillage du sens"
```

---

### Task 6 : Le moteur — angle de glisse

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

```gdscript
## Amène le moteur en dérapage établi, dans le sens donné.
func _enter_drift(direction: int) -> void:
	cmd.throttle = 1.0
	_run(5.0)
	cmd.steer = float(direction)
	cmd.drift = true
	_run(stats.hop_duration + 0.5)


func test_en_derapage_la_caisse_se_decale_du_vecteur_vitesse() -> void:
	_enter_drift(1)
	var ecart := absf(motor.heading - motor.velocity_dir)
	assert_gt(ecart, deg_to_rad(stats.drift_angle_min_deg) * 0.5,
		"la caisse doit pointer nettement à côté de la trajectoire")


func test_l_angle_de_glisse_reste_dans_la_fourchette() -> void:
	_enter_drift(1)
	# On reste au-dessus de -0.8 : au-delà, le contre-braquage annule la glisse
	# et l'angle retombe à zéro (cf. Task 8).
	for braquage in [-0.7, -0.3, 0.0, 0.5, 1.0]:
		cmd.steer = braquage
		_run(0.5)
		var degres := rad_to_deg(motor.drift_angle)
		assert_between(degres, stats.drift_angle_min_deg - 0.5, stats.drift_angle_max_deg + 0.5,
			"angle hors fourchette pour un braquage de %f" % braquage)


func test_braquer_vers_l_interieur_resserre_la_glisse() -> void:
	_enter_drift(1)
	cmd.steer = 1.0
	_run(1.0)
	var serre := motor.drift_angle
	cmd.steer = 0.0
	_run(1.0)
	assert_gt(motor.drift_angle, serre,
		"relâcher le braquage vers l'intérieur ouvre l'angle de glisse")


func test_le_derapage_fait_tourner_la_trajectoire() -> void:
	_enter_drift(1)
	var depart := motor.velocity_dir
	_run(0.5)
	assert_gt(motor.velocity_dir, depart, "une glisse à droite courbe la trajectoire à droite")


func test_deraper_ne_coute_presque_pas_de_vitesse() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	var lancee := motor.speed
	cmd.steer = 1.0
	cmd.drift = true
	_run(2.0)
	assert_gt(motor.speed, lancee * 0.9,
		"le dérapage doit rester rentable, sinon le joueur l'évite")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `drift_angle` reste à 0, l'état `DRIFT` n'étant pas encore traité dans `step()`.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `step()`, ajoute une branche au `match` :

```gdscript
		State.DRIFT:
			_update_drift(cmd, delta)
```

Ajoute à la fin du fichier :

```gdscript
## Pendant la glisse, le braquage ne fait plus tourner le kart : il module
## l'angle entre la caisse et la trajectoire. Braquer vers l'intérieur de la
## courbe resserre l'angle, contre-braquer l'ouvre.
func _update_drift(cmd: KartCommand, delta: float) -> void:
	var inward := clampf(cmd.steer * float(drift_dir), -1.0, 1.0)
	var t := (inward + 1.0) * 0.5
	var target := deg_to_rad(lerpf(stats.drift_angle_max_deg, stats.drift_angle_min_deg, t))
	drift_angle = move_toward(drift_angle, target, deg_to_rad(stats.drift_angle_rate_deg) * delta)

	var max_angle := deg_to_rad(stats.drift_angle_max_deg)
	var courbure := drift_angle / max_angle
	velocity_dir += float(drift_dir) * stats.drift_turn_rate * courbure * delta
	heading = velocity_dir + float(drift_dir) * drift_angle

	drift_charge += delta
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `22 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: angle de glisse modulé par le braquage"
```

---

### Task 7 : Le moteur — charge et mini-turbo

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

```gdscript
func test_le_palier_se_deduit_du_temps_de_glisse() -> void:
	assert_eq(motor.tier_for_charge(0.0), 0)
	assert_eq(motor.tier_for_charge(0.5), 0, "sous le premier seuil, aucune charge")
	assert_eq(motor.tier_for_charge(0.7), 1)
	assert_eq(motor.tier_for_charge(1.6), 2)
	assert_eq(motor.tier_for_charge(3.0), 3)


func test_relacher_au_palier_2_declenche_un_turbo_de_palier_2() -> void:
	_enter_drift(1)
	motor.drift_charge = stats.drift_tiers[1] + 0.1
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_almost_eq(motor.boost_timer, stats.boost_durations[1], 0.05)
	assert_eq(motor.state, KartMotor.State.GRIP, "relâcher rend l'adhérence")


func test_relacher_trop_tot_ne_donne_aucun_turbo() -> void:
	_enter_drift(1)
	motor.drift_charge = 0.0
	cmd.drift = false
	motor.step(cmd, 1.0 / 60.0)
	assert_eq(motor.boost_timer, 0.0, "sous le premier seuil, pas de récompense")


func test_le_turbo_pousse_au_dela_de_la_vitesse_max() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 1.0
	motor.step(cmd, 1.0 / 60.0)
	assert_gt(motor.speed, stats.max_speed,
		"le turbo doit franchir le plafond normal, sinon il ne se sent pas")


func test_le_turbo_s_epuise_et_la_vitesse_redescend() -> void:
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 0.3
	_run(3.0)
	assert_eq(motor.boost_timer, 0.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.2,
		"une fois le turbo fini, la vitesse revient au plafond normal")


func test_on_peut_encore_deraper_pendant_un_turbo() -> void:
	cmd.throttle = 1.0
	_run(5.0)
	motor.boost_timer = 2.0
	cmd.steer = 1.0
	cmd.drift = true
	_run(stats.hop_duration + 0.2)
	assert_eq(motor.state, KartMotor.State.DRIFT,
		"le turbo est un modificateur, il ne doit pas bloquer le dérapage")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — `tier_for_charge` n'est pas définie.

- [ ] **Step 3 : Écrire l'implémentation**

Au début de `step()`, avant le `match`, ajoute l'écoulement du turbo :

```gdscript
	boost_timer = maxf(boost_timer - delta, 0.0)
```

Dans `_update_drift()`, remplace la dernière ligne `drift_charge += delta` par :

```gdscript
	drift_charge += delta

	if not cmd.drift:
		_release_drift()
```

Ajoute à la fin du fichier :

```gdscript
## Nombre de paliers franchis pour une charge donnée. 0 = aucun turbo.
func tier_for_charge(charge: float) -> int:
	var tier := 0
	for i in stats.drift_tiers.size():
		if charge >= stats.drift_tiers[i]:
			tier = i + 1
	return tier


func _release_drift() -> void:
	var tier := tier_for_charge(drift_charge)
	if tier > 0:
		boost_timer = stats.boost_durations[tier - 1]
	_end_drift()
```

Enfin, dans `_update_speed()`, le turbo doit pousser la vitesse et pas seulement lever le plafond. Remplace la méthode entière par :

```gdscript
func _update_speed(cmd: KartCommand, delta: float) -> void:
	var ceiling := _current_max_speed()

	if boost_timer > 0.0:
		# Le turbo pousse instantanément : c'est ce coup de pied qui se sent.
		speed = maxf(speed, ceiling)
	elif cmd.brake > 0.0:
		speed = move_toward(speed, 0.0, stats.brake_force * cmd.brake * delta)
	elif cmd.throttle > 0.0:
		speed = move_toward(speed, ceiling, stats.acceleration * cmd.throttle * delta)
	else:
		speed = move_toward(speed, 0.0, stats.coast_friction * delta)

	if speed > ceiling:
		speed = move_toward(speed, ceiling, stats.coast_friction * 2.0 * delta)
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `28 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: charge de dérapage, paliers et mini-turbo"
```

---

### Task 8 : Le moteur — annulations et hors-piste

**Files:**
- Modify: `scripts/kart/kart_motor.gd`
- Modify: `tests/test_kart_motor.gd`

- [ ] **Step 1 : Écrire les tests qui échouent**

```gdscript
func test_le_contre_braquage_annule_le_derapage_sans_turbo() -> void:
	_enter_drift(1)
	_run(stats.drift_tiers[2] + 0.5)
	cmd.steer = -1.0
	_run(0.2)
	assert_eq(motor.state, KartMotor.State.GRIP, "contre-braquer casse la glisse")
	assert_eq(motor.boost_timer, 0.0, "une glisse cassée ne rapporte rien, même chargée à fond")


func test_tomber_sous_la_vitesse_minimale_annule_le_derapage() -> void:
	_enter_drift(1)
	cmd.throttle = 0.0
	cmd.brake = 1.0
	_run(3.0)
	assert_eq(motor.state, KartMotor.State.GRIP)


func test_le_hors_piste_plafonne_la_vitesse() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(20.0)
	assert_almost_eq(motor.speed, stats.max_speed * stats.offroad_speed_multiplier, 0.1)


func test_revenir_sur_la_piste_rend_la_vitesse() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(20.0)
	motor.on_offroad = false
	_run(10.0)
	assert_almost_eq(motor.speed, stats.max_speed, 0.1)


func test_le_turbo_efface_la_penalite_hors_piste() -> void:
	motor.on_offroad = true
	cmd.throttle = 1.0
	_run(10.0)
	motor.boost_timer = 1.0
	motor.step(cmd, 1.0 / 60.0)
	assert_gt(motor.speed, stats.max_speed,
		"foncer dans l'herbe sous turbo doit rester payant")
```

- [ ] **Step 2 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC sur les deux tests d'annulation — l'état reste `DRIFT`.

- [ ] **Step 3 : Écrire l'implémentation**

Dans `_update_drift()`, remplace le bloc final par :

```gdscript
	drift_charge += delta

	if not cmd.drift:
		_release_drift()
		return

	# Une glisse cassée ne rapporte rien, quel que soit son niveau de charge.
	if speed < stats.min_drift_speed or inward < -0.8:
		_end_drift()
```

- [ ] **Step 4 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `33 passing`.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart_motor.gd tests/test_kart_motor.gd && rtk git commit -m "feat: annulation de dérapage et pénalité hors-piste"
```

---

### Task 9 : Les actions d'entrée

**Files:**
- Create: `tools/setup_input_map.gd`
- Create: `tests/test_input_map.gd`
- Modify: `project.godot`

La sérialisation des `InputEvent` dans `project.godot` change d'une version mineure de Godot à l'autre. Plutôt que d'écrire ce bloc à la main, on le fait générer par le moteur lui-même : le format est alors juste par construction.

- [ ] **Step 1 : Écrire le script de configuration**

`tools/setup_input_map.gd` :

```gdscript
extends SceneTree

## Écrit le bloc [input] de project.godot via l'API du moteur.
## Lancer une seule fois :
##   godot --headless --script tools/setup_input_map.gd
## `use_item` ne sert qu'à partir du plan 3, mais on le déclare maintenant
## pour ne pas rouvrir ce fichier.

const DEADZONE := 0.2


func _init() -> void:
	_axis_action("steer_left", KEY_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_axis_action("steer_right", KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_axis_action("throttle", KEY_UP, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_axis_action("brake", KEY_DOWN, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button_action("drift", KEY_SPACE, JOY_BUTTON_A)
	_button_action("use_item", KEY_CTRL, JOY_BUTTON_X)

	var err := ProjectSettings.save()
	if err != OK:
		printerr("échec de l'écriture de project.godot : %d" % err)
		quit(1)
		return
	print("input map écrite")
	quit()


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _axis_action(action: String, keycode: Key, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": DEADZONE,
		"events": [_key(keycode), motion],
	})


func _button_action(action: String, keycode: Key, button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": DEADZONE,
		"events": [_key(keycode), press],
	})
```

Les liaisons produites :

| Action | Clavier | Manette |
|---|---|---|
| `steer_left` | Flèche gauche | Stick gauche, axe X négatif |
| `steer_right` | Flèche droite | Stick gauche, axe X positif |
| `throttle` | Flèche haut | Gâchette droite |
| `brake` | Flèche bas | Gâchette gauche |
| `drift` | Espace | Bouton A / croix |
| `use_item` | Ctrl gauche | Bouton X / carré |

- [ ] **Step 2 : Écrire le test qui échoue**

`tests/test_input_map.gd` :

```gdscript
extends GutTest

const ACTIONS := [
	"steer_left", "steer_right", "throttle", "brake", "drift", "use_item",
]


func test_toutes_les_actions_de_pilotage_sont_declarees() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "action manquante : %s" % action)


func test_chaque_action_a_au_moins_une_liaison() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		assert_gt(InputMap.action_get_events(action).size(), 0,
			"l'action %s n'a aucune liaison" % action)
```

- [ ] **Step 3 : Lancer les tests pour vérifier qu'ils échouent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : ÉCHEC — les six actions sont absentes de l'`InputMap`.

- [ ] **Step 4 : Générer l'input map**

```bash
"$GODOT" --headless --script tools/setup_input_map.gd
```

Attendu : `input map écrite`.

- [ ] **Step 5 : Lancer les tests pour vérifier qu'ils passent**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `35 passing`.

- [ ] **Step 6 : Commit**

```bash
rtk git add tools/setup_input_map.gd tests/test_input_map.gd project.godot && rtk git commit -m "chore: actions d'entrée clavier et manette générées par le moteur"
```

---

### Task 10 : Les sources de commande

**Files:**
- Create: `scripts/kart/kart_input.gd`
- Create: `scripts/kart/player_input.gd`

- [ ] **Step 1 : Écrire la classe de base**

`scripts/kart/kart_input.gd` :

```gdscript
class_name KartInput
extends Node

## Source d'intention pour un kart. Les sous-classes remplissent `command`
## dans poll(). C'est le seul point de variation entre le joueur et l'IA :
## en aval, KartMotor ne sait pas qui lui parle.

var command := KartCommand.new()


## Met `command` à jour pour cette frame et la renvoie.
func poll(_delta: float) -> KartCommand:
	command.clear()
	return command
```

- [ ] **Step 2 : Écrire la source joueur**

`scripts/kart/player_input.gd` :

```gdscript
class_name PlayerInput
extends KartInput

## Lit le clavier et la manette. Aucune allocation : on réutilise
## l'instance de KartCommand héritée de KartInput.


func poll(_delta: float) -> KartCommand:
	command.steer = Input.get_axis(&"steer_left", &"steer_right")
	command.throttle = Input.get_action_strength(&"throttle")
	command.brake = Input.get_action_strength(&"brake")
	command.drift = Input.is_action_pressed(&"drift")
	command.use_item = Input.is_action_just_pressed(&"use_item")
	return command
```

- [ ] **Step 3 : Vérifier que les scripts compilent**

```bash
"$GODOT" --headless --check-only --script scripts/kart/player_input.gd
```

Attendu : aucune sortie, code de retour 0.

- [ ] **Step 4 : Commit**

```bash
rtk git add scripts/kart/kart_input.gd scripts/kart/player_input.gd && rtk git commit -m "feat: sources de commande, base et joueur"
```

---

### Task 11 : Le nœud Kart et sa scène

**Files:**
- Create: `scripts/kart/kart.gd`
- Create: `resources/karts/default_kart.tres`
- Create: `scenes/kart/kart.tscn`

- [ ] **Step 1 : Écrire le nœud**

`scripts/kart/kart.gd` :

```gdscript
class_name Kart
extends CharacterBody3D

## Relie la source de commande, le moteur et le déplacement réel.
## Ne contient aucune règle de pilotage : tout est dans KartMotor.

const GRAVITY := 30.0
const HOP_IMPULSE := 4.5

@export var stats: KartStats
@export var input_path: NodePath

var motor: KartMotor

var _input: KartInput
var _vertical: float = 0.0
var _was_hopping: bool = false


func _ready() -> void:
	assert(stats != null, "un Kart doit avoir une ressource KartStats")
	motor = KartMotor.new(stats)
	_input = get_node(input_path) as KartInput
	assert(_input != null, "input_path doit pointer vers un KartInput")
	motor.velocity_dir = rotation.y
	motor.heading = rotation.y


func _physics_process(delta: float) -> void:
	var cmd := _input.poll(delta)
	motor.step(cmd, delta)

	# Le saut d'entrée en dérapage, purement vertical.
	var hopping := motor.state == KartMotor.State.HOP
	if hopping and not _was_hopping:
		_vertical = HOP_IMPULSE
	_was_hopping = hopping

	if is_on_floor() and _vertical <= 0.0:
		_vertical = 0.0
	else:
		_vertical -= GRAVITY * delta

	# En Godot, l'avant d'un nœud 3D est -Z.
	var forward := Vector3(-sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))
	velocity = forward * motor.speed + Vector3.UP * _vertical
	move_and_slide()

	rotation.y = motor.heading
```

- [ ] **Step 2 : Créer la ressource de réglage**

`resources/karts/default_kart.tres`. Les champs non listés prennent les valeurs par défaut de `KartStats` ; c'est ce fichier qu'on éditera pendant les sessions de réglage.

```
[gd_resource type="Resource" script_class="KartStats" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/kart/kart_stats.gd" id="1_stats"]

[resource]
script = ExtResource("1_stats")
```

- [ ] **Step 3 : Écrire la scène du kart**

`scenes/kart/kart.tscn`. Version minimale : les particules et les visuels arrivent en Task 13.

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/kart/kart.gd" id="1_kart"]
[ext_resource type="Script" path="res://scripts/kart/player_input.gd" id="2_input"]
[ext_resource type="Resource" path="res://resources/karts/default_kart.tres" id="3_stats"]

[sub_resource type="BoxShape3D" id="Shape_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="BoxMesh" id="Mesh_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="StandardMaterial3D" id="Mat_body"]
albedo_color = Color(0.55, 0.55, 0.58, 1)

[node name="Kart" type="CharacterBody3D"]
script = ExtResource("1_kart")
stats = ExtResource("3_stats")
input_path = NodePath("PlayerInput")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
shape = SubResource("Shape_body")

[node name="Body" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
mesh = SubResource("Mesh_body")
surface_material_override/0 = SubResource("Mat_body")

[node name="PlayerInput" type="Node" parent="."]
script = ExtResource("2_input")
```

- [ ] **Step 4 : Vérifier que la scène charge**

```bash
"$GODOT" --headless --quit-after 60 scenes/kart/kart.tscn
```

Attendu : aucune ligne contenant `ERROR` ni `SCRIPT ERROR` dans la sortie. Un avertissement sur l'absence de caméra est normal.

Si Godot signale un `load_steps` incorrect, corrige le nombre : c'est le total des `ext_resource` et `sub_resource`, plus un.

- [ ] **Step 5 : Commit**

```bash
rtk git add scripts/kart/kart.gd resources/karts/default_kart.tres scenes/kart/kart.tscn && rtk git commit -m "feat: nœud Kart reliant commande, moteur et déplacement"
```

---

### Task 12 : La caméra de suivi

**Files:**
- Create: `scripts/camera/chase_camera.gd`

- [ ] **Step 1 : Écrire la caméra**

`scripts/camera/chase_camera.gd`. La sensation de vitesse vient presque entièrement d'ici : le retard du suivi et l'ouverture du FOV font davantage que la vitesse réelle du kart.

```gdscript
class_name ChaseCamera
extends Camera3D

## Suit le kart avec du retard et ouvre le champ de vision avec la vitesse.

@export var target_path: NodePath
@export var distance: float = 6.0
@export var height: float = 2.6
@export var follow_stiffness: float = 6.0
@export var look_ahead: float = 3.0
@export var fov_min: float = 70.0
@export var fov_max: float = 85.0
@export var drift_roll_deg: float = 6.0

var _kart: Kart
var _roll: float = 0.0


func _ready() -> void:
	_kart = get_node(target_path) as Kart
	assert(_kart != null, "target_path doit pointer vers un Kart")
	fov = fov_min


func _physics_process(delta: float) -> void:
	var motor := _kart.motor
	var forward := Vector3(-sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))

	var desired := _kart.global_position - forward * distance + Vector3.UP * height
	# Un suivi à ressort : la caméra se laisse distancer à l'accélération.
	global_position = global_position.lerp(desired, clampf(follow_stiffness * delta, 0.0, 1.0))

	look_at(_kart.global_position + forward * look_ahead + Vector3.UP * 0.8, Vector3.UP)

	var ratio := clampf(motor.speed / _kart.stats.max_speed, 0.0, 1.0)
	fov = lerpf(fov_min, fov_max, ratio)

	# Léger roulis dans la glisse, qui accentue la lecture du dérapage.
	# Le roulis est suivi à part : look_at() vient de réécrire la base, donc
	# lerper rotation.z directement repartirait de zéro à chaque frame.
	var target_roll := 0.0
	if motor.state == KartMotor.State.DRIFT:
		target_roll = deg_to_rad(drift_roll_deg) * float(motor.drift_dir)
	_roll = lerpf(_roll, target_roll, clampf(6.0 * delta, 0.0, 1.0))
	rotation.z = _roll
```

- [ ] **Step 2 : Vérifier que le script compile**

```bash
"$GODOT" --headless --check-only --script scripts/camera/chase_camera.gd
```

Attendu : aucune sortie, code de retour 0.

- [ ] **Step 3 : Commit**

```bash
rtk git add scripts/camera/chase_camera.gd && rtk git commit -m "feat: caméra de suivi à ressort avec FOV dynamique"
```

---

### Task 13 : Inclinaison et étincelles

**Files:**
- Create: `scripts/kart/kart_visuals.gd`
- Modify: `scenes/kart/kart.tscn`

- [ ] **Step 1 : Écrire les visuels**

`scripts/kart/kart_visuals.gd`. La couleur des étincelles est la seule interface de charge du jeu : pas de jauge dans le HUD.

```gdscript
class_name KartVisuals
extends Node3D

## Inclinaison de la caisse et étincelles dont la couleur annonce le palier
## de mini-turbo chargé. Purement cosmétique : ne modifie jamais le moteur.

const TIER_COLORS := [
	Color(0.35, 0.60, 1.00),   # palier 1 — bleu
	Color(1.00, 0.65, 0.14),   # palier 2 — orange
	Color(0.66, 0.33, 0.97),   # palier 3 — violet
]

@export var kart_path: NodePath
@export var body_path: NodePath
@export var sparks_path: NodePath
@export var max_lean_deg: float = 14.0

var _kart: Kart
var _body: Node3D
var _sparks: GPUParticles3D
var _spark_material: StandardMaterial3D


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	_body = get_node(body_path) as Node3D
	_sparks = get_node(sparks_path) as GPUParticles3D
	assert(_kart != null and _body != null and _sparks != null,
		"KartVisuals a besoin du kart, de la caisse et des particules")

	# Matériau propre à cette instance, sinon tous les karts changeraient
	# de couleur ensemble.
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sparks.material_override = _spark_material
	_sparks.emitting = false


func _process(delta: float) -> void:
	var motor := _kart.motor
	_update_lean(motor, delta)
	_update_sparks(motor)


func _update_lean(motor: KartMotor, delta: float) -> void:
	var lean := 0.0
	if motor.state == KartMotor.State.DRIFT:
		lean = -deg_to_rad(max_lean_deg) * float(motor.drift_dir)
	_body.rotation.z = lerpf(_body.rotation.z, lean, clampf(10.0 * delta, 0.0, 1.0))


func _update_sparks(motor: KartMotor) -> void:
	if motor.state != KartMotor.State.DRIFT:
		_sparks.emitting = false
		return

	var tier := motor.tier_for_charge(motor.drift_charge)
	if tier == 0:
		_sparks.emitting = false
		return

	_sparks.emitting = true
	_spark_material.albedo_color = TIER_COLORS[mini(tier, TIER_COLORS.size()) - 1]
```

- [ ] **Step 2 : Remplacer la scène du kart**

Réécris entièrement `scenes/kart/kart.tscn` :

```
[gd_scene load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/kart/kart.gd" id="1_kart"]
[ext_resource type="Script" path="res://scripts/kart/player_input.gd" id="2_input"]
[ext_resource type="Resource" path="res://resources/karts/default_kart.tres" id="3_stats"]
[ext_resource type="Script" path="res://scripts/kart/kart_visuals.gd" id="4_visuals"]

[sub_resource type="BoxShape3D" id="Shape_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="BoxMesh" id="Mesh_body"]
size = Vector3(1.2, 0.8, 1.8)

[sub_resource type="StandardMaterial3D" id="Mat_body"]
albedo_color = Color(0.55, 0.55, 0.58, 1)

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

[node name="Kart" type="CharacterBody3D"]
script = ExtResource("1_kart")
stats = ExtResource("3_stats")
input_path = NodePath("PlayerInput")

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

[node name="PlayerInput" type="Node" parent="."]
script = ExtResource("2_input")

[node name="Visuals" type="Node3D" parent="."]
script = ExtResource("4_visuals")
kart_path = NodePath("..")
body_path = NodePath("../Body")
sparks_path = NodePath("../Body/Sparks")
```

- [ ] **Step 3 : Vérifier**

```bash
"$GODOT" --headless --quit-after 60 scenes/kart/kart.tscn
```

Attendu : aucune ligne contenant `ERROR` ni `SCRIPT ERROR`.

- [ ] **Step 4 : Commit**

```bash
rtk git add scripts/kart/kart_visuals.gd scenes/kart/kart.tscn && rtk git commit -m "feat: inclinaison de la caisse et étincelles colorées par palier"
```

---

### Task 14 : Le terrain d'essai

**Files:**
- Create: `scripts/world/marker_field.gd`
- Create: `scenes/test_ground.tscn`
- Modify: `project.godot`

- [ ] **Step 1 : Écrire le champ de repères**

`scripts/world/marker_field.gd`. Sur un plan uniforme, aucune sensation de vitesse n'est perceptible et le point de validation serait invalidable. Un `MultiMesh` place quarante repères pour un seul draw call — la discipline de perf du spec commence ici.

```gdscript
class_name MarkerField
extends MultiMeshInstance3D

## Repères verticaux dispersés, pour donner une référence de vitesse
## et de distance sur un sol nu.

@export var count: int = 40
@export var field_radius: float = 90.0
@export var inner_radius: float = 12.0
@export var random_seed: int = 1


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 4.0, 1.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.52, 0.22)
	box.material = material

	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = box
	mesh.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for i in count:
		var angle := rng.randf() * TAU
		# La racine carrée répartit uniformément sur le disque plutôt que
		# de tout tasser au centre.
		var span := field_radius - inner_radius
		var dist := inner_radius + sqrt(rng.randf()) * span
		var pos := Vector3(cos(angle) * dist, 2.0, sin(angle) * dist)
		mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

	multimesh = mesh
```

- [ ] **Step 2 : Écrire le terrain**

`scenes/test_ground.tscn` :

```
[gd_scene load_steps=8 format=3]

[ext_resource type="PackedScene" path="res://scenes/kart/kart.tscn" id="1_kart"]
[ext_resource type="Script" path="res://scripts/camera/chase_camera.gd" id="2_camera"]
[ext_resource type="Script" path="res://scripts/world/marker_field.gd" id="3_markers"]

[sub_resource type="BoxShape3D" id="Shape_ground"]
size = Vector3(400, 1, 400)

[sub_resource type="PlaneMesh" id="Mesh_ground"]
size = Vector2(400, 400)

[sub_resource type="StandardMaterial3D" id="Mat_ground"]
albedo_color = Color(0.42, 0.44, 0.46, 1)

[sub_resource type="Environment" id="Env_sky"]
background_mode = 1
ambient_light_source = 2
ambient_light_color = Color(0.6, 0.68, 0.78, 1)
ambient_light_energy = 0.6

[node name="TestGround" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env_sky")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.766, -0.492, 0.414, 0, 0.643, 0.766, -0.643, -0.587, 0.492, 0, 20, 0)
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)
shape = SubResource("Shape_ground")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("Mesh_ground")
surface_material_override/0 = SubResource("Mat_ground")

[node name="Markers" type="MultiMeshInstance3D" parent="."]
script = ExtResource("3_markers")

[node name="Kart" parent="." instance=ExtResource("1_kart")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)

[node name="ChaseCamera" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3, 6)
script = ExtResource("2_camera")
target_path = NodePath("../Kart")
```

- [ ] **Step 3 : Définir la scène principale**

Dans `project.godot`, section `[application]`, ajoute :

```ini
run/main_scene="res://scenes/test_ground.tscn"
```

- [ ] **Step 4 : Vérifier que la scène charge**

```bash
"$GODOT" --headless --quit-after 120 scenes/test_ground.tscn
```

Attendu : aucune ligne contenant `ERROR` ni `SCRIPT ERROR`.

- [ ] **Step 5 : Lancer la suite de tests complète**

```bash
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Attendu : `35 passing`, `0 failing`.

- [ ] **Step 6 : Commit**

```bash
rtk git add scripts/world/marker_field.gd scenes/test_ground.tscn project.godot && rtk git commit -m "feat: terrain d'essai pour le point de validation du pilotage"
```

---

### Task 15 : Le point de validation

**Files:** aucun — c'est une session de jeu, pas une tâche de code.

Cette tâche ne peut pas être exécutée par un agent. Elle demande une manette, un écran et dix minutes.

- [ ] **Step 1 : Lancer le jeu**

```bash
"$GODOT" scenes/test_ground.tscn
```

- [ ] **Step 2 : Jouer au moins dix minutes**

C'est le jalon 3 du spec, et le seul qui puisse remettre en cause le reste du design. À vérifier :

- Le kart répond immédiatement, sans sensation de latence.
- Le dérapage s'enclenche de façon fiable et se tient sans lutter.
- Les trois couleurs d'étincelles sont distinguables d'un coup d'œil, sans quitter la route des yeux.
- Le mini-turbo se **sent** au déclenchement — si le coup de pied est discret, augmente `boost_speed_multiplier`.
- Enchaîner les dérapages en zigzag sur une ligne droite est plaisant et rentable.
- La vitesse se perçoit en passant près des repères.

- [ ] **Step 3 : Régler et commiter les valeurs retenues**

Les réglages se font dans `resources/karts/default_kart.tres`, moteur tournant : l'inspecteur applique les changements en direct.

```bash
rtk git add resources/karts/default_kart.tres && rtk git commit -m "tune: réglages de pilotage retenus après la session de validation"
```

**Si la conduite n'est pas agréable ici, ne passe pas au plan 2.** Aucune piste, aucune IA et aucun shader ne rattraperont un pilotage médiocre — et c'est précisément pour le découvrir maintenant que ce jalon existe.

---

## Périmètre de ce plan

**Livré :** un kart pilotable sur un plan nu, dérapage à trois paliers et mini-turbo, caméra dynamique, étincelles colorées, 33 tests unitaires sur la physique.

**Reporté au plan 2 :** suspension par quatre raycasts et alignement sur la pente, circuit réel, checkpoints, tours, chrono, IA.

**Reporté au plan 3 :** déclenchement de l'état `SONNÉ` et champ `use_item`, tous deux déjà présents dans le code mais inertes.

**Reporté au plan 5 :** le reste du §4.4 du spec — secousse au déclenchement du turbo, lignes de vitesse, son moteur indexé sur le régime, écrasement des suspensions à la réception.
