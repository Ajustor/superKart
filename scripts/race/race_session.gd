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


func _ready() -> void:
	_track = get_node(track_path) as Track
	_kart = get_node(kart_path) as Kart
	assert(_track != null, "track_path doit pointer vers un Track")
	assert(_kart != null, "kart_path doit pointer vers un Kart")

	_kart.respawn_at(_track.spawn_at(DEPART))
	progress = RaceProgress.new(_track.track_curve, DEPART)
	_derniere_en_piste = DEPART


func _physics_process(delta: float) -> void:
	if finished:
		return

	var tours_avant := progress.lap
	progress.update(_kart.global_position)
	timer.advance(delta)

	if progress.lap > tours_avant:
		timer.complete_lap()
		if progress.lap >= lap_count:
			finished = true
			return

	# Une seule projection par image : is_off_track la referait entièrement,
	# et la remise en piste une troisième fois.
	var ecart := absf(_track.track_curve.lateral_offset(_kart.global_position))
	var dehors := ecart > _track.half_width
	_kart.set_offroad(dehors)
	if not dehors:
		# On remet en piste là où le kart roulait encore, pas là où la courbe
		# projette son point de sortie. Dans l'épingle la courbe se replie sur
		# elle-même : le point le plus proche d'une sortie de 29 m s'y trompe
		# de 48 m — en arrière d'un côté, mais en avant de l'autre. Reprojeter
		# ne punissait donc pas seulement la sortie de route, elle pouvait
		# aussi l'offrir en raccourci.
		_derniere_en_piste = progress.distance

	if _kart.global_position.y < FLOOR_LIMIT or ecart > _track.half_width + OFF_TRACK_RESPAWN_MARGIN:
		_kart.respawn_at(_track.spawn_at(_derniere_en_piste))
