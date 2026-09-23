class_name KartVisuals
extends Node3D

## Inclinaison de la caisse et étincelles dont la couleur annonce le palier
## de mini-turbo chargé. Purement cosmétique : ne modifie jamais le moteur.

## Les trois couleurs se lisent en vision périphérique, sans quitter la route
## des yeux : il leur faut donc à la fois de l'écart de teinte et de l'écart de
## luminosité. Le palier 3 tire vers le magenta plutôt que vers le violet, qui
## était trop proche du bleu du palier 1 et plus sombre que lui.
const TIER_COLORS := [
	Color(0.35, 0.60, 1.00),   # palier 1 — bleu      (teinte 217°, luma 0.58)
	Color(1.00, 0.65, 0.14),   # palier 2 — orange    (teinte  33°, luma 0.69)
	Color(1.00, 0.45, 0.88),   # palier 3 — magenta   (teinte 313°, luma 0.60)
]

@export var kart_path: NodePath
@export var body_path: NodePath
@export var sparks_path: NodePath
@export var max_lean_deg: float = 14.0
@export var lean_stiffness: float = 10.0

var _kart: Kart
var _body: Node3D
var _sparks: GPUParticles3D
var _spark_material: StandardMaterial3D
var _inclinaison: float = 0.0
## Le tonneau d'une figure, de 0 à 1 ; négatif hors figure.
var _figure: float = -1.0
const DUREE_FIGURE := 0.45
var _poussiere: CPUParticles3D
var _flammes: CPUParticles3D
var _matiere_flammes: StandardMaterial3D


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
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sparks.material_override = _spark_material
	_sparks.emitting = false
	_kart.figure.connect(func() -> void: _figure = 0.0)
	_poussiere = _creer_poussiere()
	add_child(_poussiere)
	_flammes = _creer_flammes()
	add_child(_flammes)


func _process(delta: float) -> void:
	var motor := _kart.motor
	_update_lean(motor, delta)
	_update_sparks(motor)
	# De la poussière sous les roues hors piste : on sent qu'on y perd.
	_poussiere.emitting = motor.on_offroad and _kart.au_sol and absf(motor.speed) > 5.0
	_update_flammes(motor)


func _update_lean(motor: KartMotor, delta: float) -> void:
	var lean := 0.0
	if motor.state == KartMotor.State.DRIFT:
		lean = -deg_to_rad(max_lean_deg) * float(motor.drift_dir)
	_inclinaison = lerpf(_inclinaison, lean, 1.0 - exp(-lean_stiffness * delta))
	# Un tonneau complet, vif au début et qui ralentit en fin de tour.
	var tonneau := 0.0
	if _figure >= 0.0:
		_figure += delta / DUREE_FIGURE
		if _figure >= 1.0:
			_figure = -1.0
		else:
			tonneau = TAU * (1.0 - pow(1.0 - _figure, 2.0))
	_body.rotation.z = _inclinaison + tonneau


## La recoloration est globale et instantanée : toutes les particules vivantes
## changent de couleur d'un coup. C'est volontaire — un dégradé par particule
## ferait cohabiter deux couleurs pendant une fraction de seconde à chaque
## changement de palier, soit exactement l'ambiguïté que ce signal doit éviter.
func _update_sparks(motor: KartMotor) -> void:
	var tier := 0
	if motor.state == KartMotor.State.DRIFT:
		tier = motor.tier_for_charge(motor.drift_charge)

	var should_emit := tier > 0
	if _sparks.emitting != should_emit:
		_sparks.emitting = should_emit
	if not should_emit:
		return

	var color: Color = TIER_COLORS[mini(tier, TIER_COLORS.size()) - 1]
	if _spark_material.albedo_color != color:
		_spark_material.albedo_color = color
	# Plus le palier est haut, plus la gerbe est fournie : on la lit du coin
	# de l'œil, sans regarder la couleur.
	_sparks.amount_ratio = [0.35, 0.7, 1.0][mini(tier, 3) - 1]


## Peu de particules, calculées par le processeur : quelques nuages beiges
## qui montent et s'étalent derrière le kart. Assez pour se voir, pas assez
## pour peser sur un téléphone.
func _creer_poussiere() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 18
	p.lifetime = 0.6
	p.position = Vector3(0.0, 0.15, 0.8)
	p.direction = Vector3(0.0, 1.0, 1.0)
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, -2.0, 0.0)
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 0.6))
	courbe.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = courbe
	var forme := SphereMesh.new()
	forme.radius = 0.25
	forme.height = 0.5
	forme.radial_segments = 6
	forme.rings = 3
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = Color(0.72, 0.62, 0.45, 0.55)
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	forme.material = matiere
	p.mesh = forme
	return p


## Des flammes aux pots d'échappement pendant un turbo, de la couleur de sa
## force : bleu pour un petit mini-turbo, orange pour un moyen ou un
## champignon, magenta pour le plus fort.
func _update_flammes(motor: KartMotor) -> void:
	var turbo := motor.boost_timer > 0.0
	_flammes.emitting = turbo
	if not turbo:
		return
	var couleur: Color = TIER_COLORS[0]
	if motor.boost_multiplier >= 1.45:
		couleur = TIER_COLORS[2]
	elif motor.boost_multiplier >= 1.3:
		couleur = TIER_COLORS[1]
	_matiere_flammes.albedo_color = couleur


func _creer_flammes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.18
	p.position = Vector3(0.0, 0.45, 1.05)
	p.direction = Vector3(0.0, 0.1, 1.0)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 1.0))
	courbe.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = courbe
	var forme := SphereMesh.new()
	forme.radius = 0.16
	forme.height = 0.32
	forme.radial_segments = 6
	forme.rings = 3
	_matiere_flammes = StandardMaterial3D.new()
	_matiere_flammes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_matiere_flammes.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_matiere_flammes.albedo_color = TIER_COLORS[0]
	forme.material = _matiere_flammes
	p.mesh = forme
	return p
