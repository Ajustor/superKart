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

const COUCHE_DECOR := 1
const COUCHE_KARTS := 2

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

## Faux pendant le décompte : la commande est lue puis ignorée, le kart reste
## sur sa case. La gravité, elle, continue de s'appliquer — un kart posé dix
## centimètres au-dessus de la route doit pouvoir s'y asseoir.
var controle_actif: bool = true

## Faux pour un kart piloté sur une autre machine, en réseau : il n'est pas
## simulé ici, RaceSync le pose là où son propriétaire dit qu'il est.
var simule: bool = true

## Vrai l'image où le pilote a demandé son objet. Posé ici, lu et remis à faux
## par ItemManager : le kart ne sait pas ce qu'il tient, il transmet la demande.
var demande_objet: bool = false

## Vrai tant que le kart touche le sol. La session s'en sert pour ne pas
## remettre en piste un kart qui survole le décor au milieu d'un saut.
var au_sol: bool = true

## Le pilote tient-il les gaz ? Lu même quand le kart ne répond pas encore,
## pendant le décompte : c'est ce que regarde le turbo au départ.
var gaz_tenu: bool = false

## Posé à vrai l'image où le kart quitte le sol en montant — sommet d'une
## rampe, rebord —, lu et remis à faux par la session.
var vient_de_decoller: bool = false

## Vitesse verticale, en m/s, que la rampe sous le kart lui donnerait s'il en
## quittait le sommet maintenant. Zéro hors d'une rampe. Renseignée par la
## session, qui connaît la rampe : c'est le seul endroit où perdre le sol en
## montant veut dire décoller.
var elan_de_rampe: float = 0.0

## En deçà de cette vitesse verticale, en m/s, un kart qui quitte une rampe ne
## décolle pas : il en descend.
const DECOLLAGE_MIN := 2.0

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

	# Les karts ne se voient pas dans la physique : ils ne se bloquent plus
	# comme des murs, et ne montent plus l'un sur l'autre. Leurs chocs sont
	# résolus à part, par KartCollisions. Couche 2 pour les karts, masque 1
	# pour ne heurter que le décor.
	collision_layer = COUCHE_KARTS
	collision_mask = COUCHE_DECOR


func _physics_process(delta: float) -> void:
	if not simule:
		return
	var cmd := _input.poll(delta)
	gaz_tenu = cmd.throttle > 0.5
	if not controle_actif:
		cmd.clear()
	# Un kart sonné ne lance rien : il a les mains prises.
	demande_objet = cmd.use_item and motor.state != KartMotor.State.STUNNED
	motor.step(cmd, delta)

	# Le saut d'entrée en dérapage, purement vertical.
	var hopping := motor.state == KartMotor.State.HOP
	if hopping and not _was_hopping:
		_vertical = stats.hop_impulse
	_was_hopping = hopping

	var etait_au_sol := au_sol
	au_sol = is_on_floor()
	# Le sol vient de se dérober sous un kart qui montait une rampe : il garde
	# sa vitesse verticale au lieu de la perdre d'un coup. Sans ça, une rampe
	# ne faisait pas sauter : le kart arrivait au sommet, et tombait du
	# rebord comme d'une marche.
	#
	# Sur les rampes seulement. Mesuré sur deux tours du circuit 1 : appliqué
	# partout, 87 décollages parasites dans les côtes, où un kart qui grimpe
	# à 15° monte déjà à 5,7 m/s et où le contact au sol vacille aux coutures
	# du maillage.
	#
	# Et calculée d'après la rampe, pas lue sur le kart : au sommet,
	# get_real_velocity() rendait -1,6 m/s, l'appui au sol l'emportant sur la
	# montée. Un saut calculé est en prime un saut prévisible, qu'on peut
	# dessiner.
	if elan_de_rampe > DECOLLAGE_MIN and etait_au_sol and not au_sol and _vertical <= 0.0:
		_vertical = elan_de_rampe
		vient_de_decoller = true
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
	_encaisser_les_murs()

	_orienter_la_caisse()


## Transmet au moteur les chocs que move_and_slide vient de résoudre. Seuls
## les murs comptent : une normale qui pointe vers le haut est un sol, même
## en pente.
func _encaisser_les_murs() -> void:
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if n.y < 0.6:
			motor.heurter_mur(n)


## Fait décoller le kart : un tremplin l'appelle. Refusé s'il est déjà en l'air
## ou en train de monter, sans quoi une zone de saut de quelques mètres le
## relancerait à chaque image qu'il passe au-dessus.
func sauter(impulsion: float) -> bool:
	if not au_sol or _vertical > 0.0:
		return false
	_vertical = impulsion
	au_sol = false
	return true


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


## Confie le kart à une autre source de commande. La session s'en sert pour
## passer le joueur en pilote automatique une fois la ligne franchie.
func changer_pilote(source: KartInput) -> void:
	assert(source != null, "un kart sans pilote ne se pilote pas")
	_input = source
	_input.kart = self


## La source de commande actuelle. ItemManager s'en sert pour dire à l'IA ce
## qu'elle tient.
func pilote() -> KartInput:
	return _input


func est_pilote_par_le_joueur() -> bool:
	return _input is PlayerInput


## Renseigné de l'extérieur par la session de course : le kart ne connaît pas
## le circuit, et le moteur encore moins.
func set_offroad(value: bool) -> void:
	motor.on_offroad = value
