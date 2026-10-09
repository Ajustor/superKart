class_name KartSuspension
extends Node3D

## Quatre amortisseurs, quatre rayons vers le sol, et la caisse qui s'assied
## dessus. Purement cosmétique, comme KartVisuals : ne modifie jamais le moteur.
##
## C'est délibéré, et c'est ce que fait un jeu de kart. Le pilotage y est arcade
## — une vitesse, un cap — et la suspension ne fait que le raconter : elle
## plonge au freinage, s'assied à l'accélération, roule dans les virages et se
## détend dans les sauts. Lui confier la trajectoire reviendrait à réécrire
## KartMotor et à jeter ses quarante-cinq tests pour un gain de réalisme que
## personne ne demande à un jeu de kart.
##
## La physique du ressort, elle, est réelle : c'est KartSpring, qui est testé.

@export var kart_path: NodePath

## La caisse, que la suspension fait plonger et tanguer. Elle n'y touche pas
## elle-même : elle dit de combien (`enfoncement`, `tangage`), et KartVisuals
## compose le tout avec le roulis de la glisse et le tonneau des figures, puis
## relève la caisse si elle passait sous sa hauteur de repos.
@export var body_path: NodePath

## Les quatre roues, dans l'ordre : avant gauche, avant droite, arrière gauche,
## arrière droite. Chacune est un Node3D que la suspension monte et descend.
@export var wheel_paths: Array[NodePath] = []

@export_group("Ressorts")
@export var rest_length: float = 0.26
@export var travel: float = 0.13
@export var stiffness: float = 260.0
@export var damping: float = 26.0

@export_group("Roues")
@export var wheel_radius: float = 0.17
## Braquage visible des roues avant, en degrés à fond de commande.
@export var steer_angle_deg: float = 26.0
## Vitesse à laquelle les roues avant suivent la commande, en 1/s.
@export var steer_stiffness: float = 14.0

@export_group("Transfert de masse")
## Tassement supplémentaire, en mètres par m/s² d'accélération. C'est lui qui
## fait plonger le nez au freinage et asseoir l'arrière à la remise des gaz.
##
## Sans lui, la suspension ne ferait que se détendre : la caisse est tenue à
## hauteur fixe par sa boîte de collision, donc seul un creux de la route fait
## travailler une roue — mesuré, elles n'utilisaient que la moitié haute de leur
## débattement et jamais la basse.
@export var load_transfer: float = 0.004

## Idem pour l'accélération latérale : les roues extérieures encaissent.
@export var roll_transfer: float = 0.003

@export_group("Caisse")
## Tangage maximal de la caisse, en degrés, quand l'avant et l'arrière sont
## complètement désaccordés.
@export var max_pitch_deg: float = 7.0
## Hauteur dont la caisse descend quand les quatre roues sont en butée.
@export var max_squat: float = 0.07

var _kart: Kart
var _body: Node3D
var _wheels: Array[Node3D] = []
var _springs: Array[KartSpring] = []

## Point d'attache de chaque roue dans le repère du kart, figé au montage.
##
## Figé, parce que prendre la position COURANTE de la roue rebouclait : la roue
## descendait dans son fourreau, donc l'ancrage descendait avec elle, donc le
## rayon partait de plus bas, donc la roue redescendait encore. Les quatre
## ressorts ne prenaient plus que leurs deux butées, jamais rien entre.
var _ancres: Array[Vector3] = []
## Ce que la caisse descend sous sa hauteur de repos, et son tangage (positif :
## le nez se lève), lus par KartVisuals.
var enfoncement: float = 0.0
var tangage: float = 0.0
var _spin: float = 0.0
var _steer: float = 0.0
var _vitesse_precedente: float = 0.0
var _cap_precedent: float = 0.0


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	_body = get_node(body_path) as Node3D
	assert(_kart != null and _body != null,
		"KartSuspension a besoin du kart et de la caisse")
	# Le kart la rappelle aux remises en piste. Il vit très bien sans elle :
	# le terrain d'essai n'a pas de suspension.
	_kart.suspension = self

	for chemin in wheel_paths:
		var roue := get_node_or_null(chemin) as Node3D
		assert(roue != null, "chaque entrée de wheel_paths doit pointer vers un Node3D")
		_wheels.append(roue)
		_ancres.append(roue.position)
		var ressort := KartSpring.new(rest_length, travel, stiffness, damping)
		# On naît posé, pas en pleine détente : sinon la première image écrase
		# les quatre ressorts d'un coup et le kart s'assied brutalement.
		ressort.length = rest_length - travel * 0.5
		_springs.append(ressort)


func _physics_process(delta: float) -> void:
	if _wheels.is_empty():
		return

	var espace := get_world_3d().direct_space_state
	var base := _kart.global_basis
	var bas := -base.y
	var charges := _transfert_de_masse(delta)

	for i in _wheels.size():
		# L'ancrage tourne avec la caisse, comme le ferait un vrai bras, mais ne
		# descend jamais avec la roue.
		var ancrage := _kart.global_position + base * _ancres[i]
		# La charge se retranche de la distance au sol : une roue plus chargée
		# se comporte comme si le sol était remonté vers elle. Le ressort, lui,
		# reste ignorant de tout ça — c'est ce qui le garde testable.
		var contact := _sonder(espace, ancrage, bas)
		var distance := contact
		if distance < INF:
			distance -= charges[i]
		_springs[i].step(distance, delta)
		# La roue pend sous son ancrage, de la longueur du ressort, mais n'est
		# jamais dessinée sous le sol qu'elle touche : une roue délestée
		# (charge négative) visait plus bas que le contact, et passait sous la
		# route de 9 cm. Le ressort garde sa physique ; une roue en l'air pend.
		_wheels[i].position = Vector3(
			_ancres[i].x, _ancres[i].y - minf(_springs[i].length, contact), _ancres[i].z)

	_tourner_les_roues(delta)
	_asseoir_la_caisse()


