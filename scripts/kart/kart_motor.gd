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
var on_offroad: bool = false    ## piloté de l'extérieur par la détection de terrain

var drift_dir: int = 0          ## -1 gauche, +1 droite, 0 hors dérapage
var drift_charge: float = 0.0
var drift_angle: float = 0.0    ## écart caisse / trajectoire, en radians
var hop_timer: float = 0.0
var _drift_locked_out: bool = false   ## une glisse cassée bloque jusqu'au relâchement


func _init(kart_stats: KartStats) -> void:
	stats = kart_stats


func step(cmd: KartCommand, delta: float) -> void:
	boost_timer = maxf(boost_timer - delta, 0.0)
	_update_speed(cmd, delta)

	match state:
		State.GRIP:
			_update_grip_steering(cmd, delta)
			_try_enter_drift(cmd)
		State.HOP:
			_update_grip_steering(cmd, delta)
			_update_hop(cmd, delta)
		State.DRIFT:
			_update_drift(cmd, delta)

	if not cmd.drift:
		_drift_locked_out = false


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

	if boost_timer > 0.0:
		# Le turbo pousse instantanément : c'est ce coup de pied qui se sent.
		speed = maxf(speed, ceiling)
	elif cmd.brake > 0.0:
		# Le frein ralentit d'abord, puis engage la marche arrière une fois le
		# kart arrêté : un seul bouton, deux rôles. Freiner est franc, reculer
		# est lent, d'où les deux taux distincts.
		var rate := stats.brake_force if speed > 0.0 else stats.reverse_acceleration
		var target := -stats.max_reverse_speed * cmd.brake
		speed = move_toward(speed, target, rate * cmd.brake * delta)
	elif cmd.throttle > 0.0:
		speed = move_toward(speed, ceiling, stats.acceleration * cmd.throttle * delta)
	else:
		speed = move_toward(speed, 0.0, stats.coast_friction * delta)

	if speed > ceiling:
		speed = move_toward(speed, ceiling, stats.boost_decay_rate * delta)


## Le braquage perd son autorité à basse vitesse : un kart à l'arrêt
## ne pivote pas sur place, et l'effet monte progressivement.
func _steering_authority() -> float:
	return clampf(absf(speed) / (stats.max_speed * 0.5), 0.0, 1.0)


func _update_grip_steering(cmd: KartCommand, delta: float) -> void:
	velocity_dir += cmd.steer * stats.turn_rate * _steering_authority() * delta
	heading = velocity_dir


func _try_enter_drift(cmd: KartCommand) -> void:
	if not cmd.drift:
		return
	if _drift_locked_out:
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
		hop_timer = 0.0
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


## Pendant la glisse, le braquage pilote deux choses distinctes : la courbure
## de la trajectoire, directement et proportionnellement, et l'angle de la
## caisse par rapport à cette trajectoire. Braquer vers l'intérieur resserre
## le virage et réduit l'angle de caisse ; contre-braquer élargit le virage
## et met la caisse plus en travers.
func _update_drift(cmd: KartCommand, delta: float) -> void:
	var inward := clampf(cmd.steer * float(drift_dir), -1.0, 1.0)
	var t := (inward + 1.0) * 0.5
	var target := deg_to_rad(lerpf(stats.drift_angle_max_deg, stats.drift_angle_min_deg, t))
	drift_angle = move_toward(drift_angle, target, deg_to_rad(stats.drift_angle_rate_deg) * delta)

	# La courbure suit le braquage, pas l'angle de glisse. Les dériver l'un de
	# l'autre inversait la commande : braquer vers l'intérieur ouvrait le rayon
	# et contre-braquer le resserrait, et l'entrée en glisse sous-virait le temps
	# que l'angle monte depuis zéro.
	var courbure := lerpf(0.5, 1.0, t)
	velocity_dir += float(drift_dir) * stats.drift_turn_rate * courbure * delta
	heading = velocity_dir + float(drift_dir) * drift_angle

	drift_charge += delta

	if not cmd.drift:
		_release_drift()
		return

	if _drift_is_broken(inward):
		_drift_locked_out = true
		_end_drift()


## Une glisse cassée ne rapporte rien, quel que soit son niveau de charge.
func _drift_is_broken(inward: float) -> bool:
	return speed < stats.min_drift_speed or inward < -0.8


## Nombre de paliers franchis pour une charge donnée. 0 = aucun turbo.
## Borné par le plus court des deux tableaux : un palier sans durée de
## turbo associée n'en est pas un, et indexer à l'aveugle planterait.
func tier_for_charge(charge: float) -> int:
	var count := mini(stats.drift_tiers.size(), stats.boost_durations.size())
	var tier := 0
	for i in count:
		if charge >= stats.drift_tiers[i]:
			tier = i + 1
	return tier


func _release_drift() -> void:
	var tier := tier_for_charge(drift_charge)
	if tier > 0:
		# Un turbo plus long déjà en cours ne doit pas être amputé par un
		# palier inférieur : enchaîner doit récompenser, pas punir.
		boost_timer = maxf(boost_timer, stats.boost_durations[tier - 1])
	_end_drift()


## Remet le moteur à neuf au cap donné, sans changer d'objet. Les nœuds de
## présentation gardent des références au moteur : le remplacer les
## détacherait en silence, sans erreur et sans test pour l'attraper.
func reset(yaw: float) -> void:
	state = State.GRIP
	speed = 0.0
	velocity_dir = yaw
	heading = yaw
	boost_timer = 0.0
	on_offroad = false
	drift_dir = 0
	drift_charge = 0.0
	drift_angle = 0.0
	hop_timer = 0.0
	_drift_locked_out = false
