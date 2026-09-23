class_name KartRumble
extends Node

## Retour de force de la manette du joueur. Purement cosmétique, comme
## KartVisuals : ne touche jamais au moteur, et ne sert qu'au kart du joueur —
## faire vibrer la manette pour un adversaire n'aurait aucun sens.
##
## Deux secousses, et pas une de plus : le coup de pied du mini-turbo, dont la
## force suit le palier, et le grondement sourd du hors-piste. Une manette qui
## vibre en permanence ne dit plus rien.

@export var kart_path: NodePath
@export var enabled: bool = true

## Durée de la secousse de turbo, en secondes. Volontairement plus courte que
## le turbo lui-même : c'est le départ qui se sent, pas la poussée entière.
@export var boost_pulse: float = 0.22

## Part de la secousse envoyée au moteur léger. Le moteur lourd porte le coup,
## le léger lui donne du grain.
@export var boost_weak_share: float = 0.45

## Grondement continu du hors-piste, sur le seul moteur léger : c'est une
## texture de sol, pas un choc.
@export var offroad_weak: float = 0.45

var _kart: Kart
var _manette: int = -1
var _pulse_restant: float = 0.0
var _pulse_force: float = 0.0
var _boost_precedent: float = 0.0
var _faible_en_cours: float = 0.0
var _fort_en_cours: float = 0.0


func _ready() -> void:
	_kart = get_node(kart_path) as Kart
	assert(_kart != null, "kart_path doit pointer vers un Kart")
	_rafraichir_manette()
	Input.joy_connection_changed.connect(_sur_branchement)
	enabled = GameSettings.vibrations
	GameSettings.changed.connect(_sur_reglages)


## Couper les vibrations en pleine secousse doit l'arrêter tout de suite, pas
## à la prochaine consigne.
func _sur_reglages() -> void:
	if enabled == GameSettings.vibrations:
		return
	enabled = GameSettings.vibrations
	_couper()


func _exit_tree() -> void:
	_couper()


## La force de la secousse se déduit du multiplicateur du turbo en cours plutôt
## que du palier : un seul nombre à lire, et l'échelle suit automatiquement si
## les paliers sont réglés. Rend 0 pour un turbo inexistant, 1 pour le plus fort.
static func force_de_turbo(multiplicateur: float, table: PackedFloat32Array) -> float:
	if table.is_empty():
		return 0.0
	var plafond := table[table.size() - 1]
	if plafond <= 1.0:
		return 0.0
	return clampf((multiplicateur - 1.0) / (plafond - 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	var motor := _kart.motor
	if motor == null:
		return

	_pulse_restant = maxf(_pulse_restant - delta, 0.0)

	# Front montant du turbo : un turbo qui se prolonge ne redéclenche rien,
	# sinon enchaîner les glisses ferait vibrer la manette sans discontinuer.
	if motor.boost_timer > _boost_precedent:
		_pulse_force = force_de_turbo(motor.boost_multiplier,
			_kart.stats.boost_speed_multipliers)
		_pulse_restant = boost_pulse
	_boost_precedent = motor.boost_timer

	var faible := 0.0
	var fort := 0.0
	if _pulse_restant > 0.0:
		fort = _pulse_force
		faible = _pulse_force * boost_weak_share
	elif motor.on_offroad:
		faible = offroad_weak

	_appliquer(faible, fort)


## N'appelle le moteur que lorsque la consigne change vraiment : relancer la
## vibration à chaque image la fait hoqueter sur une partie des pilotes.
func _appliquer(faible: float, fort: float) -> void:
	if is_equal_approx(faible, _faible_en_cours) and is_equal_approx(fort, _fort_en_cours):
		return
	_faible_en_cours = faible
	_fort_en_cours = fort

	if not enabled or _manette < 0:
		return
	if faible <= 0.0 and fort <= 0.0:
		Input.stop_joy_vibration(_manette)
	else:
		# Durée nulle = jusqu'à nouvel ordre. La coupure vient de l'appel
		# ci-dessus, pas d'un compte à rebours qui dériverait du nôtre.
		Input.start_joy_vibration(_manette, faible, fort, 0.0)


func _rafraichir_manette() -> void:
	var branchees := Input.get_connected_joypads()
	_manette = branchees[0] if not branchees.is_empty() else -1


func _sur_branchement(_device: int, _connecte: bool) -> void:
	_couper()
	_rafraichir_manette()


func _couper() -> void:
	if _manette >= 0:
		Input.stop_joy_vibration(_manette)
	_faible_en_cours = 0.0
	_fort_en_cours = 0.0
