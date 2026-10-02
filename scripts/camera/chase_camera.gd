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

## La caméra d'arrivée : une fois la ligne franchie (ou le joueur éliminé en
## bataille), elle quitte l'arrière du kart et vient le montrer de face, puis
## tourne lentement autour de lui. Négatif tant qu'on court.
var orbite: float = -1.0
const ORBITE_DISTANCE := 5.6
const ORBITE_HAUTEUR := 1.9
## Le demi-tour, de derrière à devant, en secondes ; ensuite on tourne à
## peine, pour que l'image vive.
const ORBITE_DEMI_TOUR := 2.2
const ORBITE_LENTE := 0.25
const FOV_ARRIVEE := 58.0


func _ready() -> void:
	_kart = get_node(target_path) as Kart
	assert(_kart != null, "target_path doit pointer vers un Kart")
	fov = fov_min
	var session := get_node_or_null("../Session") as RaceSession
	if session != null:
		session.arrivee.connect(func(e: RaceEntry) -> void:
			if e.kart == _kart and orbite < 0.0:
				orbite = 0.0)


## Passe derrière un autre kart, d'un coup (la course du menu, voir
## CourseDeFond).
func suivre(kart: Kart) -> void:
	_kart = kart
	_placee = false
	_vitesse_avant = kart.motor.speed
	orbite = -1.0


func _physics_process(delta: float) -> void:
	var motor := _kart.motor
	if orbite >= 0.0:
		_tourner_autour(delta)
		return
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


## L'angle de la caméra autour du kart, `t` secondes après l'arrivée : 0 est
## derrière lui, PI devant.
static func angle_d_orbite(t: float) -> float:
	var demi := clampf(t / ORBITE_DEMI_TOUR, 0.0, 1.0)
	# Démarrage et arrivée en douceur sur le demi-tour, puis la lente dérive.
	return PI * (demi * demi * (3.0 - 2.0 * demi)) + maxf(t - ORBITE_DEMI_TOUR, 0.0) * ORBITE_LENTE


func _tourner_autour(delta: float) -> void:
	orbite += delta
	var cap := _kart.motor.heading
	var angle := cap + PI + angle_d_orbite(orbite)
	# Le cap du moteur compte comme une boussole (voir Kart) : derrière le
	# kart, c'est -avant.
	var autour := Vector3(sin(angle), 0.0, -cos(angle))
	var voulu := _kart.global_position + autour * ORBITE_DISTANCE + Vector3.UP * ORBITE_HAUTEUR
	# Le kart roule encore (pilote automatique) : un suivi à ressort resterait
	# à la traîne et finirait collé à la caisse. Seul le passage depuis la
	# caméra de poursuite est adouci ; ensuite l'angle, déjà lissé, suffit.
	var passage := clampf(orbite / 0.5, 0.0, 1.0)
	global_position = global_position.lerp(voulu, lerpf(1.0 - exp(-8.0 * delta), 1.0, passage))
	look_at(_kart.global_position + Vector3.UP * 0.6, Vector3.UP)
	fov = lerpf(fov, FOV_ARRIVEE, 1.0 - exp(-3.0 * delta))
	h_offset = 0.0
	v_offset = 0.0
