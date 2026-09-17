class_name KartMotor
extends RefCounted

## Toute la physique arcade du kart. Ne connaît ni la scène, ni les nœuds,
## ni le temps réel : il transforme (état, commande, delta) en nouvel état.
## C'est ce qui le rend testable sans lancer le jeu.

enum State { GRIP, HOP, DRIFT, STUNNED }

const STEER_DEADZONE := 0.2

var stats: KartStats

var state: int = State.GRIP
var speed: float = 0.0
var velocity_dir: float = 0.0   ## yaw du vecteur vitesse, en radians
var heading: float = 0.0        ## yaw de la caisse, en radians
var boost_timer: float = 0.0
var on_offroad: bool = false

var drift_dir: int = 0          ## -1 gauche, +1 droite, 0 hors dérapage
var drift_charge: float = 0.0
var drift_angle: float = 0.0    ## écart caisse / trajectoire, en radians
var hop_timer: float = 0.0


func _init(kart_stats: KartStats) -> void:
	stats = kart_stats


func step(cmd: KartCommand, delta: float) -> void:
	_update_speed(cmd, delta)

	match state:
		State.GRIP:
			_update_grip_steering(cmd, delta)
			_try_enter_drift(cmd)
		State.HOP:
			_update_grip_steering(cmd, delta)
			_update_hop(cmd, delta)


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


## Le braquage perd son autorité à basse vitesse : un kart à l'arrêt
## ne pivote pas sur place, et l'effet monte progressivement.
func _steering_authority() -> float:
	return clampf(speed / (stats.max_speed * 0.5), 0.0, 1.0)


func _update_grip_steering(cmd: KartCommand, delta: float) -> void:
	velocity_dir += cmd.steer * stats.turn_rate * _steering_authority() * delta
	heading = velocity_dir


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
