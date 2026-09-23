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
@export var roll_stiffness: float = 6.0

## Degrés de champ en plus pendant un turbo : la route s'étire, on sent la
## poussée même quand la vitesse de pointe est déjà atteinte.
@export var fov_turbo: float = 8.0
## Une perte de vitesse plus brutale que ça en une image est un choc : mur,
## autre kart, objet. Freiner à fond n'en retire que 0,4 m/s.
const CHOC_MIN := 1.5
const SECOUSSE_PAR_MS := 0.035
const SECOUSSE_MAX := 0.45
const AMORTI_SECOUSSE := 9.0

var _kart: Kart
var _roll: float = 0.0
var _fov_turbo: float = 0.0
var _vitesse_avant: float = 0.0
var _en_l_air: bool = false
## Amplitude de la secousse, en mètres ; retombe d'elle-même.
var secousse: float = 0.0

## Faux jusqu'à la première image : la caméra se pose alors directement derrière
## le kart. Sans ça elle partait de l'origine du monde et traversait le décor
## pendant tout le décompte, pile quand le joueur regarde sa case.
var _placee: bool = false


func _ready() -> void:
	_kart = get_node(target_path) as Kart
	assert(_kart != null, "target_path doit pointer vers un Kart")
	fov = fov_min


func _physics_process(delta: float) -> void:
	var motor := _kart.motor
	var forward := Vector3(sin(motor.velocity_dir), 0.0, -cos(motor.velocity_dir))

	var desired := _kart.global_position - forward * distance + Vector3.UP * height
	# Un suivi à ressort : la caméra se laisse distancer à l'accélération.
	if _placee:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_stiffness * delta))
	else:
		global_position = desired
		_placee = true

	look_at(_kart.global_position + forward * look_ahead + Vector3.UP * 0.8, Vector3.UP)

	# Le plafond de référence inclut le turbo, sinon le FOV sature dès la
	# vitesse de pointe normale et le mini-turbo ne se voit plus du tout.
	var multiplicateurs := _kart.stats.boost_speed_multipliers
	var plafond_turbo: float = multiplicateurs[multiplicateurs.size() - 1] if not multiplicateurs.is_empty() else 1.0
	var ceiling := _kart.stats.max_speed * plafond_turbo
	var ratio := clampf(motor.speed / ceiling, 0.0, 1.0)
	var turbo := 1.0 if motor.boost_timer > 0.0 else 0.0
	_fov_turbo = lerpf(_fov_turbo, turbo, 1.0 - exp(-8.0 * delta))
	fov = lerpf(fov_min, fov_max, ratio) + fov_turbo * _fov_turbo

	_secouer(motor, delta)

	# Léger roulis dans la glisse, qui accentue la lecture du dérapage.
	# Le roulis est suivi à part : look_at() vient de réécrire la base, donc
	# lerper rotation.z directement repartirait de zéro à chaque frame.
	var target_roll := 0.0
	if motor.state == KartMotor.State.DRIFT:
		target_roll = deg_to_rad(drift_roll_deg) * float(motor.drift_dir)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-roll_stiffness * delta))
	rotation.z = _roll


## Une secousse à chaque choc, et à l'atterrissage d'un vrai saut. Mesurée
## sur ce que le kart perd de vitesse d'une image à l'autre : pas besoin que
## chaque source de choc prévienne la caméra.
func _secouer(motor: KartMotor, delta: float) -> void:
	var chute := _vitesse_avant - motor.speed
	_vitesse_avant = motor.speed
	if chute > CHOC_MIN:
		secousse = minf(secousse + chute * SECOUSSE_PAR_MS, SECOUSSE_MAX)
	if _en_l_air and _kart.au_sol:
		secousse = minf(secousse + 0.12, SECOUSSE_MAX)
	_en_l_air = _kart.en_saut and not _kart.au_sol
	secousse *= exp(-AMORTI_SECOUSSE * delta)
	# Par le décalage de l'objectif et non la position : le suivi à ressort
	# repartirait sinon de la position secouée, et la secousse traînerait.
	h_offset = randf_range(-1.0, 1.0) * secousse if secousse > 0.005 else 0.0
	v_offset = randf_range(-1.0, 1.0) * secousse if secousse > 0.005 else 0.0
