class_name KartMotor
extends RefCounted

## Toute la physique arcade du kart. Ne connaît ni la scène, ni les nœuds,
## ni le temps réel : il transforme (état, commande, delta) en nouvel état.
## C'est ce qui le rend testable sans lancer le jeu.

enum State { GRIP, HOP, DRIFT, STUNNED }

const STEER_DEADZONE := 0.2

## Tout champ mutable ajouté ci-dessous doit aussi être remis à neuf dans
## reset() : la remise en piste ne reconstruit plus le moteur, donc un champ
## oublié y survivrait en silence.
var stats: KartStats

var state: int = State.GRIP
var speed: float = 0.0
var velocity_dir: float = 0.0   ## yaw du vecteur vitesse, en radians
var heading: float = 0.0        ## yaw de la caisse, en radians
var boost_timer: float = 0.0

## Force du turbo en cours, en multiple de max_speed. Retenue ici plutôt que
## relue dans les stats parce qu'elle dépend du palier qui l'a déclenchée.
## Vaut le palier le plus faible au repos : un turbo accordé directement, sans
## passer par une glisse, doit pousser quand même.
var boost_multiplier: float = 1.0
var on_offroad: bool = false    ## piloté de l'extérieur par la détection de terrain

## Adhérence du sol, de 1 (bitume) à près de 0 (verglas). Pilotée de
## l'extérieur, comme on_offroad. En deçà de 1, le nez tourne mais la
## trajectoire ne le suit qu'avec retard : le kart glisse, et accélère mal.
var adherence: float = 1.0
## Vitesse à laquelle la trajectoire rejoint le nez à pleine adhérence, en
## 1/s : multipliée par l'adhérence, 0,3 sur la glace donne un retard d'une
## demi-seconde.
const RAPPEL_D_ADHERENCE := 6.0
## Sur la glace, le nez répond un peu plus vite : on pivote, puis on glisse.
const BRAQUAGE_SUR_GLACE := 1.25
var _sur_glace: bool = false

var drift_dir: int = 0          ## -1 gauche, +1 droite, 0 hors dérapage
var drift_charge: float = 0.0
var drift_angle: float = 0.0    ## écart caisse / trajectoire, en radians
var hop_timer: float = 0.0
## Secondes depuis le début de la glisse en cours (voir stats.drift_entree).
var temps_en_glisse: float = 0.0
## Le stick pendant la glisse, lissé : 0 à fond vers l'extérieur, 1 à fond
## vers l'intérieur (voir stats.drift_modulation_vitesse).
var modulation: float = 0.5

## Temps restant en tête-à-queue. Un compteur et non une machine à états de
## plus, comme le prévoyait la spec : l'état STUNNED existait déjà.
var stun_timer: float = 0.0

## Temps restant sous étoile : intouchable, plus rapide, et l'herbe ne freine
## plus. Un kart qui en percute un autre sous étoile le fait tourner.
var etoile: float = 0.0
## Temps restant rétréci par un éclair : plus lent, le temps de regrandir.
var retreci: float = 0.0
## Pièces ramassées : chacune ajoute un peu de vitesse de pointe, et un choc
## en fait perdre.
var pieces: int = 0

const DUREE_ETOILE := 7.0
const VITESSE_ETOILE := 1.25
const DUREE_RETRECI := 5.0
const VITESSE_RETRECI := 0.72
const PIECES_MAX := 10
const BONUS_PAR_PIECE := 0.01
const PIECES_PERDUES := 3

## Un palier de charge vient d'être franchi pendant la glisse : les
## étincelles changent de couleur, un son l'annonce.
signal palier_atteint(palier: int)
## Une glisse relâchée assez chargée : le mini-turbo part.
signal mini_turbo(palier: int)
## Un mur heurté : `force` est la vitesse, en m/s, qui rentrait dans le mur.
signal choc_mur(force: float)

var palier_courant: int = 0
var _derapage_avant: bool = false
var _drift_locked_out: bool = false   ## une glisse cassée bloque jusqu'au relâchement


func _init(kart_stats: KartStats) -> void:
	stats = kart_stats
	boost_multiplier = _plancher_de_turbo()


## Le plus faible des multiplicateurs, ou 1.0 si la table est vide.
func _plancher_de_turbo() -> float:
	return stats.boost_speed_multipliers[0] if not stats.boost_speed_multipliers.is_empty() else 1.0


func step(cmd: KartCommand, delta: float) -> void:
	_pas(cmd, delta)
	_derapage_avant = cmd.drift


