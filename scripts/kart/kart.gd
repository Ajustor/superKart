class_name Kart
extends CharacterBody3D

## Relie la source de commande, le moteur et le déplacement réel.
## Toute la physique horizontale vit dans KartMotor. L'axe vertical
## (saut, gravité, contact au sol, pente) reste ici parce qu'il est couplé à
## move_and_slide() et is_on_floor() — c'est la seule physique non couverte
## par les tests.
##
## Le moteur reste résolument plat : il ne connaît que des caps boussole et une
## vitesse scalaire. C'est ici qu'on couche cette intention sur le relief, en
## projetant la direction de marche sur le plan du sol. Le moteur n'a donc rien
## à apprendre des pentes, et ses 45 tests restent valides.

@export var stats: KartStats
@export var input_path: NodePath

## Vitesse de redressement de la caisse vers la normale du sol, en 1/s. Brute,
## la normale saute d'une facette à l'autre du maillage extrudé et la caisse
## tremblerait à chaque segment.
@export var ground_align_stiffness: float = 10.0

## Appui vers le sol tant qu'on le touche, en m/s. Ce n'est pas de la physique,
## c'est du pilotage arcade : il empêche le kart de décoller à chaque cassure
## de pente sans rien changer à sa vitesse le long de la route.
@export var ground_grip_push: float = 6.0

## Temps de retour à plat en l'air, en 1/s. Plus mou que le redressement au
## sol : un kart qui saute garde son assiette un instant, il ne se remet pas
## à l'horizontale d'un coup.
@export var air_align_stiffness: float = 3.0

var motor: KartMotor

var _input: KartInput
var _vertical: float = 0.0
var _was_hopping: bool = false
var _normale := Vector3.UP


## Renseignée par KartSuspension quand elle existe : le terrain d'essai n'en a
## pas, et le kart doit rouler sans elle.
var suspension: KartSuspension


func _ready() -> void:
	assert(stats != null, "un Kart doit avoir une ressource KartStats")
	motor = KartMotor.new(stats)
	_input = get_node(input_path) as KartInput
	assert(_input != null, "input_path doit pointer vers un KartInput")
	_input.kart = self
	motor.velocity_dir = -rotation.y
	motor.heading = -rotation.y

	# Sans accrochage, le kart décolle à chaque rupture de pente : à 22 m/s et
	# 20°, la route se dérobe de 13 cm par image, bien plus que les 10 cm par
	# défaut. Une fois en l'air, is_on_floor() tombe et la pente ne le porte plus.
	floor_snap_length = 0.6


func _physics_process(delta: float) -> void:
	var cmd := _input.poll(delta)
	motor.step(cmd, delta)

	# Le saut d'entrée en dérapage, purement vertical.
	var hopping := motor.state == KartMotor.State.HOP
	if hopping and not _was_hopping:
		_vertical = stats.hop_impulse
	_was_hopping = hopping

	var au_sol := is_on_floor()
	if au_sol and _vertical <= 0.0:
		_vertical = 0.0
	else:
		_vertical -= stats.gravity * delta

	# La normale BRUTE pilote la trajectoire, la lissée ne sert qu'à l'œil.
	# Les confondre coûtait cher : à 10 d'amortissement, la normale lissée a
	# 0,17 s de retard, soit 3,7 m à 22 m/s. Sur une rupture de pente elle
	# pointe encore vers le ciel et catapulte le kart — 74 % du tour en l'air.
	var contact := get_floor_normal() if au_sol else Vector3.UP
	if contact.length_squared() < 0.0001:
		contact = Vector3.UP
	_suivre_le_sol(au_sol, delta)

	# Le moteur compte ses angles comme une boussole : lacet positif = vers la
	# droite. Godot compte l'inverse — une rotation positive autour de +Y tourne
	# vers la gauche. La conversion se fait ici, au seul endroit où les deux
	# repères se rencontrent, plutôt que d'éparpiller des signes dans la physique.
	var cap := Vector3(sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))
	var marche := _le_long_de_la_pente(cap, contact)
	velocity = marche * motor.speed + Vector3.UP * _vertical

	# Appui : tant qu'on touche, on pousse vers le sol. Sans ça le kart quitte
	# la route à chaque bosse et n'y revient qu'en retombant, plusieurs mètres
	# plus loin — un kart arcade colle à la piste, il ne fait pas du saut à ski.
	if au_sol and _vertical <= 0.0:
		velocity -= contact * ground_grip_push

	move_and_slide()

	_orienter_la_caisse()


## Lisse la normale du sol sous le kart. En l'air, elle revient doucement à la
## verticale plutôt que d'un coup : on garde l'assiette du tremplin un instant.
func _suivre_le_sol(au_sol: bool, delta: float) -> void:
	var cible := Vector3.UP
	var raideur := air_align_stiffness
	if au_sol:
		var n := get_floor_normal()
		if n.length_squared() > 0.0001:
			cible = n
			raideur = ground_align_stiffness
	_normale = _normale.lerp(cible, 1.0 - exp(-raideur * delta)).normalized()


## Couche la direction de marche sur le plan du sol. À plat c'est l'identité ;
## en descente le kart plonge au lieu de s'envoler, en montée il grimpe au lieu
## de labourer la pente — et dans les deux cas il parcourt bien motor.speed
## mètres par seconde SUR la route, pas sur sa projection horizontale.
func _le_long_de_la_pente(cap: Vector3, normale: Vector3) -> Vector3:
	var couche := cap - normale * cap.dot(normale)
	if couche.length_squared() < 0.000001:
		return cap
	return couche.normalized()


## Assied la caisse sur le sol : l'avant plonge en descente, se lève en montée,
## et le kart s'incline dans le dévers. Le lacet reste celui du moteur, angle de
## glisse compris, parce que c'est lui qui dit où le kart regarde.
func _orienter_la_caisse() -> void:
	var cap := Vector3(sin(motor.heading), 0.0, -cos(motor.heading))
	var droite := cap.cross(_normale)
	if droite.length_squared() < 0.000001:
		rotation.y = -motor.heading
		return
	droite = droite.normalized()
	# Godot regarde vers -Z, d'où le dernier axe inversé.
	global_basis = Basis(droite, _normale, -_normale.cross(droite).normalized())


## Remet le kart à un état neutre à la position donnée. Le terrain d'essai
## s'en sert ; la remise en piste du circuit aussi.
func respawn_at(where: Transform3D) -> void:
	global_transform = where
	velocity = Vector3.ZERO
	_vertical = 0.0
	_was_hopping = false
	# L'assiette repart de celle de la route : sans ça le kart renaît à plat au
	# milieu d'une pente et bascule dès la première image.
	_normale = where.basis.y.normalized()
	motor.reset(-where.basis.get_euler().y)
	if suspension != null:
		# Une roue qui garde sa vitesse au moment de la téléportation fait
		# tressauter la caisse à l'arrivée.
		suspension.reset()


## Renseigné de l'extérieur par la session de course : le kart ne connaît pas
## le circuit, et le moteur encore moins.
func set_offroad(value: bool) -> void:
	motor.on_offroad = value