## Distance au sol depuis l'ancrage, le long du fourreau. INF quand la roue ne
## touche rien. Le rayon descend un peu plus bas que la butée de détente, sinon
## la roue ne verrait jamais le sol qu'elle est sur le point d'atteindre.
func _sonder(espace: PhysicsDirectSpaceState3D, depuis: Vector3, bas: Vector3) -> float:
	var requete := PhysicsRayQueryParameters3D.create(
		depuis, depuis + bas * (rest_length + wheel_radius))
	# Le kart lui-même n'est pas un sol : sans ça chaque roue verrait la boîte
	# de collision de son propre châssis.
	requete.exclude = [_kart.get_rid()]
	var touche := espace.intersect_ray(requete)
	if touche.is_empty():
		return INF
	return (touche["position"] as Vector3).distance_to(depuis) - wheel_radius


## Tassement supplémentaire de chaque roue, en mètres, dû au report de charge.
##
## Dérivé de ce que fait le moteur plutôt que de la vitesse réelle du corps :
## move_and_slide() renvoie une vitesse déjà corrigée par les collisions, qui
## sursaute à chaque contact et ferait tressauter la caisse pour rien.
func _transfert_de_masse(delta: float) -> Array[float]:
	var moteur := _kart.motor
	var longitudinal := (moteur.speed - _vitesse_precedente) / maxf(delta, 0.0001)
	_vitesse_precedente = moteur.speed

	# Accélération latérale = vitesse fois taux de rotation, la formule du
	# mouvement circulaire. Positive vers la droite, convention boussole.
	var taux := wrapf(moteur.velocity_dir - _cap_precedent, -PI, PI) / maxf(delta, 0.0001)
	_cap_precedent = moteur.velocity_dir
	var lateral := taux * moteur.speed

	longitudinal = clampf(longitudinal, -30.0, 30.0)
	lateral = clampf(lateral, -30.0, 30.0)

	var charges: Array[float] = []
	for i in _wheels.size():
		# Avant = les deux premières. Accélérer charge l'arrière, freiner l'avant.
		var devant := 1.0 if i < 2 else -1.0
		# Droite = indices impairs. Tourner à droite charge la gauche.
		var droite := 1.0 if i % 2 == 1 else -1.0
		charges.append(-longitudinal * devant * load_transfer
			- lateral * droite * roll_transfer)
	return charges


## Fait tourner les roues et braquer celles de devant. Le braquage suit la
## commande avec un peu de retard : une direction qui claque d'une butée à
## l'autre en une image se voit, et se voit mal.
func _tourner_les_roues(delta: float) -> void:
	_spin += _kart.motor.speed / maxf(wheel_radius, 0.01) * delta
	var vise := 0.0
	if _kart.motor.state == KartMotor.State.DRIFT:
		# En glisse, les roues avant pointent là où la caisse est braquée, pas
		# là où le kart va : c'est ce contre-braquage qui se lit à l'écran.
		vise = float(_kart.motor.drift_dir)
	else:
		vise = clampf(_kart.motor.heading - _kart.motor.velocity_dir, -1.0, 1.0)
	_steer = lerpf(_steer, vise, 1.0 - exp(-steer_stiffness * delta))

	for i in _wheels.size():
		var braquage := deg_to_rad(steer_angle_deg) * _steer if i < 2 else 0.0
		# Le braquage compte à la boussole, Godot à l'envers, comme partout.
		_wheels[i].rotation = Vector3(_spin, -braquage, 0.0)


## Assied la caisse sur les quatre ressorts : elle descend de leur tassement
## moyen, et tangue de leur désaccord avant/arrière.
func _asseoir_la_caisse() -> void:
	var avant := (_springs[0].compression() + _springs[1].compression()) * 0.5
	var arriere := (_springs[2].compression() + _springs[3].compression()) * 0.5
	var moyenne := (avant + arriere) * 0.5

	enfoncement = moyenne * max_squat
	# Avant tassé = nez qui plonge. Un tangage positif autour de +X lève le nez
	# dans Godot, d'où le signe.
	tangage = deg_to_rad(max_pitch_deg) * (arriere - avant)


## Détend les quatre ressorts. Appelé à la remise en piste : une roue qui garde
## sa vitesse fait tressauter la caisse à l'arrivée.
func reset() -> void:
	for ressort in _springs:
		ressort.reset()
	_spin = 0.0
	_steer = 0.0
	_vitesse_precedente = 0.0
	_cap_precedent = _kart.motor.velocity_dir if _kart != null and _kart.motor != null else 0.0
	for i in _wheels.size():
		_springs[i].length = rest_length - travel * 0.5
		_wheels[i].position = Vector3(
			_ancres[i].x, _ancres[i].y - _springs[i].length, _ancres[i].z)
		_wheels[i].rotation = Vector3.ZERO
	enfoncement = 0.0
	tangage = 0.0