func _pas(cmd: KartCommand, delta: float) -> void:
	boost_timer = maxf(boost_timer - delta, 0.0)
	etoile = maxf(etoile - delta, 0.0)
	retreci = maxf(retreci - delta, 0.0)
	if boost_timer == 0.0:
		# Sans ça, la force d'un palier 3 terminé s'appliquerait au turbo
		# suivant, même accordé par une glisse à peine chargée.
		boost_multiplier = _plancher_de_turbo()
	if state == State.STUNNED:
		_update_stun(delta)
		if not cmd.drift:
			_drift_locked_out = false
		return

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
	var base := vitesse_de_pointe()
	if boost_timer > 0.0:
		return base * maxf(boost_multiplier, VITESSE_ETOILE if etoile > 0.0 else 0.0)
	if etoile > 0.0:
		return base * VITESSE_ETOILE
	if on_offroad:
		return base * stats.offroad_speed_multiplier
	return base


## La vitesse de pointe sans turbo ni herbe : celle des stats, plus les
## pièces, moins un éclair.
func vitesse_de_pointe() -> float:
	var v := stats.max_speed * (1.0 + BONUS_PAR_PIECE * pieces)
	if retreci > 0.0:
		v *= VITESSE_RETRECI
	return v


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
		# Sous étoile, on reprend sa vitesse deux fois plus vite.
		var acceleration := stats.acceleration * (2.0 if etoile > 0.0 else 1.0)
		# Les roues patinent sur la glace.
		acceleration *= lerpf(0.6, 1.0, clampf(adherence, 0.0, 1.0))
		speed = move_toward(speed, ceiling, acceleration * cmd.throttle * delta)
	else:
		speed = move_toward(speed, 0.0, stats.coast_friction * delta)

	if speed > ceiling:
		speed = move_toward(speed, ceiling, stats.boost_decay_rate * delta)


## Le braquage perd son autorité à basse vitesse : un kart à l'arrêt
## ne pivote pas sur place, et l'effet monte progressivement.
func _steering_authority() -> float:
	return clampf(absf(speed) / (stats.max_speed * 0.5), 0.0, 1.0)


## En marche arrière, comme en voiture : braquer à gauche envoie l'arrière
## à gauche, donc le nez à droite. Sans ce changement de signe, la direction
## paraît inversée dès qu'on recule.
func _update_grip_steering(cmd: KartCommand, delta: float) -> void:
	var sens := -1.0 if speed < 0.0 else 1.0
	var virage := cmd.steer * sens * stats.turn_rate * _steering_authority() * delta
	if adherence >= 1.0:
		if _sur_glace:
			# Le nez a raison : sortant d'une glissade, la trajectoire
			# reprend là où il pointe.
			_sur_glace = false
			velocity_dir = heading
		velocity_dir += virage
		heading = velocity_dir
		return
	_sur_glace = true
	heading += virage * BRAQUAGE_SUR_GLACE
	velocity_dir = lerp_angle(velocity_dir, heading,
		1.0 - exp(-RAPPEL_D_ADHERENCE * maxf(adherence, 0.0) * delta))


## Un appui sur DRIFT fait toujours sauter le kart, braquage ou pas : c'est
## pendant le saut qu'on choisit son côté, comme dans Mario Kart. Sans
## direction à l'atterrissage, ce n'était qu'un saut.
##
## Tenu sans braquer, le bouton ne refait pas sauter en boucle : seul un
## nouvel appui, ou un braquage bouton tenu, lance un saut.
func _try_enter_drift(cmd: KartCommand) -> void:
	if not cmd.drift:
		return
	if _drift_locked_out:
		return
	# Le bond se fait à toute vitesse, même à l'arrêt, comme dans Mario Kart :
	# c'est la glisse qui demande de la vitesse, vérifiée à l'atterrissage.
	var braque := absf(cmd.steer) >= STEER_DEADZONE
	if not braque and _derapage_avant:
		return
	state = State.HOP
	hop_timer = stats.hop_duration
	drift_dir = (1 if cmd.steer > 0.0 else -1) if braque else 0


func _update_hop(cmd: KartCommand, delta: float) -> void:
	# Le côté se choisit jusqu'à l'atterrissage : le dernier braquage l'emporte.
	if absf(cmd.steer) >= STEER_DEADZONE:
		drift_dir = 1 if cmd.steer > 0.0 else -1
	hop_timer -= delta
	if hop_timer > 0.0:
		return
	if cmd.drift and drift_dir != 0 and speed >= stats.min_drift_speed:
		state = State.DRIFT
		hop_timer = 0.0
		temps_en_glisse = 0.0
		# La glisse part du braquage de l'atterrissage, sans rattrapage.
		modulation = (clampf(cmd.steer * float(drift_dir), -1.0, 1.0) + 1.0) * 0.5
		drift_charge = 0.0
		drift_angle = 0.0
		palier_courant = 0
	else:
		# Un simple saut. Braqué mais trop lent pour glisser, bouton encore
		# tenu : il faudra le relâcher pour en refaire un, sans quoi le kart
		# sautillerait tout seul. Sans braquage, pas besoin : un bouton tenu
		# sans braquer ne relance pas de bond, et braquer ensuite doit lancer
		# la glisse (bouton tenu dès le départ, avant d'avoir la vitesse).
		if cmd.drift and drift_dir != 0:
			_drift_locked_out = true
		_end_drift()


