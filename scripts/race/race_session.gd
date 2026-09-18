class_name RaceSession
extends Node

## Met le kart et le circuit en rapport. Le kart ignore le circuit, le circuit
## ignore le kart : c'est ici et nulle part ailleurs que les deux se parlent.

const FLOOR_LIMIT := -10.0
const OFF_TRACK_RESPAWN_MARGIN := 3.0

## Distance de départ le long de l'axe. Nommée plutôt que répétée en zéro :
## les trois endroits qui la citent doivent bouger ensemble, et la grille
## décalée du plan 3 les fera tous bouger.
const DEPART := 0.0

@export var track_path: NodePath
@export var kart_path: NodePath
@export var lap_count: int = 3

var progress: RaceProgress
var timer := RaceTimer.new()
var finished: bool = false

var _track: Track
var _kart: Kart
var _derniere_en_piste: float = 0.0
var _demi_largeur: float = 0.0
var _tours_comptes: int = 0


func _ready() -> void:
	# get_node lèverait l'erreur avant l'assert, et les assert disparaissent en
	# export release : le message n'aurait servi à personne.
	var piste := get_node_or_null(track_path) as Track
	var kart := get_node_or_null(kart_path) as Kart
	assert(piste != null, "track_path doit pointer vers un Track")
	assert(kart != null, "kart_path doit pointer vers un Kart")
	demarrer(piste, kart)


## Prend le circuit et le kart en paramètres plutôt que de les lire dans
## l'arbre : c'est toute la différence entre une logique testable et une
## logique qu'on ne peut qu'espérer juste.
func demarrer(piste: Track, pilote: Kart) -> void:
	assert(lap_count > 0, "une course sans tour à boucler ne finit jamais")
	_track = piste
	_kart = pilote
	# TrackCurve porte déjà sa propre copie de la demi-largeur, et c'est elle
	# que is_off_track compare : deux sources pour la même valeur finissent
	# toujours par diverger.
	_demi_largeur = _track.track_curve.half_width
	_kart.respawn_at(_track.spawn_at(DEPART))
	progress = RaceProgress.new(_track.track_curve, DEPART)
	_derniere_en_piste = DEPART


func _physics_process(delta: float) -> void:
	avancer(_kart.global_position, delta)


## Le point est passé plutôt que lu sur le kart : global_position exige
## l'arbre de scènes, et c'est le seul obstacle qui rendait cette logique
## intestable.
func avancer(point: Vector3, delta: float) -> void:
	progress.update(point)

	# La comptabilité s'arrête à l'arrivée ; le monde, lui, continue.
	if not finished:
		timer.advance(delta)
		# progress.lap n'est pas monotone : il redescend quand le kart recule.
		# Se déclencher sur sa montée enregistrait un tour à chaque
		# franchissement, donc reculer sur la ligne d'arrivée fabriquait un
		# meilleur temps de deux images. On compte sur une ligne de crue.
		if progress.lap > _tours_comptes:
			_tours_comptes = progress.lap
			timer.complete_lap()
			if _tours_comptes >= lap_count:
				finished = true

	# Une seule projection par image : is_off_track la referait entièrement,
	# et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(point))
	var dehors := ecart > _demi_largeur
	_kart.set_offroad(dehors)
	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie. Dans l'épingle la courbe se replie sur
		# elle-même : le point le plus proche d'une sortie de 29 m s'y trompe
		# de 48 m — en arrière d'un côté, mais en avant de l'autre. Reprojeter
		# ne punissait donc pas seulement la sortie de route, elle pouvait
		# aussi l'offrir en raccourci.
		_derniere_en_piste = progress.distance

	if point.y < FLOOR_LIMIT or ecart > _demi_largeur + OFF_TRACK_RESPAWN_MARGIN:
		_kart.respawn_at(_track.spawn_at(_derniere_en_piste))