## Retour en adhérence, sans turbo. Utilisé par les annulations.
func _end_drift() -> void:
	state = State.GRIP
	palier_courant = 0
	drift_dir = 0
	drift_charge = 0.0
	drift_angle = 0.0
	hop_timer = 0.0
	heading = velocity_dir


## Pendant la glisse, le stick module le virage, comme dans Mario Kart 8 :
## vers l'intérieur on serre et la caisse se met plus en travers, vers
## l'extérieur on ouvre en grand et la caisse se redresse. La glisse ne
## change jamais de côté : contre-braquer l'élargit, sans l'inverser.
func _update_drift(cmd: KartCommand, delta: float) -> void:
	var inward := clampf(cmd.steer * float(drift_dir), -1.0, 1.0)
	var t := (inward + 1.0) * 0.5
	modulation = move_toward(modulation, t, stats.drift_modulation_vitesse * delta)
	var target := deg_to_rad(lerpf(stats.drift_angle_min_deg, stats.drift_angle_max_deg, modulation))
	drift_angle = move_toward(drift_angle, target, deg_to_rad(stats.drift_angle_rate_deg) * delta)

	temps_en_glisse += delta
	var entree := smoothstep(0.0, maxf(stats.drift_entree, 0.001), temps_en_glisse)
	velocity_dir += float(drift_dir) * stats.drift_turn_rate * rapport_de_glisse(modulation) \
		* lerpf(stats.drift_entree_debut, 1.0, entree) * delta
	heading = velocity_dir + float(drift_dir) * drift_angle

	# Serrer le virage charge plus vite ; contre-braquer, plus lentement.
	drift_charge += delta * lerpf(stats.charge_au_contre_braquage, 1.0, modulation)
	var palier := tier_for_charge(drift_charge)
	if palier > palier_courant:
		palier_courant = palier
		palier_atteint.emit(palier)

	if not cmd.drift:
		_release_drift()
		return

	if _drift_is_broken(inward):
		_drift_locked_out = true
		_end_drift()


## La part de drift_turn_rate pour une modulation donnée : l'extérieur, le
## neutre et l'intérieur, reliés en deux segments.
func rapport_de_glisse(m: float) -> float:
	if m < 0.5:
		return lerpf(stats.drift_rapport_exterieur, stats.drift_rapport_neutre, m * 2.0)
	return lerpf(stats.drift_rapport_neutre, 1.0, (m - 0.5) * 2.0)


## Une glisse cassée ne rapporte rien, quel que soit son niveau de charge.
## Seule la vitesse la casse (ou un mur) : contre-braquer élargit la glisse,
## il ne l'interrompt pas — c'est ce qui permet de la tenir tout un virage.
func _drift_is_broken(_inward: float) -> bool:
	return speed < stats.min_drift_speed


## Nombre de paliers franchis pour une charge donnée. 0 = aucun turbo.
## Borné par le plus court des deux tableaux : un palier sans durée de
## turbo associée n'en est pas un, et indexer à l'aveugle planterait.
func tier_for_charge(charge: float) -> int:
	var count := mini(stats.drift_tiers.size(),
		mini(stats.boost_durations.size(), stats.boost_speed_multipliers.size()))
	var tier := 0
	for i in count:
		if charge >= stats.drift_tiers[i]:
			tier = i + 1
	return tier


func _release_drift() -> void:
	var tier := tier_for_charge(drift_charge)
	if tier > 0:
		# Un turbo plus long déjà en cours ne doit pas être amputé par un
		# palier inférieur : enchaîner doit récompenser, pas punir. La force
		# suit la même règle, sans quoi un petit palier affaiblirait un gros
		# turbo encore en cours.
		boost_timer = maxf(boost_timer, stats.boost_durations[tier - 1])
		boost_multiplier = maxf(boost_multiplier, stats.boost_speed_multipliers[tier - 1])
		mini_turbo.emit(tier)
	_end_drift()


## Tête-à-queue : les commandes sont ignorées, la caisse pivote sur elle-même
## et le kart ralentit sur sa lancée. Rend faux si le kart tournait déjà —
## un kart sonné ne se fait pas sonner une deuxième fois, sans quoi deux
## bananes rapprochées le cloueraient au sol.
func stun() -> bool:
	if state == State.STUNNED or etoile > 0.0:
		return false
	pieces = maxi(pieces - PIECES_PERDUES, 0)
	_end_drift()
	state = State.STUNNED
	stun_timer = stats.stun_duration
	# Un turbo en cours s'éteint : sinon le kart touché repartirait plein
	# pot en tournant sur lui-même.
	boost_timer = 0.0
	boost_multiplier = _plancher_de_turbo()
	return true


func _update_stun(delta: float) -> void:
	stun_timer = maxf(stun_timer - delta, 0.0)
	speed = move_toward(speed, 0.0, stats.stun_deceleration * delta)
	# La caisse tourne, la trajectoire non : c'est ce qui fait un tête-à-queue
	# et non un virage.
	var vitesse_rotation := TAU * stats.stun_spin_turns / maxf(stats.stun_duration, 0.001)
	heading += vitesse_rotation * delta
	if stun_timer <= 0.0:
		state = State.GRIP
		heading = velocity_dir


## L'étoile : un tête-à-queue en cours s'arrête net, et plus rien ne touche
## le kart le temps qu'elle dure.
func prendre_etoile() -> void:
	etoile = DUREE_ETOILE
	if state == State.STUNNED:
		state = State.GRIP
		stun_timer = 0.0
		heading = velocity_dir


## L'éclair d'un autre : tête-à-queue et rétréci. Rend faux sous étoile.
func foudroyer() -> bool:
	if etoile > 0.0:
		return false
	retreci = DUREE_RETRECI
	stun()
	return true


func gagner_pieces(n: int) -> void:
	pieces = clampi(pieces + n, 0, PIECES_MAX)


## La poussée du champignon. Même mécanique que le mini-turbo, et même règle :
## un turbo plus fort ou plus long déjà en cours n'est pas amputé.
func boost_objet() -> void:
	accorder_turbo(stats.mushroom_duration, stats.mushroom_speed_multiplier)


## Un turbo venu d'ailleurs que d'une glisse : champignon, tremplin.
func accorder_turbo(duree: float, multiplicateur: float) -> void:
	if state == State.STUNNED or duree <= 0.0:
		return
	boost_timer = maxf(boost_timer, duree)
	boost_multiplier = maxf(boost_multiplier, multiplicateur)


## Choc contre un mur, dont `normale` est la normale horizontale, tournée
## vers le kart. La vitesse qui rentre dans le mur est perdue, celle qui le
## longe est gardée : on frotte un mur de biais, on s'arrête contre un mur de
## face. La trajectoire se couche le long du mur.
##
## Sans ça, move_and_slide arrêtait bien la caisse, mais le moteur ignorait le
## choc : il croyait rouler à 22 m/s contre un mur, et repartait d'un coup dès
## qu'on s'en écartait.
func heurter_mur(normale: Vector3) -> void:
	var n := Vector3(normale.x, 0.0, normale.z)
	if n.length_squared() < 0.0001 or speed <= 0.0:
		return
	n = n.normalized()
	var marche := Vector3(sin(velocity_dir), 0.0, -cos(velocity_dir))
	var enfoncement := -marche.dot(n)
	if enfoncement <= 0.0:
		return  # on s'éloigne déjà du mur
	var longe := marche + n * enfoncement
	choc_mur.emit(speed * enfoncement)
	speed *= 1.0 - stats.wall_speed_loss * enfoncement
	if state == State.DRIFT or state == State.HOP:
		# Une glisse contre un mur est une glisse ratée.
		_drift_locked_out = true
		_end_drift()
	if longe.length_squared() > 0.0001 and enfoncement < 0.95:
		velocity_dir = atan2(longe.x, -longe.z)
		if state == State.GRIP:
			heading = velocity_dir


## Remet le moteur à neuf au cap donné, sans changer d'objet. Les nœuds de
## présentation gardent des références au moteur : le remplacer les
## détacherait en silence, sans erreur et sans test pour l'attraper.
func reset(yaw: float) -> void:
	state = State.GRIP
	speed = 0.0
	velocity_dir = yaw
	heading = yaw
	boost_timer = 0.0
	boost_multiplier = _plancher_de_turbo()
	etoile = 0.0
	retreci = 0.0
	# Une remise en piste coûte ses pièces, comme un choc.
	pieces = maxi(pieces - PIECES_PERDUES, 0)
	on_offroad = false
	adherence = 1.0
	_sur_glace = false
	drift_dir = 0
	drift_charge = 0.0
	drift_angle = 0.0
	hop_timer = 0.0
	temps_en_glisse = 0.0
	modulation = 0.5
	stun_timer = 0.0
	_drift_locked_out = false
